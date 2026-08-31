#!/usr/bin/env julia
#
# bench/run.jl — start the VBF benchmark suite and export the thesis artifacts.
#
#   julia --project=. bench/run.jl                 # level 2, every group
#   julia --project=. bench/run.jl --level=1       # the fast cases only
#   julia --project=. bench/run.jl --level=3       # add the heavy cases
#   julia --project=. bench/run.jl --group=spectra --group=invariants
#   julia --project=. bench/run.jl --n=8 --n=9
#   julia --project=. bench/run.jl --list          # print the cases, measure none
#
# The script reads only this repository and writes only into bench/generated/.
# It rebuilds no database and it runs no git command.
#
# Levels:
#   1  fast     each case is under about 0.1 s
#   2  medium   each case is under about 5 s          (the default)
#   3  heavy    a case can take minutes
#
# WARNING: level 3 runs exhaustive equivalence searches. Do not start level 3 on
# a machine that you need for other work. It can occupy the machine for an hour.

using VBF, VBFCatalog
using Random
using Printf, Dates

const BENCH_DIR = @__DIR__
const OUT_DIR   = joinpath(BENCH_DIR, "generated")

include(joinpath(BENCH_DIR, "harness.jl"))
include(joinpath(BENCH_DIR, "export.jl"))

using .BenchHarness
using .BenchExport

# ── command line ────────────────────────────────────────────────────────────

const HELP = """
bench/run.jl — start the VBF benchmark suite and export the thesis artifacts.

usage: julia --project=. bench/run.jl [options]

  --level=N            1 fast, 2 medium (default), 3 heavy
  --group=NAME         restrict to one group; repeat the flag for more
  --n=N                restrict to one bit-width; repeat the flag for more
  --target-seconds=X   wall time to aim for per case (default 1.0)
  --list               print the registered cases and measure none
  -h, --help           print this text

Output goes to bench/generated/. See bench/README.md.
"""

function parse_args(argv)
    level  = 2
    groups = String[]
    dims   = Int[]
    listonly = false
    target = 1.0
    for a in argv
        if (m = match(r"^--level=(\d+)$", a)) !== nothing
            level = parse(Int, m.captures[1])
        elseif (m = match(r"^--group=([A-Za-z_]+)$", a)) !== nothing
            push!(groups, m.captures[1])
        elseif (m = match(r"^--n=(\d+)$", a)) !== nothing
            push!(dims, parse(Int, m.captures[1]))
        elseif (m = match(r"^--target-seconds=([0-9.]+)$", a)) !== nothing
            target = parse(Float64, m.captures[1])
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
            groups = isempty(groups) ? nothing : groups,
            dims   = isempty(dims) ? nothing : dims,
            listonly = listonly,
            target = target)
end

const OPTS = parse_args(ARGS)
BenchHarness.TARGET_SECONDS[] = OPTS.target

# ── registry ────────────────────────────────────────────────────────────────
#
# Every file in bench/suites/ defines one function `register!(reg)`. The loop
# includes a file and calls that function before it moves to the next file, so
# each suite is independent of the others.

const REG = Registry()

const SUITE_DIR = joinpath(BENCH_DIR, "suites")
for file in sort(readdir(SUITE_DIR))
    endswith(file, ".jl") || continue
    include(joinpath(SUITE_DIR, file))
    Base.invokelatest(register!, REG)
end

if OPTS.listonly
    @printf("%-16s %-34s %4s %5s  %s\n", "GROUP", "CASE", "n", "COST", "NOTE")
    for c in REG
        @printf("%-16s %-34s %4d %5d  %s\n", c.group, c.name, c.n, c.cost, c.note)
    end
    @printf("\n%d cases registered.\n", length(REG))
    exit(0)
end

# ── run ─────────────────────────────────────────────────────────────────────

println("VBF benchmark suite")
println("  julia    ", VERSION)
println("  cpu      ", Sys.cpu_info()[1].model, " (", Sys.CPU_THREADS, " threads)")
println("  threads  ", Threads.nthreads())
println("  level    ", OPTS.level)
println("  cases    ", length(REG), " registered")
println()

const T0 = time()
const RESULTS = run_registry(REG; level = OPTS.level,
                             groups = OPTS.groups, dims = OPTS.dims)
const WALL = time() - T0

println()
@printf("measured %d cases in %.1f s\n", length(RESULTS), WALL)

paths = export_all(OUT_DIR, RESULTS; level = OPTS.level, wall_seconds = WALL)
println("wrote:")
for p in paths
    println("  ", relpath(p, dirname(BENCH_DIR)))
end
