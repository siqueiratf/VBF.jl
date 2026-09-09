#!/usr/bin/env julia
#
# bench/run_papers.jl — the paper-reproduction benchmark, a sibling of run.jl.
#
# Same harness, same persistence, same benchmark table as bench/run.jl. What
# differs: the source tree (bench/paper_suites/ instead of bench/suites/) and
# the provenance every row carries (paper_id, mode — see bench/harness.jl).
#
# bench/run.jl and every file in bench/suites/ stay exactly as they are: this
# script does not change what they measure or how they persist it.
#
# READ-ONLY against papers/<Paper_ID>/: every file in bench/paper_suites/ only
# `include`s a paper's own files, unmodified — the same method
# bench/calibrate.jl already uses for papers/2026/Kuznetsov_202606.
#
# Profiling is a separate concern, never run from here: see bench/profile.jl.
# A profiled execution must never stand in for a timed one, so this script
# times every case exactly the way bench/run.jl does and nothing more.
#
#   julia --project=. bench/run_papers.jl                        # level 2, every paper
#   julia --project=. bench/run_papers.jl --level=3              # add the heavy cases
#   julia --project=. bench/run_papers.jl --paper=Beierle_202107
#   julia --project=. bench/run_papers.jl --mode=core_only
#   julia --project=. bench/run_papers.jl --list                 # print the cases, measure none
#
# Levels: 1 fast (<0.1 s), 2 medium (<5 s, the default), 3 heavy (can take minutes).

using VBF, VBFCatalog
using Random
using Printf, Dates

const BENCH_DIR = @__DIR__
const PAPERS_ROOT = normpath(joinpath(BENCH_DIR, "..", "papers"))

include(joinpath(BENCH_DIR, "harness.jl"))
include(joinpath(BENCH_DIR, "persistence.jl"))
include(joinpath(BENCH_DIR, "observation.jl"))

using .BenchHarness
using .BenchPersistence
using .BenchObservation

# ── command line ────────────────────────────────────────────────────────────

const HELP = """
bench/run_papers.jl — persist raw paper-reproduction executions in the project database.

usage: julia --project=. bench/run_papers.jl [options]

  --level=N            1 fast, 2 medium (default), 3 heavy
  --paper=NAME         restrict to one paper_id; repeat the flag for more
  --mode=NAME          restrict to one mode (core_only, hybrid, paper_specific)
  --target-seconds=X   wall time to aim for per case (default 1.0)
  --database=PATH      existing project catalog (default BFA_catalog.sqlite)
  --list               print the registered cases and measure none
  -h, --help           print this text

Output appends to the benchmark table, tagged paper_id/mode. See bench/README.md.
"""

function parse_args(argv)
    level  = 2
    papers = String[]
    modes  = String[]
    listonly = false
    target = 1.0
    database = VBFCatalog.catalog_path()
    for a in argv
        if (m = match(r"^--level=(\d+)$", a)) !== nothing
            level = parse(Int, m.captures[1])
        elseif startswith(a, "--paper=")
            push!(papers, split(a, '='; limit = 2)[2])
        elseif startswith(a, "--mode=")
            push!(modes, split(a, '='; limit = 2)[2])
        elseif (m = match(r"^--target-seconds=([0-9.]+)$", a)) !== nothing
            target = parse(Float64, m.captures[1])
        elseif startswith(a, "--database=")
            database = split(a, '='; limit = 2)[2]
        elseif a == "--list"
            listonly = true
        elseif a in ("-h", "--help")
            print(HELP)
            exit(0)
        else
            error("unknown argument: $a")
        end
    end
    1 <= level <= 3 || error("--level must be 1, 2 or 3")
    return (level = level,
            papers = isempty(papers) ? nothing : papers,
            modes  = isempty(modes) ? nothing : modes,
            listonly = listonly, target = target, database = database)
end

const OPTS = parse_args(ARGS)
BenchHarness.TARGET_SECONDS[] = OPTS.target

# ── registry ────────────────────────────────────────────────────────────────
#
# Every file in bench/paper_suites/ defines one function `register!(reg)`,
# exactly like bench/suites/. Each file wraps its paper's own code in its own
# module, so two papers that both define e.g. `paper_report` never collide.

const REG = Registry()

const PAPER_SUITE_DIR = joinpath(BENCH_DIR, "paper_suites")
for file in sort(readdir(PAPER_SUITE_DIR))
    endswith(file, ".jl") || continue
    include(joinpath(PAPER_SUITE_DIR, file))
    Base.invokelatest(register!, REG)
end

OPTS.papers === nothing || filter!(c -> c.paper_id in OPTS.papers, REG)
OPTS.modes  === nothing || filter!(c -> c.mode in OPTS.modes, REG)

if OPTS.listonly
    @printf("%-24s %-34s %-15s %4s %5s  %s\n", "PAPER_ID", "CASE", "MODE", "n", "COST", "NOTE")
    for c in REG
        @printf("%-24s %-34s %-15s %4d %5d  %s\n", c.paper_id, c.name, c.mode, c.n, c.cost, c.note)
    end
    @printf("\n%d cases registered.\n", length(REG))
    exit(0)
end

# ── run ─────────────────────────────────────────────────────────────────────

println("VBF paper-reproduction benchmark")
println("  julia    ", VERSION)
println("  cpu      ", Sys.cpu_info()[1].model, " (", Sys.CPU_THREADS, " threads)")
println("  threads  ", Threads.nthreads())
println("  level    ", OPTS.level)
println("  cases    ", length(REG), " registered")
println()

const T0 = time()
const RESULTS = let db = load_catalog(OPTS.database)
    try
        writer = execution_writer(db; options = OPTS)
        run_registry(REG; level = OPTS.level, on_execution = writer)
    finally
        close(db)
    end
end
const WALL = time() - T0

println()
@printf("measured %d cases in %.1f s\n", length(RESULTS), WALL)
println("appended timed executions to ", OPTS.database, " (benchmark table)")
