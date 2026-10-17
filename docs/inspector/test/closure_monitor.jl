using Test, TOML, SHA, HTTP, JSON3
include(joinpath(@__DIR__, "..", "closure_monitor.jl"))
using .APNClosureMonitor

@testset "Direct published-root comparisons preserve reference and expansion scopes" begin
    mktempdir() do dir
        path=joinpath(dir,"direct.json")
        run=Dict{String,Any}("directory"=>dir,"initial_roots"=>2,"total_parents"=>7,
            "roots_sha256"=>"roots-digest","seed_progress"=>Dict("completed"=>2))
        saved=Dict{String,Any}("schema"=>"vbfsearch-published-root-comparison-v1",
            "campaign_run"=>dir,"roots_sha256"=>"roots-digest","published_seed_count"=>2,
            "scope"=>"direct_published_root_outputs","reference_excludes_private_discoveries"=>true,
            "unresolved_root_outputs"=>0,"direct_output_classes"=>5,"literature_absent_classes"=>2,
            "literature_matching_pairs"=>3,"literature_verified_matches"=>3,
            "historical_verified_overlap"=>1,"historical_candidate_overlap"=>1,
            "historical_total_classes"=>4,"complete"=>true,
            "all_positive_witnesses_replayed"=>true,"unresolved_pairs"=>0)
        write(path,JSON3.write(saved))
        result=APNClosureMonitor.published_root_summary(run,path)
        @test result["status"]=="complete" && result["literature_absent_classes"]==2
        @test result["direct_output_classes"]==5 # full campaign has seven classes
        for (key,value) in (("scope","recursive_closure"),("campaign_run","other"),
                ("roots_sha256","other-roots"),("published_seed_count",3),
                ("reference_excludes_private_discoveries",false),("unresolved_root_outputs",1))
            write(path,JSON3.write(merge(saved,Dict(key=>value))))
            @test APNClosureMonitor.published_root_summary(run,path)["status"]=="outdated"
        end
        write(path,JSON3.write(merge(saved,Dict("literature_verified_matches"=>2))))
        @test APNClosureMonitor.published_root_summary(run,path)["status"]=="verifying"
        write(path,JSON3.write(merge(saved,Dict("literature_absent_classes"=>3))))
        @test_throws ErrorException APNClosureMonitor.published_root_summary(run,path)
    end
end

@testset "Catalog counts retain their scope and reject stale audits" begin
    mktempdir() do directory
        path=joinpath(directory,"catalog.json")
        run=Dict{String,Any}("directory"=>directory,"initial_roots"=>2,"total_parents"=>5)
        @test APNClosureMonitor.catalog_summary(run,path)["status"]=="unavailable"
        saved=Dict{String,Any}("schema"=>"vbfsearch-catalog-comparison-v1",
            "current_run"=>directory,"current_classes"=>5,"initial_roots"=>2,
            "catalog_snapshot_validated"=>true,"all_catalog_entries_covered"=>true,
            "complete"=>false,"confirmed_absent_classes"=>7,
            "current_confirmed_absent_classes"=>3,"earlier_only_confirmed_absent_classes"=>4)
        write(path,JSON3.write(saved))
        partial=APNClosureMonitor.catalog_summary(run,path)
        @test partial["status"]=="verifying" && partial["confirmed_absent_classes"]==7
        saved["complete"]=true;write(path,JSON3.write(saved))
        @test APNClosureMonitor.catalog_summary(run,path)["status"]=="verifying"
        merge!(saved,Dict("all_positive_witnesses_replayed"=>true,"remaining_pairs"=>0,
            "verified_catalog_pairs"=>4,"total_catalog_pairs"=>4));write(path,JSON3.write(saved))
        @test APNClosureMonitor.catalog_summary(run,path)["status"]=="complete"
        growing=APNClosureMonitor.catalog_summary(merge(run,Dict("total_parents"=>6)),path)
        @test growing["status"]=="snapshot"
        @test growing["confirmed_absent_classes"]==7
        @test growing["audited_current_classes"]==5 && growing["unaudited_classes"]==1
        saved["remaining_pairs"]=1;write(path,JSON3.write(saved))
        @test APNClosureMonitor.catalog_summary(run,path)["status"]=="verifying"
        saved["remaining_pairs"]=0
        for (key,value) in (("current_classes",6),("current_run","elsewhere"),
                ("initial_roots",3),("catalog_snapshot_validated",false),
                ("all_catalog_entries_covered",false))
            write(path,JSON3.write(merge(saved,Dict(key=>value))))
            result=APNClosureMonitor.catalog_summary(run,path)
            @test result["status"]=="outdated"
            @test result["confirmed_absent_classes"]===nothing
        end
        saved["earlier_only_confirmed_absent_classes"]=5;write(path,JSON3.write(saved))
        @test_throws ErrorException APNClosureMonitor.catalog_summary(run,path)
    end
end

