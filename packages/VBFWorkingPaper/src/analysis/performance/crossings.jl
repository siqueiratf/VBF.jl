#!/usr/bin/env julia
#
# packages/VBFWorkingPaper/src/analysis/performance/crossings.jl — cross the benchmark axes and write the article artifacts.
#
#   julia --project=. packages/VBFWorkingPaper/src/analysis/performance/crossings.jl
#   julia --project=. packages/VBFWorkingPaper/src/analysis/performance/crossings.jl --csv=data/perf/archive/generated/benchmarks.csv
#
# The benchmark suite measures. This script draws the conclusions. It reads
# data/perf/archive/generated/benchmarks.csv, data/perf/archive/generated/benchmarks_meta.tex and
# packages/VBFWorkingPaper/doc/performance/crossings.toml, and it writes nothing outside data/perf/archive/generated/. It runs
# no benchmark, it touches no package and it runs no git command.
#
# It builds three crossings.
#
#   1. n x case against the theoretical exponent. A measured slope that misses
#      its predicted exponent is a result. A table of timings is not.
#   2. Outcome polarity x equivalence relation. A decision procedure answers
#      "yes" and "no" through different code paths, so one mean over both
#      answers has no meaning.
#   3. Time x allocated bytes. Some cases stop for the reason of memory before
#      the time becomes the obstacle.
#
# CAUTION: the `bytes` column comes from `@allocated`. It is the total that one
# call allocates. It is NOT the peak resident memory. See the [memory] section
# of packages/VBFWorkingPaper/doc/performance/crossings.toml.

using Printf, TOML, Dates, VBFRepro

const BENCH_DIR = @__DIR__
const ROOT      = VBFRepro.repo_root()

# ── command line ────────────────────────────────────────────────────────────

const HELP = """
packages/VBFWorkingPaper/src/analysis/performance/crossings.jl — cross the benchmark axes and write the article artifacts.

usage: julia --project=. packages/VBFWorkingPaper/src/analysis/performance/crossings.jl [options]

  --csv=PATH    the measurements   (default data/perf/archive/generated/benchmarks.csv)
  --spec=PATH   the predictions    (default packages/VBFWorkingPaper/doc/performance/crossings.toml)
  --meta=PATH   the machine        (default data/perf/archive/generated/benchmarks_meta.tex)
  --out=DIR     the output         (default data/working-paper/performance/crossings)
  -h, --help    print this text

The script measures nothing. Supply a historical summary CSV with --csv=PATH.
"""

function parse_args(argv)
    csv  = joinpath(ROOT, "data/perf/archive/generated/benchmarks.csv")
    spec = joinpath(ROOT, "packages/VBFWorkingPaper/doc/performance/crossings.toml")
    meta = joinpath(ROOT, "data/perf/archive/generated/benchmarks_meta.tex")
    out  = joinpath(ROOT, "data/working-paper/performance/crossings")
    for a in argv
        if (m = match(r"^--csv=(.+)$", a))  !== nothing; csv  = m.captures[1]
        elseif (m = match(r"^--spec=(.+)$", a)) !== nothing; spec = m.captures[1]
        elseif (m = match(r"^--meta=(.+)$", a)) !== nothing; meta = m.captures[1]
        elseif (m = match(r"^--out=(.+)$", a))  !== nothing; out  = m.captures[1]
        elseif a in ("-h", "--help"); print(HELP); exit(0)
        else; error("unknown argument: $a")
        end
    end
    return (csv = csv, spec = spec, meta = meta, out = out)
end

const OPTS = parse_args(ARGS)

# ── the measurements ────────────────────────────────────────────────────────

struct Row
    group::String
    case::String
    n::Int
    cost::Int
    reps::Int
    min_seconds::Float64
    median_seconds::Float64
    mean_seconds::Float64
    std_seconds::Float64
    bytes::Int
    note::String
end

key(r::Row) = r.group * "/" * r.case

"""
    read_rows(path) -> Vector{Row}

Read the tidy dataset that data/perf/archive/source/export.jl wrote. The last field is a quoted
note that can hold a comma, so the split keeps it whole.
"""
function read_rows(path::AbstractString)
    isfile(path) || error("no historical measurements at $path; supply --csv=PATH")
    rows = Row[]
    for (i, line) in enumerate(eachline(path))
        i == 1 && continue                      # the header
        isempty(strip(line)) && continue
        f = split(line, ','; limit = 11)
        length(f) == 11 || error("malformed row $i in $path")
        note = strip(f[11])
        if startswith(note, '"') && endswith(note, '"')
            note = replace(note[2:end-1], "\"\"" => "\"")
        end
        push!(rows, Row(f[1], f[2], parse(Int, f[3]), parse(Int, f[4]),
                        parse(Int, f[5]), parse(Float64, f[6]),
                        parse(Float64, f[7]), parse(Float64, f[8]),
                        parse(Float64, f[9]), parse(Int, f[10]), String(note)))
    end
    return rows
end

"""
    read_meta(path) -> Dict{String,String}

Read the machine description that data/perf/archive/source/export.jl wrote. A timing without a
machine is not a result, so every artifact here repeats it.
"""
function read_meta(path::AbstractString)
    d = Dict{String,String}()
    isfile(path) || return d
    for line in eachline(path)
        m = match(r"^\\newcommand\{\\(\w+)\}\{(.*)\}$", line)
        m === nothing && continue
        d[m.captures[1]] = m.captures[2]
    end
    return d
end

const ROWS = read_rows(OPTS.csv)
const META = read_meta(OPTS.meta)
const SPEC = TOML.parsefile(OPTS.spec)

