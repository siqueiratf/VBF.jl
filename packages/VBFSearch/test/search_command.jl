module SearchCommandTests
using Test,TOML,SHA,VBF,VBFSearch,SQLite
include(joinpath(@__DIR__,"..","tools","vbfsearch.jl"))
include(joinpath(@__DIR__,"..","tools","vbfsearch_worker.jl"))
include(joinpath(@__DIR__,"..","tools","vbfsearch_output.jl"))
include(joinpath(@__DIR__,"..","tools","closure_continuous.jl"))
const C=VBFSearchCommand
const O=VBFSearchOutput
const DS=VBFSearch.DiscoveryStore

"""Create synthetic audit artifacts to test launch wiring, not profile claims."""
function campaign_fixture(directory;two_roots=false)
    props=two_roots ? VBFSearch.properties.([gold_apn(8).lut,gold_apn(8,3).lut]) : [VBFSearch.properties(gold_apn(8).lut)]
    count=length(props)
    rootfile=joinpath(directory,"verified.tsv")
    open(rootfile,"w") do io
        println(io,"sigma_hash\tlut_hex\tcatalog_id\tlut_sha256\tP6_bminK")
        for (i,p) in enumerate(props)
            println(io,join((p["sigma_hash"],p["lut_hex"],"fixture:$i",p["lut_sha256"],"0,0:52,96"),'\t'))
        end
    end
    selected=joinpath(directory,"selected_roots.tsv");cp(rootfile,selected)
    certificates=joinpath(directory,"EA_certificates.tsv");write(certificates,"fixture\n")
    hash(path)=bytes2hex(open(SHA.sha256,path))
    function toml(name,value)
        path=joinpath(directory,name)
        open(io->TOML.print(io,value),path,"w");path
    end
    toml("qualification.toml",Dict("complete"=>true,"inconclusive"=>0,"processed"=>count,"total"=>count,
        "selected_roots_sha256"=>hash(selected)))
    toml("equivalence.toml",Dict("complete"=>true,"all_encoded_positive_witnesses_replayed"=>true,
        "verified_roots_sha256"=>hash(rootfile),"verified_seed_classes"=>count,"certificate_sha256"=>hash(certificates)))
    toml("pool.toml",Dict("fixture"=>true))
    toml("campaign.toml",Dict("schema"=>"vbfsearch-literature-closure-plan-v2",
        "roots"=>Dict("n"=>8,"m"=>8,"profile_order"=>"bminK","profile_b6"=>52,
            "historical_discoveries_as_roots"=>false,"qualified_root_file"=>"verified.tsv",
            "equivalence_evidence"=>"equivalence.toml","qualification_evidence"=>"qualification.toml",
            "source_inventory"=>"pool.toml","qualified_root_count"=>count,"sources"=>["fixture"]),
        "methods"=>Dict("v5"=>Dict("target_b6"=>52,"bent"=>"max","heuristic_histogram_pruning"=>false)),
        "promotion"=>Dict("global_b6_filter"=>"none","p6_profile_filter"=>"none")))
end

"""Read every scientific row in a small test database, excluding output metadata."""
function scientific_rows(path)
    db=SQLite.DB(path)
    try
        tables=DS.query(db,"SELECT name FROM sqlite_master WHERE type='table' AND name!='vbfsearch_artifacts' ORDER BY name")
        Dict(row["name"]=>DS.query(db,row["name"]=="metadata" ?
            "SELECT * FROM metadata WHERE key NOT LIKE 'vbfsearch_%' ORDER BY key" :
            "SELECT * FROM \""*row["name"]*"\" ORDER BY rowid") for row in tables)
    finally
        close(db)
    end
end

"""Prepare exactly the workspace owned by the public command, without dispatch."""
function sqlite_launch(campaign,output;extra=String[])
    args=vcat(["--recursive-closure","--campaign",campaign,"--output",output,"-j1"],extra)
    launch=C.plan(C.options(args);env=Dict{String,String}())
    C.main(args;env=Dict{String,String}(),io=IOBuffer(),dispatch=_->nothing)
    launch
end

