# Implements shared constants, TSV input/output and report helpers
# Study: census of quadratic APN functions on F_2^8 (data/apn/archive/census)
#
# Pseudocode:
#   1. Store study constants (known-class counts, exact masses for small n).
#   2. Encode and decode the coefficient string of a pure quadratic function.
#   3. Read sample TSV files (files or directories) into log-weights and APN hits.
#   4. Compact form of sample files (manifest + hit rows, data/): write, read, verify.
#   5. Write machine-readable results under results/.
# VBF API used: SBox

using Dates
using Printf
using SHA
using Statistics
using TOML
using VBF


const STUDY_TITLE = "Number of CCZ classes of quadratic APN functions on F_2^8"
const STUDY_DIR = normpath(joinpath(@__DIR__,"../../../../data/apn/archive/census"))
const LEGACY_DIR = normpath(joinpath(@__DIR__, "../../../../packages/VBFRepro/papers/2025/Beierle_202508/results/class_count"))

# Known classes: lower bound of Beierle et al. (2025), Theorem 5.1.
const KNOWN_CLASSES = 3_808_491
# Sum of 2^8/|Aut| = sum of 1/|Stab| over the known classes, from the automorphism-group
# distribution of Beierle et al. (2025, v2), Table 5.2 (a)+(b).
const KNOWN_MASS = 3_799_974.1228
# Classes minus mass of the known classes. N >= mass + DELTA_KNOWN, because a class with
# |Stab| >= 2 contributes less than 1 to the mass.
const DELTA_KNOWN = KNOWN_CLASSES - KNOWN_MASS

# Exact masses sum_{classes} 1/|Stab| = sum 2^n/|Aut(F)| from the VBFCatalog CCZ class
# representatives (exact_masses.jl recomputes them; n = 7 takes about 20 minutes).
const EXACT_MASS = Dict(
    (4, 4) => 1 // 360,                     # 1 class, |Aut| = 5760
    (5, 5) => 2 // 155,                     # 2 classes (Gold x^3, x^5), |Aut| = 4960
    (6, 6) => 7 + 2 // 5 + 1 // 7 + 1 // 14 + 1 // 63 + 1 // 378,
    (7, 7) => 473 + 12 // 7 + 3 // 889,    # 488 classes
)

# Exact tree sizes T(n,m) (exact_count by DFS).
const EXACT_T = Dict((3, 3) => 168, (3, 4) => 2520, (3, 5) => 26040, (4, 4) => 1_128_960)

# Published results of the 4,012,000-sample run (s1.tsv + chunks c101..c140).
const PUBLISHED = (
    samples = 4_012_000,
    hits = 1661,
    mass = 5.464e6,
    mass_se = 1.58e5,
    coverage = 0.6770,
    coverage_se = 0.0133,
    n_cov = 5.621e6,
    n_cov_se = 1.1e5,
    new_sigma = 553,
)

# The 553 new classes of the legacy run (sigma_hash<TAB>coeffs, sorted by hash).
const NEW_CLASSES_FILE = joinpath(@__DIR__, "../../../../data/apn/archive/census/new_classes_553.tsv")
const NOVELTY_STATUS = "historical index absence; use VBFSearch validation against the source-rebuilt reference for current evidence"

function print_header(io::IO = stdout)
    println(io, "# Census: ", STUDY_TITLE)
    println(io, "# Knuth estimator of sum 1/|Stab| and sigma-index coverage")
    println(io)
end

function print_section(title::AbstractString, io::IO = stdout)
    println(io)
    println(io, "## ", title)
end

# --- coefficient strings -----------------------------------------------------------

"""
    encode_coeffs(C, n) -> String

Hex string of `C[a,b]` for `a < b` in row order, two hex digits each
(28 bytes = 56 characters for `n = 8`).
"""
encode_coeffs(C::Matrix{UInt16},n::Int) = VBF.QuadraticAPNTree.encode_coeffs(C,n)
decode_coeffs(coeffs::AbstractString,n::Int) = VBF.QuadraticAPNTree.decode_coeffs(coeffs,n)
sbox_from_coeffs(coeffs::AbstractString,n::Int) = SBox{n}(UInt8.(VBF.QuadraticAPNTree.lut(decode_coeffs(coeffs,n),n)))

# --- sample files --------------------------------------------------------------------

"""
    expand_paths(spec) -> Vector{String}

Expand a whitespace-separated list of files and directories. A directory contributes
its `*.tsv` files in sorted order.
"""
function expand_paths(spec::AbstractString)
    out = String[]
    for p in split(spec)
        if isdir(p)
            append!(out, sort([joinpath(p, f) for f in readdir(p) if endswith(f, ".tsv")]))
        elseif isfile(p)
            push!(out, String(p))
        else
            error("no such file or directory: $p")
        end
    end
    isempty(out) && error("no sample files in: $spec")
    out
