# Implements shared metadata and report helpers
# Paper: Beierle et al. (2025), "Millions of inequivalent quadratic APN functions in eight variables"
# Section: 2-5
#
# Pseudocode:
#   1. Store paper constants used by multiple experiment scripts.
#   2. Provide bounded report/result-writing helpers.
#   3. Provide small generic LUT utilities for non-square paper checks.
# VBF API used: SBox

using Dates
using TOML
using VBF

const PAPER_TITLE = "Millions of inequivalent quadratic APN functions in eight variables"
const PAPER_AUTHORS =
    "Christof Beierle, Philippe Langevin, Gregor Leander, Alexandr Polujan, Shahram Rasoolzadeh"
const PAPER_YEAR = 2025
const PAPER_DATE = "August 2025"
const ZENODO_RECORD = "https://zenodo.org/records/16752428"
const ZENODO_DOI = "https://doi.org/10.5281/zenodo.16752428"
const ZENODO_FILE = "new_apns.txt"
const ZENODO_FILE_BYTES = 3_400_000_000
const ZENODO_FILE_MD5 = "dd6ae0655ba8a299a3d668cfc6cf10bf"

const PRIOR_KNOWN_CLASSES = 32_892
const NEW_ZENODO_CLASSES = 3_775_599
const THEOREM_5_1_LOWER_BOUND = 3_808_491

const RANDOM_SEARCH_TOTAL = 92_955
const RANDOM_SEARCH_DISTINCT = 92_253
const SECTION41_KNOWN_OR_FOUND_CLASSES = 3_776_451
const RANDOM_SEARCH_NEW_OUTSIDE_SECTION41 = 32_286

function print_header(io::IO = stdout)
    println(io, "# Reproduction: Beierle et al. (2025)")
    println(io, "# \"", PAPER_TITLE, "\"")
    println(io)
end

function print_section(title::AbstractString, io::IO = stdout)
    println(io)
    println(io, "## ", title)
end

status_str(ok::Bool) = ok ? "PASS" : "FAIL"

function print_check(label::AbstractString, ok::Bool, io::IO = stdout)
    println(io, "  [", status_str(ok), "] ", label)
end

function print_kv(label::AbstractString, value, io::IO = stdout)
    println(io, "  ", label, ": ", value)
end

function completeness_label(exhaustive::Bool, evaluated::Integer, budget::Integer)
    exhaustive ? "exhaustive ($(evaluated) evaluated)" :
    "budget-limited ($(evaluated)/$(budget) evaluated)"
end

function paper_results_dir()
    dir = joinpath(@__DIR__, "results")
    mkpath(dir)
    dir
end

paper_results_path(filename::AbstractString) = joinpath(paper_results_dir(), filename)

toml_safe(x::Bool) = x
toml_safe(x::Integer) = typemin(Int) <= x <= typemax(Int) ? Int(x) : string(x)
toml_safe(x::AbstractFloat) = isfinite(x) ? Float64(x) : string(x)
toml_safe(x::AbstractString) = String(x)
toml_safe(x::Symbol) = String(x)
toml_safe(::Nothing) = "nothing"
toml_safe(x::AbstractVector) = Any[toml_safe(v) for v in x]
toml_safe(x::Tuple) = Any[toml_safe(v) for v in x]

function toml_safe(x::NamedTuple)
    Dict(String(k) => toml_safe(x[k]) for k in keys(x))
end

function toml_safe(x::AbstractDict)
    Dict(string(k) => toml_safe(v) for (k, v) in x)
end

toml_safe(x) = string(x)

function write_results_toml(data, filename::AbstractString)
    path = paper_results_path(filename)
    open(path, "w") do io
        TOML.print(io, toml_safe(data); sorted = true)
    end
    path
end

function generic_differential_uniformity(lut::AbstractVector{<:Integer}, nbits::Integer, output_bits::Integer)
    n = Int(nbits)
    m = Int(output_bits)
    size = 1 << n
    length(lut) == size || throw(ArgumentError("LUT length must be 2^$n"))
    counts = zeros(Int, 1 << m)
    best = 0
    @inbounds for a = 1:(size - 1)
        fill!(counts, 0)
        for x = 0:(size - 1)
            d = Int(lut[x + 1]) ⊻ Int(lut[(x ⊻ a) + 1])
            0 <= d < (1 << m) || throw(ArgumentError("output difference exceeds $m bits"))
            counts[d + 1] += 1
        end
        rowmax = maximum(counts)
        rowmax > best && (best = rowmax)
    end
    best
end

function linear_lut_from_columns(columns::AbstractVector{<:Integer}, nbits::Integer)
    n = Int(nbits)
    length(columns) == n || throw(ArgumentError("need $n column images"))
    lut = zeros(Int, 1 << n)
    @inbounds for x = 0:((1 << n) - 1)
        acc = 0
        for i = 0:(n - 1)
            ((x >> i) & 1) == 1 && (acc ⊻= Int(columns[i + 1]))
        end
        lut[x + 1] = acc
    end
    lut
end

function all_linear_luts(nbits::Integer, output_bits::Integer)
    n = Int(nbits)
    m = Int(output_bits)
    total = 1 << (n * m)
    out = Vector{Vector{Int}}(undef, total)
    for code = 0:(total - 1)
        columns = Vector{Int}(undef, n)
        tmp = code
        for i = 1:n
            columns[i] = tmp & ((1 << m) - 1)
            tmp >>= m
        end
        out[code + 1] = linear_lut_from_columns(columns, n)
    end
    out
end
