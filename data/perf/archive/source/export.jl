# bench/export.jl — turn BenchResult values into the files that the thesis reads.
#
# The exporter writes three artifacts into bench/generated/:
#   benchmarks.csv        the tidy dataset, one row per measured case
#   benchmarks_table.tex  a booktabs table, grouped by library tier
#   benchmarks_facts.tex  one \newcommand per case, for an inline citation
#
# It also writes benchmarks_meta.tex with the machine and the version, because a
# timing without a machine is not a result.
module BenchExport

using Printf, Dates, InteractiveUtils
using ..BenchHarness: BenchResult

export write_csv, write_latex_table, write_macros, write_meta, export_all

const GROUP_TITLES = Dict(
    "representations" => "Representations and finite fields",
    "linalg"          => "Linear algebra over GF(2)",
    "spectra"         => "Spectra and statistics",
    "invariants"      => "Invariants",
    "equivalence"     => "Equivalence tests",
    "constructions"   => "Constructions and searches",
    "catalog"         => "Catalog queries",
)

# The order that the table prints. A group outside this list prints last.
const GROUP_ORDER = ["representations", "linalg", "spectra", "invariants",
                     "equivalence", "constructions", "catalog"]

group_rank(g) = something(findfirst(==(g), GROUP_ORDER), length(GROUP_ORDER) + 1)

"Sort the results by group order, then by case name, then by n."
function ordered(results::Vector{BenchResult})
    return sort(results; by = r -> (group_rank(r.group), r.name, r.n))
end

# ── CSV ─────────────────────────────────────────────────────────────────────

const CSV_HEADER = "group,case,n,cost,reps,min_seconds,median_seconds," *
                   "mean_seconds,std_seconds,bytes,note"

csv_escape(s::AbstractString) = '"' * replace(s, '"' => "\"\"") * '"'

"""
    write_csv(path, results)

Write the tidy dataset. One row is one measured case. A spreadsheet, R, pandas
or pgfplots can read this file without any further work.
"""
function write_csv(path::AbstractString, results::Vector{BenchResult})
    open(path, "w") do io
        println(io, CSV_HEADER)
        for r in ordered(results)
            @printf(io, "%s,%s,%d,%d,%d,%.9g,%.9g,%.9g,%.9g,%d,%s\n",
                    r.group, r.name, r.n, r.cost, r.reps,
                    r.min_seconds, r.median_seconds, r.mean_seconds,
                    r.std_seconds, r.bytes, csv_escape(r.note))
        end
    end
    return path
end

# ── LaTeX ───────────────────────────────────────────────────────────────────

"Format a time in seconds as LaTeX maths, with three significant digits."
function fmt_sci(x::Float64)
    x == 0 && return raw"$0$"
    e = floor(Int, log10(abs(x)))
    m = x / 10.0^e
    return @sprintf("\$%.2f\\times10^{%d}\$", m, e)
end

"Format a byte count with a thin space every three digits."
function fmt_int(v::Integer)
    s = string(v)
    parts = String[]
    while length(s) > 3
        pushfirst!(parts, s[end-2:end]); s = s[1:end-3]
    end
    pushfirst!(parts, s)
    return join(parts, "\\,")
end

const TEX_SPECIAL = Dict(
    '\\' => "\\textbackslash{}",
    '{'  => "\\{",
    '}'  => "\\}",
    '#'  => "\\#",
    '$'  => "\\\$",
    '%'  => "\\%",
    '&'  => "\\&",
    '_'  => "\\_",
    '~'  => "\\textasciitilde{}",
    '^'  => "\\textasciicircum{}",
)

"Escape every character that LaTeX reserves."
function tex_escape(s::AbstractString)
    io = IOBuffer()
    for c in s
        print(io, get(TEX_SPECIAL, c, c))
    end
    return String(take!(io))
end

"""
    tex_note(s) -> String

Escape a note for LaTeX. A note holds mathematics such as `x^3` or `2^n`, so the
function turns each power into maths first, then escapes the rest. Without this
step a bare `^` stops the LaTeX run with "Missing \$ inserted".
"""
function tex_note(s::AbstractString)
    parts = String[]
    last = 1
    for m in eachmatch(r"([A-Za-z0-9])\^([A-Za-z0-9]+)", s)
        push!(parts, tex_escape(SubString(s, last, prevind(s, m.offset))))
        push!(parts, "\$" * m.captures[1] * "^{" * m.captures[2] * "}\$")
        last = m.offset + ncodeunits(m.match)
    end
    push!(parts, tex_escape(SubString(s, last)))
    return join(parts)
end

