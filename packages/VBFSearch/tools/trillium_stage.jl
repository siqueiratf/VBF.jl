"""Prepare one private Trillium pilot from an immutable, verified checkpoint.

Copy and full verification run inside the compute allocation, never on a login
node. This changes execution paths and controller settings only.
"""
module TrilliumStage
using TOML, SHA, VBFSearch
const VS = VBFSearch

"""Construct pilot settings without inheriting workstation paths or STOP files."""
function pilot_config(template, working, output, slots; cpu_allocation=192)
    slots isa Integer && slots > 0 || error("compute slots must be positive")
    slots <= cpu_allocation || error("compute slots exceed allocation")
    config = deepcopy(template)
    for key in ("run", "evidence", "timing_history", "seed_progress_helper", "controller_path",
            "checkpoint_directory", "checkpoint_active_project", "evidence_segment_directory",
            "stop_files", "storage_paths", "quota_status_file", "duration_seconds", "max_windows")
        pop!(config, key, nothing)
    end
    merge!(config, Dict{String,Any}(
        "run" => abspath(working), "evidence" => joinpath(abspath(output), "evidence"),
        "concurrency" => slots, "cpu_allocation" => cpu_allocation,
        "reservation_horizon" => max(1024, 4slots), "max_apply_per_step" => 32,
        "baseline_policy" => "summary", "rolling_windows" => false,
        "storage_paths" => [abspath(working), abspath(output)],
        "checkpoint_directory" => joinpath(abspath(output), "checkpoints"),
        "checkpoint_interval_seconds" => 0.0, "checkpoint_keep" => 1,
        "checkpoint_on_stop" => true, "shutdown_grace_seconds" => 2400.0,
        "supervisor_duration_seconds" => 900.0,
        "evidence_segment_directory" => joinpath(abspath(working), "cold")))
    config
end

"""Reject a runtime mismatch before allocating or copying a large checkpoint."""
function check_runtime(manifest; version=string(VERSION),
        commit=string(Base.GIT_VERSION_INFO.commit),
        executable=joinpath(Sys.BINDIR, "julia"))
    version == manifest["julia"] || error("checkpoint Julia version differs")
    expected = manifest["runtime_build"]
    commit == expected["commit"] || error("checkpoint Julia build differs")
    bytes2hex(open(SHA.sha256, executable)) == expected["executable_sha256"] ||
        error("checkpoint Julia executable differs; use its matching runtime/container")
    nothing
end

"""Validate the frozen launcher against its retained deployment hashes."""
function check_launcher(directory, plan, identity)
    plan["current_implementation"] == identity["implementation"] ||
        error("launcher plan and checkpoint implementations differ")
    for (name, digest) in plan["launcher_sha256"]
        basename(name) == name || error("unsafe launcher filename")
        bytes2hex(open(SHA.sha256, joinpath(directory, name))) == digest ||
            error("frozen launcher helper changed: $name")
    end
    haskey(plan["launcher_sha256"], "closure_run.jl") || error("launcher entry point is unpinned")
    nothing
end

"""Stage a sealed generation, verify it in local RAM, then bind its new paths."""
function prepare(source, working, output, launcher, slots; cpu_allocation=192,
        local_reserve_bytes::Integer=32 * 1024^3)
    local_reserve_bytes >= 0 || error("local storage reserve must be nonnegative")
    source = realpath(source); working = abspath(working); output = abspath(output)
    for path in (working, output)
        (path == source || startswith(path, source * string(Base.Filesystem.path_separator))) &&
            error("pilot paths cannot modify the immutable source generation")
    end
    manifest = TOML.parsefile(joinpath(source, "checkpoint-manifest.toml"))
    manifest["schema"] == "vbfsearch-checkpoint-bundle-v1" || error("a sealed checkpoint generation is required")
    check_runtime(manifest)
    ispath(working) && error("working checkpoint must be new")
    ispath(output) && error("pilot output directory must be new")
    # The imported project is the checkpoint's own frozen inspector environment.
    identity = TOML.parsefile(joinpath(source, "identity.toml"))
    identity["implementation"] == Base.invokelatest(VS.implementation_fingerprint) ||
        error("load this helper under the checkpoint's frozen inspector project")
    plan = VS.JSON3.read(read(joinpath(launcher, "launch-plan.json"), String), Dict{String,Any})
    check_launcher(launcher, plan, identity)
    template = TOML.parsefile(joinpath(launcher, "config.toml"))
    bytes2hex(open(SHA.sha256, joinpath(launcher, "config.toml"))) == plan["config_sha256"] ||
        error("frozen controller configuration changed")
    footprint = Base.invokelatest(VS._closure_portable_tree_bytes, source)
    mkpath(dirname(working))
    Base.Filesystem.diskstat(dirname(working)).available >= 2footprint + local_reserve_bytes ||
        error("node-local storage needs two checkpoint footprints plus $local_reserve_bytes reserve bytes")
    println("Copying sealed checkpoint into node-local storage"); flush(stdout)
    cp(source, working)
    println("Verifying node-local checkpoint; shared source remains immutable"); flush(stdout)
    verification = Base.invokelatest(VS.closure_verify_checkpoint, working)
    Base.invokelatest(VS.closure_relocate!, working)
    mkpath(output)
    config = pilot_config(template, working, output, slots; cpu_allocation)
    if haskey(ENV, "SLURM_JOB_END_TIME")
        remaining = parse(Float64, ENV["SLURM_JOB_END_TIME"]) - time() - 2460
        remaining > 0 || error("staging used the pilot's compute window; use a longer allocation")
        config["supervisor_duration_seconds"] = min(900.0, remaining)
    end
    open(io -> TOML.print(io, config), joinpath(output, "config.toml"), "w")
    receipt = Dict("source" => source, "working" => working, "output" => output,
        "compute_slots" => slots, "cpu_allocation" => cpu_allocation,
        "launcher" => abspath(launcher), "verification" => verification,
        "scope" => "isolated pilot branch; not a merge into the workstation campaign")
    open(io -> TOML.print(io, receipt), joinpath(output, "preparation.toml"), "w")
    println("Pilot ready: ", joinpath(output, "config.toml")); flush(stdout)
    nothing
end
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) == 6 || error("usage: trillium_stage.jl CHECKPOINT WORKING OUTPUT LAUNCHER COMPUTE_SLOTS ALLOCATED_CPUS")
    TrilliumStage.prepare(ARGS[1:4]..., parse(Int, ARGS[5]); cpu_allocation=parse(Int, ARGS[6]))
end
