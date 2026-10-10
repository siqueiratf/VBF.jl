using Test, TOML, VBFRepro

@testset "VBFRepro discovery" begin
    papers = discover_papers()
    @test length(papers) == 44
    @test length(unique(p.id for p in papers)) == length(papers)
    @test isfile(joinpath(paper_path("202211-yu-qam"), "qam_correspondence.jl"))
    @test isfile(joinpath(repo_root(), "Project.toml"))
    @test papers_root() == joinpath(repo_root(), "packages", "VBFRepro", "src")
    @test all(p -> startswith(p.id,p.year) && dirname(p.path)==papers_root(),papers)
    @test_throws ArgumentError paper_path("../202211-yu-qam")
    @test_throws ArgumentError paper_path("absent")
    # A valid --project flag does not imply that the migrated test script exists.
    for paper in papers
        directory = paper_path(paper.id)
        expected = [joinpath(directory,name,"runtests.jl") for name in ("test","tests")
            if isfile(joinpath(directory,name,"runtests.jl"))]
        command = read(`make --no-print-directory -n -C $directory test`, String)
        @test any(path -> occursin(path, replace(command,"//"=>"/")), expected)
    end
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
        @test main(["run", "202211-yu-qam", "--target", "help", "--param", "limit=17",
                    "--timeout-seconds", "10", "--output", joinpath(temporary,"cli")]) == 0
        metadata = TOML.parsefile(joinpath(temporary,"cli","run.toml"))
        @test metadata["paper"] == "202211-yu-qam"
        @test metadata["parameters"]["limit"] == "17"
        @test metadata["timeout_seconds"] == 10
        @test_throws ArgumentError main(["run"])
        @test_throws ArgumentError main(["absent"])
        @test_throws ArgumentError main(["list", "extra"])
        @test_throws ArgumentError main(["run", "202211-yu-qam", "--param", "x"])
        @test_throws ArgumentError main(["run", "202211-yu-qam", "--param", "x=1", "--param", "x=2"])
        @test_throws ArgumentError main(["test", "202211-yu-qam", "--target", "report"])
    end
end

@testset "isolated execution and durable evidence" begin
    mktempdir() do temporary
        root = joinpath(temporary, "papers")
        paper = joinpath(root, "202600-fixture-evidence")
        project = joinpath(temporary, "project")
        mkpath(paper); mkpath(project)
        mkpath(joinpath(paper,"input"))
        write(joinpath(paper,"input","fixture.txt"), "independent original input\n")
        write(joinpath(project, "Project.toml"), "[deps]\n")
        for kind in ("input","results")
            directory=joinpath(project,"packages","VBFRepro","src","202600-other-study",kind)
            mkpath(directory)
            write(joinpath(directory,"excluded.jl"),"error(\"never import generated evidence\")\n")
        end
        fixture = joinpath(paper,"certificate.toml")
        write(fixture, "columns = [1,2,4]\n")
        verifier = joinpath(paper,"verify.jl")
        write(verifier,"println(\"independent verifier\")\n")
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
        result = run_paper("202600-fixture-evidence"; root, project, output=out,
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
        @test !any(key->endswith(key,"excluded.jl"),keys(metadata["source_sha256"]))
        @test haskey(metadata["source_sha256"], relpath(verifier,project))
        fixture_key = relpath(fixture, project)
        @test haskey(metadata["source_sha256"], fixture_key)
        old_hash = metadata["source_sha256"][fixture_key]
        write(fixture, "columns = [1,2,5]\n")
        @test VBFRepro._source_hashes(paper,project)[fixture_key] != old_hash
        @test length(metadata["input_sha256"]) == 1
        @test length(metadata["output_log_sha256"]) == 64
        log = read(joinpath(out, "output.log"), String)
        @test occursin("cwd=$paper", log)
        @test occursin("parameter=17", log)
        @test occursin("environment=set", log)
        @test_throws ArgumentError run_paper("202600-fixture-evidence"; root, project, output=out)
        failed = run_paper("202600-fixture-evidence"; root, project, target="fail", output=joinpath(temporary,"failed"))
        @test failed.status == "failed"
        @test failed.exit_code != 0
        tested = test_paper("202600-fixture-evidence"; root, project, output=joinpath(temporary,"tested"))
        @test tested.status == "passed"
        @test tested.target == "test"
        timed = run_paper("202600-fixture-evidence"; root, project, target="slow", timeout_seconds=0.15,
                          output=joinpath(temporary,"timed"))
        @test timed.status == "timed_out"
        @test TOML.parsefile(timed.manifest)["elapsed_seconds"] < 5
        @test_throws ArgumentError run_paper("202600-fixture-evidence"; root, project, target="-C")
        @test_throws ArgumentError run_paper("202600-fixture-evidence"; root, project, timeout_seconds=0)
        @test_throws ArgumentError run_paper("202600-fixture-evidence"; root, project, parameters=Dict("ROOT"=>"bad"))
        @test_throws ArgumentError run_paper("202600-fixture-evidence"; root, project, parameters=Dict("limit"=>"\$(shell echo x)"))
        errored = joinpath(temporary,"errored")
        @test_throws Base.IOError run_paper("202600-fixture-evidence"; root, project, make="/nonexistent-make", output=errored)
        @test TOML.parsefile(joinpath(errored,"run.toml"))["status"] == "error"
    end
end
