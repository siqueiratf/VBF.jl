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
        @test_throws VBFRepro.UsageError main(["run"])
        @test_throws VBFRepro.UsageError main(["absent"])
        @test_throws VBFRepro.UsageError main(["list", "a", "b"])
        @test_throws VBFRepro.UsageError main(["run", "202211-yu-qam", "--param", "x"])
        @test_throws VBFRepro.UsageError main(["run", "202211-yu-qam", "--param", "x=1", "--param", "x=2"])
        @test_throws VBFRepro.UsageError main(["test", "202211-yu-qam", "--target", "report"])
        @test_throws VBFRepro.UsageError main(["run", "yu"])            # ambiguous part of an ID
        @test_throws VBFRepro.UsageError main(["run", "no-such-paper"])
    end
end

@testset "command-line help and lookup" begin
    @test VBFRepro.resolve_command("te") == "test"
    @test VBFRepro.resolve_command("li") == "list"
    @test_throws VBFRepro.UsageError VBFRepro.resolve_command("x")
    @test VBFRepro.resolve_paper("202211-yu-qam"; io=devnull) == "202211-yu-qam"
    @test VBFRepro.resolve_paper("Yu_202211"; io=devnull) == "202211-yu-qam"
    @test VBFRepro.resolve_paper("yu-qam"; io=devnull) == "202211-yu-qam"
    @test ("limit" => "2147483647") in VBFRepro.paper_parameters(paper_path("202211-yu-qam"))
    for args in (String[], ["help"], ["help", "run"], ["run", "--help"], ["test", "-h"])
        @test redirect_stdout(() -> main(args), devnull) == 0
    end
    @test redirect_stdout(() -> main(["list", "qam"]), devnull) == 0
    for shell in ("bash", "zsh", "fish")
        @test redirect_stdout(() -> main(["completions", shell]), devnull) == 0
    end
    @test redirect_stderr(() -> VBFRepro.cli(["run"]), devnull) == 2
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