@testset "One-command flags are explicit, bounded and reject ambiguous input" begin
    for argv in (["--recursive-closure","-j8","--start=2","--end=3","--time=15m"],
            ["--recursive-closure","--threads","8","--start","2","--end","3","--time","15m"])
        cfg=C.options(argv).config
        @test cfg==Dict("threads"=>"8","start"=>"2","end"=>"3","time"=>"15m")
    end
    @test C.options(["--recursive-closure","-j","--dry-run"]).config["threads"]=="auto"
    @test "--rolling-windows" in C.options(["--rolling-windows"]).flags
    @test C.seconds("60")==60.0 && C.seconds("1.5h")==5400.0
    for value in ("0","-1","NaN","Inf","1d","1e1000")
        @test_throws ArgumentError C.seconds(value)
    end
    for argv in (["--time"],["--start="],["--unknown","1"],["--recursive-closure","--recursive-closure"],
            ["-j1","--threads=2"],["--heap=1G","--heap-size-hint=2G"],["--time=1","--time=2"],
            ["--rolling-windows","--rolling-windows"],["--window-size=10","--window-size=20"],["stray"])
        @test_throws ArgumentError C.options(argv)
    end
    text=IOBuffer()
    @test C.main(["--help"];io=text)==0
    @test occursin("--recursive-closure",String(take!(text)))
end

@testset "Automatic pools respect Slurm compute and auxiliary budgets" begin
    @test C.available_cpu_count(status="Cpus_allowed_list:\t4-7,9\n",fallback=32)==5
    @test C.available_cpu_count(status="",fallback=4)==4
    plain=C.threads("auto";env=Dict{String,String}(),cpu_threads=32)
    @test (plain.compute,plain.interactive,plain.mark,plain.sweep)==(32,1,8,1)
    for allocation in (2,4,8,16,32,192)
        p=C.threads("auto";env=Dict("SLURM_CPUS_PER_TASK"=>string(allocation)))
        @test p.compute>0 && p.compute+p.interactive+p.mark+p.sweep<=allocation
    end
    p=C.threads("auto";env=Dict("SLURM_CPUS_PER_TASK"=>"192"))
    @test p.compute==182
    @test C.threads("1";env=Dict("SLURM_CPUS_PER_TASK"=>"2")).compute==1
    @test_throws ArgumentError C.threads("auto";env=Dict("SLURM_CPUS_PER_TASK"=>"1"))
    @test_throws ArgumentError C.threads("8";env=Dict("SLURM_CPUS_PER_TASK"=>"8"))
    @test_throws ArgumentError C.threads("0";env=Dict{String,String}())
    @test_throws ArgumentError C.threads("33";env=Dict{String,String}(),cpu_threads=32)
    @test_throws ArgumentError C.threads("auto";env=Dict("SLURM_CPUS_PER_TASK"=>"garbage"))
end

@testset "Dry run validates seed selection without creating state" begin
    mktempdir() do directory
        campaign=campaign_fixture(directory);output=joinpath(directory,"a new output")
        args=["--recursive-closure","--campaign",campaign,"--output",output,"-j1","--start=1","--end=1","--time=30s"]
        parsed=C.options(args);launch=C.plan(parsed;env=Dict{String,String}())
        @test launch.config["root_first"]==launch.config["root_last"]==launch.total==1
        @test launch.config["concurrency"]==1 && launch.heap=="512M"
        @test launch.config["checkpoint_on_stop"]===false
        @test launch.config["cached_global_counts"]===true
        @test launch.config["human_progress"]===true
        @test launch.config["window_size"]==100 && !launch.config["rolling_windows"]
        @test launch.config["report_interval_seconds"]==15.0
        @test !ispath(output)
        text=IOBuffer()
        @test C.main([args;"--dry-run"];env=Dict{String,String}(),io=text)==0
        @test occursin("1–1",String(take!(text)))
        @test !ispath(output)
        for extra in (["--start=0"],["--start=2"],["--end=2"],["--time=0"],["--heap=0G"],
                ["--window-size=0"],["--window-size=no"],["--progress-interval=0"],["--progress-interval=Inf"])
            stripped=filter(x->!startswith(x,first(split(first(extra),'='))*"="),args)
            @test_throws ArgumentError C.plan(C.options([stripped;extra]);env=Dict{String,String}())
        end
        rm(joinpath(directory,"EA_certificates.tsv"))
        @test_throws ArgumentError C.plan(parsed;env=Dict{String,String}())
        @test !ispath(output)
    end
end

