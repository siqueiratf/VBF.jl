"""Truth tables for functions F₂ⁿ → F₂ᵐ, including square `SBox` tables."""
abstract type AbstractTruthTable{N,M} end

inputbits(::AbstractTruthTable{N,M}) where {N,M} = N::Int

"""Number of output coordinates of a binary truth table."""
outputbits(::AbstractTruthTable{N,M}) where {N,M} = M::Int

"""
    VBFTable{N,M}(lut)

A function F₂ⁿ → F₂ᵐ with independent input and output dimensions, as in
Kaleyski–Sunde (ePrint 2026/940). Mathematical indexing is zero-based.
Both dimensions are positive; output values must fit in `M` bits.
Native graph algorithms additionally require `N + M ≤ 32`.
"""
struct VBFTable{N,M,T<:Unsigned} <: AbstractTruthTable{N,M}
    lut::Vector{T}
    function VBFTable{N,M,T}(lut::Vector{T}) where {N,M,T<:Unsigned}
        N isa Int && 1 <= N < 8sizeof(Int)-1 || throw(ArgumentError("invalid input dimension"))
        M isa Int && 1 <= M <= 8sizeof(T) || throw(ArgumentError("invalid output dimension"))
        length(lut) == 1 << N || throw(ArgumentError("table must contain 2^N entries"))
        all(v -> M == 8sizeof(T) || v < T(1) << M, lut) ||
            throw(ArgumentError("output exceeds M-bit range"))
        new{N,M,T}(lut)
    end
end

function VBFTable{N,M}(lut::AbstractVector{<:Integer}) where {N,M}
    M isa Int && 1 <= M <= 64 || throw(ArgumentError("output dimension must be in 1:64"))
    all(v -> v >= 0 && big(v) < big(1) << M, lut) || throw(ArgumentError("output exceeds M-bit range"))
    T = _storage_for(M)
    return VBFTable{N,M,T}(T.(lut))
end

Base.length(F::VBFTable) = length(F.lut)
Base.size(F::VBFTable) = size(F.lut)
(F::VBFTable)(x::Integer) = F.lut[x+1]
Base.getindex(F::VBFTable, x::Integer) = F(x)
storage_type(::VBFTable{N,M,T}) where {N,M,T} = T
Base.copy(F::VBFTable{N,M,T}) where {N,M,T} = VBFTable{N,M,T}(copy(F.lut))
Base.:(==)(F::VBFTable{N,M}, G::VBFTable{N,M}) where {N,M} = F.lut == G.lut
Base.hash(F::VBFTable{N,M}, h::UInt) where {N,M} = hash((N,M,F.lut),h)

Base.:(==)(::VBFTable, ::VBFTable) = false
