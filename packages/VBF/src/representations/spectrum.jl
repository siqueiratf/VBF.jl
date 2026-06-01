"""
    Spectrum

Multiset histogram over integer values, used throughout BFA to summarise
distributions (differential spectrum, Walsh spectrum, boomerang spectrum,
ortho-derivative spectra, …).

Backed by `Dict{Int, Int}` (value → count). Equality is content-based;
iteration order is **unspecified**. For sorted output use [`sorted_pairs`](@ref).

# Constructors
- `Spectrum()`                  — empty.
- `Spectrum(values)`            — build from an iterable of values.
- `Spectrum(pairs::Dict)`       — adopt an existing dict.

# Mutation
- `add!(s, v)`        — increment count of `v` by 1.
- `add!(s, v, c)`     — increment count of `v` by `c`.
- `merge!(dst, src)`  — accumulate `src` into `dst`.

# Examples
```jldoctest
julia> using VBF

julia> s = Spectrum([2, 2, 4, 4, 4, 8]);

julia> sorted_pairs(s)
3-element Vector{Pair{Int64, Int64}}:
 2 => 2
 4 => 3
 8 => 1

julia> length(s)
3
```
"""
struct Spectrum
    counts::Dict{Int,Int}
end

Spectrum() = Spectrum(Dict{Int,Int}())

function Spectrum(values::AbstractVector{<:Integer})
    s = Spectrum()
    for v in values
        add!(s, v)
    end
    s
end

# --- mutation -----------------------------------------------------------------

"""
    add!(s::Spectrum, value::Integer, count::Integer=1) -> Spectrum

Increment `s[value]` by `count`. Returns `s` for chaining.
"""
function add!(s::Spectrum, value::Integer, count::Integer = 1)
    k = Int(value)
    c = Int(count)
    s.counts[k] = get(s.counts, k, 0) + c
    s
end

function Base.merge!(dst::Spectrum, src::Spectrum)
    for (k, c) in src.counts
        dst.counts[k] = get(dst.counts, k, 0) + c
    end
    dst
end

# --- introspection ------------------------------------------------------------

Base.length(s::Spectrum) = length(s.counts)
Base.isempty(s::Spectrum) = isempty(s.counts)

"""
    sorted_pairs(s::Spectrum) -> Vector{Pair{Int,Int}}

`(value => count)` pairs sorted by `value` ascending. Allocates a fresh
vector each call.
"""
sorted_pairs(s::Spectrum) = sort!(collect(s.counts), by = first)

"""
    total_mass(s::Spectrum) -> Int

Sum of all counts.
"""
total_mass(s::Spectrum) = sum(values(s.counts); init = 0)

Base.haskey(s::Spectrum, v::Integer) = haskey(s.counts, Int(v))
Base.getindex(s::Spectrum, v::Integer) = s.counts[Int(v)]
Base.get(s::Spectrum, v::Integer, default) = get(s.counts, Int(v), default)

# Iteration delegates to the underlying Dict — order unspecified.
Base.iterate(s::Spectrum, state...) = iterate(s.counts, state...)

# --- Base interface -----------------------------------------------------------

Base.:(==)(a::Spectrum, b::Spectrum) = a.counts == b.counts
Base.hash(s::Spectrum, h::UInt) = hash(s.counts, hash(:Spectrum, h))
Base.copy(s::Spectrum) = Spectrum(copy(s.counts))

function Base.show(io::IO, s::Spectrum)
    print(
        io,
        "Spectrum(",
        length(s),
        " distinct values, mass ",
        total_mass(s),
        ")",
    )
end

function Base.show(io::IO, ::MIME"text/plain", s::Spectrum)
    show(io, s)
    isempty(s) && return
    println(io)
    for (v, c) in sorted_pairs(s)
        println(io, "  ", v, " => ", c)
    end
end
