using Test, TOML, VBFRepro

@testset "VBFRepro discovery" begin
    papers = discover_papers()
    @test length(papers) == 44
    @test length(unique(p.id for p in papers)) == length(papers)
    @test isfile(joinpath(paper_path("Yu_202211d"), "qam_correspondence.jl"))
    @test isfile(joinpath(repo_root(), "Project.toml"))
    @test papers_root() == joinpath(repo_root(), "packages", "VBFRepro", "papers")
    @test_throws ArgumentError paper_path("../Yu_202211d")
    @test_throws ArgumentError paper_path("absent")
end

@testset "atomic output ownership and termination race" begin
    mktempdir() do temporary
        empty_output = joinpath(temporary, "empty")
        mkdir(empty_output)
        @test VBFRepro._claim_output(empty_output) == empty_output
        @test isdir(joinpath(empty_output, ".vbf-repro-claim"))
        @test_throws ArgumentError VBFRepro._claim_output(empty_output)
        absent_output = joinpath(temporary, "parent", "absent")
        @test VBFRepro._claim_output(absent_output) == absent_output
        existing_output = joinpath(temporary, "existing")
        mkdir(existing_output)
        write(joinpath(existing_output, "evidence.txt"), "immutable")
        @test_throws ArgumentError VBFRepro._claim_output(existing_output)
        @test readdir(existing_output) == ["evidence.txt"]

        # Race independent OS processes, not merely cooperative Julia tasks.
        shared = joinpath(temporary, "raced")
        gate = joinpath(temporary, "start")
        jobs = Base.Process[]
        for index in 1:2
            expression = "using VBFRepro; write(ARGS[3], \"ready\"); while !isfile(ARGS[2]); sleep(0.001); end; " *
                "try VBFRepro._claim_output(ARGS[1]); println(\"claimed\"); " *
                "catch e; e isa ArgumentError || rethrow(); println(\"rejected\"); end"
            ready = joinpath(temporary, "ready_$index")
            command = `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) -e $expression -- $shared $gate $ready`
            io = open(joinpath(temporary, "result_$index"), "w")
            push!(jobs, run(pipeline(command; stdout=io, stderr=io); wait=false))
            close(io)
        end
        ready_status = timedwait(() -> all(isfile(joinpath(temporary,"ready_$index")) for index in 1:2), 30)
        @test ready_status == :ok
        if ready_status != :ok
            kill.(jobs)
            error("claim-race subprocesses did not start")
        end
        write(gate, "start")
        wait.(jobs)
        @test all(success, jobs)
        outcomes = [strip(read(joinpath(temporary,"result_$index"),String)) for index in 1:2]
        @test sort(outcomes) == ["claimed", "rejected"]
        @test readdir(shared) == [".vbf-repro-claim"]
        if Sys.isunix()
            finished = run(`$(Base.julia_cmd()) --startup-file=no -e 'nothing'`; wait=false)
            wait(finished)
            @test VBFRepro._terminate_group(finished) === nothing
        end
    end
end

@testset "command-line dispatch" begin
    mktempdir() do temporary
        @test main(["run", "Yu_202211d", "--target", "help", "--param", "limit=17",
                    "--timeout-seconds", "10", "--output", joinpath(temporary,"cli")]) == 0
        metadata = TOML.parsefile(joinpath(temporary,"cli","run.toml"))
        @test metadata["paper"] == "Yu_202211d"
        @test metadata["parameters"]["limit"] == "17"
        @test metadata["timeout_seconds"] == 10
        @test_throws ArgumentError main(["run"])
        @test_throws ArgumentError main(["absent"])
        @test_throws ArgumentError main(["list", "extra"])
        @test_throws ArgumentError main(["run", "Yu_202211d", "--param", "x"])
        @test_throws ArgumentError main(["run", "Yu_202211d", "--param", "x=1", "--param", "x=2"])
        @test_throws ArgumentError main(["test", "Yu_202211d", "--target", "report"])
    end
end

@testset "isolated execution and durable evidence" begin
    mktempdir() do temporary
        root = joinpath(temporary, "papers")
        paper = joinpath(root, "2026", "Fixture_202600")
        project = joinpath(temporary, "project")
        mkpath(paper); mkpath(project)
        mkpath(joinpath(paper,"input"))
        write(joinpath(paper,"input","fixture.txt"), "independent original input\n")
        write(joinpath(project, "Project.toml"), "[deps]\n")
        write(joinpath(paper, "Makefile"), raw"""
report:
	@echo "cwd=$$(pwd)"
	@echo "parameter=$(limit)"
	@echo "environment=$$VBF_REPRO_FIXTURE"
test:
	@echo fixture-tests-passed
fail:
	@exit 7
slow:
	@sleep 10
""")
        out = joinpath(temporary, "passed")
        result = run_paper("Fixture_202600"; root, project, output=out,
            parameters=Dict(:limit => 17), environment=Dict("VBF_REPRO_FIXTURE"=>"set"))
        @test result.status == "passed"
        @test result.exit_code == 0
        metadata = TOML.parsefile(result.manifest)
        @test metadata["parameters"] == Dict("limit"=>"17")
        @test metadata["cwd"] == paper
        @test metadata["project"] == project
        @test metadata["environment_overrides"] == Dict("VBF_REPRO_FIXTURE"=>"set")
        @test metadata["status"] == "passed"
        @test !isempty(metadata["source_sha256"])
        @test length(metadata["input_sha256"]) == 1
        @test length(metadata["output_log_sha256"]) == 64
        log = read(joinpath(out, "output.log"), String)
        @test occursin("cwd=$paper", log)
        @test occursin("parameter=17", log)
        @test occursin("environment=set", log)
        @test_throws ArgumentError run_paper("Fixture_202600"; root, project, output=out)
        failed = run_paper("Fixture_202600"; root, project, target="fail", output=joinpath(temporary,"failed"))
        @test failed.status == "failed"
        @test failed.exit_code != 0
        tested = test_paper("Fixture_202600"; root, project, output=joinpath(temporary,"tested"))
        @test tested.status == "passed"
        @test tested.target == "test"
        timed = run_paper("Fixture_202600"; root, project, target="slow", timeout_seconds=0.15,
                          output=joinpath(temporary,"timed"))
        @test timed.status == "timed_out"
        @test TOML.parsefile(timed.manifest)["elapsed_seconds"] < 5
        @test_throws ArgumentError run_paper("Fixture_202600"; root, project, target="-C")
        @test_throws ArgumentError run_paper("Fixture_202600"; root, project, timeout_seconds=0)
        @test_throws ArgumentError run_paper("Fixture_202600"; root, project, parameters=Dict("ROOT"=>"bad"))
        @test_throws ArgumentError run_paper("Fixture_202600"; root, project, parameters=Dict("limit"=>"\$(shell echo x)"))
        errored = joinpath(temporary,"errored")
        @test_throws Base.IOError run_paper("Fixture_202600"; root, project, make="/nonexistent-make", output=errored)
        @test TOML.parsefile(joinpath(errored,"run.toml"))["status"] == "error"
    end
end
