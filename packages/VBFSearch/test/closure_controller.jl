using Test,VBF,VBFSearch,TOML
isdefined(@__MODULE__,:ClosureRefillTests) || include(joinpath(@__DIR__,"closure_refill.jl"))
isdefined(@__MODULE__,:ContinuousSeedSearch) || include(joinpath(@__DIR__,"..","tools","closure_continuous.jl"))
const ControllerVS=VBFSearch

@testset "Controller slots share explicit rank lookup and private scratch" begin
    Q=VBF.QuadraticExtensions
    prepared=ContinuousSeedSearch.worker_contexts(3;geometry=Q.geometry(4))
    @test prepared.rank_table_bytes==16 && prepared.rank_table_encoding=="two-bit"
    @test all(c->c.rank_table===prepared.contexts[1].rank_table,prepared.contexts)
    @test length(unique(c.guard for c in prepared.contexts))==3
    @test all(c->c.work===nothing && c.geometry===nothing,prepared.contexts)
    byte=ContinuousSeedSearch.worker_contexts(2;packed_rank_table=false,geometry=Q.geometry(4))
    @test byte.rank_table_bytes==64 && byte.rank_table_encoding=="byte"
    @test all(c->c.rank_table isa Q.PolarRankTable,byte.contexts)
    plain=ContinuousSeedSearch.worker_contexts(2;precompute_rank_table=false,geometry=Q.geometry(4))
    @test plain.rank_table_bytes==0 && all(c->c.rank_table===nothing,plain.contexts)
    @test_throws ArgumentError ContinuousSeedSearch.worker_contexts(0;geometry=Q.geometry(4))
    @test_throws ArgumentError ContinuousSeedSearch.worker_contexts(1;precompute_rank_table="false",geometry=Q.geometry(4))
    @test_throws ArgumentError ContinuousSeedSearch.worker_contexts(1;packed_rank_table="true",geometry=Q.geometry(4))
end

# Recursive parent 24389 of the 2026-10-17 campaign: one maximizing five-space,
# so a complete window takes seconds and still has every kind of wave.
const CONTROLLER_ROOT="00000079003b96d40083a55feb53d819009efe19a005c814cfd294f084a2491600094b3be0d23d7679f3976472c30ac220b7957b60cc4396968286eb3d12bbed002d13470c1a89e6802e36e167f247ab10a3fd37bc34c7365f6f175e1813c6b404205c01e8f72640fd5a00defa669174348e925178f948b0023b0141a5a7304b00598aaa04661803409a6fccaf4e168e08cf7cc2ac504ecb87c3566bc8b78f890252c3eae68db1a33be85ff534dcc6572ae415a26e9bc74bdc91467273057f700175989509460630c136fd7322ee883d19f37eedb16040e8167fd4c45507012a077ad5d1efa9ab94be40c94ebd785ce03fdc138977afcd6c4929c0d9eab1f5d7"

function controller_window(directory,concurrency;duration=Inf,normalized=false,extra=Dict{String,Any}())
    mkpath(directory);p=ControllerVS.properties(hex2bytes(CONTROLLER_ROOT))
    rootfile=joinpath(directory,"root.tsv");write(rootfile,p["lut_hex"]*"\n")
    digest=ControllerVS.DiscoveryEvidence.filehash(rootfile)
    identity=Dict{String,Any}("schema"=>ControllerVS.CLOSURE_SCHEMA,"campaign"=>rootfile,"campaign_sha256"=>digest,
        "roots_sha256"=>digest,"initial_roots"=>1,"qualification_complete"=>true,"inputs"=>Dict(rootfile=>digest),
        "implementation"=>ControllerVS.implementation_fingerprint(),"julia"=>string(VERSION),
        "scientific"=>Dict("n"=>8,"m"=>8,"target_b6"=>52,"max_kernel"=>23,"extension_cosets"=>65536,"switching_directions"=>255))
    run=joinpath(directory,"run")
    ControllerVS._closure_initialize(run,identity,[(lut_sha256=p["lut_sha256"],lut_hex=p["lut_hex"],sigma_hash=p["sigma_hash"],catalog_id="controller-fixture:1")];normalized)
    config=merge(Dict{String,Any}("run"=>run,"evidence"=>joinpath(directory,"evidence"),"concurrency"=>concurrency,
        "window_size"=>1,"max_windows"=>1,"duration_seconds"=>duration),extra)
    ContinuousSeedSearch.run(config),run