const FIT  = SPEC["fit"]
const TOL  = Float64(FIT["tolerance_bits"])
const MINP = Int(FIT["min_points"])
const FLOOR_SECONDS = Float64(FIT["overhead_floor_seconds"])
const T_CEILING = Float64(FIT["time_ceiling_seconds"])
const B_CEILING = Float64(FIT["memory_ceiling_bytes"])
const MAX_EXTRAP = Int(FIT["max_extrapolation_n"])
const MAX_RESIDUAL = Float64(FIT["max_residual_bits"])

# ── size kinds ──────────────────────────────────────────────────────────────

const KIND_DEFAULTS  = SPEC["size_kind"]["defaults"]
const KIND_OVERRIDES = SPEC["size_kind"]["overrides"]

"Return what the `n` column means for one case."
function size_kind(k::AbstractString, n::Integer)
    n == 0 && return "none"
    haskey(KIND_OVERRIDES, k) && return KIND_OVERRIDES[k]
    grp = String(split(k, '/')[1])
    return get(KIND_DEFAULTS, grp, "unclassified")
end

"An exponential model applies to a width; a power law applies to a matrix side."
model_of(kind::AbstractString) =
    kind in ("bit_width", "vector_len") ? "exponential" :
    kind == "matrix_dim" ? "power_law" : "none"

# ── the fit ─────────────────────────────────────────────────────────────────

"""
    fit_line(xs, ys) -> NamedTuple

Least squares of `y = a + b*x`. The caller passes `log2` of the measurement as
`y`, so `b` is the slope in bits.
"""
function fit_line(xs::Vector{Float64}, ys::Vector{Float64})
    m = length(xs)
    mx = sum(xs) / m
    my = sum(ys) / m
    sxx = sum((x - mx)^2 for x in xs)
    sxx == 0 && error("every point has the same x")
    b = sum((xs[i] - mx) * (ys[i] - my) for i = 1:m) / sxx
    a = my - b * mx
    sstot = sum((y - my)^2 for y in ys)
    ssres = sum((ys[i] - (a + b * xs[i]))^2 for i = 1:m)
    return (slope = b, intercept = a,
            r2 = sstot == 0 ? 1.0 : 1 - ssres / sstot,
            maxres = maximum(abs(ys[i] - (a + b * xs[i])) for i = 1:m))
end

"Return the slope between each pair of neighbours, so curvature stays visible."
function pair_slopes(xs::Vector{Float64}, ys::Vector{Float64})
    return [(ys[i+1] - ys[i]) / (xs[i+1] - xs[i]) for i = 1:(length(xs) - 1)]
end

"""
    reach(intercept, slope, ceiling) -> Int

Return the largest integer `n` that the fitted line keeps under `ceiling`.
Return -1 when the line never crosses it, or when the slope is not positive.
"""
function reach(a::Float64, b::Float64, ceiling::Float64)
    b <= 0 && return -1
    return floor(Int, (log2(ceiling) - a) / b)
end

# ── crossing 1: n x case against the theoretical exponent ───────────────────

struct Growth
    case::String
    kind::String            # what n means
    model::String           # exponential or power_law
    points::Int
    nmin::Int
    nmax::Int
    tmin::Float64
    tmax::Float64
    slope::Float64
    predicted::Float64
    predkind::String        # exact or lower_bound
    delta::Float64
    r2::Float64
    maxres::Float64
    plo::Float64
    phi::Float64
    bslope::Float64         # the slope of the allocation
    verdict::String
    reach_time::Int
    reach_bytes::Int
    capped_time::Bool
    capped_bytes::Bool
    binding::String
    basis::String
    source::String
    caveat::String
end

const EXCLUDED = Dict{String,String}(
    String(e["case"]) => String(e["reason"]) for e in get(SPEC, "excluded", Any[]))

"Group the rows of one case, sorted by n, with n > 0 only."
function series(k::AbstractString)
    rs = sort!(filter(r -> key(r) == k && r.n > 0, ROWS); by = r -> r.n)
    return rs
end

function build_growth()
    out = Growth[]
    for g in SPEC["growth"]
        k = String(g["case"])
        rs = series(k)
        if length(rs) < MINP
            @warn "growth series too short; the script skips it" case=k points=length(rs) need=MINP
            continue
        end
        kind = size_kind(k, rs[1].n)
        mdl  = model_of(kind)
        mdl == "none" && error("case $k has size_kind $kind and cannot be fitted")

        xs = mdl == "exponential" ? Float64[r.n for r in rs] :
                                    Float64[log2(r.n) for r in rs]
        ys = Float64[log2(r.min_seconds) for r in rs]
        bs = Float64[log2(max(r.bytes, 1)) for r in rs]

        f  = fit_line(xs, ys)
        fb = fit_line(xs, bs)
        ps = pair_slopes(xs, ys)

        predicted = Float64(g["predicted_slope"])
        predkind  = String(g["kind"])
        delta     = f.slope - predicted

        floored = minimum(r.min_seconds for r in rs) < FLOOR_SECONDS
        verdict = if floored
            "inconclusive: overhead floor"
        elseif predkind == "lower_bound"
            delta >= -TOL ? "confirms the bound" : "below the bound"
        else
            abs(delta) <= TOL ? "confirms" : (delta > 0 ? "above" : "below")
        end
        # A curved series has no single exponent. The verdict must say so, or
        # the average slope reads as a law that the points do not support.
        if !floored && f.maxres > MAX_RESIDUAL
            verdict *= " (curved fit)"
        end

        # An extrapolation is worth printing only near the measured range. A fit
        # over n = 8 to 12 says nothing about n = 32. Past `cap` the script
        # keeps the bound ">cap" and drops the number.
        cap = rs[end].n + MAX_EXTRAP
        fittable = !floored && mdl == "exponential"
        rt, ct = -1, false
        rb, cb = -1, false
        if fittable
            raw_t = reach(f.intercept, f.slope, T_CEILING)
            rt, ct = (raw_t < 0 || raw_t > cap) ? (cap, true) : (raw_t, false)
            raw_b = reach(fb.intercept, fb.slope, B_CEILING)
            rb, cb = (raw_b < 0 || raw_b > cap) ? (cap, true) : (raw_b, false)
        end
        binding = (!fittable || ct || cb) ? "--" :
                  rt < rb ? "time" : rb < rt ? "memory" : "both"

        push!(out, Growth(k, kind, mdl, length(rs), rs[1].n, rs[end].n,
                          rs[1].min_seconds, rs[end].min_seconds,
                          f.slope, predicted, predkind, delta, f.r2, f.maxres,
                          minimum(ps), maximum(ps), fb.slope, verdict, rt, rb,
                          ct, cb, binding, String(g["basis"]), String(g["source"]),
                          String(get(g, "caveat", ""))))
    end
    return sort!(out; by = x -> x.case)
