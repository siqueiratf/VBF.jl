"""
    F2LinearMap{N, T<:Unsigned}

An F₂-linear map `L : F₂ᴺ → F₂ᴺ`, stored as the images of the standard
basis vectors.

# Type parameters
- `N`: input/output dimension.
- `T`: storage word; smallest unsigned type covering `N` bits.

# Fields
- `cols::Vector{T}`: length `N`; `cols[j+1]` is `L(eⱼ)` where `eⱼ` is the
  unit vector with bit `j` set.

For any input `x = ∑ⱼ xⱼ · 2ʲ`, `L(x) = ⊕ⱼ cols[j+1] · xⱼ`.

# Constructors
- `F2LinearMap{N,T}(cols)`     — fully specified.
- `F2LinearMap{N}(cols)`       — `T` inferred from `N`.
- `F2LinearMap(cols)`          — `N` inferred as `length(cols)`, `T` from `N`.

# Examples
```jldoctest
julia> using BFA

julia> identity_linear_map(4)
F2LinearMap{4, UInt8} (identity)

julia> L = F2LinearMap(UInt8[1, 2, 4, 8]);  L(0b1010)
0x0a
```
"""
struct F2LinearMap{N, T<:Unsigned}
    cols::Vector{T}

    function F2LinearMap{N, T}(cols::Vector{T}) where {N, T<:Unsigned}
        N isa Integer && N ≥ 1 ||
            throw(ArgumentError("F2LinearMap{N,T}: N must be a positive integer, got $N"))
        N ≤ 8 * sizeof(T) ||
            throw(ArgumentError(
                "F2LinearMap{$N, $T}: N=$N exceeds storage width 8*sizeof($T)=$(8 * sizeof(T))"))
        length(cols) == N ||
            throw(ArgumentError(
                "F2LinearMap{$N, $T}: cols must have length N=$N, got $(length(cols))"))
        if N < 8 * sizeof(T)
            mask = T((1 << N) - 1)
            for (i, v) in pairs(cols)
                v & mask == v ||
                    throw(ArgumentError(
                        "F2LinearMap{$N, $T}: cols[$i] = $v exceeds $N-bit range"))
            end
        end
        new{N, T}(cols)
    end
end

F2LinearMap{N}(cols::AbstractVector{<:Integer}) where {N} =
    F2LinearMap{N, _storage_for(N)}(convert(Vector{_storage_for(N)}, cols))

function F2LinearMap(cols::AbstractVector{<:Integer})
    N = length(cols)
    N ≥ 1 || throw(ArgumentError("F2LinearMap: empty cols"))
    F2LinearMap{N}(cols)
end

# --- canonical instances ------------------------------------------------------

"""
    identity_linear_map(N::Integer, T::Type=_storage_for(N))

Identity F₂-linear map of dimension `N`.
"""
function identity_linear_map(N::Integer, T::Type{<:Unsigned}=_storage_for(N))
    F2LinearMap{N, T}(T[T(1) << j for j in 0:N-1])
end

"""
    zero_linear_map(N::Integer, T::Type=_storage_for(N))

Zero map; sends everything to zero.
"""
zero_linear_map(N::Integer, T::Type{<:Unsigned}=_storage_for(N)) =
    F2LinearMap{N, T}(zeros(T, N))

# --- accessors ----------------------------------------------------------------

inputbits(::F2LinearMap{N}) where {N} = N::Int
storage_type(::F2LinearMap{N, T}) where {N, T} = T

# --- evaluation ---------------------------------------------------------------

@inline function (L::F2LinearMap{N, T})(x::Integer) where {N, T}
    y = zero(T)
    xs = T(x)
    @inbounds for j in 1:N
        ((xs >> (j - 1)) & T(1)) == T(1) && (y ⊻= L.cols[j])
    end
    y
end

# --- Base interface -----------------------------------------------------------

Base.:(==)(a::F2LinearMap{N, T}, b::F2LinearMap{N, T}) where {N, T} = a.cols == b.cols
Base.:(==)(a::F2LinearMap{N}, b::F2LinearMap{N}) where {N} = a.cols == b.cols
Base.:(==)(::F2LinearMap, ::F2LinearMap) = false

Base.hash(L::F2LinearMap{N, T}, h::UInt) where {N, T} =
    hash(L.cols, hash((:F2LinearMap, N, T), h))

Base.copy(L::F2LinearMap{N, T}) where {N, T} = F2LinearMap{N, T}(copy(L.cols))

function _is_identity(L::F2LinearMap{N, T}) where {N, T}
    @inbounds for j in 1:N
        L.cols[j] == (T(1) << (j - 1)) || return false
    end
    true
end

function Base.show(io::IO, L::F2LinearMap{N, T}) where {N, T}
    print(io, "F2LinearMap{", N, ", ", T, "}")
    _is_identity(L) && print(io, " (identity)")
end

function Base.show(io::IO, ::MIME"text/plain", L::F2LinearMap{N, T}) where {N, T}
    show(io, L)
    println(io)
    for j in 1:N
        println(io, "  e", j - 1, " ↦ ", repr(L.cols[j]))
    end
end