"""
    write_latex_table(path, results)

Write a booktabs table of every measured case, grouped by library tier. The
caller must load `booktabs` in the thesis preamble.
"""
function write_latex_table(path::AbstractString, results::Vector{BenchResult})
    rows = ordered(results)
    open(path, "w") do io
        println(io, "% !!! GENERATED FILE — DO NOT EDIT !!!")
        println(io, "% Produced by bench/run.jl. Regenerate with `make -C bench bench`.")
        println(io, "\\begin{tabular}{llrrrr}")
        println(io, "\\toprule")
        println(io, "Operation & Note & \$n\$ & min (s) & median (s) & reps \\\\")
        last_group = ""
        for r in rows
            if r.group != last_group
                println(io, "\\midrule")
                title = get(GROUP_TITLES, r.group, r.group)
                println(io, "\\multicolumn{6}{l}{\\emph{", tex_escape(title), "}} \\\\")
                last_group = r.group
            end
            ncell = r.n > 0 ? string(r.n) : "---"
            @printf(io, "\\texttt{%s} & %s & %s & %s & %s & %d \\\\\n",
                    tex_escape(r.name), tex_note(r.note), ncell,
                    fmt_sci(r.min_seconds), fmt_sci(r.median_seconds), r.reps)
        end
        println(io, "\\bottomrule")
        println(io, "\\end{tabular}")
    end
    return path
end

const DIGIT_WORDS = ["Zero", "One", "Two", "Three", "Four",
                     "Five", "Six", "Seven", "Eight", "Nine"]

"""
    macro_name(r) -> String

Build a LaTeX control sequence for one case. A control sequence accepts letters
only, so the function spells every digit as a word.
"""
function macro_name(r::BenchResult)
    # A trailing "!" marks the in-place method. Keep it, or the in-place case and
    # the allocating case of the same operation collapse to one command.
    raw = replace(r.group * "_" * r.name, "!" => "_bang")
    parts = split(raw, r"[^A-Za-z0-9]+"; keepempty = false)
    body = join(uppercasefirst(String(p)) for p in parts)
    body = replace(body, r"[0-9]" => c -> DIGIT_WORDS[parse(Int, c) + 1])
    suffix = r.n > 0 ? "N" * join(DIGIT_WORDS[d + 1] for d in digits(r.n; pad = 1) |> reverse) : ""
    return "bm" * body * suffix
end

"""
    write_macros(path, results)

Write one `\\newcommand` per case, holding the minimum time in seconds. The
thesis can then quote a single figure in running text and keep it in step with
the table.
"""
function write_macros(path::AbstractString, results::Vector{BenchResult})
    open(path, "w") do io
        println(io, "% !!! GENERATED FILE — DO NOT EDIT !!!")
        println(io, "% One command per benchmark case; the value is the minimum time in seconds.")
        seen = Set{String}()
        for r in ordered(results)
            nm = macro_name(r)
            if nm in seen
                # Two cases map to one command. A silent skip would lose a figure,
                # so the exporter renames the second case and says so.
                base = nm
                k = 1
                while nm in seen
                    k += 1
                    nm = base * "Alt" * DIGIT_WORDS[k]
                end
                @warn "benchmark macro name collision" case = "$(r.group)/$(r.name)" n = r.n original = base renamed = nm
            end
            push!(seen, nm)
            println(io, "\\newcommand{\\", nm, "}{", fmt_sci(r.min_seconds), "}")
        end
    end
    return path
end

"""
    write_meta(path, results; level, wall_seconds)

Write the machine, the Julia version and the run parameters. A timing without a
machine is not a result, so the thesis must print this next to the table.
"""
function write_meta(path::AbstractString, results::Vector{BenchResult};
                    level::Integer, wall_seconds::Float64)
    cpu = try
        Sys.cpu_info()[1].model
    catch
        "unknown"
    end
    mem_gb = Sys.total_memory() / 2^30
    open(path, "w") do io
        println(io, "% !!! GENERATED FILE — DO NOT EDIT !!!")
        println(io, "\\newcommand{\\bmMetaDate}{", Dates.format(now(UTC), "yyyy-mm-dd"), "}")
        println(io, "\\newcommand{\\bmMetaJulia}{", string(VERSION), "}")
        println(io, "\\newcommand{\\bmMetaCPU}{", tex_escape(cpu), "}")
        @printf(io, "\\newcommand{\\bmMetaCores}{%d}\n", Sys.CPU_THREADS)
        @printf(io, "\\newcommand{\\bmMetaThreads}{%d}\n", Threads.nthreads())
        @printf(io, "\\newcommand{\\bmMetaMemoryGB}{%.1f}\n", mem_gb)
        @printf(io, "\\newcommand{\\bmMetaCases}{%d}\n", length(results))
        @printf(io, "\\newcommand{\\bmMetaLevel}{%d}\n", level)
        @printf(io, "\\newcommand{\\bmMetaWallSeconds}{%.1f}\n", wall_seconds)
        println(io, "\\newcommand{\\bmMetaStatistic}{minimum of \$N\$ repetitions after one warm-up call}")
    end
    return path
end

"""
    export_all(dir, results; level, wall_seconds) -> Vector{String}

Write every artifact into `dir` and return the paths.
"""
function export_all(dir::AbstractString, results::Vector{BenchResult};
                    level::Integer, wall_seconds::Float64)
    mkpath(dir)
    return [
        write_csv(joinpath(dir, "benchmarks.csv"), results),
        write_latex_table(joinpath(dir, "benchmarks_table.tex"), results),
        write_macros(joinpath(dir, "benchmarks_facts.tex"), results),
        write_meta(joinpath(dir, "benchmarks_meta.tex"), results;
                   level = level, wall_seconds = wall_seconds),
    ]
end

end # module