end

"""
    unmodelled() -> Vector{Tuple{String,Int}}

Return every case that has enough points to fit and that the spec neither
predicts nor excludes. A silent omission here would let a new case drop out of
the article, so the script prints this list and writes it into the header of
the growth table.
"""
function unmodelled(gs::Vector{Growth})
    have = Set(x.case for x in gs)
    counts = Dict{String,Int}()
    for r in ROWS
        r.n == 0 && continue
        counts[key(r)] = get(counts, key(r), 0) + 1
    end
    out = Tuple{String,Int}[]
    for (k, c) in counts
        c >= MINP || continue
        (k in have || haskey(EXCLUDED, k)) && continue
        push!(out, (k, c))
    end
    return sort!(out)
end

# ── crossing 2: outcome polarity x equivalence relation ─────────────────────

struct Polarity
    relation::String
    n::Int
    poscase::String
    negcase::String
    pos::Float64
    neg::Float64
    ratio::Float64          # negative over positive
    posbytes::Int
    negbytes::Int
    bratio::Float64
    expectation::String
    direction::String
    agrees::Bool
    posnote::String
    negnote::String
    mechanism::String
end

const BALANCED_BAND = Float64(get(get(SPEC, "polarity_rules", Dict()),
                                  "balanced_band", 1.5))

function find_row(k::AbstractString, n::Integer)
    i = findfirst(r -> key(r) == k && r.n == n, ROWS)
    return i === nothing ? nothing : ROWS[i]
end

function build_polarity()
    out = Polarity[]
    for p in SPEC["polarity"]
        n  = Int(p["n"])
        pk = String(p["positive"]); nk = String(p["negative"])
        pr = find_row(pk, n); nr = find_row(nk, n)
        if pr === nothing || nr === nothing
            @warn "polarity pair absent from the measurements; the script skips it" relation=p["relation"] n=n
            continue
        end
        ratio = nr.min_seconds / pr.min_seconds
        dir = ratio > BALANCED_BAND ? "negative_slower" :
              ratio < 1 / BALANCED_BAND ? "negative_faster" : "balanced"
        push!(out, Polarity(String(p["relation"]), n, pk, nk,
                            pr.min_seconds, nr.min_seconds, ratio,
                            pr.bytes, nr.bytes,
                            nr.bytes / max(pr.bytes, 1),
                            String(p["expectation"]), dir,
                            dir == String(p["expectation"]),
                            pr.note, nr.note,
                            strip(String(p["mechanism"]))))
    end
    return out
end

# ── crossing 3: time x allocated bytes ──────────────────────────────────────

const MEMCFG = SPEC["memory"]
const MACHINE_BYTES = parse(Float64, get(META, "bmMetaMemoryGB", "0")) * 2^30

struct Mem
    group::String
    case::String
    n::Int
    seconds::Float64
    bytes::Int
    gib::Float64
    rate::Float64           # allocated bytes per second
    share::Float64          # share of the memory of the machine
    marked::Bool
end

function build_memory()
    out = Mem[]
    for r in ROWS
        gib = r.bytes / 2^30
        share = MACHINE_BYTES > 0 ? r.bytes / MACHINE_BYTES : 0.0
        push!(out, Mem(r.group, r.case, r.n, r.min_seconds, r.bytes, gib,
                       r.bytes / r.min_seconds, share,
                       share >= Float64(MEMCFG["mark_fraction_of_machine"])))
    end
    return sort!(out; by = m -> -m.bytes)
end

# ── the external check of an extrapolation ──────────────────────────────────

struct Check
    case::String
    n::Int
    predicted::Float64
    measured::Float64
    ratio::Float64
    source::String
    note::String
end

function build_checks(gs::Vector{Growth})
    out = Check[]
    for c in get(SPEC, "extrapolation_check", Any[])
        k = String(c["case"])
        i = findfirst(g -> g.case == k, gs)
        if i === nothing
            @warn "no fitted series for an extrapolation check" case=k
            continue
        end
        rs = series(k)
        xs = Float64[r.n for r in rs]
        ys = Float64[log2(r.min_seconds) for r in rs]
        f  = fit_line(xs, ys)
        n  = Int(c["n"])
        pred = 2.0^(f.intercept + f.slope * n)
        meas = Float64(c["measured_seconds"])
        push!(out, Check(k, n, pred, meas, pred / meas,
                         String(c["source"]), strip(String(c["note"]))))
    end
    return out
