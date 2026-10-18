using Test,VBFSearch,TOML,SQLite
isdefined(@__MODULE__,:closure_fixture) || include("closure.jl")

function progress_reader_stub(body)
    expression="using JSON3; println(JSON3.write(Dict(\"schema\"=>\"vbfsearch-progress-reader-v1\"))); flush(stdout); "*body
    `$(Base.julia_cmd()) --startup-file=no --threads=1,0 --gcthreads=1 --project=$(dirname(Base.active_project())) -e $expression`
end

@testset "External progress reader persists and publishes the final committed state" begin
    mktempdir() do directory
        run=closure_fixture(directory);store=VBFSearch._closure_open(run);reader=nothing
        try
            store.report_backend=:process
            @test VBFSearch._closure_report!(store;force=true)
            reader=store.report_reader
            @test reader!==nothing && process_running(reader.process)
            pid=getpid(reader.process)
            @test TOML.parsefile(joinpath(run,"progress.toml"))["initial_roots"]==1
            @test VBFSearch._closure_report!(store;force=true)
            @test getpid(store.report_reader.process)==pid && reader.request_id==2
            store.last_report_ns=0
            @test VBFSearch._closure_report!(store)
            @test !VBFSearch._closure_report!(store)
            # Final publication joins the outstanding request before another
            # snapshot, and observes this committed mutation.
            VBFSearch._closure_transaction(store) do
                now=VBFSearch._closure_now()
                VBFSearch._closure_exec(store.db,"INSERT INTO sessions(started,finished,heartbeat,pid,host,state,budgets) VALUES(?,?,?,?,?,?,?)",
                    (now,now,now,getpid(),"fixture","paused_budget",""))
            end
            @test VBFSearch._closure_report!(store;force=true)
            progress=TOML.parsefile(joinpath(run,"progress.toml"))
            @test progress["state"]=="paused_budget" && !progress["running"]
            @test first(progress["sessions"])["finished"]!=""
            @test reader.request_id==4
            events=VBFSearch.JSON3.read.(readlines(joinpath(run,"progress-reader-events.jsonl")))
            @test length(events)==8
            @test [event["phase"] for event in events]==repeat(["started","finished"],4)
            @test all(event["pid"]==pid for event in events)
            @test all(event["snapshot_seconds"]>=0 && event["ok"] for event in events if event["phase"]=="finished")
        finally
            VBFSearch._closure_close(store)
        end
        @test reader!==nothing && process_exited(reader.process)
        @test store.report_reader===nothing && store.report_task===nothing
        @test !VBFSearch._closure_writer_alive(run)
    end
end

@testset "External reader failures and timeouts reap the child and release the lease" begin
    for body in ("exit(0)","readline(stdin); println(\"malformed reply\"); flush(stdout); sleep(60)",
        "readline(stdin); sleep(60)")
        mktempdir() do directory
            run=closure_fixture(directory);store=VBFSearch._closure_open(run)
            reader=VBFSearch._closure_start_reader(run;command=progress_reader_stub(body),verify_identity=false,timeout_seconds=10)
            store.report_backend=:process;store.report_reader=reader
            reader.timeout_seconds=0.2
            @test VBFSearch._closure_report!(store)
            started=time()
            @test_throws TaskFailedException VBFSearch._closure_close(store)
            @test time()-started<5
            @test process_exited(reader.process)
            @test store.report_reader===nothing && store.report_task===nothing
            @test !VBFSearch._closure_writer_alive(run)
            reopened=VBFSearch._closure_open(run);VBFSearch._closure_close(reopened)
        end
    end
end

@testset "Explicit custom readers retain the thread test-hook contract" begin
    mktempdir() do directory
        run=closure_fixture(directory);store=VBFSearch._closure_open(run)
        try
            store.report_backend=:process
            @test VBFSearch._closure_report!(store;force=true,read_snapshot=_->Dict("custom"=>true))
            @test store.report_reader===nothing
            @test TOML.parsefile(joinpath(run,"progress.toml"))["custom"]
        finally
            VBFSearch._closure_close(store)
        end
    end
end

