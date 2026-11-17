# Execution evidence, schema vbf-evidence-1.
#
# A record has separate parts:
#   provenance   where and when it ran: commit, dirty flag, CI run, Julia, time. Never used
#                to decide compatibility, so a documentation-only commit keeps old evidence.
#   fingerprint  digests of the executable dependencies of the run (below). A record is
#                compatible with a checkout when every component is equal.
#   result       kind (regression | reproduction), outcome, per-file test counts, claims.
#
# Fingerprint components (conservative; each is a SHA-256):
#   julia            the full Julia version of the run
#   project          root Project.toml and Manifest.toml (all external packages)
#   paper_mk         packages/VBFRepro/src/paper.mk
#   paper            the paper folder: executable files only (.jl, Makefile, data files);
#                    README.md, site.md, paper.toml and results/ are excluded
#   paper:<id>       each other paper folder that the code names (shared helpers)
#   VBF              packages/VBF/src and Project.toml (every paper uses VBF)
#   VBFCatalog       packages/VBFCatalog/src and Project.toml, when the code loads it; this
#                    tree holds the declarations from which the catalog is built
#   VBFSearch        packages/VBFSearch/src and Project.toml, when the code loads it
#   parameters       the Make parameters of the run

const EVIDENCE_SCHEMA = "vbf-evidence-1"
const EVIDENCE_KINDS = ("regression", "reproduction")
const OUTCOMES = ("passed", "failed", "timed_out", "error")
const DATA_EXT = (".jl", ".mk", ".toml", ".tsv", ".csv", ".json", ".gz", ".bib", ".txt", ".tex", ".sage", ".py")
const NOT_EXECUTABLE = ("README.md", "site.md", "paper.toml")

_sha(path) = bytes2hex(open(sha256, path))
_digest(lines) = bytes2hex(sha256(join(sort(lines), "\n")))

"""Digest of the executable files under `dir` (paths relative to `base`)."""
function _tree_digest(dir, base; skip_dirs = ("results", ".git"))
    lines = String[]
    for (d, dirs, files) in walkdir(dir)
        filter!(x -> !(x in skip_dirs), dirs)
        for f in files
            (f == "Makefile" || any(e -> endswith(f, e), DATA_EXT)) || continue
            f in NOT_EXECUTABLE && continue
            p = joinpath(d, f)
            push!(lines, relpath(p, base) * ":" * _sha(p))
        end
    end
    _digest(lines)
end

"""Packages loaded and other paper folders named by the code of a paper."""
function paper_dependencies(id::AbstractString; root = papers_root())
    path = paper_path(id; root)
    packages = Set(["VBF"]); papers = Set{String}()
    for (d, dirs, files) in walkdir(path)
        filter!(x -> x != "results", dirs)
        for f in files
            endswith(f, ".jl") || continue
            text = read(joinpath(d, f), String)
            for p in ("VBFCatalog", "VBFSearch")
                occursin(Regex("^\\s*(using|import)\\s[^#\\n]*\\b$p\\b", "m"), text) && push!(packages, p)
            end
            for m in eachmatch(r"\"(\d{6}-[a-z0-9]+(?:-[a-z0-9]+)*)\"", text)
                m[1] != id && isdir(joinpath(root, m[1])) && push!(papers, m[1])
            end
        end
    end
    (; packages, papers)
end

"""Full Julia version of the `julia` that runs the paper (not of this process)."""
julia_version(julia = "julia") = strip(replace(read(`$julia --version`, String), "julia version" => ""))

"""
    evidence_fingerprint(id; parameters, julia) -> Dict{String,String}

The compatibility fingerprint of a run of paper `id`: component name => SHA-256.
"""
function evidence_fingerprint(id::AbstractString; root = papers_root(), project = repo_root(),
                              parameters = Dict{String,String}(), julia = "julia")
    deps = paper_dependencies(id; root)
    fp = Dict{String,String}()
    fp["julia"] = bytes2hex(sha256(julia_version(julia)))
    fp["project"] = _digest(["$f:" * _sha(joinpath(project, f)) for f in ("Project.toml", "Manifest.toml")
                             if isfile(joinpath(project, f))])
    fp["paper_mk"] = _sha(joinpath(root, "paper.mk"))
    fp["paper"] = _tree_digest(paper_path(id; root), root)
    for p in deps.papers
        fp["paper:$p"] = _tree_digest(joinpath(root, p), root)
    end
    for pkg in deps.packages
        dir = joinpath(project, "packages", pkg)
        fp[pkg] = _digest(["src:" * _tree_digest(joinpath(dir, "src"), project),
                           "Project.toml:" * _sha(joinpath(dir, "Project.toml"))])
    end
    fp["parameters"] = _digest(["$k=$v" for (k, v) in parameters])
    fp
end

