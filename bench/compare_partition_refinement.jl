#!/usr/bin/env julia
# Public native API versus the external Kaleyski–Sunde C++ reference core.
using VBF, Random, Statistics, SHA

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

function main(args)
    if "--help" in args
        println("julia --project=. bench/compare_partition_refinement.jl --reference=/path/to/CCZ-EA-equivalence [--samples=5] [--hard]")
        return
    end
    reference = only(filter(a -> startswith(a, "--reference="), args))[13:end]
    samples_arg = filter(a -> startswith(a, "--samples="), args)
    samples = isempty(samples_arg) ? 5 : parse(Int, only(samples_arg)[11:end])
    samples > 0 && isodd(samples) || error("samples must be positive and odd")
    cases = fixtures(; hard = "--hard" in args)
    println("# Julia $(VERSION), $(Sys.CPU_NAME), $(Threads.nthreads()) threads")
    println("# CPU: $(Sys.cpu_info()[1].model); $(first(split(read(`g++ --version`, String), '\n')))")
    println("# Julia source revision: $(chomp(read(`git -C $(@__DIR__) rev-parse HEAD`, String)))")
    native_src = normpath(joinpath(@__DIR__, "..", "packages", "VBF", "src"))
    native_files = sort([joinpath(base, f) for (base, _, names) in walkdir(native_src) for f in names
                         if endswith(f, ".jl")])
    native_hash = sha256(join(relpath(f, native_src) * "\n" * read(f, String) for f in native_files))
    println("# Julia source SHA-256: $(bytes2hex(native_hash))")
    println("# Samples: $samples, fixture seed: 940")
    println("# C++ -std=c++17 -O3 -DNDEBUG -march=native; quadratic translations only, no general automorphism discovery")
    println("# Timing includes preprocessing, refinement and certificate recovery; excludes JIT, I/O and verification")
    flush(stdout)
    mktempdir() do tmp
        binary = joinpath(tmp, "reference")
        src = joinpath(reference, "src")
        files = [joinpath(base, f) for (base, _, names) in walkdir(src) for f in names
                 if endswith(f, ".cpp") && !(f in ("main.cpp", "python.cpp", "group_benchmark.cpp"))]
        reference_files = sort([joinpath(base, f) for (base, _, names) in walkdir(src) for f in names
                                if endswith(f, ".cpp") || endswith(f, ".h")])
        fingerprint = sha256(join(relpath(f, src) * "\n" * read(f, String) for f in reference_files))
        println("# Reference source SHA-256: $(bytes2hex(fingerprint))")
        flush(stdout)
        run(`g++ -std=c++17 -O3 -DNDEBUG -march=native -I$src $(joinpath(@__DIR__, "partition_refinement_reference.cpp")) $files -o $binary`)
        input = joinpath(tmp, "fixtures.txt")
        open(input, "w") do io
            for (name, relation, F, G, expected) in cases
                println(io, "$name $relation $(inputbits(F)) $(Int(expected)) $samples")
                println(io, join(F.lut, ' ')); println(io, join(G.lut, ' '))
            end
        end
        output = read(pipeline(`timeout 180 $binary`; stdin = input), String)
        cpp = Dict(name => parse(Float64, seconds) for (name, seconds) in
                   (split(line, ',') for line in split(chomp(output), '\n')))
        println("case,julia_seconds,cpp_seconds,julia_over_cpp,nodes")
        for (name, relation, F, G, expected) in cases
            solve() = partition_refinement_equivalence(F, G; relation, timeout_seconds = 120.0)
            result = solve() # compilation excluded
            verify(result, F, G, relation === :ea, expected)
            times = Float64[]
            for _ in 1:samples
                GC.gc()
                elapsed = @elapsed result = solve()
                verify(result, F, G, relation === :ea, expected)
                push!(times, elapsed)
            end
            seconds = median(times)
            println("$name,$seconds,$(cpp[name]),$(seconds/cpp[name]),$(nodes_visited(result))")
        end
    end
end

abspath(PROGRAM_FILE) == (@__FILE__) && main(ARGS)
