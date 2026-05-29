"""
    SBox{N, T<:Unsigned}

A vectorial Boolean function `F : F₂ᴺ → F₂ᴺ` stored as a lookup table.

# Type parameters
- `N`: number of input/output bits. Must satisfy `1 ≤ N ≤ 8*sizeof(T)`.
- `T`: storage word. `UInt8` covers `N ≤ 8`, `UInt16` covers `N ≤ 16`,
  `UInt32` covers `N ≤ 32`, `UInt64` covers `N ≤ 64`. Functions on
  `N > 64` bits use a different storage scheme (added in a later phase).

# Fields
- `lut::Vector{T}`: length `2^N`; `lut[x+1]` is `F(x)` for `x = 0,…,2^N-1`.

# Indexing convention
`s(x)` and `s[x]` both return `F(x)` using **0-based** input indexing,
matching the cryptographic literature. The underlying `lut` is 1-based
because Julia arrays are.

# Constructors
- `SBox{N,T}(lut::Vector{T})` — fully specified.
- `SBox{N}(lut)`              — `T` inferred as the smallest unsigned type ≥ `N` bits.
- `SBox(lut)`                 — `N` inferred as `log2(length(lut))`, `T` from `N`.

# Examples
```jldoctest
julia> using VBF

julia> id = SBox(UInt8[0, 1, 2, 3])
SBox{2, UInt8} (4-element LUT)

julia> id(2)
0x02
```
"""
struct SBox{N, T<:Unsigned}
    lut::Vector{T}

    function SBox{N, T}(lut::Vector{T}) where {N, T<:Unsigned}
        N isa Integer && N ≥ 1 ||
            throw(ArgumentError("SBox{N,T}: N must be a positive integer, got $N"))
        N ≤ 8 * sizeof(T) ||
            throw(ArgumentError(
                "SBox{$N, $T}: N=$N exceeds storage width 8*sizeof($T)=$(8 * sizeof(T))"))
        len = 1 << N
        length(lut) == len ||
            throw(ArgumentError(
                "SBox{$N, $T}: LUT must have length 2^$N = $len, got $(length(lut))"))
        # Range check: every entry must fit in N bits.
        N < 8 * sizeof(T) && (mask = T(len - 1); for (i, v) in pairs(lut)
            v & mask == v ||
                throw(ArgumentError(
                    "SBox{$N, $T}: lut[$i] = $v exceeds $N-bit range"))
        end)
        new{N, T}(lut)
    end
end

# --- inference constructors ---------------------------------------------------

"""
    _storage_for(N::Integer) -> Type{<:Unsigned}

Smallest unsigned type with at least `N` bits.
"""
function _storage_for(N::Integer)
    N ≤ 8  && return UInt8
    N ≤ 16 && return UInt16
    N ≤ 32 && return UInt32
    N ≤ 64 && return UInt64
    throw(ArgumentError("scalar SBox not supported for N=$N > 64; bit-packed storage lands in a later phase"))
end

SBox{N}(lut::AbstractVector{<:Integer}) where N =
    SBox{N, _storage_for(N)}(convert(Vector{_storage_for(N)}, lut))

function SBox(lut::AbstractVector{<:Integer})
    n = length(lut)
    n ≥ 1 || throw(ArgumentError("SBox: empty LUT"))
    N = trailing_zeros(n)
    1 << N == n || throw(ArgumentError("SBox: LUT length $n is not a power of 2"))
    SBox{N}(lut)
end

# --- accessors / introspection ------------------------------------------------

"""
    inputbits(s::SBox{N}) where N -> Int

Number of input (= output) bits of `s`.
"""
inputbits(::SBox{N}) where {N} = N::Int

"""
    storage_type(s::SBox{N,T}) where {N,T} -> Type{T}

Underlying unsigned-integer storage type of the LUT.
"""
storage_type(::SBox{N, T}) where {N, T} = T

# --- evaluation ---------------------------------------------------------------

@inline (s::SBox)(x::Integer) = s.lut[x + 1]
@inline Base.getindex(s::SBox, x::Integer) = s.lut[x + 1]

# --- Base interface -----------------------------------------------------------

Base.length(s::SBox{N}) where {N} = 1 << N
Base.size(s::SBox{N}) where {N} = (1 << N,)

Base.:(==)(a::SBox{N, T}, b::SBox{N, T}) where {N, T} = a.lut == b.lut
Base.:(==)(a::SBox{N}, b::SBox{N}) where {N} = a.lut == b.lut
Base.:(==)(::SBox, ::SBox) = false
Base.hash(s::SBox{N, T}, h::UInt) where {N, T} =
    hash(s.lut, hash((:SBox, N, T), h))

Base.copy(s::SBox{N, T}) where {N, T} = SBox{N, T}(copy(s.lut))

"""
    is_permutation(s::SBox) -> Bool

`true` iff the underlying LUT is a bijection of `F₂ᴺ`.
"""
function is_permutation(s::SBox{N, T}) where {N, T}
    n = 1 << N
    seen = falses(n)
    @inbounds for v in s.lut
        i = Int(v) + 1
        (i < 1 || i > n) && return false
        seen[i] && return false
        seen[i] = true
    end
    true
end

"""
    is_linear(s::SBox) -> Bool

`true` iff `s` is an F₂-linear function: `s(0) = 0` and
`s(x) ⊕ s(y) = s(x ⊕ y)` for all `x, y`.
"""
function is_linear(s::SBox{N, T}) where {N, T}
    s.lut[1] == 0 || return false
    n = 1 << N
    @inbounds for x in 0:n - 1
        sx = Int(s.lut[x + 1])
        for y in 0:n - 1
            (sx ⊻ Int(s.lut[y + 1])) == Int(s.lut[(x ⊻ y) + 1]) || return false
        end
    end
    true
end

"""
    inv(s::SBox) -> SBox

Functional inverse of `s`. Throws `ArgumentError` if `s` is not a
permutation.
"""
function Base.inv(s::SBox{N, T}) where {N, T}
    n = 1 << N
    inv_lut = zeros(T, n)
    seen = falses(n)
    @inbounds for x in 0:n - 1
        y = Int(s.lut[x + 1])
        seen[y + 1] &&
            throw(ArgumentError("inv(s::SBox): s is not a permutation"))
        inv_lut[y + 1] = T(x)
        seen[y + 1] = true
    end
    all(seen) ||
        throw(ArgumentError("inv(s::SBox): s is not a permutation"))
    SBox{N, T}(inv_lut)
end

function Base.show(io::IO, s::SBox{N, T}) where {N, T}
    print(io, "SBox{", N, ", ", T, "} (", 1 << N, "-element LUT)")
end

function Base.show(io::IO, ::MIME"text/plain", s::SBox{N, T}) where {N, T}
    show(io, s)
    println(io)
    n = 1 << N
    cols = N ≤ 4 ? n : min(16, n)
    for row_start in 0:cols:n-1
        print(io, "  ")
        for i in row_start:min(row_start + cols - 1, n - 1)
            print(io, lpad(repr(s.lut[i + 1]), 6), " ")
        end
        row_start + cols < n && println(io)
    end
end