@testset "Scheduling controls reach the persisted plan without changing seed scope" begin
    mktempdir() do directory
        campaign=campaign_fixture(directory);output=joinpath(directory,"configured")
        args=["--recursive-closure","--campaign",campaign,"--output",output,"-j1",
            "--window-size=256","--rolling-windows","--progress-interval=10s"]
        text=IOBuffer()
        @test C.main(args;env=Dict{String,String}(),io=text,dispatch=_->nothing)==0
        config=TOML.parsefile(joinpath(output,"command.toml"))
        @test config["window_size"]==256 && config["rolling_windows"]===true
        @test config["report_interval_seconds"]==10.0
        @test config["root_first"]==config["root_last"]==1
        @test config["parent_scope"]=="all" && config["concurrency"]==1
        description=String(take!(text))
        @test occursin("256 parents/window; overlap on",description)
    end
end

@testset "Launch persists one plan and keeps paths out of shell code" begin
    mktempdir() do directory
        campaign=campaign_fixture(directory);output=joinpath(directory,"run with spaces")
        captured=Ref{Cmd}()
        dispatch=command->begin
            @test ENV["OPENBLAS_NUM_THREADS"]==ENV["OMP_NUM_THREADS"]==ENV["MKL_NUM_THREADS"]=="1"
            captured[]=command
        end
        args=["--recursive-closure","--campaign",campaign,"--output",output,"-j1","--time=1h"]
        @test C.main(args;env=Dict{String,String}(),io=IOBuffer(),dispatch)==0
        config=TOML.parsefile(joinpath(output,"command.toml"))
        @test config["supervisor_duration_seconds"]==3600.0
        @test config["run"]==joinpath(output,"state") && config["evidence"]==joinpath(output,"session")
        @test first(captured[].exec)=="python3"
        @test joinpath(output,"command.toml") in captured[].exec
        @test "--threads=1,0" in captured[].exec && "--gcthreads=1,0" in captured[].exec
        @test "--heap-size-hint=512M" in captured[].exec
        @test !ispath(config["run"]) && !ispath(config["evidence"])
        @test_throws ArgumentError C.main(args;env=Dict{String,String}(),io=IOBuffer(),dispatch)
    end
end

@testset "Human progress preserves the structured event contract" begin
    event=Dict("event"=>"batch_progress","batch"=>Dict("completed"=>2,"target_count"=>3,
        "processed_packets"=>42,"elapsed_seconds"=>12.345))
    text=IOBuffer();ContinuousSeedSearch.console_event(event;human=true,io=text)
    human=String(take!(text))
    @test occursin("2/3 parents",human) && occursin("42 work packets",human)
    @test !occursin("\"event\"",human)
    ContinuousSeedSearch.console_event(event;io=text)
    @test VBFSearch.JSON3.read(String(take!(text)),Dict{String,Any})==event
    completed=Dict("event"=>"seed_completed","parent_id"=>124,"completed_this_session"=>119,
        "timing"=>Dict("origin"=>"root","elapsed_from_first_dispatch_seconds"=>2.34))
    ContinuousSeedSearch.console_event(completed;human=true,io=text)
    human=String(take!(text))
    @test isempty(human)
    ContinuousSeedSearch.console_event(completed;io=text)
    @test VBFSearch.JSON3.read(String(take!(text)),Dict{String,Any})==completed
    window=Dict("event"=>"window_started","origin"=>"root","first"=>101,"last"=>200,
        "rolling"=>true,"active_windows"=>2)
    ContinuousSeedSearch.console_event(window;human=true,io=text)
    @test occursin("101–200 (2 scheduling window(s) active)",String(take!(text)))
    window["first_seed"]=21101;window["last_seed"]=21200
    ContinuousSeedSearch.console_event(window;human=true,io=text)
    @test occursin("audited rows 21101–21200",String(take!(text)))
    @test ContinuousSeedSearch.published_row(Dict("root_first"=>21001),101)==21101
    @test ContinuousSeedSearch.published_row(Dict("root_order"=>"reverse","root_last"=>22000),101)==21900
    event["window_origin"]="discovered"
    event["seed_statistics"]=Dict("completed_this_session"=>1234,
        "published_completed_this_session"=>1200,"published_selected"=>24294)
    event["runtime_metrics"]=Dict("process_cpu_available"=>true,
        "resources"=>Dict("concurrency"=>182,"cpu_allocation"=>192),
        "scheduler"=>Dict("workers_computing"=>160,"completed"=>120,"completed_uncollected"=>8),
        "recent_average_cpu_cores"=>144.0,"recent_gc_pause_seconds"=>1.0,
        "recent_apply_seconds"=>8.0,"recent_reporting_seconds"=>0.2,"recent_wall_seconds"=>15.0,
        "recent_packets"=>150,"recent_packets_per_second"=>10.0)
    ContinuousSeedSearch.console_event(event;human=true,io=text)
    human=String(take!(text))
    @test occursin("Discovered parents",human) && occursin("expanded this run: 1234",human)
    @test occursin("1200/24294 selected",human) && occursin("waiting to apply: 128",human)
    @test occursin("+150; 10.0/s",human) && !occursin("compute calls:",human)
    @test occursin("144.0 busy cores / 192 allocated (75.0%)",human)
    @test occursin("coordinator apply: 8.0s",human) && occursin("progress update: 0.2s",human)
    event["publication_seconds"]=1.75
    ContinuousSeedSearch.console_event(event;human=true,io=text)
    @test occursin("progress update: 1.75s",String(take!(text)))
    drained=Dict("event"=>"window_drained","first"=>101,"last"=>200)
    ContinuousSeedSearch.console_event(drained;human=true,io=text)
    @test occursin("101–200 drained",String(take!(text)))