end

"""Evidence that must not depend on the schedule: keyed by stable job keys, not row ids."""
function controller_science(run)
    s=ControllerVS._closure_open(run)
    try
        rows(sql)=ControllerVS._closure_rows(s.db,sql)
        keys=Dict(Int(j["id"])=>String(j["job_key"]) for j in rows("SELECT id,job_key FROM jobs"))
        ledger=Any[]
        ControllerVS._closure_foreach_chunk(s.db) do r
            push!(ledger,(keys[Int(r["job_id"])],r["first_x"],r["next_x"],r["total_x"],r["capped"],r["evidence"]))
        end
        groups=Dict{Any,Vector{String}}()
        for c in rows("SELECT id,class_id FROM candidates WHERE apn=1 AND degree=2")
            push!(get!(groups,c["class_id"],String[]),c["id"])
        end
        ControllerVS._closure_validate_cursors(s)
        (paths=sort([(r["parent_id"],r["method"],r["cursor"],r["child_id"],r["witness"]) for r in rows("SELECT * FROM paths")]),
         ledger=sort(ledger),
         kernels=sort([(keys[Int(r["job_id"])],r["direction"],r["dimension"],r["evidence"]) for r in rows("SELECT * FROM kernels")]),
         partition=sort([sort(v) for v in values(groups)]),
         running=ControllerVS._closure_count(s.db,"SELECT COUNT(*) n FROM jobs WHERE status='running'"),
         undecided=ControllerVS._closure_count(s.db,"SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2 AND class_id IS NULL"))
    finally
        ControllerVS._closure_close(s)
    end
end

@testset "Refilled controller slots preserve scientific evidence and bounded restart storage" begin
    mktempdir() do directory
        one,run1=controller_window(joinpath(directory,"one"),1)
        three,run3=controller_window(joinpath(directory,"three"),min(3,Threads.nthreads(:default)))
        @test one["state"]==three["state"]=="paused_window_limit"
        a=controller_science(run1);b=controller_science(run3)
        @test a.running==b.running==0
        @test a.undecided==b.undecided==0
        @test !isempty(a.paths) && a.paths==b.paths
        @test !isempty(a.ledger) && a.ledger==b.ledger
        @test length(a.kernels)==255 && a.kernels==b.kernels
        @test length(a.partition)>1 && a.partition==b.partition
        @test length(readlines(joinpath(directory,"three","evidence","seed-timings.jsonl")))==1
        @test one["baseline"]["policy"]==three["baseline"]["policy"]=="summary"
        @test one["baseline"]["bytes"]<65536
        @test !isfile(joinpath(directory,"one","evidence","classification-before.sqlite"))
        @test isfile(joinpath(directory,"one","evidence","closure_refill.jl"))
        @test isfile(joinpath(directory,"one","evidence","closure_baseline.jl"))
        summary=ControllerVS.TOML.parsefile(one["baseline"]["path"])
        @test summary["watermarks"]["parents_max_rowid"]==1
        @test occursin("not a rollback backup",summary["scope"])
        s=ControllerVS._closure_open(run1)
        try
            @test ControllerVS._closure_count(s.db,"SELECT COUNT(*) n FROM sqlite_master WHERE type='index' AND name='jobs_pending_ea'")==1
            indexed="SELECT id FROM jobs INDEXED BY jobs_pending_ea WHERE kind='deduplicate' AND status IN ('pending','paused') AND (last_session!=0 OR id IN (0)) ORDER BY id LIMIT 32"
            ordinary=replace(indexed," INDEXED BY jobs_pending_ea"=>"")
            @test ControllerVS._closure_rows(s.db,indexed)==ControllerVS._closure_rows(s.db,ordinary)
            @test any(occursin("jobs_pending_ea",string(row)) for row in ControllerVS._closure_rows(s.db,"EXPLAIN QUERY PLAN "*indexed))
            blocked=joinpath(directory,"full-baseline-preflight");mkpath(blocked)
            @test_throws ErrorException ContinuousSeedSearch.continuous_baseline!(s,blocked;
                policy="full",full_reserve_bytes=typemax(Int))
            @test !isfile(joinpath(blocked,"classification-before.sqlite"))
        finally
            ControllerVS._closure_close(s)
        end
        # An already expired deadline stops before dispatch, independent of how
        # quickly this small fixture runs on the current machine.
        stopped,run2=controller_window(joinpath(directory,"deadline"),min(3,Threads.nthreads(:default));duration=0.0)
        @test stopped["state"]=="paused_budget"
        @test stopped["processed_packets"]==0
        c=controller_science(run2)
        @test c.running==0
        @test isempty(c.paths)
    end
