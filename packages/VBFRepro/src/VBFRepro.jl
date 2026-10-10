module VBFRepro

using Dates, SHA, TOML, UUIDs

export repo_root, papers_root, discover_papers, paper_path, run_paper, test_paper, main

"""Root of the VBF workspace containing the reproducible execution environment."""
repo_root() = normpath(joinpath(@__DIR__, "..", "..", ".."))
"""Directory containing standalone paper reproductions, grouped by year."""
papers_root() = normpath(joinpath(@__DIR__, "..", "papers"))

"""List `(id, year, path)` for papers having a Makefile; no scripts are loaded."""
function discover_papers(; root=papers_root())
    found = NamedTuple{(:id, :year, :path),Tuple{String,String,String}}[]
    for year in sort(readdir(root))
        year_path = joinpath(root, year)
        isdir(year_path) || continue
        for id in sort(readdir(year_path))
            path = joinpath(year_path, id)
            isfile(joinpath(path, "Makefile")) && push!(found, (;id, year, path=abspath(path)))
        end
    end
    return found
end

"""Resolve an unambiguous paper ID. Arbitrary paths and traversal are rejected."""
function paper_path(id::AbstractString; root=papers_root())
    occursin(r"^[A-Za-z0-9_-]+$", id) || throw(ArgumentError("invalid paper ID"))
    matches = filter(p -> p.id == id, discover_papers(; root))
    length(matches) == 1 || throw(ArgumentError("paper '$id' has $(length(matches)) matches"))
    return only(matches).path
end

function _write_metadata(path, metadata)
    temporary = path * ".tmp"
    open(temporary, "w") do io
        TOML.print(io, metadata; sorted=true)
    end
    mv(temporary, path; force=true)
end

function _source_hashes(paper, project)
    paths = String[]
    roots = [paper]
    shared_papers = joinpath(project, "packages", "VBFRepro", "papers")
    isdir(shared_papers) && push!(roots, shared_papers)
    # Existing reproductions sometimes include another paper's helpers. Hash the
    # complete paper implementation tree rather than claiming a guessed closure.
    for root in roots
        for (dir, dirs, files) in walkdir(root)
            filter!(d -> !(d in ("input", "inputs", "results", "tuples", ".git")), dirs)
            append!(paths, [joinpath(dir, f) for f in files if any(ext -> endswith(f, ext), (".jl", ".toml", ".json", ".csv", ".tsv")) || f == "Makefile"])
        end
    end
    push!(paths, joinpath(papers_root(), "paper.mk"))
    for f in ("Project.toml", "Manifest.toml")
        path = joinpath(project, f)
        isfile(path) && push!(paths, path)
    end
    # Package math and catalog source are part of the executed implementation.
    for package in ("VBF", "VBFCatalog", "VBFSearch", "VBFRepro")
        source = joinpath(project, "packages", package, "src")
        isdir(source) || continue
        for (dir, _, files) in walkdir(source)
            append!(paths, [joinpath(dir, f) for f in files if endswith(f, ".jl")])
        end
    end
    return Dict(relpath(path, project) => bytes2hex(sha256(read(path))) for path in sort!(unique(paths)))
end

function _input_hashes(paper, project)
    paths = String[]
    for name in ("input", "inputs", "tuples")
        directory = joinpath(paper, name)
        isdir(directory) || continue
        for (dir, _, files) in walkdir(directory)
            append!(paths, joinpath.(dir, files))
        end
    end
    catalog = joinpath(project, "packages", "VBFCatalog", "BFA_catalog.sqlite")
    isfile(catalog) && push!(paths, catalog)
    return Dict(relpath(path, project) => open(io -> bytes2hex(sha256(io)), path)
                for path in sort!(unique(paths)))
end

function _terminate_group(process)
    if Sys.isunix()
        # Cmd(detach=true) gives make and its Julia children their own process group.
        pid = try
            getpid(process)
        catch error
            # The process can finish between the caller's liveness check and
            # this lookup. Only that specific race is benign.
            error isa Base.IOError && error.code == Base.UV_ESRCH || rethrow()
            return nothing
        end
        ccall(:kill, Cint, (Cint, Cint), -pid, Base.SIGTERM)
        sleep(0.2)
        ccall(:kill, Cint, (Cint, Cint), -pid, Base.SIGKILL)
    else
        kill(process)
    end
