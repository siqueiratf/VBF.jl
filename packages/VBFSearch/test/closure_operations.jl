module ClosureOperationsTests
using Test,VBFSearch
include(joinpath(@__DIR__,"..","tools","closure_operations.jl"))
const O=ClosureOperations

@testset "Resource limits describe actual Julia pools" begin
    resources=O.validate_resources(Dict();default_threads=8,interactive_threads=1,gc_threads=2,env=Dict())
    @test resources["concurrency"]==8 && resources["runtime_threads"]==11
    @test resources["cpu_allocation"]==0 && resources["job_id"]=="none"
    large=O.validate_resources(Dict();default_threads=190,interactive_threads=0,gc_threads=2,
        env=Dict("SLURM_CPUS_PER_TASK"=>"192"),heap_size_hint=4*1024^3)
    @test large["concurrency"]==190 && large["runtime_threads"]==192
    @test large["work_buffer_lower_bound_bytes"]>8*1024^3
    @test !isempty(large["warnings"])
    explicit=O.validate_resources(Dict("concurrency"=>12);default_threads=190,interactive_threads=0,gc_threads=2,
        env=Dict(),heap_size_hint=16*1024^3)
    @test explicit["concurrency"]==12 && explicit["concurrency_source"]=="explicit"
    @test isempty(explicit["warnings"])

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
    @test occursin("not CPU utilization",result["scheduler_active_scope"])
    @test occursin("completion checks",result["reporting_scope"])
end
function exact_report_counts(s)
    queries=("total_parents"=>"SELECT COUNT(*) n FROM parents",
        "promoted_parents"=>"SELECT COUNT(*) n FROM parents WHERE origin='discovered'",
        "exact_luts"=>"SELECT COUNT(*) n FROM candidates",
        "quadratic_apn_luts"=>"SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2",
        "nonquadratic_apn_luts"=>"SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree>2",
        "unresolved_equivalence"=>"SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2 AND class_id IS NULL",
        "verified_equivalent_luts"=>"SELECT COUNT(*) n FROM candidates WHERE state='equivalent'")
    Dict(key=>VBFSearch._closure_count(s,sql) for (key,sql) in queries)
end

@testset "Session report counters follow physical writes and roll back with scientific rows" begin
    for normalized in (false,true)
        mktempdir() do directory
            db=VBFSearch.SQLite.DB();VBFSearch._closure_create_schema(db;normalized)
            lease=VBFSearch._closure_lease(directory)
            store=VBFSearch.ClosureStore(db,directory,lease,Dict{String,Any}(),0,UInt64(0))
            execute(sql,args=())=VBFSearch._closure_exec(store,sql,args)
            query(sql,args=())=VBFSearch._closure_rows(store,sql,args)
            function candidate(i;apn=true,degree=2)
                Dict{String,Any}("lut_sha256"=>repeat(string(i),64),"lut_hex"=>repeat("0"*string(i),256),
                    "sigma_hash"=>"fixture","apn"=>apn,"algebraic_degree"=>degree,"ortho_lut_hex"=>"")
            end
            try
                for p in (candidate(1),candidate(2;degree=3),candidate(3;apn=false))
                    VBFSearch._closure_insert_candidate!(store,p)
                end
                VBFSearch._closure_add_parent!(store,candidate(1)["lut_sha256"],"fixture";origin="root")
                initial=exact_report_counts(store)
                counters=O.install_report_counters!(store,initial)
                @test O.report_counter_snapshot(counters)==initial
                @test isempty(query("SELECT name FROM main.sqlite_master WHERE name LIKE 'closure_runtime_%'"))
                @test length(query("SELECT name FROM temp.sqlite_master WHERE type='trigger'"))==6
                VBFSearch._closure_insert_candidate!(store,candidate(4))
                VBFSearch._closure_insert_candidate!(store,candidate(4))
                physical=normalized ? "closure_candidates" : "candidates"
                execute("INSERT OR IGNORE INTO $physical SELECT * FROM $physical WHERE id=?",(candidate(4)["lut_sha256"],))
                @test O.report_counter_snapshot(counters)==exact_report_counts(store)
                @test O.report_counter_snapshot(counters)["exact_luts"]==4
                saved=O.report_counter_snapshot(counters)
                execute("BEGIN IMMEDIATE");execute("SAVEPOINT scientific_packet")
                execute("UPDATE candidates SET class_id=1,state='equivalent' WHERE id=?",(candidate(4)["lut_sha256"],))
                VBFSearch._closure_add_parent!(store,candidate(2)["lut_sha256"],"fixture")
                @test O.report_counter_snapshot(counters)==exact_report_counts(store)
                @test O.report_counter_snapshot(counters)["verified_equivalent_luts"]==1
                execute("ROLLBACK TO scientific_packet")
                @test O.report_counter_snapshot(counters)==saved==exact_report_counts(store)
                execute("RELEASE scientific_packet");execute("ROLLBACK")
                @test O.report_counter_snapshot(counters)==saved
                execute("UPDATE candidates SET state='awaiting_equivalence' WHERE id=?",(candidate(4)["lut_sha256"],))
                @test O.report_counter_snapshot(counters)==saved
                VBFSearch._closure_transaction(store) do
                    execute("UPDATE candidates SET class_id=1,state='equivalent' WHERE id=?",(candidate(4)["lut_sha256"],))
                    execute("UPDATE parents SET origin='discovered' WHERE id=1")
                end
                @test O.report_counter_snapshot(counters)==exact_report_counts(store)
                @test O.report_counter_snapshot(counters)["promoted_parents"]==1
                execute("UPDATE $physical SET apn=0,degree=3 WHERE id=?",(candidate(4)["lut_sha256"],))
                @test O.report_counter_snapshot(counters)==exact_report_counts(store)
                execute("DELETE FROM candidates WHERE id=?",(candidate(4)["lut_sha256"],))
                execute("DELETE FROM parents WHERE id=1")
                @test O.report_counter_snapshot(counters)==exact_report_counts(store)
                execute("BEGIN IMMEDIATE")
                @test_throws ErrorException O.install_report_counters!(store,exact_report_counts(store))
                execute("ROLLBACK")
            finally
                VBFSearch.DiscoveryStore.close_statements!(store.statements)
                close(db);close(lease)
            end
        end
    end