@testset "Discovery metrics require a completed comparison of the current class set" begin
    mktempdir() do directory
        run=Dict{String,Any}("directory"=>directory,"initial_roots"=>2,
            "total_parents"=>5,"promoted_parents"=>3,"unresolved_equivalence"=>0)
        @test APNClosureMonitor.discovery_summary(run,"")["new_vs_earlier"]===nothing
        path=joinpath(directory,"comparison.json")
        saved=Dict{String,Any}("current_run"=>directory,"current_class_representatives"=>5,
            "published_current_roots"=>2,"unresolved_cross_dataset_pairs"=>0,
            "verified_ea_class_overlap"=>1,"old_class_representatives"=>4,"combined_ea_classes"=>8,
            "current_discovered_classes_absent_from_old_dataset_and_published_roots"=>2,
            "completed_utc"=>"2026-10-15T22:00:00Z",
            "ea_comparison_summary"=>Dict("all_positive_witnesses_replayed"=>true,
                "status_counts"=>Dict("equivalent_with_verified_witness"=>1)))
        write(path,JSON3.write(saved))
        result=APNClosureMonitor.discovery_summary(run,path)
        @test result["comparison_status"]=="current" && result["new_vs_earlier"]==2
        @test result["discovered_classes"]==3 && result["literature_novelty"]=="unresolved"
        for (field,value) in (("total_parents",6),("initial_roots",1),("unresolved_equivalence",1),("directory","other-run"))
            changed=merge(run,Dict(field=>value))
            result=APNClosureMonitor.discovery_summary(changed,path)
            @test result["comparison_status"]=="outdated"
            @test result["new_vs_earlier"]===nothing
        end
        saved["ea_comparison_summary"]["all_positive_witnesses_replayed"]=false
        write(path,JSON3.write(saved))
        @test APNClosureMonitor.discovery_summary(run,path)["new_vs_earlier"]===nothing
        relayed=APNClosureMonitor.discovery_summary(merge(run,Dict("relayed_discoveries"=>result)),"")
        @test relayed==result
    end
end

@testset "Controller progress polls use the published report without reading SQLite" begin
    mktempdir() do directory
        ledger=joinpath(directory,"closure.sqlite")
        write(ledger,"not a SQLite database; polling must use the report")
        progress=Dict("schema"=>"vbfsearch-closure-progress-v1",
            "state"=>"paused_budget","initial_roots"=>2,"running"=>false,
            "heartbeat_utc"=>"","sessions"=>Any[])
        open(io->TOML.print(io,progress),joinpath(directory,"progress.toml"),"w")
        result=APNClosureMonitor.controller_snapshot(directory)
        @test result["initial_roots"]==2
        @test result["state"]=="paused_budget" && !result["running"]
        @test result["directory"]==abspath(directory)
        @test read(ledger,String)=="not a SQLite database; polling must use the report"
        progress["sessions"]=[Dict("pid"=>1234,"finished"=>"")]
        open(io->TOML.print(io,progress),joinpath(directory,"progress.toml"),"w")
        metrics=Dict("schema"=>"vbfsearch-process-metrics-v1","pid"=>1234,
            "mean_cpu_cores"=>Dict("30"=>17.0))
        metrics_path=joinpath(directory,"process_metrics.json")
        write(metrics_path,JSON3.write(metrics))
        lease=APNClosureMonitor.VBFSearch._closure_lease(directory)
        try
            measured=APNClosureMonitor.controller_snapshot(directory)
            @test measured["process_metrics"]["mean_cpu_cores"]["30"]==17.0
            metrics["pid"]=5678
            write(metrics_path,JSON3.write(metrics))
            @test !haskey(APNClosureMonitor.controller_snapshot(directory),"process_metrics")
        finally
            close(lease)
        end
    end
end

function fixture(directory)
    mkpath(joinpath(directory, "seed_count"))
    roots = joinpath(directory, "seed_count", "verified_roots.tsv")
    write(roots, "lut_sha256\nroot-one\nroot-two\n")
    plan = Dict("roots" => Dict(
        "qualified_root_file" => "seed_count/verified_roots.tsv",
        "equivalence_evidence" => "seed_count/equivalence_result.toml",
        "qualified_root_count" => 2, "profile_b6" => 52, "profile_order" => "bminK",
        "qualified_b5_28_classes" => 1, "qualified_b5_30_classes" => 1,
        "sources" => ["published-fixture"],
    ))
    open(io -> TOML.print(io, plan), joinpath(directory,"campaign.toml"), "w")
    audit = Dict("complete" => true, "all_encoded_positive_witnesses_replayed" => true,
        "verified_seed_classes" => 2, "verified_roots_sha256" => bytes2hex(open(SHA.sha256, roots)))
    open(io -> TOML.print(io, audit), joinpath(directory,"seed_count","equivalence_result.toml"), "w")
    figures = joinpath(directory,"diagrams","gallery")
    mkpath(figures)
    write(joinpath(figures,"slide_pipeline.svg"), "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>")
    write(joinpath(figures,"index.html"), "<html>fixture gallery</html>")
    directory
end