@testset "portal metadata: discovery, scaffold, checks" begin
    mktempdir() do root
        paper = joinpath(root, "202601-fixture-claims")
        mkpath(joinpath(paper, "test"))
        write(joinpath(paper, "Makefile"), """
            include ../paper.mk
            help:
            \t@echo '  theorem3        Thm 3: main result'
            \t@echo '  sweep           Check Lemma 2.1 and Table 4 counts'
            \t@echo '  extra           Bounded diagnostics'
            theorem3:
            \techo 3
            sweep:
            \techo s
            extra:
            \techo e
            """)
        write(joinpath(paper, "theorem3.jl"), "# Implements Theorem 3 — the main result\n# VBF API used: SBox, differential_uniformity\n")
        write(joinpath(paper, "sweep.jl"), "# Implements Lemma 2.1 and Table 4 checks\n# VBF API used: none\n")
        write(joinpath(paper, "extra.jl"), "# Implements bounded diagnostics\n")
        write(joinpath(paper, "helpers.jl"), "# Implements shared helpers\n")
        write(joinpath(paper, "test", "test_theorem3.jl"), "")
        claims, unassigned = discover_candidates("202601-fixture-claims"; root)
        ids = [c["id"] for c in claims]
        @test ids == ["lemma2_1", "table4", "theorem3"]                  # one file, two results
        @test all(c -> c["review"] == "pending", claims)                 # never reviewed by discovery
        @test only(c for c in claims if c["id"] == "table4")["files"] == ["sweep.jl"]
        @test only(c for c in claims if c["id"] == "theorem3")["tests"] == ["test/test_theorem3.jl"]
        @test only(c for c in claims if c["id"] == "theorem3")["api"] == ["SBox", "differential_uniformity"]
        @test unassigned == ["extra.jl"]                                  # no result named: for review
        @test VBFRepro.stem_label("table4_1") == "Table 4.1"
        @test VBFRepro.stem_label("sweep") === nothing

        file = scaffold_paper("202601-fixture-claims"; root)
        @test isfile(file)
        @test_throws ArgumentError scaffold_paper("202601-fixture-claims"; root)   # never replaced
        errors, review = check_paper_metadata("202601-fixture-claims"; root)
        @test any(contains("no publication with role \"primary\""), errors)
        @test count(contains("candidate, not reviewed"), review) == 3
        @test any(contains("extra.jl is in no claim"), review)

        meta = TOML.parsefile(file)
        meta["publications"] = [Dict("key" => "Fixture_202601", "role" => "primary")]
        c = only(c for c in meta["claims"] if c["id"] == "theorem3")
        c["review"] = "done"; c["targets"] = ["theorem3", "missing_target"]
        write(file, VBFRepro.render_paper_metadata(meta))
        errors, _ = check_paper_metadata("202601-fixture-claims"; root)
        @test any(contains("no Make target 'missing_target'"), errors)
        @test any(contains("a reviewed claim needs 'verification'"), errors)

        c["targets"] = ["theorem3"]; c["summary"] = "Main result."; c["verification"] = "computational-check"
        c["completeness"] = "complete"; c["scope"] = "n = 4"
        write(file, VBFRepro.render_paper_metadata(meta))
        errors, review = check_paper_metadata("202601-fixture-claims"; root)
        @test isempty(errors)
        @test count(contains("candidate, not reviewed"), review) == 2

        # A reviewed tool goes to `support` and leaves the review list; parameters must exist.
        write(joinpath(paper, "Makefile"), read(joinpath(paper, "Makefile"), String) * "limit ?= 10\n")
        meta["support"] = ["extra.jl"]
        c["parameters"] = Dict("limit" => "100")
        write(file, VBFRepro.render_paper_metadata(meta))
        errors, review = check_paper_metadata("202601-fixture-claims"; root)
        @test isempty(errors)
        @test !any(contains("extra.jl"), review)
        c["parameters"] = Dict("no_such" => "1")
        write(file, VBFRepro.render_paper_metadata(meta))
        errors, _ = check_paper_metadata("202601-fixture-claims"; root)
        @test any(contains("'no_such' is not a Makefile parameter"), errors)
        c["parameters"] = Dict("limit" => "100")
        write(file, VBFRepro.render_paper_metadata(meta))

        # --update appends new candidates only; the reviewed claim stays as it is.
        write(joinpath(paper, "lemma5.jl"), "# Implements Lemma 5\n")
        scaffold_paper("202601-fixture-claims"; root, update = true)
        meta2 = TOML.parsefile(file)
        @test only(c for c in meta2["claims"] if c["id"] == "theorem3")["review"] == "done"
        @test any(c -> c["id"] == "lemma5" && c["review"] == "pending", meta2["claims"])
    end
end