end
expand_paths(v::AbstractVector) = expand_paths(join(v, ' '))

"""
    read_samples(paths) -> (lw, hits)

Read sample lines `i<TAB>logw<TAB>e<TAB>coeffs`. `lw[t] = logw + log(e)`, or `-Inf`
when `e == 0` (dead end or no APN completion). Every line stays in `lw`: the
estimator divides by the number of probes. `hits` lists `(t, coeffs)` for `e > 0`.
A path can also be a compact manifest (`*_chunks.tsv`, see [`compact_samples`](@ref)).
The compact form gives the same `lw` and `hits`, bit for bit.
"""
function read_samples(paths::AbstractVector{<:AbstractString})
    lw = Float64[]
    hits = Tuple{Int,String}[]
    for f in paths
        if is_manifest(f)
            _read_compact!(lw, hits, f)
            continue
        end
        for line in eachline(f)
            p = split(line, '\t')
            e = parse(Int, p[3])
            if e == 0
                push!(lw, -Inf)
            else
                push!(lw, parse(Float64, p[2]) + log(e))
                push!(hits, (length(lw), String(p[4])))
            end
        end
    end
    lw, hits
end

# --- compact sample data (data/) ----------------------------------------------------
#
# A failure (logw = -Inf or e = 0) has weight 0. Its only effect on every estimate is
# its position in the sample sequence. Thus a sample file is fully described by its
# number of lines and its hit lines (e > 0). The compact form has two files:
#   <name>_chunks.tsv  manifest, header MANIFEST_HEADER, one row per sample file:
#                      file, seed, samples, neg_inf (rows with logw = -Inf),
#                      zero_e (rows with e = 0, the -Inf rows included), hits, sha256.
#   <name>_hits.tsv    no header, one row per hit: file, seed, i, logw, e, coeffs.
#                      logw is the original text, so parse() gives the same Float64.

const DATA_DIR = joinpath(@__DIR__, "../../../../data/apn/archive/census/data")
const MANIFEST_HEADER = "file\tseed\tsamples\tneg_inf\tzero_e\thits\tsha256"

"True when `path` is a compact manifest (first line is `MANIFEST_HEADER`)."
function is_manifest(path::AbstractString)
    isfile(path) || return false
    open(path) do io
        eof(io) ? false : readline(io) == MANIFEST_HEADER
    end
end

"Path of the hits file of a manifest: `x_chunks.tsv` -> `x_hits.tsv`."
hits_path(manifest::AbstractString) = replace(manifest, r"_chunks\.tsv$" => "_hits.tsv")

"""
    read_manifest(path) -> Vector{NamedTuple}

Rows `(file, seed, samples, neg_inf, zero_e, hits, sha256)` of a compact manifest.
"""
function read_manifest(path::AbstractString)
    lines = readlines(path)
    first(lines) == MANIFEST_HEADER || error("not a compact manifest: $path")
    map(lines[2:end]) do l
        p = split(l, '\t')
        length(p) == 7 || error("bad manifest row in $path: $l")
        (file = String(p[1]), seed = parse(Int, p[2]), samples = parse(Int, p[3]),
         neg_inf = parse(Int, p[4]), zero_e = parse(Int, p[5]), hits = parse(Int, p[6]),
         sha256 = String(p[7]))
    end
end

"""
    read_hit_rows(path) -> Dict{String,Vector{NamedTuple}}

Hit rows `(seed, i, logw, e, coeffs)` of a compact hits file, grouped by file label
in file order. `logw` and `e` stay text.
"""
function read_hit_rows(path::AbstractString)
    out = Dict{String,Vector{NamedTuple{(:seed, :i, :logw, :e, :coeffs),
                                         Tuple{Int,Int,String,String,String}}}}()
    for l in eachline(path)
        p = split(l, '\t')
        length(p) == 6 || error("bad hit row in $path: $l")
        push!(get!(out, String(p[1]), []),
              (seed = parse(Int, p[2]), i = parse(Int, p[3]), logw = String(p[4]),
               e = String(p[5]), coeffs = String(p[6])))
    end
    out
end