"""One SHA-256 of a whole fingerprint (a cache key)."""
fingerprint_sha256(fp) = _digest(["$k=$v" for (k, v) in fp])

"""Provenance of a run: commit, dirty flag of the dependencies, CI run. Not part of compatibility."""
function evidence_provenance(id::AbstractString; project = repo_root(), root = papers_root())
    git(args...) = try readchomp(Cmd(`git -C $project $args`)) catch; "" end
    deps = paper_dependencies(id; root)
    paths = vcat([relpath(paper_path(id; root), project), relpath(joinpath(root, "paper.mk"), project),
                  "Project.toml", "Manifest.toml"],
                 [relpath(joinpath(root, p), project) for p in deps.papers],
                 ["packages/$p" for p in deps.packages])
    dirty = !isempty(git("status", "--porcelain", "--", paths...))
    ci = Dict{String,String}()
    for (k, e) in ("repository" => "GITHUB_REPOSITORY", "run_id" => "GITHUB_RUN_ID",
                   "run_attempt" => "GITHUB_RUN_ATTEMPT", "workflow" => "GITHUB_WORKFLOW", "ref" => "GITHUB_REF")
        haskey(ENV, e) && (ci[k] = ENV[e])
    end
    Dict{String,Any}("commit" => git("rev-parse", "HEAD"), "dirty" => dirty, "ci" => ci,
        "created_utc" => string(now(UTC)), "orchestrator_julia" => string(VERSION))
end

"""Claims of `paper.toml` whose `tests` include a file, and claims that run a target."""
function _claims_by_test(id; root = papers_root())
    meta = load_paper_metadata(id; root)
    d = Dict{String,Vector{String}}()
    meta === nothing && return d
    # A claim that needs Make parameters is not checked by the default test run.
    for c in get(meta, "claims", []), t in get(c, "tests", [])
        isempty(get(c, "parameters", Dict())) && push!(get!(d, t, String[]), c["id"])
    end
    d
end

"""
    test_with_evidence(id; evidence_dir, timeout_seconds, julia) -> NamedTuple

Run the test suite of a paper through `evidence_runner.jl` and write a regression record
`<evidence_dir>/<id>/<run-id>/record.toml` with `output.log`. The record keeps the command
that ran (not the reproduction command of a claim), the result of each test file and the
claims whose tests these files are.
"""
function test_with_evidence(id::AbstractString; evidence_dir, root = papers_root(), project = repo_root(),
                            timeout_seconds = nothing, julia = "julia")
    path = paper_path(id; root)
    runtests = first(filter(isfile, [joinpath(path, "test", "runtests.jl"), joinpath(path, "tests", "runtests.jl")]))
    run_id = Dates.format(now(UTC), "yyyymmddTHHMMSS") * "-" * string(uuid4())
    dir = joinpath(abspath(evidence_dir), id, run_id)
    mkpath(dir)
    results = joinpath(dir, "testsets.toml")
    argv = [julia, "--startup-file=no", "--project=$project", joinpath(@__DIR__, "evidence_runner.jl"), runtests, results]
    status, exit_code, elapsed = _run_logged(Cmd(Cmd(argv); dir = path), joinpath(dir, "output.log"); timeout_seconds)
    files = isfile(results) ? TOML.parsefile(results)["files"] : Dict{String,Any}[]
    outcome = status == "timed_out" ? "timed_out" : !isfile(results) ? "error" :
              TOML.parsefile(results)["total"]["outcome"]
    by_test = _claims_by_test(id; root)
    for f in files
        f["claims"] = get(by_test, f["file"], String[])
    end
    record = Dict{String,Any}(
        "schema" => EVIDENCE_SCHEMA, "kind" => "regression", "paper" => id, "run_id" => run_id,
        "outcome" => outcome, "exit_code" => exit_code, "elapsed_seconds" => elapsed,
        "command" => "bin/vbfrepro test $id --evidence DIR",
        "argv" => [julia, "--startup-file=no", "--project=.", "packages/VBFRepro/src/evidence_runner.jl",
                   relpath(runtests, project), "testsets.toml"],
        "parameters" => Dict{String,String}(),
        "testsets" => files,
        "claims" => sort(unique(vcat([f["claims"] for f in files]...))),
        "log" => Dict("file" => "output.log", "sha256" => _sha(joinpath(dir, "output.log"))),
        "fingerprint" => evidence_fingerprint(id; root, project, julia),
        "provenance" => merge(evidence_provenance(id; project, root), Dict("julia" => julia_version(julia))))
    record["fingerprint_sha256"] = fingerprint_sha256(record["fingerprint"])
    rm(results; force = true)
    open(io -> TOML.print(io, record; sorted = true), joinpath(dir, "record.toml"), "w")
    (; outcome, dir, record)
end

