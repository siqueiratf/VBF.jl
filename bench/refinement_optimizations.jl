#!/usr/bin/env julia
# Before/after pruning costs and serial/threaded kernels, all through VBF APIs.
using VBF, Random, Statistics
include(joinpath(@__DIR__, "compare_partition_refinement.jl"))

function measure(call, check, samples)
    result = call() # compilation excluded
    check(result)
    times = Float64[]
    for _ in 1:samples
        GC.gc()
        push!(times, @elapsed result = call())
        check(result)
    end
    bytes = @allocated allocation_result = call()
    check(allocation_result)
    return median(times), bytes, result
end

function optimization_main(args)
    sample_args = filter(a -> startswith(a,"--samples="),args)
    samples = isempty(sample_args) ? 5 : parse(Int,only(sample_args)[11:end])
    samples > 0 && isodd(samples) || error("samples must be positive and odd")
    println("# Julia $(VERSION), CPU $(Sys.cpu_info()[1].model), $(Threads.nthreads()) default threads, $samples samples, seed 940")
    println("# Source revision: $(chomp(read(`git -C $(@__DIR__) rev-parse HEAD`,String)))")
    println("# Discovery has a 1-second sub-budget; all equivalence calls have 120 seconds and 10^6 nodes")
    println("case,mode,median_seconds,bytes,nodes,complete,order")
    for (name,relation,F,G,expected) in fixtures(;hard=true)
        name in ("gold7_negative","gold8_negative","kim_dillon_ea") || continue
        check(r) = verify(r,F,G,relation===:ea,expected)
        # Warm discovery separately: compilation is included in search budgets,
        # but must not consume the short discovery allowance in measurements.
        H = partition_refinement_automorphisms(G;relation,timeout_seconds=10)
        auto_check(r) = all(A -> is_invertible(A) && ccz_equivalent_function(G,A)==G &&
            (relation !== :ea || all(v -> v >> inputbits(G) == 0,A.linear.cols[1:inputbits(G)])),
            r.generators) || error("invalid automorphism")
        seconds,bytes,H = measure(() -> partition_refinement_automorphisms(G;
            relation,timeout_seconds=1),auto_check,samples)
        println("$name,discovery,$seconds,$bytes,$(nodes_visited(H)),$(H.complete),$(H.order)")
        for (mode,options) in (("unpruned",(;)),("supplied_group",(;automorphisms=H)),
                              ("discovery_and_search",(;automorphism_timeout_seconds=1.0)))
            seconds,bytes,r = measure(() -> partition_refinement_equivalence(F,G;
                relation,timeout_seconds=120,options...),check,samples)
            println("$name,$mode,$seconds,$bytes,$(nodes_visited(r)),,")
            flush(stdout)
        end
    end
    rng = Xoshiro(940)
    F = random_function_sbox(rng,Val(9))
    G = SBox{9}([F(x ⊻ 37) ⊻ 91 for x in 0:511])
    for threaded in (false,true)
        check(r) = verify(r,F,G,true,true)
        seconds,bytes,r = measure(() -> partition_refinement_equivalence(F,G;
            relation=:ea,threaded,timeout_seconds=120),check,samples)
        println("random9_positive,$(threaded ? "threaded" : "serial"),$seconds,$bytes,$(nodes_visited(r)),,")
    end
    println("# Walsh buffers are reset outside timing; transformation and its temporary allocations are timed")
    for exponent in (18,20,22)
        input = rand(rng,Int32(-8):Int32(8),1<<exponent)
        expected = walsh_hadamard!(copy(input))
        for threaded in (false,true)
            work = copy(input)
            walsh_hadamard!(work;threaded) # compilation excluded
            times = Float64[]
            for _ in 1:samples
                copyto!(work,input)
                push!(times,@elapsed walsh_hadamard!(work;threaded))
                work == expected || error("incorrect Walsh transform")
            end
            copyto!(work,input)
            bytes = @allocated walsh_hadamard!(work;threaded)
            work == expected || error("incorrect Walsh transform")
            println("walsh_2^$exponent,$(threaded ? "threaded" : "serial"),$(median(times)),$bytes,,,")
        end
    end
end

abspath(PROGRAM_FILE) == (@__FILE__) && optimization_main(ARGS)
