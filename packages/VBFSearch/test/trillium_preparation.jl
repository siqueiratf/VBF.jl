module TrilliumPreparationTests
using Test, TOML, SHA, VBF, VBFSearch
include(joinpath(@__DIR__, "..", "tools", "trillium_stage.jl"))
const T = TrilliumStage
const VS = VBFSearch

@testset "Fresh Slurm pilot drains and publishes its single SQLite" begin
    @test success(`python3 $(joinpath(@__DIR__,"trillium_fresh_test.py"))`)
end

@testset "Trillium configuration removes workstation bindings" begin
    template = Dict{String,Any}(
        "run" => "/workstation/run", "evidence" => "/workstation/evidence",
        "timing_history" => "/workstation/history", "stop_files" => ["/workstation/STOP"],
        "seed_progress_helper" => "/workstation/helper", "controller_path" => "/workstation/controller",
        "checkpoint_active_project" => "/workstation/project", "quota_status_file" => "/workstation/quota",
        "max_windows" => 1, "duration_seconds" => 1.0, "packed_rank_table" => true)
    config = T.pilot_config(template, "/node/run", "/scratch/pilot", 180)
    @test config["concurrency"] == 180
    @test config["reservation_horizon"] >= config["concurrency"]
    @test config["run"] == "/node/run"
    @test config["checkpoint_directory"] == "/scratch/pilot/checkpoints"
    @test config["evidence_segment_directory"] == "/node/run/cold"
    @test config["checkpoint_on_stop"] && config["checkpoint_interval_seconds"] == 0
    @test config["packed_rank_table"]
    @test config["storage_paths"] == ["/node/run", "/scratch/pilot"]
    @test !occursin("/workstation", sprint(TOML.print, config))
    @test all(!haskey(config, key) for key in ("stop_files", "duration_seconds", "max_windows", "quota_status_file"))
    @test template["run"] == "/workstation/run"
    @test_throws ErrorException T.pilot_config(template, "/node/run", "/scratch/pilot", 193)
end

@testset "Trillium staging verifies a sealed generation and immutable launcher" begin
    mktempdir() do directory
        props = VS.properties(gold_apn(8).lut)
        input = joinpath(directory, "seed.tsv"); write(input, props["lut_hex"] * "\n")
        digest = VS.DiscoveryEvidence.filehash(input)
        identity = Dict{String,Any}("schema" => VS.CLOSURE_SCHEMA, "campaign" => input,
            "campaign_sha256" => digest, "roots_sha256" => digest, "initial_roots" => 1,
            "qualification_complete" => true, "inputs" => Dict(input => digest),
            "implementation" => VS.implementation_fingerprint(), "julia" => string(VERSION),
            "scientific" => Dict("n" => 8, "m" => 8, "target_b6" => 52, "max_kernel" => 23))
        roots = [(lut_sha256=props["lut_sha256"], lut_hex=props["lut_hex"],
            sigma_hash=props["sigma_hash"], catalog_id="trillium-fixture:1")]
        run = joinpath(directory, "source"); VS._closure_initialize(run, identity, roots)
        environment = joinpath(run, "replay", "workspace", "docs", "inspector")
        mkpath(environment)
        for name in ("Project.toml", "Manifest.toml")
            cp(joinpath(dirname(Base.active_project()), name), joinpath(environment, name); force=true)
        end
        VS.closure_relocate!(run; active_project=environment)
        generation = joinpath(directory, "sealed")
        VS.closure_export_checkpoint(run; output=generation)
        launcher = joinpath(directory, "launcher"); mkpath(launcher)
        write(joinpath(launcher, "closure_run.jl"), "# pinned fixture launcher\n")
        open(io -> TOML.print(io, Dict("run" => "/old/run", "evidence" => "/old/evidence")),
            joinpath(launcher, "config.toml"), "w")
        plan = Dict("current_implementation" => identity["implementation"],
            "launcher_sha256" => Dict("closure_run.jl" => VS.DiscoveryEvidence.filehash(joinpath(launcher, "closure_run.jl"))),
            "config_sha256" => VS.DiscoveryEvidence.filehash(joinpath(launcher, "config.toml")))
        write(joinpath(launcher, "launch-plan.json"), VS.JSON3.write(plan))
        manifest = TOML.parsefile(joinpath(generation, "checkpoint-manifest.toml"))
        @test T.check_runtime(manifest) === nothing
        @test_throws ErrorException T.check_runtime(manifest; version="0.0.0")
        @test_throws ErrorException T.prepare(generation, joinpath(generation, "nested"),
            joinpath(directory, "unused"), launcher, 4)
        working = joinpath(directory, "node", "run"); output = joinpath(directory, "pilot")
        T.prepare(generation, working, output, launcher, 4; cpu_allocation=8, local_reserve_bytes=0)
        @test read(joinpath(working, "identity.toml")) == read(joinpath(generation, "identity.toml"))
        @test VS.closure_verify_checkpoint(generation)["verified"]
        @test TOML.parsefile(joinpath(output, "config.toml"))["concurrency"] == 4
        @test TOML.parsefile(joinpath(output, "preparation.toml"))["verification"]["verified"]
        @test_throws ErrorException T.prepare(generation, working, output, launcher, 4; cpu_allocation=8)
        write(joinpath(launcher, "closure_run.jl"), "# changed\n")
        rejected = joinpath(directory, "rejected")
        @test_throws ErrorException T.prepare(generation, rejected, joinpath(directory, "unused"), launcher, 4)
        @test !ispath(rejected)
    end
end
end