function _read_compact!(lw::Vector{Float64}, hits::Vector{Tuple{Int,String}}, manifest)
    rows = read_manifest(manifest)
    hp = hits_path(manifest)
    isfile(hp) || error("hits file of $manifest not found: $hp")
    hr = read_hit_rows(hp)
    unknown = setdiff(keys(hr), [r.file for r in rows])
    isempty(unknown) || error("$hp has hits of files absent from $manifest: $(collect(unknown))")
    for r in rows
        off = length(lw)
        append!(lw, fill(-Inf, r.samples))
        h = get(hr, r.file, [])
        length(h) == r.hits || error("$(r.file): $(length(h)) hit rows, manifest says $(r.hits)")
        last_i = 0
        for x in h
            last_i < x.i <= r.samples || error("$(r.file): hit index $(x.i) out of order or range")
            last_i = x.i
            e = parse(Int, x.e)
            e > 0 || error("$(r.file): hit row $(x.i) has e = 0")
            lw[off + x.i] = parse(Float64, x.logw) + log(e)
            push!(hits, (off + x.i, x.coeffs))
        end
    end
    lw, hits
end

"File labels of `paths`: a manifest contributes its rows, a sample file its base name."
sample_labels(paths::AbstractVector{<:AbstractString}) =
    reduce(vcat, [is_manifest(f) ? [r.file for r in read_manifest(f)] : [basename(f)]
                  for f in paths]; init = String[])

"""
    scan_sample_file(path) -> NamedTuple

Counts, hit rows and SHA-256 of a full sample file. Checks the format: four fields,
`i` equal to the line number, `logw = -Inf` only with `e = 0`, coeffs only when `e > 0`.
"""
function scan_sample_file(path::AbstractString)
    samples = neg_inf = zero_e = 0
    hits = Tuple{Int,String,String,String}[]
    for line in eachline(path)
        samples += 1
        p = split(line, '\t')
        length(p) == 4 || error("$path:$samples: expected 4 fields")
        parse(Int, p[1]) == samples || error("$path:$samples: index $(p[1]) is not the line number")
        e = parse(Int, p[3])
        (e == 0) == isempty(p[4]) || error("$path:$samples: coeffs must be empty exactly when e = 0")
        if p[2] == "-Inf"
            neg_inf += 1
            e == 0 || error("$path:$samples: logw = -Inf with e > 0")
        end
        if e == 0
            zero_e += 1
        else
            push!(hits, (samples, String(p[2]), String(p[3]), String(p[4])))
        end
    end
    sha = bytes2hex(open(SHA.sha256, path))
    (samples = samples, neg_inf = neg_inf, zero_e = zero_e, hits = hits, sha256 = sha)
end

"""
    compact_samples(sources, manifest; write_hits = true) -> manifest

Write the compact form of the sample files `sources = [(label, path, seed), ...]`:
the manifest `manifest` (`*_chunks.tsv`) and, with `write_hits`, its hits file.
"""
function compact_samples(sources, manifest::AbstractString; write_hits::Bool = true,
                         io::IO = stdout)
    endswith(manifest, "_chunks.tsv") || throw(ArgumentError("manifest must end in _chunks.tsv"))
    mkpath(dirname(manifest))
    scans = [(label, seed, scan_sample_file(path)) for (label, path, seed) in sources]
    open(manifest, "w") do f
        println(f, MANIFEST_HEADER)
        for (label, seed, s) in scans
            println(f, join((label, seed, s.samples, s.neg_inf, s.zero_e, length(s.hits),
                             s.sha256), '\t'))
        end
    end
    if write_hits
        open(hits_path(manifest), "w") do f
            for (label, seed, s) in scans, (i, logw, e, coeffs) in s.hits
                println(f, join((label, seed, i, logw, e, coeffs), '\t'))
            end
        end
    end
    @printf(io, "wrote %s: %d files, %d samples, %d hits%s\n", manifest, length(scans),
            sum(s.samples for (_, _, s) in scans), sum(length(s.hits) for (_, _, s) in scans),
            write_hits ? " (+ $(basename(hits_path(manifest))))" : " (counts only)")
    manifest
end

"""
    compact_legacy(legacy_dir = LEGACY_DIR, out_dir = DATA_DIR)

Write `legacy_chunks.tsv` + `legacy_hits.tsv` (s1.tsv, chunks/c101..c140) and
`legacy_s77_chunks.tsv` (counts only; s77.tsv is too large for the repository).
Reads the legacy files only.
"""
function compact_legacy(legacy_dir::AbstractString = LEGACY_DIR,
                        out_dir::AbstractString = DATA_DIR; io::IO = stdout)
    src = [("s1.tsv", joinpath(legacy_dir, "s1.tsv"), 1)]
    cdir = joinpath(legacy_dir, "chunks")
    for f in sort(filter(f -> occursin(r"^c\d+\.tsv$", f), readdir(cdir)); by = f -> parse(Int, f[2:end-4]))
        push!(src, ("chunks/" * f, joinpath(cdir, f), parse(Int, f[2:end-4])))
    end
    compact_samples(src, joinpath(out_dir, "legacy_chunks.tsv"); io)
    s77 = joinpath(legacy_dir, "s77.tsv")
    isfile(s77) && compact_samples([("s77.tsv", s77, 7)], joinpath(out_dir, "legacy_s77_chunks.tsv");
                                   write_hits = false, io)
    nothing
