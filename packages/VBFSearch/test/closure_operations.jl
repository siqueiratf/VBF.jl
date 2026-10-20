module ClosureOperationsTests
using Test,VBFSearch
include(joinpath(@__DIR__,"..","tools","closure_operations.jl"))
const O=ClosureOperations

@testset "Resource limits describe actual Julia pools" begin
    resources=O.validate_resources(Dict();default_threads=8,interactive_threads=1,gc_threads=2,env=Dict())
    @test resources["concurrency"]==8 && resources["runtime_threads"]==11
    @test resources["cpu_allocation"]==0 && resources["job_id"]=="none"
    @test_throws ArgumentError O.validate_resources(Dict("concurrency"=>9);default_threads=8,env=Dict())
    @test_throws ArgumentError O.validate_resources(Dict("cpu_allocation"=>8);default_threads=8,interactive_threads=1,gc_threads=2,env=Dict())
    @test O.validate_resources(Dict();default_threads=8,interactive_threads=1,gc_threads=2,
        env=Dict("SLURM_CPUS_PER_TASK"=>"11","SLURM_JOB_ID"=>"123"))["job_id"]=="123"
    @test_throws ArgumentError O.validate_resources(Dict("cpu_allocation"=>100);default_threads=8,interactive_threads=1,gc_threads=2,
        env=Dict("SLURM_CPUS_PER_TASK"=>"8"))
end

@testset "Storage limits latch with drain reserve and fail closed on quota errors" begin
    mktempdir() do directory
        write(joinpath(directory,"a"),zeros(UInt8,20))
        mkpath(joinpath(directory,"nested"));write(joinpath(directory,"nested","b"),zeros(UInt8,10))
        symlink(joinpath(directory,"a"),joinpath(directory,"link"))
        snapshot=O.storage_snapshot([directory,joinpath(directory,"nested")])
        @test snapshot["bytes"]==30 && snapshot["files"]==2
        @test snapshot["available_bytes"]>0
        config=Dict{String,Any}("storage_max_bytes"=>100,"min_free_bytes"=>10,"storage_reserve_bytes"=>20)
        guard=O.StorageGuard(config,[directory]);calls=Ref(0)
        sample=_ -> begin calls[]+=1;Dict{String,Any}("bytes"=>79,"available_bytes"=>100) end
        @test !O.check_storage!(guard;now=100.0,sample)
        @test !O.check_storage!(guard;now=101.0,sample) && calls[]==1
        high=_ -> Dict{String,Any}("bytes"=>80,"available_bytes"=>100)
        @test O.check_storage!(guard;force=true,now=102.0,sample=high)
        @test guard.reason=="storage_max_bytes"
        @test O.check_storage!(guard;force=true,sample) && calls[]==1
        free=O.StorageGuard(config,[directory])
        @test O.check_storage!(free;sample=_ -> Dict{String,Any}("bytes"=>0,"available_bytes"=>29))
        @test free.reason=="min_free_bytes"
        quota=joinpath(directory,"quota.json");write(quota,"{\"available_bytes\":100,\"updated_epoch\":100}")
        config["quota_status_file"]=quota
        q=O.StorageGuard(config,[directory])
        @test !O.check_storage!(q;now=100.0,sample)
        @test O.check_storage!(q;now=500.0,sample) && q.reason=="storage_check_failed"
        @test_throws ArgumentError O.StorageGuard(Dict("storage_check_seconds"=>0),[directory])
    end
end

@testset "Telemetry retains bounded complete compressed records" begin
    mktempdir() do directory
        log=O.TelemetryLog(directory,Dict("telemetry_segment_bytes"=>80,"telemetry_keep_segments"=>2))
        for i in 1:100;O.telemetry!(log,"packet-metrics.jsonl",Dict("i"=>i));end
        files=readdir(directory);@test length(files)==3
        @test all(filesize(joinpath(directory,p))<=160 for p in files)
        retained=Int[]
        for path in ("packet-metrics.jsonl.2.zst","packet-metrics.jsonl.1.zst","packet-metrics.jsonl")
            bytes=read(joinpath(directory,path));endswith(path,".zst") && (bytes=transcode(VBFSearch.CodecZstd.ZstdDecompressor,bytes))
            for line in split(String(bytes),'\n';keepempty=false);push!(retained,Int(VBFSearch.JSON3.read(line)["i"]));end
        end
        @test last(retained)==100 && issorted(retained) && length(unique(retained))==length(retained)
        @test length(retained)<100
        @test_throws ArgumentError O.telemetry!(log,"../bad.jsonl",Dict())
        @test_throws ArgumentError O.telemetry!(log,"packet-metrics.jsonl",Dict("large"=>repeat("x",100)))
    end
end

@testset "Aggregated runtime metrics distinguish wall, compute and CPU time" begin
    m=O.RuntimeMetrics();O.record_packet!(m,"deduplicate",2.0,.5,.25);O.record_packet!(m,"deduplicate",3.0,.1,.5)
    result=O.runtime_snapshot(m,O.validate_resources(Dict()))
    @test result["packet_totals"]["deduplicate"]["packets"]==2
    @test result["packet_totals"]["deduplicate"]["compute_wall_seconds"]==5.0
    @test result["packet_totals"]["deduplicate"]["ready_wait_seconds"]==.75
    @test result["process_cpu_seconds"]>=0 && result["gc_pause_seconds"]>=0
end
end