end

@testset "Fresh worker reuses audited initialization and the real controller" begin
    mktempdir() do directory
        campaign=campaign_fixture(directory;two_roots=true);output=joinpath(directory,"worker")
        launch=C.plan(C.options(["--recursive-closure","--campaign",campaign,"--output",output,"-j1","--start=2","--end=2"]);env=Dict{String,String}())
        mkpath(output);path=joinpath(output,"command.toml")
        config=merge(launch.config,Dict("duration_seconds"=>0.0,"precompute_rank_table"=>false))
        open(io->TOML.print(io,config),path,"w")
        command=C.worker_command(launch,path;project=dirname(Base.active_project()))
        withenv("VBF_CLOSURE_STOP_FILE"=>nothing,"SLURM_CPUS_PER_TASK"=>nothing,
                "OPENBLAS_NUM_THREADS"=>"1","OMP_NUM_THREADS"=>"1","MKL_NUM_THREADS"=>"1") do
            process=run(pipeline(ignorestatus(command);stdout=joinpath(directory,"worker.stdout"),stderr=joinpath(directory,"worker.stderr")))
            @test process.exitcode==0 || error(read(joinpath(directory,"worker.stderr"),String))
        end
        progress=TOML.parsefile(joinpath(config["run"],"progress.toml"))
        @test progress["initial_roots"]==1
        @test progress["qualified_roots"]==2 && progress["root_first"]==progress["root_last"]==2
        @test occursin("audited rows 2–2",read(joinpath(directory,"worker.stdout"),String))
        @test progress["seed_statistics"]["published_selected"]==1
        identity=TOML.parsefile(joinpath(config["run"],"identity.toml"))
        @test identity["scientific"]["extension_cosets"]==65536
        @test identity["scientific"]["switching_directions"]==32
        @test progress["state"]=="paused_budget"
        @test !progress["running"]
        @test isfile(joinpath(config["evidence"],"result.json"))
        result=VBFSearch.JSON3.read(read(joinpath(config["evidence"],"result.json"),String),Dict{String,Any})
        @test result["processed_packets"]==0
        @test result["runtime_metrics"]["resources"]["concurrency"]==1
        @test result["runtime_metrics"]["resources"]["default_threads"]==1
        @test result["runtime_metrics"]["resources"]["interactive_threads"]==0
        @test result["runtime_metrics"]["resources"]["gc_threads"]==1
    end
end

@testset "Executable deadline supervises worker startup without a database" begin
    mktempdir() do directory
        campaign=campaign_fixture(directory);output=joinpath(directory,"bounded launch")
        command=Cmd(Cmd([joinpath(C.ROOT,"bin","vbfsearch"),"--recursive-closure","-j1",
            "--campaign",campaign,"--output",output,"--time=0.001"]);dir=directory)
        out=joinpath(directory,"stdout");err=joinpath(directory,"stderr")
        process=run(pipeline(ignorestatus(command);stdout=out,stderr=err))
        @test process.exitcode==0
        @test isfile(joinpath(output,"command.toml"))
        @test !ispath(joinpath(output,"state"))
        @test occursin("Stopped before search initialization",read(out,String))
    end