@testset "evidence: records, fingerprint, compatibility, reuse" begin
    mktempdir() do project
        # A self-contained project: a paper folder, paper.mk, a git history.
        root = joinpath(project, "packages", "VBFRepro", "src")
        paper = joinpath(root, "202601-fixture-evidence")
        mkpath(joinpath(paper, "test"))
        mkpath(joinpath(project, "packages", "VBF", "src"))
        write(joinpath(project, "packages", "VBF", "src", "VBF.jl"), "module VBF end\n")
        write(joinpath(project, "packages", "VBF", "Project.toml"), "name = \"VBF\"\n")
        write(joinpath(project, "Project.toml"), "[deps]\n")
        write(joinpath(root, "paper.mk"), "JULIA ?= julia\n")
        write(joinpath(paper, "Makefile"), "test:\n\techo t\nlemma1:\n\techo l\n")
        write(joinpath(paper, "lemma1.jl"), "# Implements Lemma 1\nlemma1_value() = 2\n")
        write(joinpath(paper, "README.md"), "notes\n")
        write(joinpath(paper, "test", "runtests.jl"), """
            using Test
            include("test_lemma1.jl")
            include("test_failing.jl")
            @testset "inline" begin @test true end
            """)
        write(joinpath(paper, "test", "test_lemma1.jl"),
              "include(joinpath(@__DIR__, \"..\", \"lemma1.jl\"))\n@testset \"lemma1\" begin @test lemma1_value() == 2; @test true end\n")
        write(joinpath(paper, "test", "test_failing.jl"), "@testset \"failing\" begin @test 1 == 2 end\n")
        write(joinpath(paper, "paper.toml"), """
            schema = "vbf-paper-1"
            [[publications]]
            key = "Fixture_202601"
            role = "primary"
            [[claims]]
            id = "lemma1"
            label = "Lemma 1"
            files = ["lemma1.jl"]
            targets = ["lemma1"]
            tests = ["test/test_lemma1.jl"]
            review = "pending"
            """)
        git(args...) = run(pipeline(Cmd(`git -C $project $args`); stdout = devnull, stderr = devnull))
        git("init", "-q"); git("-c", "user.email=t@t", "-c", "user.name=t", "add", ".")
        git("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "-m", "fixture")

        id = "202601-fixture-evidence"
        fp = evidence_fingerprint(id; root, project)
        @test Set(keys(fp)) == Set(["julia", "project", "paper_mk", "paper", "VBF", "parameters"])
        # Prose and metadata are not executable: they do not change the fingerprint.
        write(joinpath(paper, "README.md"), "other notes\n")
        write(joinpath(paper, "paper.toml"), read(joinpath(paper, "paper.toml"), String) * "# comment\n")
        @test evidence_fingerprint(id; root, project) == fp
        # Code does.
        write(joinpath(paper, "lemma1.jl"), "# Implements Lemma 1\nlemma1_value() = 2 # same value\n")
        @test evidence_fingerprint(id; root, project)["paper"] != fp["paper"]
        write(joinpath(paper, "lemma1.jl"), "# Implements Lemma 1\nlemma1_value() = 2\n")
        @test evidence_fingerprint(id; root, project, parameters = Dict("limit" => "5"))["parameters"] != fp["parameters"]

        ev = mktempdir()
        r = test_with_evidence(id; evidence_dir = ev, root, project)
        @test r.outcome == "failed"
        files = Dict(t["file"] => t for t in r.record["testsets"])
        @test files["test/test_lemma1.jl"]["pass"] == 2 && files["test/test_lemma1.jl"]["claims"] == ["lemma1"]
        @test files["test/test_failing.jl"]["fail"] == 1 && files["test/test_failing.jl"]["outcome"] == "failed"
        @test files["test/runtests.jl"]["pass"] == 1                       # the inline test set
        @test r.record["command"] == "bin/vbfrepro test $id --evidence DIR"   # the test command, not a claim command
        @test !any(contains(project), r.record["argv"])                     # portable
        @test isempty(validate_evidence(r.record; dir = r.dir))
        @test isempty(evidence_changes(r.record; root, project))

        # Validation catches tampering; reuse needs a passing CI record from a clean checkout.
        bad = deepcopy(r.record); bad["fingerprint"]["paper"] = "0"^64
        @test any(contains("fingerprint_sha256 does not match"), validate_evidence(bad))
        ok, reasons = reusable(r.record; dir = r.dir, root, project)
        @test !ok && any(contains("outcome is not passed"), reasons) && any(contains("not made by CI"), reasons)

        write(joinpath(paper, "test", "runtests.jl"), "using Test\ninclude(\"test_lemma1.jl\")\n")
        git("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "-am", "drop the failing test")
        withenv("GITHUB_REPOSITORY" => "siqueiratf/VBF.jl", "GITHUB_RUN_ID" => "1") do
            r2 = test_with_evidence(id; evidence_dir = ev, root, project)
            @test r2.outcome == "passed"
            @test reusable(r2.record; dir = r2.dir, root, project)[1]
            dest = VBFRepro.reuse_evidence(id, ev; evidence_dir = mktempdir(), root, project)
            @test dest !== nothing && haskey(TOML.parsefile(joinpath(dest, "record.toml")), "reused_by")
            arch = mktempdir()
            kept = archive_evidence(r2.dir; archive = arch)
            @test isfile(joinpath(kept, "record.toml")) && isfile(joinpath(kept, "output.log"))
            @test isempty(validate_evidence(TOML.parsefile(joinpath(kept, "record.toml")); dir = kept))
            @test_throws ArgumentError archive_evidence(r2.dir; archive = arch)    # never overwritten
            # A change of code makes the record historical: no reuse, and the reason names it.
            write(joinpath(paper, "lemma1.jl"), "# Implements Lemma 1\nlemma1_value() = 1 + 1\n")
            ok2, reasons2 = reusable(r2.record; dir = r2.dir, root, project)
            @test !ok2 && any(contains("changed since the run: paper"), reasons2)
        end
    end
end