"""
    reproduction_evidence(result, claims) -> Dict

Turn a `run_paper` result (a run of a claim's target) into a reproduction record next to
its `run.toml`. Used for expensive runs that are archived instead of run by CI.
"""
function reproduction_evidence(result; root = papers_root(), project = repo_root(), julia = "julia")
    run = TOML.parsefile(result.manifest)
    id = run["paper"]
    params = Dict{String,String}(string(k) => string(v) for (k, v) in run["parameters"])
    meta = load_paper_metadata(id; root)
    claims = meta === nothing ? String[] :
        [c["id"] for c in get(meta, "claims", []) if run["target"] in get(c, "targets", []) &&
         all(get(params, k, nothing) == v for (k, v) in get(c, "parameters", Dict()))]
    record = Dict{String,Any}(
        "schema" => EVIDENCE_SCHEMA, "kind" => "reproduction", "paper" => id,
        "run_id" => basename(dirname(result.manifest)),
        "outcome" => run["status"] == "running" ? "error" : run["status"],
        "exit_code" => get(run, "exit_code", -1), "elapsed_seconds" => get(run, "elapsed_seconds", 0.0),
        "command" => "bin/vbfrepro run $id --target $(run["target"])" *
                     join([" --param $k=$v" for (k, v) in sort!(collect(params))]),
        "argv" => run["command"], "parameters" => params, "claims" => claims, "testsets" => Dict{String,Any}[],
        "log" => Dict("file" => "output.log", "sha256" => get(run, "output_log_sha256", "")),
        "fingerprint" => evidence_fingerprint(id; root, project, parameters = params, julia),
        "provenance" => merge(evidence_provenance(id; project, root), Dict("julia" => run["julia_version"])))
    record["fingerprint_sha256"] = fingerprint_sha256(record["fingerprint"])
    open(io -> TOML.print(io, record; sorted = true), joinpath(dirname(result.manifest), "record.toml"), "w")
    record
end

"""
    validate_evidence(record; dir=nothing) -> Vector{String}

Schema and integrity problems of a record (empty when valid). With `dir`, the log file
must exist there and match its SHA-256.
"""
function validate_evidence(r::AbstractDict; dir = nothing)
    p = String[]
    get(r, "schema", "") == EVIDENCE_SCHEMA || push!(p, "schema is not $EVIDENCE_SCHEMA")
    get(r, "kind", "") in EVIDENCE_KINDS || push!(p, "kind must be regression or reproduction")
    get(r, "outcome", "") in OUTCOMES || push!(p, "outcome must be one of $(join(OUTCOMES, ", "))")
    for k in ("paper", "run_id", "command", "argv", "claims", "fingerprint", "fingerprint_sha256", "provenance", "log")
        haskey(r, k) || push!(p, "missing $k")
    end
    fp = get(r, "fingerprint", Dict())
    for k in ("julia", "project", "paper_mk", "paper", "VBF", "parameters")
        occursin(r"^[0-9a-f]{64}$", get(fp, k, "")) || push!(p, "fingerprint.$k is not a SHA-256")
    end
    haskey(r, "fingerprint_sha256") && r["fingerprint_sha256"] != fingerprint_sha256(fp) &&
        push!(p, "fingerprint_sha256 does not match the fingerprint")
    occursin(r"^[0-9a-f]{40}$", get(get(r, "provenance", Dict()), "commit", "")) || push!(p, "provenance.commit is not a git SHA")
    occursin(r"^[0-9a-f]{64}$", get(get(r, "log", Dict()), "sha256", "")) || push!(p, "log.sha256 is not a SHA-256")
    if dir !== nothing
        log = joinpath(dir, get(get(r, "log", Dict()), "file", "output.log"))
        if isfile(log)
            _sha(log) == r["log"]["sha256"] || push!(p, "log SHA-256 does not match")
        elseif !haskey(get(r, "log", Dict()), "url")
            push!(p, "log file is missing and the record names no log url")
        end
    end
    p
end

const ARCHIVE_DIR = joinpath(dirname(@__DIR__), "evidence")   # packages/VBFRepro/evidence
const ARCHIVE_LOG_LIMIT = 1 << 20