end

# ── LaTeX helpers ───────────────────────────────────────────────────────────
#
# These repeat data/perf/archive/source/export.jl, so a command that this script writes matches the
# style of a command that the suite writes.

const TEX_SPECIAL = Dict('\\' => "\\textbackslash{}", '{' => "\\{", '}' => "\\}",
                         '#' => "\\#", '$' => "\\\$", '%' => "\\%", '&' => "\\&",
                         '_' => "\\_", '~' => "\\textasciitilde{}",
                         '^' => "\\textasciicircum{}")

function tex_escape(s::AbstractString)
    io = IOBuffer()
    for c in s
        print(io, get(TEX_SPECIAL, c, c))
    end
    return String(take!(io))
end

function fmt_sci(x::Float64)
    (x == 0 || !isfinite(x)) && return raw"$0$"
    e = floor(Int, log10(abs(x)))
    return @sprintf("\$%.2f\\times10^{%d}\$", x / 10.0^e, e)
end

"Format a ratio: plain when it is near one, in maths when it is not."
fmt_ratio(x::Float64) = (0.01 <= x <= 100) ? @sprintf("%.2f", x) : fmt_sci(x)

const DIGIT_WORDS = ["Zero", "One", "Two", "Three", "Four",
                     "Five", "Six", "Seven", "Eight", "Nine"]

"Build a LaTeX control sequence from a case name. A control sequence takes
letters only, so every digit becomes a word."
function macroize(s::AbstractString)
    raw = replace(s, "!" => "_bang")
    parts = split(raw, r"[^A-Za-z0-9]+"; keepempty = false)
    body = join(uppercasefirst(String(p)) for p in parts)
    return replace(body, r"[0-9]" => c -> DIGIT_WORDS[parse(Int, c) + 1])
end

const STAMP = """
% Machine: $(get(META, "bmMetaCPU", "unknown")), $(get(META, "bmMetaCores", "?")) cores, \
$(get(META, "bmMetaThreads", "?")) Julia thread(s), $(get(META, "bmMetaMemoryGB", "?")) GB.
% Julia $(get(META, "bmMetaJulia", "?")); measured $(get(META, "bmMetaDate", "?")) \
at level $(get(META, "bmMetaLevel", "?")); statistic: the minimum of N repetitions.
"""

function header(io::IO, what::AbstractString; comment::Char = '%')
    c = string(comment)
    println(io, c, " !!! GENERATED FILE — DO NOT EDIT !!!")
    println(io, c, " ", what)
    println(io, c, " Produced by packages/VBFWorkingPaper/src/analysis/performance/crossings.jl from ", relpath(OPTS.csv, ROOT),
            " and ", relpath(OPTS.spec, ROOT), ".")
    println(io, c, " Regenerate with:  make -C bench crossings")
    for line in split(rstrip(STAMP), '\n')
        println(io, c, replace(line, r"^%" => ""))
    end
end

# ── writers: crossing 1 ─────────────────────────────────────────────────────

function write_growth_csv(path, gs::Vector{Growth}, un)
    open(path, "w") do io
        println(io, "case,size_kind,model,points,n_min,n_max,seconds_at_n_min,seconds_at_n_max," *
                    "slope,predicted_slope,prediction_kind,delta,r2,max_residual_bits," *
                    "pair_slope_min,pair_slope_max,bytes_slope,verdict," *
                    "reach_n_time,reach_n_bytes,binding,basis,source,caveat")
        for g in gs
            @printf(io, "%s,%s,%s,%d,%d,%d,%.6g,%.6g,%.4f,%.4f,%s,%+.4f,%.4f,%.4f,%.4f,%.4f,%.4f,\"%s\",%s,%s,%s,\"%s\",%s,\"%s\"\n",
                    g.case, g.kind, g.model, g.points, g.nmin, g.nmax,
                    g.tmin, g.tmax, g.slope, g.predicted, g.predkind, g.delta,
                    g.r2, g.maxres, g.plo, g.phi, g.bslope, g.verdict,
                    g.reach_time < 0 ? "" :
                        (g.capped_time ? ">" : "") * string(g.reach_time),
                    g.reach_bytes < 0 ? "" :
                        (g.capped_bytes ? ">" : "") * string(g.reach_bytes),
                    g.binding, g.basis, g.source, g.caveat)
        end
    end
    return path
end

function write_growth_table(path, gs::Vector{Growth}, checks::Vector{Check})
    open(path, "w") do io
        header(io, "Crossing 1: measured growth against the predicted exponent.")
        println(io, "\\begin{tabular}{llrrrl}")
        println(io, "\\toprule")
        println(io, "Operation & \$n\$ & Measured & Predicted & \$\\Delta\$ & Verdict \\\\")
        println(io, "\\midrule")
        println(io, "\\multicolumn{6}{l}{\\emph{Exponential model: time \$\\sim 2^{cn}\$; the columns give \$c\$ in bits per unit of \$n\$}} \\\\")
        exps = filter(g -> g.model == "exponential", gs)
        pows = filter(g -> g.model == "power_law", gs)
        for g in exps
            @printf(io, "\\texttt{%s} & %d--%d & %.2f & %s%.2f & %+.2f & %s \\\\\n",
                    tex_escape(g.case), g.nmin, g.nmax, g.slope,
                    g.predkind == "lower_bound" ? "\$\\geq\$" : "", g.predicted,
                    g.delta, tex_escape(g.verdict))
        end
        if !isempty(pows)
            println(io, "\\midrule")
            println(io, "\\multicolumn{6}{l}{\\emph{Power-law model: time \$\\sim n^{c}\$; \$n\$ is a matrix side, not a width}} \\\\")
            for g in pows
                @printf(io, "\\texttt{%s} & %d--%d & %.2f & %.2f & %+.2f & %s \\\\\n",
                        tex_escape(g.case), g.nmin, g.nmax, g.slope,
                        g.predicted, g.delta, tex_escape(g.verdict))
            end
        end
        println(io, "\\bottomrule")
        println(io, "\\end{tabular}")
        for c in checks
            println(io, "% external check: ", c.case, " at n=", c.n,
                    ": the fit gives ", @sprintf("%.1f s", c.predicted),
                    ", another instrument measured ", @sprintf("%.1f s", c.measured),
                    " (ratio ", @sprintf("%.2f", c.ratio), "); source ", c.source)
        end
    end
    return path
