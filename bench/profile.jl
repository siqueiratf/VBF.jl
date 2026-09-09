#!/usr/bin/env julia
#
# bench/profile.jl — a separate, opt-in profiling entry point.
#
# NOT part of bench/run.jl or bench/run_papers.jl, and never invoked by
# them: a profiled execution is never used as a benchmark timing
# measurement. This script writes nothing to the benchmark table. Profiling
# here is exactly one untimed, uncounted execution of a case already
# registered by bench/suites/ or bench/paper_suites/, used only to explain
# where that case's runtime goes — never to select which cases exist.
#
# Requires the bench/profiling environment: FlameGraphs.jl, ProfileSVG.jl,
# and ProfileView.jl live there, not in the root project bench/run.jl and
# bench/run_papers.jl share.
#
#   julia --project=bench/profiling bench/profile.jl --group=constructions --name=gold_apn --n=8
#   julia --project=bench/profiling bench/profile.jl --paper=Beierle_202107 --case=Beierle_202107_algorithm1
#   julia --project=bench/profiling bench/profile.jl --paper=Beierle_202107 --case=Beierle_202107_algorithm1 --view
#
# Workflow: warm up once (uncounted) to estimate a sampling delay and let
# JIT compilation happen outside the profile; clear Profile; profile one
# full call; retain the raw data in a portable, reloadable form
# (Profile.retrieve); build a FlameGraphs.jl call tree; derive the
# core/paper/other attribution from that tree (bench/profiling/attribution.jl,
# not a per-frame scan); save an SVG flame graph (ProfileSVG.jl); optionally
# open an interactive view (ProfileView.jl — needs a display; the SVG is the
# optional diagnostic artifact; structured summaries support later thesis plots).
#
# Artifacts land under bench/profiles/core/<case>/<timestamp>/ or
# bench/profiles/papers/<paper_id>/<case>/<timestamp>/ — never inside the
# SQLite catalog. Each directory holds profile_raw.jls (the portable raw
# data), attribution.json, and flamegraph.svg (unless --no-svg).

using VBF, VBFCatalog
using Profile, FlameGraphs, ProfileSVG
using Dates, Printf, Serialization, JSON3, Random, SHA

const BENCH_DIR = @__DIR__
const PROFILES_DIR = joinpath(BENCH_DIR, "profiles")

include(joinpath(BENCH_DIR, "harness.jl"))
include(joinpath(BENCH_DIR, "observation.jl"))
include(joinpath(BENCH_DIR, "persistence.jl")) # bench/suites/06_constructions.jl names BenchPersistence.PRODUCERS; loading it defines that constant and nothing else — this script never calls its execution_writer, so it never touches the database
include(joinpath(BENCH_DIR, "profiling", "attribution.jl"))

using .BenchHarness
using .BenchObservation
using .BenchPersistence
using .ProfileAttribution

const HELP = """
bench/profile.jl — profile ONE core or paper-reproduction case, once.

usage:
  julia --project=bench/profiling bench/profile.jl --group=G --name=NAME [--n=N] [options]
  julia --project=bench/profiling bench/profile.jl --paper=PAPER_ID --case=NAME [options]

  --group=NAME   select a bench/suites/ case by group (e.g. constructions)
  --name=NAME    select a case by its registered name
  --n=N          disambiguate a name registered at more than one n
  --paper=ID     select a bench/paper_suites/ case by paper_id
  --case=NAME    select a paper case by its registered name
  --view         also open an interactive ProfileView.jl window (needs a display)
  --no-svg       skip the SVG export (on by default)
  -h, --help     print this text

Never writes to the benchmark table. Artifacts land under bench/profiles/.
"""

function parse_args(argv)
    group = nothing; name = nothing; n = nothing
    paper = nothing; case = nothing
    view = false; svg = true
    for a in argv
        if startswith(a, "--group=");    group = split(a, '='; limit = 2)[2]
        elseif startswith(a, "--name="); name  = split(a, '='; limit = 2)[2]
        elseif startswith(a, "--n=");    n     = parse(Int, split(a, '='; limit = 2)[2])
        elseif startswith(a, "--paper="); paper = split(a, '='; limit = 2)[2]
        elseif startswith(a, "--case=");  case  = split(a, '='; limit = 2)[2]
        elseif a == "--view"; view = true
        elseif a == "--no-svg"; svg = false
        elseif a in ("-h", "--help"); print(HELP); exit(0)
        else error("unknown argument: $a")
        end
    end
    (; group, name, n, paper, case, view, svg)
end

const OPTS = parse_args(ARGS)

# ── find the one case ───────────────────────────────────────────────────────
#
# Loaded the same way bench/run.jl and bench/run_papers.jl load a suite
# directory — include each file, call the register! it defines, all at top
# level (not wrapped in a function: Julia 1.12's world-age rules for a
# redefined global like `register!` want that, and it is what bench/run.jl
# and bench/run_papers.jl already do). Selects exactly one BenchCase and
# runs its setup/call unmodified — this script adds no code to the case
# itself.

const CASE, ARTIFACT_ROOT = if OPTS.paper !== nothing || OPTS.case !== nothing
    (OPTS.paper !== nothing && OPTS.case !== nothing) ||
        error("--paper and --case must be given together")
    reg = Registry()
    local paper_suite_dir = joinpath(BENCH_DIR, "paper_suites")
    for file in sort(readdir(paper_suite_dir))
        endswith(file, ".jl") || continue
        include(joinpath(paper_suite_dir, file))
        Base.invokelatest(register!, reg)
    end
    matches = filter(c -> c.paper_id == OPTS.paper && c.name == OPTS.case, reg)
    isempty(matches) &&
        error("no paper case matches --paper=$(OPTS.paper) --case=$(OPTS.case)")
    length(matches) > 1 &&
        error("more than one case matches --paper=$(OPTS.paper) --case=$(OPTS.case)")
    matches[1], joinpath(PROFILES_DIR, "papers", OPTS.paper, OPTS.case)