@testset "Assigned roots remain bound to the entire published audit" begin
    mktempdir() do directory
        fixture(directory)
        current = Ref{Dict{String,Any}}()
        monitor = APNClosureMonitor.Monitor(directory; read_run=_ -> deepcopy(current[]))
        roots = APNClosureMonitor.root_summary!(monitor)
        runtime = APNClosureMonitor.empty_execution(roots)
        merge!(runtime, Dict("roots_sha256"=>roots["sha256"],
            "campaign_sha256"=>roots["campaign_sha256"], "initial_roots"=>1,
            "qualified_roots"=>2, "root_first"=>2, "root_last"=>2,
            "root_order"=>"reverse", "total_parents"=>1))
        current[] = runtime
        mkpath(monitor.run)
        write(joinpath(monitor.run,"closure.sqlite"), "reader fixture")
        write(joinpath(monitor.run,"progress.toml"), "schema = \"fixture\"\n")
        result = APNClosureMonitor.snapshot(monitor; force=true)
        @test result["execution"]["initial_roots"] == 1
        @test result["roots"]["count"] == 2
        @test result["remaining_parents"] == 1
        current[]["qualified_roots"] = 3
        @test_throws ErrorException APNClosureMonitor.snapshot(monitor; force=true)
        current[]["qualified_roots"] = 2
        current[]["root_first"] = 1
        @test_throws ErrorException APNClosureMonitor.snapshot(monitor; force=true)
        current[]["root_first"] = 0
        @test_throws ErrorException APNClosureMonitor.snapshot(monitor; force=true)
        current[]["root_first"] = 2
        current[]["root_order"] = "unknown"
        @test_throws ErrorException APNClosureMonitor.snapshot(monitor; force=true)
    end
end

@testset "Audited roots, absent runner, and read-only gallery routes" begin
    mktempdir() do directory
        fixture(directory)
        monitor = APNClosureMonitor.Monitor(directory)
        call(method,path) = APNClosureMonitor.handle(monitor, HTTP.Request(method,path))
        result = JSON3.read(String(call("GET","/api/progress").body))
        @test result.roots.count == 2
        @test result.execution.state == "not_started"
        @test result.execution.promoted_parents == result.execution.completed_parents == 0
        @test result.execution.queued_parents === nothing
        @test !isdir(joinpath(directory,"run"))
        @test call("POST","/api/progress").status == 405
        @test call("GET","/diagram.svg").status == 200
        @test call("GET","/figures/").status == 200
        @test call("GET","/figures/%2e%2e/campaign.toml").status == 400
        @test call("GET","/figures/%00.svg").status == 400
        @test call("GET","/missing").status == 404
        outside = joinpath(directory,"private.svg")
        write(outside,"not a public figure")
        symlink(outside, joinpath(monitor.figures,"escape.svg"))
        @test call("GET","/figures/escape.svg").status == 400
        write(joinpath(directory,"seed_count","verified_roots.tsv"), "changed\n")
        @test_throws ErrorException APNClosureMonitor.snapshot(monitor; force=true)
    end
end

@testset "Committed counters update without conflating outputs and parents" begin
    mktempdir() do directory
        fixture(directory)
        current = Ref{Dict{String,Any}}()
        reads = Ref(0)
        monitor = APNClosureMonitor.Monitor(directory; read_run=path -> (reads[]+=1; deepcopy(current[])))
        roots = APNClosureMonitor.root_summary!(monitor)
        runtime = APNClosureMonitor.empty_execution(roots)
        merge!(runtime, Dict("roots_sha256"=>roots["sha256"],
            "campaign_sha256"=>roots["campaign_sha256"],"state"=>"running","running"=>true,
            "promoted_parents"=>1,"total_parents"=>3,"completed_parents"=>1,
            "queued_parents"=>1,"active_parents"=>1,"exact_luts"=>10))
        current[] = runtime
        mkpath(monitor.run)
        write(joinpath(monitor.run,"closure.sqlite"), "reader fixture")
        preparing = APNClosureMonitor.snapshot(monitor; force=true, now_seconds=99)
        @test preparing["execution"]["state"] == "initializing"
        @test reads[] == 0
        write(joinpath(monitor.run,"progress.toml"), "schema = \"fixture\"\n")
        first = APNClosureMonitor.snapshot(monitor; force=true, now_seconds=100)
        @test first["execution"]["attached"]
        @test first["remaining_parents"] == 2
        @test first["completion_fraction"] == 1/3
        @test first["execution"]["promoted_parents"] != first["execution"]["exact_luts"]
        @test first["rates"]["promoted_per_minute"] === nothing
        APNClosureMonitor.snapshot(monitor; now_seconds=101)
        @test reads[] == 1
        current[]["promoted_parents"] = 3
        current[]["total_parents"] = 5
        second = APNClosureMonitor.snapshot(monitor; force=true, now_seconds=160)
        @test second["execution"]["total_parents"] == 5
        @test second["rates"]["promoted_per_minute"] == 2
        current[]["roots_sha256"] = "wrong-campaign-roots"
        @test_throws ErrorException APNClosureMonitor.snapshot(monitor; force=true)
        @test read(joinpath(monitor.run,"closure.sqlite"),String) == "reader fixture"
    end
end
