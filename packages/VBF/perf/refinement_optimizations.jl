#!/usr/bin/env julia
# Before/after pruning costs and serial/threaded kernels, all through VBF APIs.
using VBF, Random, Statistics, BenchmarkTools
include(joinpath(@__DIR__, "compare_partition_refinement.jl"))

function measure(trials, key, call, check, samples)
    result = call() # compilation excluded
    check(result)
    trial = @benchmark value=$call() setup=(value=nothing) teardown=($check(value)) evals=1 samples=samples seconds=1200
    trials[key]=trial
    return median(trial).time/1e9, minimum(trial).memory, result
end

function optimization_main(args)
    if "--help" in args
        println("refinement_optimizations.jl [--samples=5] [--out=PATH]; expensive bounded equivalence and Walsh diagnostics")
        return
    end
    trials=BenchmarkGroup();summary=IOBuffer()
    report(row)=(println(row);println(summary,row))
    sample_args = filter(a -> startswith(a,"--samples="),args)
    samples = isempty(sample_args) ? 5 : parse(Int,only(sample_args)[11:end])
    samples > 0 && isodd(samples) || error("samples must be positive and odd")
    println("# Julia $(VERSION), CPU $(Sys.cpu_info()[1].model), $(Threads.nthreads()) default threads, $samples samples, seed 940")
    println("# Source revision: $(chomp(read(`git -C $(@__DIR__) rev-parse HEAD`,String)))")
    println("# Discovery has a 1-second sub-budget; all equivalence calls have 120 seconds and 10^6 nodes")
    report("case,mode,median_seconds,bytes,nodes,complete,order")
    for (name,relation,F,G,expected) in fixtures(;hard=true)
        name in ("gold7_negative","gold8_negative","kim_dillon_ea") || continue
        check(r) = verify(r,F,G,relation===:ea,expected)
        # Warm discovery separately: compilation is included in search budgets,
        # but must not consume the short discovery allowance in measurements.
        H = partition_refinement_automorphisms(G;relation,algorithm=:optimized,timeout_seconds=10)
        auto_check(r) = all(A -> is_invertible(A) && ccz_equivalent_function(G,A)==G &&
            (relation !== :ea || all(v -> v >> inputbits(G) == 0,A.linear.cols[1:inputbits(G)])),
            r.generators) || error("invalid automorphism")
        seconds,bytes,H = measure(trials,name*"_discovery",() -> partition_refinement_automorphisms(G;
            relation,algorithm=:optimized,timeout_seconds=1),auto_check,samples)
        report("$name,discovery,$seconds,$bytes,$(nodes_visited(H)),$(H.complete),$(H.order)")
        for (mode,options) in (("unpruned",(;)),("supplied_group",(;automorphisms=H)),
                              ("discovery_and_search",(;automorphism_timeout_seconds=1.0)))
            seconds,bytes,r = measure(trials,name*"_"*mode,() -> partition_refinement_equivalence(F,G;
                relation,algorithm=:optimized,timeout_seconds=120,options...),check,samples)
            report("$name,$mode,$seconds,$bytes,$(nodes_visited(r)),,")
            flush(stdout)
        end
    end
    rng = Xoshiro(940)
    F = random_function_sbox(rng,Val(9))
    G = SBox{9}([F(x ⊻ 37) ⊻ 91 for x in 0:511])
    for threaded in (false,true)
        check(r) = verify(r,F,G,true,true)
        seconds,bytes,r = measure(trials,"random9_"*string(threaded),() -> partition_refinement_equivalence(F,G;
            relation=:ea,algorithm=:optimized,threaded,timeout_seconds=120),check,samples)
        report("random9_positive,$(threaded ? "threaded" : "serial"),$seconds,$bytes,$(nodes_visited(r)),,")
    end
    println("# Walsh buffers are reset outside timing; transformation and its temporary allocations are timed")
    for exponent in (18,20,22)
        input = rand(rng,Int32(-8):Int32(8),1<<exponent)
        expected = walsh_hadamard!(copy(input))
        for threaded in (false,true)
            work = copy(input)
            walsh_hadamard!(work;threaded) # compilation excluded
            kernel = v -> walsh_hadamard!(v;threaded)
            check = v -> (v == expected || error("incorrect Walsh transform"))
            trial = @benchmark $kernel(work) setup=(work=copy($input)) teardown=($check(work)) evals=1 samples=samples seconds=1200
            trials["walsh_"*string(exponent)*"_"*string(threaded)]=trial
            seconds=median(trial).time/1e9
            bytes=minimum(trial).memory
            report("walsh_2^$exponent,$(threaded ? "threaded" : "serial"),$seconds,$bytes,,,")
        end
    end
    save_diagnostic(trials,"refinement_optimizations",args,
        Dict("samples"=>samples,"evals"=>1,"seed"=>940,"equivalence_timeout_seconds"=>120,
            "automorphism_timeout_seconds"=>1),summary)
end

abspath(PROGRAM_FILE) == (@__FILE__) && optimization_main(ARGS)
