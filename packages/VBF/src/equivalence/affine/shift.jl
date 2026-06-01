"""
Affine equivalence via shift-then-Stennes reduction.

For an SBox `F : F₂ⁿ → F₂ⁿ`, define the **zero-anchored shift**

    F̃_a(x) := F(x ⊕ a) ⊕ F(a),     so F̃_a(0) = 0.

If `G = A₁ ∘ F ∘ A₂` is an affine equivalence with
`A₂(x) = L₂(x) ⊕ L₂(a)` and `A₁(y) = L₁(y) ⊕ b`, substituting
`z = x ⊕ a` gives

    G(z ⊕ a) ⊕ G(a) = L₁(F(L₂(z)) ⊕ F(0)) = L₁(F̃_0(L₂(z))),

so `G̃_a = L₁ ∘ F̃_0 ∘ L₂` — a **linear** equivalence between two
zero-anchored functions. The constant `b` cancels, so we only enumerate
the shift `a`. This gives a 2ⁿ-fold reduction of affine equivalence to
linear equivalence:

> `F ~_A G` iff `∃ a ∈ F₂ⁿ` such that `linear_representative(F̃_0)
>  == linear_representative(G̃_a)`.

Permutations only at v0.1; non-permutations are rejected by the public
wrappers because `linear_representative` requires invertibility.
"""

# F̃_a(x) = F(x ⊕ a) ⊕ F(a).  F̃_a(0) = 0 by construction.
function _shift_anchor(F::SBox{N,T}, a::Integer) where {N,T}
    n = 1 << N
    a_T = T(a)
    F_a = @inbounds F.lut[a_T+1]
    out = Vector{T}(undef, n)
    @inbounds for x = 0:(n-1)
        out[x+1] = F.lut[(T(x)⊻a_T)+1] ⊻ F_a
    end
    return SBox{N,T}(out)
end

# Affine equivalence by enumeration: fix F's anchor at 0, vary G's.
function _are_affine_equivalent_shift(F::SBox{N,T}, G::SBox{N,T}) where {N,T}
    (is_permutation(F) && is_permutation(G)) || return false
    R_F = linear_representative(_shift_anchor(F, 0)).representative
    n = 1 << N
    @inbounds for a = 0:(n-1)
        G_a = _shift_anchor(G, a)
        if linear_representative(G_a).representative == R_F
            return true
        end
    end
    return false
end

function _are_affine_equivalent_general(F::SBox{N,T}, G::SBox{N,T}) where {N,T}
    differential_spectrum(F) == differential_spectrum(G) || return false
    absolute_walsh_spectrum(F) == absolute_walsh_spectrum(G) || return false
    F_0 = _shift_anchor(F, 0)
    n = 1 << N
    for a = 0:(n-1)
        are_linear_equivalent(F_0, _shift_anchor(G, a)) && return true
    end
    return false
end

"""
    affine_class_signature(F::SBox{N,T}) -> Vector{SBox{N,T}}

The deduplicated, lex-sorted set

    { linear_representative(F̃_a).representative : a ∈ F₂ⁿ }

— the **affine-equivalence-class signature** of `F`. Two SBoxes are
affine-equivalent iff their signatures share at least one element; the
first (lex-smallest) entry is [`affine_representative`](@ref).

`F` must be a permutation.

The signature usually contains far fewer than `2ⁿ` distinct elements:
under the linear self-equivalence group of `F̃_0`, the orbit of any
single anchor produces the same linear representative, so distinct
representatives arise only from *cosets* of that group.
"""
function affine_class_signature(F::SBox{N,T}) where {N,T}
    is_permutation(F) ||
        throw(ArgumentError("affine_class_signature: F must be a permutation"))
    n = 1 << N
    reps = Vector{SBox{N,T}}(undef, n)
    @inbounds for a = 0:(n-1)
        reps[a+1] = linear_representative(_shift_anchor(F, a)).representative
    end
    sort!(reps; by = r -> r.lut)
    unique!(r -> r.lut, reps)
    return reps
end

"""
    affine_representative(F::SBox{N,T}) -> SBox{N,T}

The canonical affine-equivalence-class representative of `F`: the
lexicographically smallest LUT in
`{linear_representative(F̃_a).representative : a ∈ F₂ⁿ}`.

Two permutation SBoxes are affine-equivalent iff their affine
representatives agree. Faster than `affine_class_signature` for the
"compare two functions" use-case because it short-circuits once the
minimum is fixed.
"""
function affine_representative(F::SBox{N,T}) where {N,T}
    sig = affine_class_signature(F)
    return sig[1]
end
