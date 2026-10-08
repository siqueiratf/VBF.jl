# Implements shared constants, TSV input/output and report helpers
# Study: census of quadratic APN functions on F_2^8 (census/quadratic_apn8)
#
# Pseudocode:
#   1. Store study constants (known-class counts, exact masses for small n).
#   2. Encode and decode the coefficient string of a pure quadratic function.
#   3. Read sample TSV files (files or directories) into log-weights and APN hits.
#   4. Write machine-readable results under results/.
# VBF API used: SBox

using Dates
using Printf
using Statistics
using TOML
using VBF

isdefined(@__MODULE__, :QK) || include(joinpath(@__DIR__, "qknuth.jl"))

const STUDY_TITLE = "Number of CCZ classes of quadratic APN functions on F_2^8"
const STUDY_DIR = @__DIR__
const LEGACY_DIR = normpath(joinpath(@__DIR__, "..", "..", "papers", "2025", "Beierle_202508",
                                     "results", "class_count"))

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
encode_coeffs(C::Matrix{UInt16}, n::Int) =
    join([string(C[a, b], base = 16, pad = 2) for a in 1:n for b in a + 1:n])

"""
    decode_coeffs(coeffs, n) -> Matrix{UInt16}

Inverse of [`encode_coeffs`](@ref): the symmetric coefficient matrix with zero diagonal.
"""
function decode_coeffs(coeffs::AbstractString, n::Int)
    npairs = n * (n - 1) ÷ 2
    length(coeffs) == 2npairs || throw(ArgumentError("expected $(2npairs) hex digits"))
    c = [parse(UInt16, coeffs[2k - 1:2k], base = 16) for k in 1:npairs]
    C = zeros(UInt16, n, n)
    t = 0
    for a in 1:n, b in a + 1:n
        t += 1
        C[a, b] = c[t]
        C[b, a] = c[t]
    end
    C
end

"`SBox{n}` of the pure quadratic function with coefficient string `coeffs` (m <= 8)."
sbox_from_coeffs(coeffs::AbstractString, n::Int) =
    SBox{n}(UInt8.(QK.lut(decode_coeffs(coeffs, n), n)))

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
"""
function read_samples(paths::AbstractVector{<:AbstractString})
    lw = Float64[]
    hits = Tuple{Int,String}[]
    for f in paths, line in eachline(f)
        p = split(line, '\t')
        e = parse(Int, p[3])
        if e == 0
            push!(lw, -Inf)
        else
            push!(lw, parse(Float64, p[2]) + log(e))
            push!(hits, (length(lw), String(p[4])))
        end
    end
    lw, hits
end

"""
    mass_estimate(lw, n, m; batches = 20) -> NamedTuple

Knuth estimate of `T(n,m) / (|GL(n,2)| |GL(m,2)|) = sum 1/|Stab|` with its standard
error, the batch-means check for heavy tails and the largest weight share.
"""
function mass_estimate(lw::AbstractVector{Float64}, n::Int, m::Int; batches::Int = 20)
    N = length(lw)
    lg = Float64(log(QK.gl_order(n)) + log(QK.gl_order(m)))
    mx = maximum(lw)
    isfinite(mx) || return (samples = N, hits = 0, mass = 0.0, se = 0.0,
                            batch_se = 0.0, max_share = 0.0)
    w = exp.(lw .- mx)
    μ = mean(w)
    se = std(w) / sqrt(N)
    mass = exp(mx - lg) * μ
    semass = exp(mx - lg) * se
    bs = div(N, batches)
    bm = [exp(mx - lg) * mean(w[(b - 1) * bs + 1:b * bs]) for b in 1:batches]
    (samples = N, hits = count(isfinite, lw), mass = mass, se = semass,
     batch_se = std(bm) / sqrt(batches), max_share = maximum(w) / sum(w))
end

# --- results -------------------------------------------------------------------------

function results_dir(sub::AbstractString = "")
    dir = joinpath(STUDY_DIR, "results", sub)
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
