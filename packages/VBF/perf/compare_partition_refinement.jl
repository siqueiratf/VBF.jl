#!/usr/bin/env julia
# Public native API versus the external Kaleyski–Sunde C++ reference core.
using VBF, Random, Statistics, SHA, BenchmarkTools, TOML, Dates
isdefined(@__MODULE__, :PerfSupport) || include(joinpath(@__DIR__, "support.jl"))
using .PerfSupport: source_manifest

function fixtures(; hard = false)
    rng = Xoshiro(940)
    cases = Tuple{String,Symbol,SBox,SBox,Bool}[]
    for n in (5, 7, 8)
        F = gold_apn(n, 1)
        inner = random_affine_permutation(rng, Val(n))
        outer = random_affine_permutation(rng, Val(n))
        drift = random_linear_function(rng, Val(n))
        G = SBox{n}([outer(F(inner(x))) ⊻ drift(x) for x in 0:((1 << n)-1)])
        push!(cases, ("gold$(n)_positive", :ea, F, G, true))
    end
    push!(cases, ("gold5_negative", :ccz, gold_apn(5, 1), gold_apn(5, 2), false))
    push!(cases, ("gold8_negative", :ccz, gold_apn(8, 1), gold_apn(8, 3), false))
    push!(cases, ("kim_dillon_ccz", :ccz, kim_apn(), dillon_apn_permutation(), true))
    push!(cases, ("kim_dillon_ea", :ea, kim_apn(), dillon_apn_permutation(), false))
    F = random_function_sbox(rng, Val(8))
    G = SBox{8}([F(x ⊻ 37) ⊻ 81 for x in 0:255])
    push!(cases, ("random8_positive", :ea, F, G, true))
    hard && push!(cases, ("gold7_negative", :ccz, gold_apn(7, 1), gold_apn(7, 2), false))
    return cases
end

function verify(result, F, G, ea, expected)
    result isa BudgetHit && error("benchmark is inconclusive: $(result.where_it_stopped)")
    (result isa Found) == expected || error("wrong decision")
    if result isa Found
        A = only(search_solutions(result))
        is_invertible(A) && ccz_equivalent_function(F, A) == G || error("wrong certificate")
        ea && !all(c -> c >> inputbits(F) == 0, A.linear.cols[1:inputbits(F)]) &&
            error("wrong EA block form")
    end
end

function save_diagnostic(trials,label,args,config,summary)
    options=filter(a->startswith(a,"--out="),args)
    out=isempty(options) ? joinpath(PerfSupport.ROOT,"packages","VBFPaper","bench","data","VBF",
        label*"_"*Dates.format(now(UTC),"yyyymmddTHHMMSS")*"_"*string(getpid())) : only(options)[7:end]
    ispath(out) && error("diagnostic output already exists: $out")
    mkpath(out)
    manifest=source_manifest("VBF";config)
    manifest["measurement_protocol"]="BenchmarkTools diagnostic trials v1"
    manifest["validation"]="every measured result verified outside timing; equivalence outcomes and witnesses checked"
    # Bind the diagnostic's C++ driver as well as the Julia implementation.
    for name in ("partition_refinement_reference.cpp","partition_refinement_specification_audit.cpp")
        path=joinpath(@__DIR__,name)
        manifest["provenance"]["source_files"][relpath(path,PerfSupport.ROOT)]=bytes2hex(sha256(read(path)))
    end
    hashes=manifest["provenance"]["source_files"]
    manifest["provenance"]["source_tree_sha256"]=bytes2hex(sha256(join(k*"\t"*hashes[k]*"\n" for k in sort(collect(keys(hashes))))))
    BenchmarkTools.save(joinpath(out,"benchmarktools.json"),trials)
    open(io->TOML.print(io,manifest),joinpath(out,"manifest.toml"),"w")
    write(joinpath(out,"comparison.csv"),String(take!(summary)))
    env=dirname(Base.active_project())
    for name in ("Project.toml","Manifest.toml")
        path=joinpath(env,name);isfile(path) && cp(path,joinpath(out,name))
    end
    println("# Saved diagnostic evidence: ",out)
    out
end