end

@testset "Normalized checkpoint completes the same full seed expansion" begin
    mktempdir() do directory
        legacy,old=controller_window(joinpath(directory,"legacy"),1)
        compact,new=controller_window(joinpath(directory,"normalized"),1;normalized=true,
            extra=Dict("evidence_segment_directory"=>joinpath(directory,"cold"),"evidence_segment_interval_seconds"=>1e-6,
                "checkpoint_directory"=>joinpath(directory,"generations"),"checkpoint_interval_seconds"=>1e-6,"checkpoint_keep"=>3))
        a=controller_science(old);b=controller_science(new)
        @test legacy["state"]==compact["state"]=="paused_window_limit"
        @test a.paths==b.paths && !isempty(b.paths)
        @test a.ledger==b.ledger && !isempty(b.ledger)
        @test a.kernels==b.kernels && length(b.kernels)==255
        @test a.partition==b.partition && length(b.partition)>1
        @test b.running==b.undecided==0
        @test !isempty(filter(p->endswith(p,".zst"),readdir(joinpath(directory,"cold"))))
        @test length(compact["checkpoint_exports"])>=2
        for generation in compact["checkpoint_exports"]
            @test ControllerVS.closure_verify_checkpoint(generation)["verified"]
            db=ControllerVS.SQLite.DB("file:"*joinpath(generation,"closure.sqlite")*"?mode=ro")
            try
                progress=TOML.parsefile(joinpath(generation,"progress.toml"))
                @test progress["total_parents"]==ControllerVS._closure_count(db,"SELECT COUNT(*) n FROM parents")
                @test progress["construction_paths"]==ControllerVS._closure_count(db,"SELECT COUNT(*) n FROM paths")
            finally
                close(db)
            end
        end
    end
end

@testset "Operational limits pause without losing a committed checkpoint" begin
    mktempdir() do directory
        cold=joinpath(directory,"external-cold");mkpath(cold);write(joinpath(cold,"payload"),zeros(UInt8,100))
        durable=joinpath(directory,"snapshots")
        common=Dict{String,Any}("precompute_rank_table"=>false,"min_free_bytes"=>0,"storage_reserve_bytes"=>0)
        paused,run=controller_window(joinpath(directory,"limited"),1;duration=0.0,
            extra=merge(common,Dict("storage_max_bytes"=>1,"checkpoint_directory"=>durable,"evidence_segment_directory"=>cold)))
        @test paused["state"]=="paused_storage" && paused["processed_packets"]==0
        @test paused["storage_stop_reason"]=="storage_max_bytes" && isempty(paused["checkpoint_error"])
        @test !ispath(durable)
        @test cold in paused["storage"]["paths"]
        @test ControllerVS.closure_progress(run)["state"]=="paused_storage"
        @test controller_science(run).running==0

        cosmetic,run2=controller_window(joinpath(directory,"telemetry"),1;duration=0.0,
            extra=merge(common,Dict("telemetry_segment_bytes"=>32)))
        @test cosmetic["state"]=="paused_budget" && !isempty(cosmetic["telemetry_error"])
        @test controller_science(run2).running==0
        @test isfile(joinpath(directory,"telemetry","evidence","telemetry-error.toml"))

        failed,run3=controller_window(joinpath(directory,"export-failure"),1;duration=0.0,
            extra=merge(common,Dict("checkpoint_directory"=>durable,"checkpoint_active_project"=>joinpath(directory,"missing-project"))))
        @test failed["state"]=="paused_checkpoint_error" && !isempty(failed["checkpoint_error"])
        @test ControllerVS.closure_progress(run3)["state"]=="paused_checkpoint_error"
        @test controller_science(run3).running==0
    end