@testset "Slow progress readers do not hold the search writer or race final publication" begin
    mktempdir() do directory
        run=closure_fixture(directory);store=VBFSearch._closure_open(run)
        entered=Channel{Nothing}(1);release=Channel{Nothing}(1)
        try
            now=VBFSearch._closure_now()
            VBFSearch._closure_exec(store.db,"INSERT INTO sessions(started,heartbeat,pid,host,state,budgets) VALUES(?,?,?,?,?,?)",
                (now,now,getpid(),"fixture","running",""))
            store.session=1
            slow_reader=dir->begin
                snapshot=closure_snapshot(dir)
                db=SQLite.DB("file:"*joinpath(dir,"closure.sqlite")*"?mode=ro")
                try
                    VBFSearch._closure_exec(db,"BEGIN")
                    VBFSearch._closure_count(db,"SELECT COUNT(*) n FROM candidates")
                    put!(entered,nothing);take!(release)
                finally
                    VBFSearch._closure_exec(db,"ROLLBACK");close(db)
                end
                snapshot
            end
            @test VBFSearch._closure_report!(store;read_snapshot=slow_reader)
            take!(entered)
            @test !istaskdone(store.report_task)
            @test !VBFSearch._closure_report!(store;read_snapshot=slow_reader)
            VBFSearch._closure_transaction(store) do
                VBFSearch._closure_exec(store.db,"UPDATE sessions SET state='paused_external',finished=? WHERE id=1",(VBFSearch._closure_now(),))
            end
            @test VBFSearch._closure_count(store.db,"SELECT COUNT(*) n FROM sessions WHERE finished!=''")==1
            forced=Threads.@spawn VBFSearch._closure_report!(store;force=true)
            put!(release,nothing)
            @test fetch(forced)
            @test store.report_task===nothing
            progress=closure_progress(run)
            @test progress["state"]=="paused_external"
            @test !progress["running"]
            @test first(progress["sessions"])["finished"]!=""
        finally
            isready(release) || put!(release,nothing)
            VBFSearch._closure_close(store)
        end
    end
end

@testset "Failed reporting releases the database and OS lease" begin
    mktempdir() do directory
        run=closure_fixture(directory);store=VBFSearch._closure_open(run)
        @test VBFSearch._closure_report!(store;read_snapshot=_->error("controlled reporting failure"))
        @test_throws TaskFailedException VBFSearch._closure_close(store)
        @test !VBFSearch._closure_writer_alive(run)
        @test store.report_task===nothing
        reopened=VBFSearch._closure_open(run)
        VBFSearch._closure_close(reopened)
    end
end

@testset "Cached progress avoids ledger reads and refreshes process liveness" begin
    mktempdir() do directory
        run=closure_fixture(directory)
        snapshot=closure_snapshot(run)
        snapshot["sessions"]=[Dict("finished"=>"")]
        snapshot["running"]=true;snapshot["state"]="running"
        snapshot["heartbeat_utc"]="2000-01-01T00:00:00.000Z"
        VBFSearch.DiscoveryStore.atomic_toml(joinpath(run,"progress.toml"),snapshot)
        ledger=joinpath(run,"closure.sqlite");bytes=read(ledger)
        write(ledger,"not a SQLite database; a progress poll must not open it")
        try
            progress=closure_progress(run)
            @test progress["initial_roots"]==1
            @test progress["state"]=="interrupted" && !progress["running"]
            lease=VBFSearch._closure_lease(run)
            try
                live=closure_progress(run)
                @test live["running"] && live["state"]=="running"
                @test live["heartbeat_stale"] && live["heartbeat_age_seconds"]>120
                @test live["directory"]==abspath(run)
            finally
                close(lease)
            end
        finally
            write(ledger,bytes)
        end
        rm(joinpath(run,"progress.toml"))
        @test closure_progress(run)["initial_roots"]==1
    end
end

@testset "Controllers release the writer when final report publication fails" begin
    controllers=(
        run->closure_run!(run;duration_seconds=10.0,max_jobs=1,max_evaluations=1),
    )
    for run_controller in controllers
        mktempdir() do directory
            run=closure_fixture(directory)
            blocked=joinpath(run,"progress.toml.tmp")
            mkdir(blocked)
            @test_throws SystemError run_controller(run)
            @test !VBFSearch._closure_writer_alive(run)
            rm(blocked)
            reopened=VBFSearch._closure_open(run)
            VBFSearch._closure_close(reopened)
            @test !VBFSearch._closure_writer_alive(run)
        end
    end
end