end

function write_growth_dat(path, gs::Vector{Growth})
    open(path, "w") do io
        header(io, "Crossing 1: one line per measured point of every fitted series.")
        println(io, "% Filter one series in pgfplots with, for example,")
        println(io, "%   \\addplot table[x=n, y=seconds, discard if not={caseid}{3}] {crossing_growth.dat};")
        for (i, g) in enumerate(gs)
            println(io, "% caseid ", i, " = ", g.case, "  (", g.model, ")")
        end
        println(io, "caseid n seconds bytes")
        for (i, g) in enumerate(gs)
            for r in series(g.case)
                @printf(io, "%d %d %.9g %d\n", i, r.n, r.min_seconds, r.bytes)
            end
        end
    end
    return path
end

"""
    write_reach_table(path, gs)

Crossings 1 and 4 together. The growth of the time and the growth of the
allocation each give a largest reachable `n`, and the smaller of the two is the
one that stops the operation. This is the table that a reader who plans a run
needs.
"""
function write_reach_table(path, gs::Vector{Growth})
    rows = filter(g -> g.reach_time >= 0, gs)
    bound(v, capped) = capped ? @sprintf("\$>%d\$", v) : string(v)
    open(path, "w") do io
        header(io, "Crossings 1 and 4: the largest n that one hour and 4 GiB reach.")
        @printf(io, "%% Ceilings: %.0f s of one core, %.0f GiB allocated. Both come from packages/VBFWorkingPaper/doc/performance/crossings.toml.\n",
                T_CEILING, B_CEILING / 2^30)
        println(io, "% A bound \$>n\$ means the ceiling lies past the extrapolation cap of the fit.")
        println(io, "\\begin{tabular}{lrrrl}")
        println(io, "\\toprule")
        println(io, "Operation & Measured \$n\$ & \$n\$ under 1\\,h & \$n\$ under 4\\,GiB & Stops for \\\\")
        println(io, "\\midrule")
        for g in rows
            @printf(io, "\\texttt{%s} & %d--%d & %s & %s & %s \\\\\n",
                    tex_escape(g.case), g.nmin, g.nmax,
                    bound(g.reach_time, g.capped_time),
                    bound(g.reach_bytes, g.capped_bytes),
                    g.binding == "time" ? "time" :
                    g.binding == "memory" ? "memory" :
                    g.binding == "both" ? "both at once" : "---")
        end
        println(io, "\\bottomrule")
        println(io, "\\end{tabular}")
        println(io, "% CAUTION: the allocation column counts what one call allocates in total.")
        println(io, "% It is not the peak resident memory. See [memory] in packages/VBFWorkingPaper/doc/performance/crossings.toml.")
    end
    return path
end

# ── writers: crossing 2 ─────────────────────────────────────────────────────

function write_polarity_csv(path, ps::Vector{Polarity})
    open(path, "w") do io
        println(io, "relation,n,positive_case,negative_case,positive_seconds,negative_seconds," *
                    "ratio_seconds,positive_bytes,negative_bytes,ratio_bytes," *
                    "expectation,direction,agrees,positive_note,negative_note")
        for p in ps
            @printf(io, "%s,%d,%s,%s,%.6g,%.6g,%.4g,%d,%d,%.4g,%s,%s,%s,\"%s\",\"%s\"\n",
                    p.relation, p.n, p.poscase, p.negcase, p.pos, p.neg, p.ratio,
                    p.posbytes, p.negbytes, p.bratio, p.expectation, p.direction,
                    p.agrees ? "yes" : "no", p.posnote, p.negnote)
        end
    end
    return path
end

function write_polarity_table(path, ps::Vector{Polarity})
    open(path, "w") do io
        header(io, "Crossing 2: the asymmetry between the two answers of a decision procedure.")
        println(io, "\\begin{tabular}{llrrrl}")
        println(io, "\\toprule")
        println(io, "Relation & \$n\$ & Yes (s) & No (s) & No/Yes & Faster answer \\\\")
        println(io, "\\midrule")
        for p in ps
            label = p.direction == "negative_faster" ? "no" :
                    p.direction == "negative_slower" ? "yes" : "neither"
            @printf(io, "%s & %d & %s & %s & %s & %s \\\\\n",
                    tex_escape(p.relation), p.n, fmt_sci(p.pos), fmt_sci(p.neg),
                    p.ratio >= 100 || p.ratio <= 0.01 ?
                        @sprintf("\$%.1f\\times10^{%d}\$",
                                 p.ratio / 10.0^floor(Int, log10(p.ratio)),
                                 floor(Int, log10(p.ratio))) :
                        @sprintf("%.2f", p.ratio),
                    label)
        end
        println(io, "\\bottomrule")
        println(io, "\\end{tabular}")
        for p in ps
            println(io, "% ", p.relation, " n=", p.n, ": expected ", p.expectation,
                    ", measured ", p.direction, " -> ", p.agrees ? "agrees" : "DISAGREES")
        end
    end
    return path
