"""
Thickness spectrum and CCZ-class enumeration.

For an n-dimensional F₂-linear subspace `V ⊆ Z(F)` of the Walsh-zeroes
set of `F`, the **thickness** of `V` is the F₂-rank of its projection
onto the low n bits:

    thickness(V) := rank_{F₂}( { v & mask : v ∈ basis(V) } )

where `mask = 2ⁿ - 1`. The thickness ranges over `0:N`; thickness `N`
corresponds to subspaces that yield **permutations** in the CCZ-class
of F (per the Canteaut-Perrin framework,
[Canteaut and Perrin, 2019](@cite CanteautPerrin2019CCZ)).

The **thickness spectrum** is the multiset of thicknesses over all
n-dim subspaces of `Z(F)`. It is a CCZ-invariant.

Enumeration of EA-class representatives in F's CCZ-class proceeds by:

  for each basis `b` of an n-dim subspace of Z(F):
    img := reverse(complete_basis(b, 2n))       # 2n × 2n matrix columns
    L   := F2AffineMap(F2LinearMap(img), 0).transpose()
    F'  := ccz_equivalent_function(F, L)
    push F' onto the result

Each EA-class in F's CCZ-class has at least one representative in this
output (possibly multiple).
"""

# ---------------------------------------------------------------------------
# Thickness of a single subspace + thickness spectrum.
# ---------------------------------------------------------------------------

"""
    thickness(basis::Vector{UInt32}, N::Int) -> Int

Thickness of a Walsh-zeroes subspace given by its `2n`-bit basis: the
F₂-rank of its projection `{b & mask : b ∈ basis}` onto the low `N`
bits.
"""
function thickness(basis::Vector{UInt32}, N::Int)
    mask = (UInt32(1) << N) - UInt32(1)
    proj = UInt32[b & mask for b in basis]
    return rank_f2(proj; nbits = N)
end

"""
    thickness_spectrum(F::SBox{N,T}) -> Vector{Int}

The multiset of thicknesses over every `N`-dim subspace of `Z(F)`,
returned as a sorted-descending `Vector{Int}`.

# Invariance scope

`thickness_spectrum` is an **EA-class invariant** but **NOT a CCZ-class
invariant**. Under a generic CCZ-mapping `L : F₂²ⁿ → F₂²ⁿ` the
projection π_b (onto the low `N` bits) does not commute with
`L⁻ᵀ`, so individual subspace thicknesses change. In particular, for
`F` and its functional inverse `F⁻¹` (related by the swap CCZ-map),
`thickness_spectrum(F)` and `thickness_spectrum(F⁻¹)` typically differ
— their multisets are the "complemented" versions `{k ↦ count(k)}` vs
`{n - k ↦ count(k)}`.

`thickness_spectrum` IS still useful: it distinguishes EA-classes
inside a CCZ-class (`enumerate_ccz_class` may produce many EA-
inequivalent functions, separable by their individual thickness
contributions in the spectrum).

CCZ-invariants used by `are_ccz_equivalent` for fast rejection are the
DDT multiset and `walsh_zeroes_size`.
"""
function thickness_spectrum(F::SBox{N,T}) where {N,T}
    Z = walsh_zeroes(F)
    bases = extract_linear_subspaces(Z, N; max_bits = 2N)
    thicks = [thickness(b, N) for b in bases]
    sort!(thicks; rev = true)
    return thicks
end

"""
    is_ccz_equivalent_to_permutation(F::SBox{N}) -> Bool

True iff the APN function `F` is CCZ-equivalent to a permutation. By
[Canteaut and Perrin (2019)](@cite CanteautPerrin2019CCZ) this holds iff the
Walsh-zero set `Z(F)` contains two
**complementary** `n`-dimensional subspaces `V₁, V₂` (i.e. `V₁ ⊕ V₂ = F₂^{2n}`).

This complementary-*pair* condition is CCZ-invariant — unlike the thickness of a
single subspace, which a CCZ-map does not preserve (an earlier attempt using the
thickness-N of one subspace gave a false negative on the Kim function, which IS
CCZ-equivalent to the Dillon permutation). The only known even-dimension example
is the Dillon permutation and the [`kim_apn`](@ref) it comes from (`N = 6`); Gold
`x³` in even dimension returns `false` (the "big APN problem"). Cost is that of
enumerating the n-dim Walsh-zero subspaces (tractable for `n ≤ 6`).
"""
function is_ccz_equivalent_to_permutation(F::SBox{N}) where {N}
    M = 2N
    bases = extract_linear_subspaces(walsh_zeroes(F), N; max_bits = M)
    @inbounds for i in eachindex(bases), j in (i + 1):length(bases)
        rank_f2(UInt32[bases[i]; bases[j]]; nbits = M) == M && return true
    end
    false