end

@testset "Single-file planning is explicit and dry runs create no workspace" begin
    mktempdir() do directory
        campaign=campaign_fixture(directory)
        for suffix in (".sqlite",".sqlite3",".db",".SQLITE")
            output=joinpath(directory,"results"*suffix)
            args=["--recursive-closure","--campaign",campaign,"--output",output,"--dry-run"]
            launch=C.plan(C.options(args);env=Dict{String,String}())
            @test launch.config["output_format"]=="sqlite"
            @test launch.config["workspace"]==joinpath(directory,"."*basename(output)*".work")
            @test C.main(args;env=Dict{String,String}(),io=IOBuffer())==0
            @test !ispath(output) && !ispath(launch.config["workspace"])
        end
        launch=C.plan(C.options(["--recursive-closure","--campaign",campaign]);env=Dict{String,String}())
        @test endswith(launch.config["output"],".sqlite")
        @test !ispath(launch.config["workspace"])
    end
end

@testset "SQLite publication preserves all rows and embeds portable evidence without copying the database" begin
    mktempdir() do directory
        inputs=joinpath(directory,"inputs");mkdir(inputs)
        campaign=campaign_fixture(inputs)
        output=joinpath(directory,"results with spaces %?#.sqlite")
        launch=sqlite_launch(campaign,output);config=launch.config
        workspace=config["workspace"];source=joinpath(config["run"],"closure.sqlite")
        @test !ispath(output) && isfile(joinpath(workspace,"launcher","vbfsearch_output.jl"))
        VBFSearch.closure_init(campaign;output=config["run"])
        store=VBFSearch._closure_open(config["run"])
        try
            job=only(VBFSearch._closure_rows(store,"SELECT id,parent_id,kind FROM jobs WHERE kind='switching'"))
            p=VBFSearch.properties(gold_apn(8).lut)
            VBFSearch._closure_record_candidate!(store,job,p,"output-fixture",Dict("direction"=>1,"fixture"=>true))
        finally
            VBFSearch._closure_close(store)
        end
        bytes=UInt8[0x00,0xff,0x41,0x00];write(joinpath(workspace,"binary evidence"),bytes)
        write(joinpath(workspace,"empty evidence"),UInt8[])
        before=scientific_rows(source);inode=stat(source).inode
        result=Dict("state"=>"paused_budget","processed_packets"=>0)
        # A failure after packaging must retain all data and leave no final output.
        @test_throws ErrorException O.publish(config,result;before_publish=()->error("injected before publication"))
        @test !ispath(output) && isfile(source)
        @test isequal(scientific_rows(source),before)
        @test stat(source).inode==inode
        # An output created concurrently is never overwritten.
        write(output,"do not overwrite")
        @test_throws ErrorException O.publish(config,result)
        @test read(output,String)=="do not overwrite"
        rm(output)
        receipt=O.publish(config,result)
        @test receipt["verified"] && receipt["state"]=="paused_budget"
        @test stat(output).inode==inode
        @test !ispath(workspace)
        @test all(!ispath(output*suffix) for suffix in ("-wal","-shm","-journal"))
        @test isequal(scientific_rows(output),before)
        rm(inputs;recursive=true)
        @test O.verify(output)==receipt
        db=SQLite.DB(output)
        try
            @test only(DS.query(db,"SELECT content FROM vbfsearch_artifacts WHERE path='binary evidence'"))["content"]==bytes
            @test isempty(only(DS.query(db,"SELECT content FROM vbfsearch_artifacts WHERE path='empty evidence'"))["content"])
            @test only(DS.query(db,"SELECT COUNT(*) n FROM paths"))["n"]==1
            @test only(DS.query(db,"SELECT witness FROM paths"))["witness"]==VBFSearch._closure_text(Dict("direction"=>1,"fixture"=>true))
            @test only(DS.query(db,"SELECT COUNT(*) n FROM candidates"))["n"]==1
            @test only(DS.query(db,"PRAGMA journal_mode"))["journal_mode"]=="delete"
        finally
            close(db)
        end
        # Integrity checks also work on a moved file and reject changed archives.
        damaged=joinpath(directory,"moved.sqlite");cp(output,damaged)
        @test O.verify(damaged)["verified"]
        db=SQLite.DB(damaged)
        try
            DS.execute!(db,"UPDATE vbfsearch_artifacts SET content=? WHERE path='binary evidence'",(reverse(bytes),))
        finally
            close(db)
        end
        @test_throws ErrorException O.verify(damaged)
        @test O.verify(output)["verified"]
    end