end

# ── writers: crossing 3 ─────────────────────────────────────────────────────

function write_memory_csv(path, ms::Vector{Mem})
    open(path, "w") do io
        println(io, "group,case,n,seconds,bytes,gib,bytes_per_second,share_of_machine,marked")
        for m in ms
            @printf(io, "%s,%s,%d,%.6g,%d,%.6g,%.6g,%.6g,%s\n",
                    m.group, m.case, m.n, m.seconds, m.bytes, m.gib, m.rate,
                    m.share, m.marked ? "yes" : "no")
        end
    end
    return path
end

function write_memory_table(path, ms::Vector{Mem})
    k = min(Int(MEMCFG["table_rows"]), length(ms))
    open(path, "w") do io
        header(io, "Crossing 3: the cases that allocate the most, and what they cost in time.")
        println(io, "\\begin{tabular}{llrrrr}")
        println(io, "\\toprule")
        println(io, "Group & Operation & \$n\$ & min (s) & Allocated (GiB) & GiB/s \\\\")
        println(io, "\\midrule")
        for m in ms[1:k]
            @printf(io, "%s & \\texttt{%s} & %d & %s & %.3f & %.2f \\\\\n",
                    tex_escape(m.group), tex_escape(m.case), m.n,
                    fmt_sci(m.seconds), m.gib, m.rate / 2^30)
        end
        println(io, "\\bottomrule")
        println(io, "\\end{tabular}")
    end
    return path
end

function write_memory_dat(path, ms::Vector{Mem})
    groups = sort!(unique(m.group for m in ms))
    idx = Dict(g => i for (i, g) in enumerate(groups))
    open(path, "w") do io
        header(io, "Crossing 3: one line per case. Plot bytes against seconds on log axes.")
        for g in groups
            println(io, "% groupid ", idx[g], " = ", g)
        end
        zero = count(m -> m.bytes == 0, ms)
        @printf(io, "%% %d case(s) allocate nothing and carry bytes = 0. A log axis cannot hold them;\n", zero)
        println(io, "% filter them with  y filter/.expression={\\thisrow{bytes}>0 ? \\thisrow{bytes} : nan}.")
        println(io, "groupid seconds bytes n")
        for m in ms
            @printf(io, "%d %.9g %d %d\n", idx[m.group], m.seconds, m.bytes, m.n)
        end
    end
    return path
end

# ── writers: the facts ──────────────────────────────────────────────────────

function write_facts(path, gs::Vector{Growth}, ps::Vector{Polarity},
                     ms::Vector{Mem}, checks::Vector{Check}, un)
    conclusive = filter(g -> !startswith(g.verdict, "inconclusive"), gs)
    confirms   = filter(g -> startswith(g.verdict, "confirms"), conclusive)
    heavy      = ms[1]
    above1gib  = count(m -> m.gib >= 1.0, ms)
    open(path, "w") do io
        header(io, "One command per figure that the prose of the article quotes.")
        # crossing 1
        @printf(io, "\\newcommand{\\bmxGrowthSeries}{%d}\n", length(gs))
        @printf(io, "\\newcommand{\\bmxGrowthConclusive}{%d}\n", length(conclusive))
        @printf(io, "\\newcommand{\\bmxGrowthConfirms}{%d}\n", length(confirms))
        @printf(io, "\\newcommand{\\bmxGrowthUnmodelled}{%d}\n", length(un))
        for (i, g) in enumerate(gs)
            nm = macroize(g.case)
            # The figure filters crossing_growth.dat on this number. It must
            # come from the script, or an edit to the spec would silently move
            # a curve.
            @printf(io, "\\newcommand{\\bmxCaseid%s}{%d}\n", nm, i)
            @printf(io, "\\newcommand{\\bmxSlope%s}{%.2f}\n", nm, g.slope)
            @printf(io, "\\newcommand{\\bmxPredicted%s}{%.2f}\n", nm, g.predicted)
            # A capped reach is a bound and not a figure. The article must not
            # quote it as one, so the script does not define a command for it.
            if g.reach_time >= 0 && !g.capped_time
                @printf(io, "\\newcommand{\\bmxReachTime%s}{%d}\n", nm, g.reach_time)
            end
            if g.reach_bytes >= 0 && !g.capped_bytes
                @printf(io, "\\newcommand{\\bmxReachBytes%s}{%d}\n", nm, g.reach_bytes)
            end
        end
        # the external checks
        for c in checks
            nm = macroize(c.case) * "N" *
                 join(DIGIT_WORDS[d + 1] for d in reverse(digits(c.n; pad = 1)))
            @printf(io, "\\newcommand{\\bmxCheck%sFit}{%.1f}\n", nm, c.predicted)
            @printf(io, "\\newcommand{\\bmxCheck%sMeasured}{%.1f}\n", nm, c.measured)
            @printf(io, "\\newcommand{\\bmxCheck%sRatio}{%.2f}\n", nm, c.ratio)
        end
        # crossing 2
        @printf(io, "\\newcommand{\\bmxPolarityPairs}{%d}\n", length(ps))
        if !isempty(ps)
            top = ps[argmax([max(p.ratio, 1 / p.ratio) for p in ps])]
            @printf(io, "\\newcommand{\\bmxPolarityWidestRelation}{%s}\n",
                    tex_escape(top.relation))
            @printf(io, "\\newcommand{\\bmxPolarityWidestFactor}{%s}\n",
                    fmt_ratio(max(top.ratio, 1 / top.ratio)))
            @printf(io, "\\newcommand{\\bmxPolarityWidestN}{%d}\n", top.n)
        end
        for p in ps
            nm = macroize(p.relation)
            @printf(io, "\\newcommand{\\bmxPolarity%sRatio}{%s}\n", nm,
                    fmt_ratio(p.ratio))
        end
        # crossing 3
        @printf(io, "\\newcommand{\\bmxMemHeaviestCase}{\\texttt{%s}}\n",
                tex_escape(heavy.group * "/" * heavy.case))
        @printf(io, "\\newcommand{\\bmxMemHeaviestGiB}{%.2f}\n", heavy.gib)
        @printf(io, "\\newcommand{\\bmxMemHeaviestN}{%d}\n", heavy.n)
        @printf(io, "\\newcommand{\\bmxMemAboveOneGiB}{%d}\n", above1gib)
        @printf(io, "\\newcommand{\\bmxMemMachineGB}{%.1f}\n", MACHINE_BYTES / 2^30)
        # The allocation rate separates a case that waits for memory from a case
        # that waits for arithmetic. A small allocation stays in cache and
        # reaches a much higher rate than a large one, so the two figures below
        # are reported apart.
        fast = argmax(m -> m.rate, ms)
        large = filter(m -> m.gib >= 1.0, ms)
        @printf(io, "\\newcommand{\\bmxMemRateMaxGiB}{%.1f}\n", fast.rate / 2^30)
        @printf(io, "\\newcommand{\\bmxMemRateMaxCase}{\\texttt{%s}}\n",
                tex_escape(fast.group * "/" * fast.case))
        if !isempty(large)
            @printf(io, "\\newcommand{\\bmxMemRateLargeMaxGiB}{%.2f}\n",
                    maximum(m.rate for m in large) / 2^30)
        end
        # The scatter filters crossing_memory.dat on these numbers.
        for (i, g) in enumerate(sort!(unique(m.group for m in ms)))
            @printf(io, "\\newcommand{\\bmxGroupid%s}{%d}\n", macroize(g), i)
        end
    end
    return path