elseif OPTS.group !== nothing || OPTS.name !== nothing
    (OPTS.group !== nothing && OPTS.name !== nothing) ||
        error("--group and --name must be given together")
    reg = Registry()
    local suite_dir = joinpath(BENCH_DIR, "suites")
    for file in sort(readdir(suite_dir))
        endswith(file, ".jl") || continue
        include(joinpath(suite_dir, file))
        Base.invokelatest(register!, reg)
    end
    matches = filter(c -> c.group == OPTS.group && c.name == OPTS.name &&
                          (OPTS.n === nothing || c.n == OPTS.n), reg)
    isempty(matches) && error("no core case matches --group=$(OPTS.group) " *
        "--name=$(OPTS.name)" * (OPTS.n === nothing ? "" : " --n=$(OPTS.n)"))
    length(matches) > 1 && error("more than one case matches; add --n= to " *
        "disambiguate (n ∈ $(join(unique(c.n for c in matches), ", ")))")
    c = matches[1]
    c, joinpath(PROFILES_DIR, "core", c.n == 0 ? c.name : "$(c.name)_n$(c.n)")
else
    print(HELP)
    error("select a case: either --group/--name, or --paper/--case")
end

println("profiling: ", CASE.group, "/", CASE.name,
        CASE.paper_id == "" ? "" : "  (paper_id=$(CASE.paper_id), mode=$(CASE.mode))")

# ── one untimed, unbenchmarked execution ────────────────────────────────────

seed = 0x5EED0000 + hash((CASE.group, CASE.name, CASE.n)) % 0xFFFF
Random.seed!(seed)
payload = CASE.setup()
warm = @elapsed CASE.call(payload) # warm-up: JIT + a duration estimate; uncounted, unstored
@printf("warm-up call: %.3f s (uncounted; not a benchmark measurement)\n", warm)

# Same adaptive-delay reasoning the old bench/profile_split.jl used: a slow
# call cannot be interrupted mid-call, so Julia's default 1 ms delay
# overflows the sample buffer before a call of a few hundred seconds
# finishes. Only widen the delay once the warm-up says the call is slow.
delay = warm < 0.5 ? 0.001 : max(0.001, warm / 50_000)
Profile.init(n = 20_000_000, delay = delay)
Profile.clear()
t0 = time()
Profile.@profile CASE.call(payload)
elapsed = time() - t0
@printf("profiled call: %.3f s (one execution; not stored as a benchmark row)\n", elapsed)

data, lidict = Profile.retrieve() # portable form: safe to serialize and reload in a later session
println("raw samples: ", length(data))

# ── artifacts ────────────────────────────────────────────────────────────────

stamp = Dates.format(Dates.now(Dates.UTC), "yyyymmdd-HHMMSSZ")
out_dir = joinpath(ARTIFACT_ROOT, stamp)
mkpath(out_dir)

open(joinpath(out_dir, "profile_raw.jls"), "w") do io
    serialize(io, (; data, lidict,
        case = (; group = CASE.group, name = CASE.name, n = CASE.n,
                  paper_id = CASE.paper_id, mode = CASE.mode, note = CASE.note,
                  approach = CASE.approach, parameters = CASE.parameters),
        seed = string(seed), sampling_delay = delay,
        provenance = (; cpu = Sys.cpu_info()[1].model, julia_threads = Threads.nthreads(),
            source_tree_sha256 = bytes2hex(sha256(JSON3.write(sort!(collect(
                BenchPersistence.source_hashes(dirname(BENCH_DIR))); by=first))))),
        warm_seconds = warm, profiled_seconds = elapsed,
        julia_version = string(VERSION), recorded_at = string(Dates.now(Dates.UTC))))
end
println("raw profile saved:  ", joinpath(out_dir, "profile_raw.jls"))

g = flamegraph(data; lidict)
attribution = attribute_flamegraph(g)
println("attribution (estimated, sampling-based): ", attribution)

open(joinpath(out_dir, "attribution.json"), "w") do io
    finite_attribution = Dict(string(k) => (v isa AbstractFloat && !isfinite(v) ? nothing : v)
                              for (k, v) in pairs(attribution))
    JSON3.write(io, merge(finite_attribution, Dict(
        "group" => CASE.group, "name" => CASE.name, "n" => CASE.n,
        "paper_id" => (isempty(CASE.paper_id) ? nothing : CASE.paper_id),
        "mode" => (isempty(CASE.mode) ? nothing : CASE.mode),
        "warm_seconds" => warm, "profiled_seconds" => elapsed)))
end
println("attribution saved: ", joinpath(out_dir, "attribution.json"))

if OPTS.svg
    svg_path = joinpath(out_dir, "flamegraph.svg")
    ProfileSVG.save(svg_path, g)
    println("flame graph saved:  ", svg_path)
end

if OPTS.view
    try
        @eval using ProfileView
        Base.invokelatest(ProfileView.view, g)
        println("ProfileView window opened. Press Enter here to close and exit.")
        readline()
    catch e
        println("ProfileView could not open (no display available?): ", sprint(showerror, e))
    end
end