"""
    archive_evidence(run_dir; log_url=nothing) -> String

Copy a valid reproduction record (and its log, if at most 1 MiB) into
`packages/VBFRepro/evidence/<paper>/<run-id>/`. A larger log needs `log_url`, a permanent
copy (for example a Zenodo file) whose SHA-256 is the one in the record. A record made
from a checkout with local changes is refused.
"""
function archive_evidence(run_dir; log_url = nothing, archive = ARCHIVE_DIR)
    r = TOML.parsefile(joinpath(run_dir, "record.toml"))
    problems = validate_evidence(r; dir = run_dir)
    isempty(problems) || throw(ArgumentError("invalid record: " * join(problems, "; ")))
    get(r["provenance"], "dirty", true) && throw(ArgumentError("the run was made from a checkout with local changes"))
    dest = joinpath(archive, r["paper"], r["run_id"])
    isdir(dest) && throw(ArgumentError("$dest exists"))
    mkpath(dest)
    log = joinpath(run_dir, r["log"]["file"])
    if filesize(log) <= ARCHIVE_LOG_LIMIT
        cp(log, joinpath(dest, r["log"]["file"]))
    else
        log_url === nothing && (rm(dest; recursive = true);
            throw(ArgumentError("the log is larger than 1 MiB: upload it and give --log-url")))
        r["log"]["url"] = log_url
    end
    open(io -> TOML.print(io, r; sorted = true), joinpath(dest, "record.toml"), "w")
    dest
end

"""Fingerprint components that differ from the current checkout (empty = compatible)."""
function evidence_changes(r::AbstractDict; root = papers_root(), project = repo_root(), julia = "julia")
    current = evidence_fingerprint(r["paper"]; root, project, parameters = get(r, "parameters", Dict()), julia)
    old = r["fingerprint"]
    sort!([k for k in union(keys(current), keys(old)) if get(current, k, "") != get(old, k, "")])
end

"""
    reusable(r; dir, repository) -> (ok, reasons)

A record may stand for a new run only if it is valid, passed, was made from a clean
checkout by CI of `repository`, at a commit that is an ancestor of HEAD, and is compatible
with the current checkout.
"""
function reusable(r::AbstractDict; dir = nothing, repository = "siqueiratf/VBF.jl", project = repo_root(),
                  root = papers_root(), julia = "julia")
    reasons = validate_evidence(r; dir)
    get(r, "outcome", "") == "passed" || push!(reasons, "outcome is not passed")
    prov = get(r, "provenance", Dict())
    get(prov, "dirty", true) && push!(reasons, "made from a checkout with local changes")
    get(get(prov, "ci", Dict()), "repository", "") == repository || push!(reasons, "not made by CI of $repository")
    commit = get(prov, "commit", "")
    isempty(reasons) && !success(`git -C $project merge-base --is-ancestor $commit HEAD`) &&
        push!(reasons, "commit $commit is not an ancestor of HEAD")
    isempty(reasons) && (changed = evidence_changes(r; root, project, julia); isempty(changed) ||
        push!(reasons, "changed since the run: " * join(changed, ", ")))
    (isempty(reasons), reasons)
end

"""
    reuse_evidence(id, from_dir; evidence_dir) -> Union{Nothing,String}

Look for a reusable regression record of paper `id` under `from_dir` (see `reusable`). If one
exists, copy it with its log to `evidence_dir/<id>/<run-id>/`, add `reused_by` (the current
commit and time) and return the new folder; else return `nothing`. The copy keeps the original
provenance, so it never claims to be a new run.
"""
function reuse_evidence(id::AbstractString, from_dir; evidence_dir, root = papers_root(), project = repo_root(),
                        repository = "siqueiratf/VBF.jl", julia = "julia")
    base = joinpath(from_dir, id)
    isdir(base) || return nothing
    for run in sort(readdir(base); rev = true)
        file = joinpath(base, run, "record.toml")
        isfile(file) || continue
        r = TOML.parsefile(file)
        get(r, "kind", "") == "regression" || continue
        ok, _ = reusable(r; dir = joinpath(base, run), repository, project, root, julia)
        ok || continue
        dest = joinpath(abspath(evidence_dir), id, run)
        mkpath(dest)
        cp(joinpath(base, run, r["log"]["file"]), joinpath(dest, r["log"]["file"]); force = true)
        r["reused_by"] = Dict("commit" => readchomp(`git -C $project rev-parse HEAD`), "time_utc" => string(now(UTC)))
        open(io -> TOML.print(io, r; sorted = true), joinpath(dest, "record.toml"), "w")
        return dest
    end
    nothing
end

"""Run `cmd` with stdout and stderr to `log`; stop its process group after `timeout_seconds`."""
function _run_logged(cmd, log; timeout_seconds = nothing)
    started = time_ns()
    process = nothing; timed_out = false
    open(log, "w") do io
        process = run(pipeline(Cmd(cmd; detach = Sys.isunix()); stdout = io, stderr = io); wait = false)
        while process_running(process)
            if timeout_seconds !== nothing && (time_ns() - started) / 1e9 >= timeout_seconds
                timed_out = true; _terminate_group(process); break
            end
            sleep(0.05)
        end
        wait(process)
    end
    status = timed_out ? "timed_out" : success(process) ? "passed" : "failed"
    (status, process.exitcode, round((time_ns() - started) / 1e9; digits = 3))
end