end

# ── provenance ──────────────────────────────────────────────────────────────
#
# The three CSV files hold data only, so everything that a reader needs to
# interpret them lives here: the machine, the units, the cases that carry no
# prediction, the cases that the spec excludes, and the external checks.

function write_provenance(path, gs::Vector{Growth}, ps::Vector{Polarity},
                          ms::Vector{Mem}, checks::Vector{Check}, un)
    open(path, "w") do io
        println(io, "# Provenance of the benchmark crossings\n")
        println(io, "Do not edit. Rebuild with `make -C bench crossings`.")
        println(io, "`packages/VBFWorkingPaper/src/analysis/performance/README.md` explains each crossing.\n")
        println(io, "| Field | Value |")
        println(io, "|---|---|")
        println(io, "| Measurements | `", relpath(OPTS.csv, ROOT), "` |")
        println(io, "| Predictions | `", relpath(OPTS.spec, ROOT), "` |")
        println(io, "| Machine | ", get(META, "bmMetaCPU", "unknown"), ", ",
                get(META, "bmMetaCores", "?"), " cores, ",
                get(META, "bmMetaThreads", "?"), " Julia thread(s), ",
                get(META, "bmMetaMemoryGB", "?"), " GB |")
        println(io, "| Julia | ", get(META, "bmMetaJulia", "?"), " |")
        println(io, "| Measured | ", get(META, "bmMetaDate", "?"),
                ", level ", get(META, "bmMetaLevel", "?"), " |")
        println(io, "| Statistic | the minimum of N repetitions after one warm-up call |")

        println(io, "\n## `crossing_growth.csv`\n")
        println(io, "- `model = exponential`: the slope is bits of time for each unit of `n`, so time ~ 2^(slope*n).")
        println(io, "- `model = power_law`: the slope is the exponent `c` in time ~ n^c, and `n` is a matrix side.")
        println(io, "- `reach_n_time` and `reach_n_bytes` give the largest `n` under the ceilings of `packages/VBFWorkingPaper/doc/performance/crossings.toml`.")
        println(io, "- A reach that starts with `>` is a bound: the ceiling lies past the extrapolation cap of the fit.")
        println(io, "- `verdict` reads `inconclusive` when the fastest point is under one microsecond, and `(curved fit)` when the straight line misses a point by more than half a bit.\n")
        if isempty(un)
            println(io, "Every case with three or more points carries a prediction.\n")
        else
            println(io, "**Unmodelled cases.** These have enough points and no prediction. Add a `[[growth]]` block for each one, or exclude it with a reason.\n")
            println(io, "| Case | Points |")
            println(io, "|---|---|")
            for (k, c) in un
                println(io, "| `", k, "` | ", c, " |")
            end
            println(io)
        end
        if !isempty(EXCLUDED)
            println(io, "**Excluded series.**\n")
            for (k, why) in sort!(collect(EXCLUDED))
                println(io, "- `", k, "` — ", replace(strip(why), "\n" => " "))
            end
            println(io)
        end
        if !isempty(checks)
            println(io, "**External checks of an extrapolation.**\n")
            println(io, "| Case | n | Fit (s) | Measured (s) | Ratio | Source |")
            println(io, "|---|---|---|---|---|---|")
            for c in checks
                @printf(io, "| `%s` | %d | %.1f | %.1f | %.2f | %s |\n",
                        c.case, c.n, c.predicted, c.measured, c.ratio, c.source)
            end
            println(io)
        end

        println(io, "## `crossing_polarity.csv`\n")
        println(io, "`ratio_seconds` and `ratio_bytes` are the negative side over the positive side.")
        println(io, "`direction` names the faster answer; `agrees` says whether it met the expectation of the spec.\n")

        println(io, "## `crossing_memory.csv`\n")
        println(io, "CAUTION: `bytes` comes from `@allocated`. It is the total that one call")
        println(io, "allocates, and it is NOT the peak resident memory. A routine that allocates")
        println(io, "2 GB in small pieces can run inside a much smaller resident set.\n")
        @printf(io, "- Machine memory: %.1f GB.\n", MACHINE_BYTES / 2^30)
        @printf(io, "- Cases that allocate at least 1 GiB: %d of %d.\n",
                count(m -> m.gib >= 1.0, ms), length(ms))
        @printf(io, "- Highest allocation rate among those: %.2f GiB/s.\n",
                isempty(filter(m -> m.gib >= 1.0, ms)) ? 0.0 :
                maximum(m.rate for m in ms if m.gib >= 1.0) / 2^30)
    end
    return path