function comparison_main(args)
    if "--help" in args
        println("julia --project=packages/VBF/perf packages/VBF/perf/compare_partition_refinement.jl --reference=/path/to/CCZ-EA-equivalence [--samples=5] [--hard] [--algorithm=optimized|paper] [--translations=quadratic|none] [--only=case1,case2] [--out=PATH]")
        return
    end
    reference = only(filter(a -> startswith(a, "--reference="), args))[13:end]
    samples_arg = filter(a -> startswith(a, "--samples="), args)
    samples = isempty(samples_arg) ? 5 : parse(Int, only(samples_arg)[11:end])
    samples > 0 && isodd(samples) || error("samples must be positive and odd")
    algorithm_args = filter(a -> startswith(a,"--algorithm="),args)
    algorithm = isempty(algorithm_args) ? :optimized : Symbol(only(algorithm_args)[13:end])
    algorithm in (:paper,:optimized) || error("algorithm must be paper or optimized")
    translation_args = filter(a -> startswith(a,"--translations="),args)
    translations = isempty(translation_args) ? :quadratic : Symbol(only(translation_args)[16:end])
    translations in (:quadratic,:none) || error("translations must be quadratic or none")
    algorithm===:optimized && translations===:none &&
        error("optimized automatically prunes quadratic root symmetry; use paper for no translations")
    cases = fixtures(; hard = "--hard" in args)
    only_args = filter(a -> startswith(a,"--only="),args)
    if !isempty(only_args)
        names = split(only(only_args)[8:end],',')
        all(name -> any(c -> c[1]==name,cases),names) || error("unknown fixture name")
        filter!(c -> c[1] in names,cases)
    end
    println("# Julia $(VERSION), $(Sys.CPU_NAME), $(Threads.nthreads()) threads")
    println("# CPU: $(Sys.cpu_info()[1].model); $(first(split(read(`g++ --version`, String), '\n')))")
    println("# Julia source revision: $(chomp(read(`git -C $(@__DIR__) rev-parse HEAD`, String)))")
    native_src = normpath(joinpath(@__DIR__, "..", "src"))
    native_files = sort([joinpath(base, f) for (base, _, names) in walkdir(native_src) for f in names
                         if endswith(f, ".jl")])
    native_hash = sha256(join(relpath(f, native_src) * "\n" * read(f, String) for f in native_files))
    println("# Julia source SHA-256: $(bytes2hex(native_hash))")
    println("# Samples: $samples, fixture seed: 940")
    println("# Julia algorithm: $algorithm; translations: $translations; no general automorphism discovery")
    println("# C++ -std=c++17 -O3 -DNDEBUG -march=native")
    println("# Timing includes preprocessing, refinement and certificate recovery; excludes JIT, I/O and verification")
    flush(stdout)
    trials=BenchmarkGroup()
    summary=IOBuffer()
    config=Dict{String,Any}("samples"=>samples,"evals"=>1,"seed"=>940,
        "algorithm"=>string(algorithm),"translations"=>string(translations),
        "reference_path"=>abspath(reference),"cpp_flags"=>"-std=c++17 -O3 -DNDEBUG -march=native",
        "compiler"=>first(split(read(`g++ --version`,String),'\n')))
    mktempdir() do tmp
        binary = joinpath(tmp, "reference")
        src = joinpath(reference, "src")
        files = [joinpath(base, f) for (base, _, names) in walkdir(src) for f in names
                 if endswith(f, ".cpp") && !(f in ("main.cpp", "python.cpp", "group_benchmark.cpp"))]
        reference_files = sort([joinpath(base, f) for (base, _, names) in walkdir(src) for f in names
                                if endswith(f, ".cpp") || endswith(f, ".h")])
        fingerprint = sha256(join(relpath(f, src) * "\n" * read(f, String) for f in reference_files))
        config["reference_source_sha256"]=bytes2hex(fingerprint)
        println("# Reference source SHA-256: $(bytes2hex(fingerprint))")
        flush(stdout)
        run(`g++ -std=c++17 -O3 -DNDEBUG -march=native -I$src $(joinpath(@__DIR__, "partition_refinement_reference.cpp")) $files -o $binary`)
        input = joinpath(tmp, "fixtures.txt")
        open(input, "w") do io
            for (name, relation, F, G, expected) in cases
                println(io, "$name $relation $(inputbits(F)) $(Int(expected)) $samples $(Int(translations===:quadratic))")
                println(io, join(F.lut, ' ')); println(io, join(G.lut, ' '))
            end
        end
        output = read(pipeline(`timeout 180 $binary`; stdin = input), String)
        cpp = Dict(fields[1] => parse.(Float64,fields[2:4]) for fields in
                   (split(line, ',') for line in split(chomp(output), '\n')))
        header="case,julia_seconds,cpp_seconds,julia_over_cpp,nodes,julia_min_seconds,julia_max_seconds,cpp_min_seconds,cpp_max_seconds"
        println(header);println(summary,header)
        for (name, relation, F, G, expected) in cases
            function solve()
                if algorithm===:paper && translations===:quadratic
                    # Lemma 14 generators are constructed within each timed call,
                    # matching the C++ driver's supplied graph-action subgroup.
                    H = algebraic_degree(G)<=2 ? VBF._pr_quadratic_translations(G) : F2AffineMap[]
                    return partition_refinement_equivalence(F,G;relation,algorithm,
                        automorphisms=H,timeout_seconds=120.0)
                end
                return partition_refinement_equivalence(F,G;relation,algorithm,timeout_seconds=120.0)
            end
            result = solve() # compilation excluded
            verify(result, F, G, relation === :ea, expected)
            check = r -> verify(r,F,G,relation===:ea,expected)
            trial = @benchmark value=$solve() setup=(value=nothing) teardown=($check(value)) evals=1 samples=samples seconds=1200
            trials[name]=trial
            times = trial.times ./ 1e9
            seconds = median(times)
            cseconds,cmin,cmax = cpp[name]
            row="$name,$seconds,$cseconds,$(seconds/cseconds),$(nodes_visited(result)),$(minimum(times)),$(maximum(times)),$cmin,$cmax"
            println(row);println(summary,row)
            flush(stdout)
        end
    end
    save_diagnostic(trials,"cpp_comparison",args,config,summary)
end

abspath(PROGRAM_FILE) == (@__FILE__) && comparison_main(ARGS)