end

"""
    verify_sample_file(path, manifest; seed, io) -> Bool

Compare a regenerated sample file with the manifest row of `seed`: counts, SHA-256 and,
when the hits file exists, every hit row (i, logw, e, coeffs).
"""
function verify_sample_file(path::AbstractString, manifest::AbstractString; seed::Int,
                            io::IO = stdout)
    rows = filter(r -> r.seed == seed, read_manifest(manifest))
    length(rows) == 1 || error("manifest $manifest has $(length(rows)) rows with seed $seed")
    r = only(rows)
    s = scan_sample_file(path)
    checks = Pair{String,Bool}[
        "samples" => s.samples == r.samples,
        "neg_inf" => s.neg_inf == r.neg_inf,
        "zero_e" => s.zero_e == r.zero_e,
        "hits" => length(s.hits) == r.hits,
    ]
    hp = hits_path(manifest)
    if isfile(hp)
        ref = [(x.i, x.logw, x.e, x.coeffs) for x in get(read_hit_rows(hp), r.file, [])]
        push!(checks, "hit rows" => s.hits == ref)
    end
    push!(checks, "sha256" => s.sha256 == r.sha256)
    println(io, "regenerated ", path)
    println(io, "reference   ", manifest, " row ", r.file, " (seed ", r.seed, ")")
    for (k, v) in checks
        @printf(io, "  %-9s %s\n", k, v ? "identical" : "DIFFERS")
    end
    @printf(io, "  counts: samples=%d neg_inf=%d zero_e=%d hits=%d (reference %d %d %d %d)\n",
            s.samples, s.neg_inf, s.zero_e, length(s.hits), r.samples, r.neg_inf, r.zero_e, r.hits)
    ok = all(last, checks)
    println(io, ok ? "verify_data: PASS (byte-identical)" : "verify_data: FAIL")
    ok
end

"""
    mass_estimate(lw, n, m; batches = 20) -> NamedTuple

Knuth estimate of `T(n,m) / (|GL(n,2)| |GL(m,2)|) = sum 1/|Stab|` with its standard
error, the batch-means check for heavy tails and the largest weight share.
"""
function mass_estimate(lw::AbstractVector{Float64}, n::Int, m::Int; batches::Int = 20)
    N = length(lw)
    N>=2 && batches>=2 && all(x->isfinite(x)||x==-Inf,lw) || throw(ArgumentError("expected at least two finite-or-dead weights and batches >= 2"))
    batches=min(batches,N)
    lg = Float64(log(VBF.QuadraticAPNTree.gl_order(n)) + log(VBF.QuadraticAPNTree.gl_order(m)))
    mx = maximum(lw)
    isfinite(mx) || return (samples = N, hits = 0, mass = 0.0, se = 0.0,
                            batch_se = 0.0, max_share = 0.0)
    w = exp.(lw .- mx)
    μ = mean(w)
    se = std(w) / sqrt(N)
    mass = exp(mx - lg) * μ
    semass = exp(mx - lg) * se
    bm = [exp(mx - lg) * mean(w[div((b-1)*N,batches)+1:div(b*N,batches)]) for b in 1:batches]
    (samples = N, hits = count(isfinite, lw), mass = mass, se = semass,
     batch_se = std(bm) / sqrt(batches), max_share = maximum(w) / sum(w))
end

# --- results -------------------------------------------------------------------------

function results_dir(sub::AbstractString = "")
    dir = joinpath(@__DIR__, "../../../../data/apn/runs/census", sub)
    mkpath(dir)
    dir
end

toml_safe(x::Bool) = x
toml_safe(x::Integer) = typemin(Int) <= x <= typemax(Int) ? Int(x) : string(x)
toml_safe(x::AbstractFloat) = isfinite(x) ? Float64(x) : string(x)
toml_safe(x::Rational) = string(numerator(x), "/", denominator(x))
toml_safe(x::AbstractString) = String(x)
toml_safe(x::Symbol) = String(x)
toml_safe(::Nothing) = "nothing"
toml_safe(x::AbstractVector) = Any[toml_safe(v) for v in x]
toml_safe(x::Tuple) = Any[toml_safe(v) for v in x]
toml_safe(x::NamedTuple) = Dict(String(k) => toml_safe(x[k]) for k in keys(x))
toml_safe(x::AbstractDict) = Dict(string(k) => toml_safe(v) for (k, v) in x)
toml_safe(x) = string(x)

function write_results_toml(data, filename::AbstractString)
    path = joinpath(results_dir(), filename)
    open(path, "w") do io
        TOML.print(io, toml_safe(data); sorted = true)
    end
    path
end