end

@testset "Only a complete identity-matched published-root summary becomes immutable" begin
    db=VBFSearch.SQLite.DB();cache=O.SeedSummaryCache();calls=Ref(0)
    summary=Ref(Dict{String,Any}("total"=>3,"completed"=>1,"v5_completed"=>2,"switching_completed"=>3,"focus_available"=>true))
    reader=_ -> begin calls[]+=1;deepcopy(summary[]) end
    first=O.seed_summary!(cache,reader,db,3)
    @test first["completed"]==1 && cache.terminal===nothing
    summary[]["completed"]=2
    @test O.seed_summary!(cache,reader,db,3)["completed"]==2 && calls[]==2
    summary[]=Dict{String,Any}("total"=>3,"completed"=>3,"v5_completed"=>3,"switching_completed"=>3,"focus_available"=>false)
    O.seed_summary!(cache,reader,db,4)
    @test cache.terminal===nothing
    complete=O.seed_summary!(cache,reader,db,3)
    @test cache.terminal!==nothing && calls[]==4
    complete["total"]=99
    cached=O.seed_summary!(cache,reader,db,3)
    @test cached["total"]==3 && calls[]==4 && cache.hits==1
    cached["completed"]=99
    @test O.seed_summary!(cache,reader,db,3)["completed"]==3 && calls[]==4
    O.seed_summary!(cache,reader,db,4)
    @test calls[]==5 && cache.terminal===nothing
    @test_throws ArgumentError O.seed_summary!(cache,reader,db,-1)
    close(db)
end

@testset "Rolled-back root completion cannot populate a terminal summary cache" begin
    db=VBFSearch.SQLite.DB();cache=O.SeedSummaryCache()
    execute(sql)=VBFSearch._closure_exec(db,sql)
    try
        execute("CREATE TABLE root_fixture(complete INTEGER)")
        execute("INSERT INTO root_fixture VALUES(0)")
        reader=db->begin
            complete=VBFSearch._closure_count(db,"SELECT complete n FROM root_fixture")
            Dict{String,Any}("total"=>1,"completed"=>complete,"v5_completed"=>complete,"switching_completed"=>complete,"focus_available"=>complete==0)
        end
        execute("BEGIN IMMEDIATE");execute("UPDATE root_fixture SET complete=1")
        @test O.seed_summary!(cache,reader,db,1)["completed"]==1
        @test cache.terminal===nothing
        execute("ROLLBACK")
        @test O.seed_summary!(cache,reader,db,1)["completed"]==0
        @test cache.terminal===nothing
        execute("UPDATE root_fixture SET complete=1")
        @test O.seed_summary!(cache,reader,db,1)["completed"]==1 && cache.terminal!==nothing
        @test O.seed_summary!(cache,reader,db,1)["completed"]==1 && cache.hits==1
    finally
        close(db)
    end
end

end
