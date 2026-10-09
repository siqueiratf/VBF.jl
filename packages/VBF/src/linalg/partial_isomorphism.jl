"""
Incremental GF(2) isomorphisms between subspaces.

Paired echelon bases propagate linear relations without enumerating the span.
Used by the affine search of Kaleyski and Sunde, *Efficiently deciding and
recovering CCZ and EA equivalence …*, ePrint 2026/940, Section 5:
https://eprint.iacr.org/2026/940.
"""

"""A partial injective linear map, with domain and image echelon bases."""
mutable struct _PartialF2Isomorphism
    domain::Vector{UInt32}
    images::Vector{UInt32}
    codomain::Vector{UInt32}
    rank::Int
end

"""Construct an empty partial isomorphism on `d` bits."""
_PartialF2Isomorphism(d::Int) =
    _PartialF2Isomorphism(zeros(UInt32, d), zeros(UInt32, d), zeros(UInt32, d), 0)

Base.copy(A::_PartialF2Isomorphism) =
    _PartialF2Isomorphism(copy(A.domain), copy(A.images), copy(A.codomain), A.rank)

"""Evaluate the partial map, returning `nothing` outside its domain."""
@inline function _partial_image(A::_PartialF2Isomorphism, x::UInt32)
    y = UInt32(0)
    @inbounds while x != 0
        p = 32 - leading_zeros(x)
        A.domain[p] == 0 && return nothing
        x ⊻= A.domain[p]
        y ⊻= A.images[p]
    end
    return y
end

"""Test membership in the image of a partial isomorphism."""
@inline function _partial_image_contains(A::_PartialF2Isomorphism, y::UInt32)
    @inbounds while y != 0
        p = 32 - leading_zeros(y)
        A.codomain[p] == 0 && return false
        y ⊻= A.codomain[p]
    end
    return true
end

"""
Add `A(x) = y`. Reject inconsistent relations or loss of injectivity.
A rejected insertion leaves the map unchanged.
"""
function _partial_insert!(A::_PartialF2Isomorphism, x::UInt32, y::UInt32)
    @inbounds while x != 0
        p = 32 - leading_zeros(x)
        A.domain[p] == 0 && break
        x ⊻= A.domain[p]
        y ⊻= A.images[p]
    end
    x == 0 && return y == 0
    v = y
    @inbounds while v != 0
        p = 32 - leading_zeros(v)
        A.codomain[p] == 0 && break
        v ⊻= A.codomain[p]
    end
    v == 0 && return false
    @inbounds begin
        p = 32 - leading_zeros(x)
        A.domain[p] = x
        A.images[p] = y
        A.codomain[32-leading_zeros(v)] = v
    end
    A.rank += 1
    return true
end

"""
Extend a partial isomorphism to an invertible map on the full ambient space.
When `output_bits > 0`, first complete the low-bit output subspace within itself.
The caller must have imposed the corresponding quotient-map constraints.
Returns `nothing` if no such completion exists.
"""
function _partial_complete(A::_PartialF2Isomorphism; output_bits::Int = 0)
    d = length(A.domain)
    B = copy(A)
    for i = 0:(d-1)
        x = UInt32(1) << i
        _partial_image(B, x) === nothing || continue
        lastbit = i < output_bits ? output_bits - 1 : d - 1
        j = findfirst(j -> !_partial_image_contains(B, UInt32(1) << j), 0:lastbit)
        j === nothing && return nothing
        _partial_insert!(B, x, UInt32(1) << (j - 1)) || return nothing
    end
    return F2LinearMap{d,UInt32}(UInt32[_partial_image(B, UInt32(1) << i) for i = 0:(d-1)])
end