end

function _claim_output(directory)
    ispath(directory) && (!isdir(directory) || !isempty(readdir(directory))) &&
        throw(ArgumentError("output must be an absent or empty directory"))
    mkpath(directory)
    claim = joinpath(directory, ".vbf-repro-claim")
    try
        # mkdir is atomic even when two processes both saw an empty directory.
        mkdir(claim)
    catch error
        error isa Base.IOError && error.code == Base.UV_EEXIST || rethrow()
        throw(ArgumentError("output is already claimed by another run"))
    end
    # Also refuse files that appeared after the initial emptiness check.
    readdir(directory) == [".vbf-repro-claim"] ||
        throw(ArgumentError("output acquired existing files while being claimed"))
    return directory
end

"""
    run_paper(id; target="report", parameters=Dict(), timeout_seconds=nothing,
              output=nothing, environment=Dict(), project=repo_root())

Execute one paper's existing Make target in a separate process and its own working
directory. Record the exact arguments, parameter overrides, Julia environment,
source hashes, stdout/stderr and exit status under `data/repro/runs/` by default.
No paper scripts are imported into the caller. Existing paper-local result files
remain controlled by the target's `save_results` parameter. A wall timeout stops
the process group on Unix; it does not certify that a partial result is complete.

The output directory must be absent or empty. An atomic, persistent ownership
marker prevents concurrent executions from overwriting each other's evidence.
Only explicit environment overrides are recorded; secrets from the inherited
process environment are not serialized. Source hashes are provenance records,
not an archived execution environment or a mathematical validation certificate.
"""
function run_paper(id::AbstractString; target::AbstractString="report", parameters=Dict(),
                   timeout_seconds=nothing, output=nothing, environment=Dict(),
                   project=repo_root(), root=papers_root(), make="make", julia=Base.julia_cmd().exec[1])
    occursin(r"^[A-Za-z_][A-Za-z0-9_-]*$", target) || throw(ArgumentError("invalid Make target"))
    if timeout_seconds !== nothing
        isfinite(timeout_seconds) && timeout_seconds > 0 || throw(ArgumentError("timeout must be positive and finite"))
    end
    overrides = Dict{String,String}()
    for (key, value) in pairs(parameters)
        name = string(key)
        occursin(r"^[A-Za-z_][A-Za-z0-9_]*$", name) || throw(ArgumentError("invalid parameter name"))
        name in ("ROOT", "JULIA", "JULIA_PROJECT", "MAKEFILE_DIR", "MAKEFLAGS", "SHELL") &&
            throw(ArgumentError("execution variable '$name' is not a paper parameter"))
        text = string(value)
        occursin('\n', text) && throw(ArgumentError("parameter values must be single-line"))
        occursin('$', text) && throw(ArgumentError("Make expansion is not allowed in parameter values"))
        overrides[name] = text
    end
    paper = paper_path(id; root)
    project = abspath(project)
    isfile(joinpath(project, "Project.toml")) || throw(ArgumentError("missing execution Project.toml"))
    run_id = Dates.format(now(UTC), "yyyymmddTHHMMSS") * "-" * string(uuid4())
    directory = output === nothing ? joinpath(repo_root(), "data", "repro", "runs", id, run_id) : abspath(output)
    _claim_output(directory)
    arguments = [string(make), "--no-print-directory", "-C", paper, string(target),
                 "JULIA=$(julia)", "ROOT=$(project)"]
    append!(arguments, ["$key=$(overrides[key])" for key in sort!(collect(keys(overrides)))])
    command = Cmd(Cmd(arguments); dir=paper, detach=Sys.isunix())
    command = addenv(command, [string(k) => string(v) for (k,v) in pairs(environment)]...)
    metadata = Dict{String,Any}("schema_version" => 1, "paper" => string(id), "target" => string(target),
        "cwd" => paper, "project" => project, "command" => arguments, "parameters" => overrides,
        "environment_overrides" => Dict(string(k)=>string(v) for (k,v) in pairs(environment)),
        "orchestrator_julia_version" => string(VERSION),
        "julia_version" => strip(read(Cmd([string(julia), "--version"]), String)),
        "started_at_utc" => string(now(UTC)), "status" => "running",
        "source_sha256" => _source_hashes(paper, project),
        "input_sha256" => _input_hashes(paper, project))
    timeout_seconds === nothing || (metadata["timeout_seconds"] = Float64(timeout_seconds))
    manifest = joinpath(directory, "run.toml")
    _write_metadata(manifest, metadata)
    started = time_ns()
    process = nothing
    try
        open(joinpath(directory, "output.log"), "w") do io
            process = run(pipeline(command; stdout=io, stderr=io); wait=false)
            timed_out = false
            while process_running(process)
                if timeout_seconds !== nothing && (time_ns()-started)/1e9 >= timeout_seconds
                    timed_out = true
                    _terminate_group(process)
                    break
                end
                sleep(0.05)
            end
            wait(process)
            metadata["exit_code"] = process.exitcode
            metadata["status"] = timed_out ? "timed_out" : success(process) ? "passed" : "failed"
        end
    catch error
        process === nothing || !process_running(process) || _terminate_group(process)
        metadata["status"] = "error"
        metadata["error"] = sprint(showerror, error)
        rethrow()
    finally
        metadata["elapsed_seconds"] = (time_ns()-started)/1e9
        metadata["finished_at_utc"] = string(now(UTC))
        log = joinpath(directory, "output.log")
        isfile(log) && (metadata["output_log_sha256"] = open(io -> bytes2hex(sha256(io)), log))
        _write_metadata(manifest, metadata)
    end
    return (;paper=string(id), target=string(target), status=metadata["status"],
             exit_code=metadata["exit_code"], output=directory, manifest)