end

# ── run ─────────────────────────────────────────────────────────────────────

const GROWTH   = build_growth()
const UNMODEL  = unmodelled(GROWTH)
const POLARITY = build_polarity()
const MEMORY   = build_memory()
const CHECKS   = build_checks(GROWTH)

mkpath(OPTS.out)
const PATHS = [
    write_growth_csv(joinpath(OPTS.out, "crossing_growth.csv"), GROWTH, UNMODEL),
    write_growth_table(joinpath(OPTS.out, "crossing_growth_table.tex"), GROWTH, CHECKS),
    write_growth_dat(joinpath(OPTS.out, "crossing_growth.dat"), GROWTH),
    write_reach_table(joinpath(OPTS.out, "crossing_reach_table.tex"), GROWTH),
    write_polarity_csv(joinpath(OPTS.out, "crossing_polarity.csv"), POLARITY),
    write_polarity_table(joinpath(OPTS.out, "crossing_polarity_table.tex"), POLARITY),
    write_memory_csv(joinpath(OPTS.out, "crossing_memory.csv"), MEMORY),
    write_memory_table(joinpath(OPTS.out, "crossing_memory_table.tex"), MEMORY),
    write_memory_dat(joinpath(OPTS.out, "crossing_memory.dat"), MEMORY),
    write_facts(joinpath(OPTS.out, "crossings_facts.tex"), GROWTH, POLARITY,
                MEMORY, CHECKS, UNMODEL),
    write_provenance(joinpath(OPTS.out, "CROSSINGS.md"), GROWTH, POLARITY,
                     MEMORY, CHECKS, UNMODEL),
]

println("VBF benchmark crossings")
println("  measurements ", relpath(OPTS.csv, ROOT), "  (", length(ROWS), " rows, level ",
        get(META, "bmMetaLevel", "?"), ")")
println("  predictions  ", relpath(OPTS.spec, ROOT))
println()

println("crossing 1 — growth against the predicted exponent")
@printf("  %-46s %6s %8s %8s  %s\n", "CASE", "n", "SLOPE", "PRED", "VERDICT")
for g in GROWTH
    @printf("  %-46s %2d-%-3d %8.2f %8.2f  %s\n", g.case, g.nmin, g.nmax,
            g.slope, g.predicted, g.verdict)
end
for c in CHECKS
    @printf("  external check: %s at n=%d -> fit %.1f s, measured %.1f s, ratio %.2f\n",
            c.case, c.n, c.predicted, c.measured, c.ratio)
end
if !isempty(UNMODEL)
    println("  CAUTION: these cases have enough points and no prediction:")
    for (k, c) in UNMODEL
        @printf("    %-46s %d points\n", k, c)
    end
end
for (k, why) in sort!(collect(EXCLUDED))
    println("  excluded: ", k, " — ", first(split(why, '\n')))
end
println()

println("crossing 2 — the cost of a yes against the cost of a no")
@printf("  %-22s %3s %12s %12s %10s  %s\n", "RELATION", "n", "YES (s)", "NO (s)", "NO/YES", "EXPECTED?")
for p in POLARITY
    @printf("  %-22s %3d %12.3e %12.3e %10.4g  %s\n", p.relation, p.n, p.pos,
            p.neg, p.ratio, p.agrees ? "yes" : "NO — " * p.direction)
end
println()

println("crossing 3 — allocated bytes against time")
@printf("  machine memory %.1f GB; %d cases allocate at least 1 GiB\n",
        MACHINE_BYTES / 2^30, count(m -> m.gib >= 1.0, MEMORY))
@printf("  %-16s %-34s %4s %10s %10s\n", "GROUP", "CASE", "n", "SECONDS", "GiB")
for m in MEMORY[1:min(8, length(MEMORY))]
    @printf("  %-16s %-34s %4d %10.3e %10.3f\n", m.group, m.case, m.n, m.seconds, m.gib)
end
println()

println("crossings 1 and 4 — the largest n that one hour and 4 GiB reach")
@printf("  %-46s %10s %10s  %s\n", "CASE", "n <= 1h", "n <= 4GiB", "STOPS FOR")
for g in GROWTH
    g.reach_time < 0 && continue
    @printf("  %-46s %10s %10s  %s\n", g.case,
            (g.capped_time ? ">" : "") * string(g.reach_time),
            (g.capped_bytes ? ">" : "") * string(g.reach_bytes), g.binding)
end
println()

println("wrote:")
for p in PATHS
    println("  ", relpath(p, ROOT))
end