end

@testset "Real worker finishes an initialized search as one SQLite" begin
    mktempdir() do directory
        campaign=campaign_fixture(directory;two_roots=true);output=joinpath(directory,"worker.sqlite")
        launch=sqlite_launch(campaign,output;extra=["--start=2","--end=2"])
        config=merge(launch.config,Dict("duration_seconds"=>0.0,"precompute_rank_table"=>false))
        path=joinpath(config["workspace"],"command.toml")
        open(io->TOML.print(io,config),path,"w")
        command=C.worker_command(launch,path)
        withenv("VBF_CLOSURE_STOP_FILE"=>nothing,"SLURM_CPUS_PER_TASK"=>nothing,
                "OPENBLAS_NUM_THREADS"=>"1","OMP_NUM_THREADS"=>"1","MKL_NUM_THREADS"=>"1") do
            process=run(pipeline(ignorestatus(command);stdout=joinpath(directory,"worker.stdout"),stderr=joinpath(directory,"worker.stderr")))
            @test process.exitcode==0 || error(read(joinpath(directory,"worker.stderr"),String))
        end
        @test isfile(output) && !ispath(config["workspace"])
        @test O.verify(output)["state"]=="paused_budget"
        db=SQLite.DB(output)
        try
            result=VBFSearch.JSON3.read(only(DS.query(db,"SELECT value FROM metadata WHERE key='vbfsearch_result'"))["value"],Dict{String,Any})
            @test result["processed_packets"]==0
            @test result["runtime_metrics"]["resources"]["default_threads"]==1
            progress=TOML.parse(String(only(DS.query(db,"SELECT content FROM vbfsearch_artifacts WHERE path='state/progress.toml'"))["content"]))
            @test progress["qualified_roots"]==2 && progress["root_first"]==progress["root_last"]==2
            @test !progress["running"] && progress["initial_roots"]==1
            @test only(DS.query(db,"SELECT COUNT(*) n FROM vbfsearch_artifacts WHERE path='session/result.json'"))["n"]==1
        finally
            close(db)
        end
    end
end

@testset "Public executable returns a single SQLite even when stopped before initialization" begin
    mktempdir() do directory
        campaign=campaign_fixture(directory);output=joinpath(directory,"early.sqlite")
        command=Cmd(Cmd([joinpath(C.ROOT,"bin","vbfsearch"),"--recursive-closure","-j1",
            "--campaign",campaign,"--output",output,"--time=0.001"]);dir=directory)
        process=run(pipeline(ignorestatus(command);stdout=joinpath(directory,"stdout"),stderr=joinpath(directory,"stderr")))
        @test process.exitcode==0
        @test isfile(output) && !ispath(joinpath(directory,".early.sqlite.work"))
        @test O.verify(output)["state"]=="stopped_before_initialization"
        db=SQLite.DB(output)
        try
            @test only(DS.query(db,"SELECT COUNT(*) n FROM candidates"))["n"]==0
            @test isempty(DS.query(db,"SELECT value FROM metadata WHERE key='initialization_complete'"))
        finally
            close(db)
        end
    end
end

@testset "An outer batch STOP survives public-command startup" begin
    mktempdir() do directory
        campaign=campaign_fixture(directory);output=joinpath(directory,"scheduler.sqlite")
        request=joinpath(directory,"scheduler STOP");write(request,"SIGUSR1\n")
        command=Cmd([joinpath(C.ROOT,"bin","vbfsearch"),"--recursive-closure","-j1",
            "--campaign",campaign,"--output",output,"--time=60"])
        out=joinpath(directory,"stdout");err=joinpath(directory,"stderr")
        process=withenv("VBF_SEARCH_STOP_FILE"=>request) do
            run(pipeline(ignorestatus(command);stdout=out,stderr=err))
        end
        @test process.exitcode==0 || error(read(err,String))
        @test O.verify(output)["state"]=="stopped_before_initialization"
        @test !ispath(joinpath(directory,".scheduler.sqlite.work"))
        @test occursin("Stopped before search initialization",read(out,String))
    end
end
end
