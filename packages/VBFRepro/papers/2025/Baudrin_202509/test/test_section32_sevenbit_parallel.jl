@testset "Section 3.2 task-local root workers" begin
    include(joinpath(@__DIR__,"..","section32_sevenbit.jl"))
    F = gold_apn(4,1)
    inputs = [(;function_value=SBox{4}([F(x ⊻ i) ⊻ i for x in 0:15]),
        label="fixture$i",identifier="fixture$i",provenance="test") for i in 0:3]
    identities = [Dict("source_lut"=>Int.(input.function_value.lut),
        "schema"=>"vbf-sevenbit-closure-v1","source_hashes"=>Dict("fixture"=>repeat("0",64)),
        "seed"=>940+i-1,"subspace_algorithm"=>"optimized","algorithm_profile"=>"optimized")
        for (i,input) in pairs(inputs)]
    compute(i) = _bgp_seven_compute_row(inputs[i],i,identities[i];
        root_timeout=30,max_nodes=typemax(Int),max_subspaces=10^6,
        max_memory_bytes=512*1024^2,group_algorithm=:optimized,seed=940)
    serial = [compute(i) for i in eachindex(inputs)]
    tasks = [Threads.@spawn compute(i) for i in eachindex(inputs)]
    parallel = fetch.(tasks)
    for (first,second) in zip(serial,parallel)
        @test first["complete"] && second["complete"]
        @test Dict(k=>v for (k,v) in first if k != "elapsed_seconds") ==
              Dict(k=>v for (k,v) in second if k != "elapsed_seconds")
    end
    mktempdir() do directory
        path = joinpath(directory,"root_001.toml")
        save(row) = open(path,"w") do io
            TOML.print(io,row;sorted=true)
        end
        budget() = (;start=time_ns(),timeout=30.0)
        save(first(serial))
        restored = _bgp_seven_resume_row(path,identities[1],inputs[1],1,budget())
        @test restored["complete"] && restored["classes"] == first(serial)["classes"]
        for corrupt in (row -> (row["classes"] += 1),
                        row -> (row["degrees"]["2"] += 1),
                        row -> (row["identifier"] = "another input"))
            bad = deepcopy(first(serial))
            corrupt(bad)
            save(bad)
            @test_throws ArgumentError _bgp_seven_resume_row(path,identities[1],inputs[1],1,budget())
        end
    end
    @test_throws ArgumentError section32_sevenbit(limit=0,workers=0)
    @test_throws ArgumentError section32_sevenbit(limit=0,workers=Threads.nthreads(:default)+1)
    # Exercise the actual queue/output/summary path without a seven-bit search.
    worker_count = min(2,Threads.nthreads(:default))
    partial = section32_sevenbit(limit=2,workers=worker_count,max_nodes=0,io=IOBuffer())
    @test !partial.complete && length(partial.rows) == 2
    @test all(row -> !row["complete"] && row["stop_reason"] == "nodes",partial.rows)
    @test partial.summary["workers"] == worker_count
    @test partial.summary["parameters"]["group_algorithm"] == "optimized"
    TOML.print(IOBuffer(),partial.summary)
end