end

@testset "Controller exports retain verified generations across resumed sessions" begin
    mktempdir() do directory
        durable=joinpath(directory,"durable")
        common=Dict{String,Any}("precompute_rank_table"=>false,"min_free_bytes"=>0,"storage_reserve_bytes"=>0,
            "checkpoint_directory"=>durable,"checkpoint_keep"=>1)
        first_result,run=controller_window(joinpath(directory,"source"),1;duration=0.0,extra=common)
        @test isempty(first_result["checkpoint_error"]) && length(first_result["checkpoint_exports"])==1
        old=only(first_result["checkpoint_exports"])
        @test ControllerVS.closure_verify_checkpoint(old)["verified"]
        @test !ControllerVS.closure_progress(old)["running"]
        @test isfile(joinpath(old,"execution","session-1.toml"))
        @test isdir(joinpath(old,"execution","controllers"))
        manifest=TOML.parsefile(joinpath(old,"checkpoint-manifest.toml"))
        manifest["created_utc"]="9999-12-31T00:00:00Z"
        ControllerVS.DiscoveryStore.atomic_toml(joinpath(old,"checkpoint-manifest.toml"),manifest)
        malformed=joinpath(durable,"checkpoint-999-1-1");mkpath(malformed)
        write(joinpath(malformed,"checkpoint-manifest.toml"),"invalid = [")
        write(joinpath(malformed,"keep"),"unrelated data")
        cfg=TOML.parsefile(joinpath(directory,"source","evidence","config.toml"))
        cfg["evidence"]=joinpath(directory,"second-session")
        second_result=ContinuousSeedSearch.run(cfg)
        latest=only(second_result["checkpoint_exports"])
        @test latest!=old && !ispath(old)
        @test isfile(joinpath(malformed,"keep"))
        @test ControllerVS.closure_verify_checkpoint(latest)["verified"]
        working=joinpath(directory,"moved-working-copy");cp(latest,working)
        frozen_project=joinpath(working,"replay","workspace","docs","inspector")
        child=`$(Base.julia_cmd()) --startup-file=no --compiled-modules=existing --threads=1,0 --gcthreads=1,0 --project=$frozen_project -e 'using VBFSearch; s=VBFSearch._closure_open(only(ARGS)); VBFSearch._closure_close(s)' -- $working`
        @test success(child)
        cfg["evidence"]=joinpath(directory,"failed-session")
        cfg["checkpoint_active_project"]=joinpath(directory,"missing")
        failure=ContinuousSeedSearch.run(cfg)
        @test failure["state"]=="paused_checkpoint_error"
        @test isdir(latest) && ControllerVS.closure_verify_checkpoint(latest)["verified"]
        @test only(failure["checkpoint_exports"])==latest
        cfg["evidence"]=joinpath(directory,"budgeted-session");delete!(cfg,"checkpoint_active_project")
        footprint=ContinuousSeedSearch.ClosureOperations.storage_snapshot([run,durable,cfg["evidence"]])["bytes"]
        staging=filesize(joinpath(run,"closure.sqlite"))+Int(ControllerVS._closure_portable_tree_bytes(joinpath(run,"replay")))
        cfg["storage_max_bytes"]=footprint+staging÷2
        budgeted=ContinuousSeedSearch.run(cfg)
        @test budgeted["state"]=="paused_storage" && isempty(budgeted["checkpoint_error"])
        @test budgeted["storage_stop_reason"]=="checkpoint_storage_max_bytes"
        @test isdir(latest) && ControllerVS.closure_verify_checkpoint(latest)["verified"]
    end
end