end

# ---------------------------------------------------------------------------
# CCZ-class EA representatives.
# ---------------------------------------------------------------------------

# Build the CCZ mapping L : F₂²ⁿ → F₂²ⁿ that sends the graph of F to a function
# graph, given the `2n`-bit basis of an n-dim Walsh-zero subspace `V₁` and a
# completing basis `comp` (so `[V₁; comp]` spans F₂²ⁿ):
#   L := transpose( F2LinearMap([V₁; comp]) ).
# When `comp` is the basis of a *complementary Walsh-zero subspace* `V₂`
# (`V₁ ⊕ V₂ = F₂²ⁿ`), the resulting representative is a permutation
# (Canteaut–Perrin, FFA 2019); an arbitrary completion is used only as a
# fallback when `V₁` has no Walsh-zero complement.
function _ccz_mapping_from_bases(b1::Vector{UInt32}, comp::Vector{UInt32}, N::Int)
    M = 2N
    return transpose(F2LinearMap{M, UInt32}(UInt32[b1; comp]))
end

# Backwards-compatible single-subspace mapping (arbitrary completion).
function _ccz_mapping_from_basis(basis::Vector{UInt32}, N::Int)
    M = 2N
    img = complete_basis(basis, M)
    reverse!(img)
    return transpose(F2LinearMap{M, UInt32}(img))
end

"""
    enumerate_ccz_class(F::SBox{N,T}) -> Vector{SBox{N,T}}

Enumerate CCZ-equivalent representatives of `F` — at least one per
EA-class in F's CCZ-class.

For each `N`-dim subspace `V₁` of `Z(F)`, builds a CCZ mapping `L`
(per [Canteaut and Perrin, 2019](@cite CanteautPerrin2019CCZ)) and applies it to the graph of `F` via
[`ccz_equivalent_function`](@ref). `V₁` is completed to a basis of
`F₂²ⁿ` by a **complementary Walsh-zero subspace** `V₂ ⊆ Z(F)` whenever
one exists — the completion that keeps `L` admissible *and* recovers the
permutation-bearing EA-classes of the class (a complementary pair
`V₁ ⊕ V₂ = F₂²ⁿ` of Walsh-zero subspaces is exactly the Canteaut–Perrin
condition for a permutation). An arbitrary completion is used only as a
fallback when `V₁` has no Walsh-zero complement. Non-admissible `L`'s
(whose image graph is not a function graph) are skipped.

Using a Walsh-zero complement (rather than arbitrary vectors) makes the
enumeration **symmetric across the class**: e.g. `enumerate_ccz_class`
of the [`kim_apn`](@ref) function and of the [`dillon_apn_permutation`](@ref)
it is CCZ-equivalent to yield the same set of EA-classes (an earlier
arbitrary-completion version missed the permutation classes when started
from `kim_apn`).

# Caveats

- Some EA-classes may be represented multiple times (duplicate
  representatives are not deduplicated).
- For `n ≥ 6` the number of subspaces can grow rapidly; subspace
  enumeration may be slow.

# Examples

```jldoctest
julia> using VBF

julia> reps = enumerate_ccz_class(load_literature_sbox("PRESENT"));

julia> length(reps) ≥ 1
true
```
"""
function enumerate_ccz_class(F::SBox{N,T}) where {N,T}
    M = 2N
    Z = walsh_zeroes(F)
    bases = extract_linear_subspaces(Z, N; max_bits = M)
    results = SBox{N,T}[]
    for (i, b1) in pairs(bases)
        admitted = false
        # Prefer a complementary Walsh-zero subspace V₂ (recovers permutations).
        for (j, b2) in pairs(bases)
            i == j && continue
            rank_f2(UInt32[b1; b2]; nbits = M) == M || continue
            L = _ccz_mapping_from_bases(b1, b2, N)
            F_eq = ccz_equivalent_function(F, F2AffineMap(L, UInt32(0)))
            F_eq === nothing && continue
            push!(results, F_eq)
            admitted = true
            break
        end
        admitted && continue
        # Fallback: arbitrary completion (V₁ has no Walsh-zero complement).
        L = _ccz_mapping_from_basis(b1, N)
        F_eq = ccz_equivalent_function(F, F2AffineMap(L, UInt32(0)))
        F_eq === nothing && continue
        push!(results, F_eq)
    end
    return results
end