end

"""Run the selected paper's test target through the same isolated evidence runner."""
test_paper(id::AbstractString; kwargs...) = run_paper(id; target="test", kwargs...)

"""Command-line entry for `list`, `run PAPER`, and `test PAPER`; return an exit code."""
function main(args=ARGS)
    if isempty(args) || first(args) in ("help", "--help", "-h")
        println("vbfrepro list")
        println("vbfrepro run PAPER [--target TARGET] [--param key=value] [--timeout-seconds N] [--output DIR]")
        println("vbfrepro test PAPER [--timeout-seconds N] [--output DIR]")
        return 0
    end
    if first(args) == "list"
        length(args) == 1 || throw(ArgumentError("list accepts no arguments"))
        foreach(p -> println(p.year, "/", p.id), discover_papers())
        return 0
    end
    command = first(args)
    command in ("run", "test") || throw(ArgumentError("unknown command '$command'"))
    length(args) >= 2 || throw(ArgumentError("missing paper ID"))
    id = args[2]
    target = command == "test" ? "test" : "report"
    parameters = Dict{String,String}()
    timeout = nothing
    output = nothing
    index = 3
    while index <= length(args)
        option = args[index]
        index < length(args) || throw(ArgumentError("missing value for '$option'"))
        value = args[index+1]
        if option == "--target" && command == "run"
            target = value
        elseif option == "--param" && command == "run"
            pieces = split(value, '='; limit=2)
            length(pieces) == 2 || throw(ArgumentError("parameter must be key=value"))
            haskey(parameters, pieces[1]) && throw(ArgumentError("duplicate parameter '$(pieces[1])'"))
            parameters[pieces[1]] = pieces[2]
        elseif option == "--timeout-seconds"
            timeout = parse(Float64, value)
        elseif option == "--output"
            output = value
        else
            throw(ArgumentError("unsupported option '$option'"))
        end
        index += 2
    end
    result = run_paper(id; target, parameters, timeout_seconds=timeout, output)
    println("$(result.paper) $(result.target): $(result.status)\nEvidence: $(result.output)")
    return result.status == "passed" ? 0 : 1
end

end
