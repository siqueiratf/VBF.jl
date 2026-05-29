"""
Thickness spectrum and CCZ-class enumeration.

For an n-dimensional F₂-linear subspace `V ⊆ Z(F)` of the Walsh-zeroes
set of `F`, the **thickness** of `V` is the F₂-rank of its projection
onto the low n bits:

    thickness(V) := rank_{F₂}( { v & mask : v ∈ basis(V) } )

where `mask = 2ⁿ - 1`. The thickness ranges over `0:N`; thickness `N`
corresponds to subspaces that yield **permutations** in the CCZ-class
of F (per the Canteaut-Perrin framework, FFA 2019).

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

# ---------------------------------------------------------------------------
# CCZ-class EA representatives.
# ---------------------------------------------------------------------------

# Build the CCZ mapping L : F₂²ⁿ → F₂²ⁿ from a single n-dim subspace basis:
#   img = complete_basis(basis, 2n); reverse; build F2LinearMap; transpose.
function _ccz_mapping_from_basis(basis::Vector{UInt32}, N::Int)
    M = 2N
    img = complete_basis(basis, M)
    reverse!(img)
    L_lin = F2LinearMap{M, UInt32}(img)
    return transpose(L_lin)
end

"""
    enumerate_ccz_class(F::SBox{N,T}) -> Vector{SBox{N,T}}

Enumerate CCZ-equivalent representatives of `F` — at least one per
EA-class in F's CCZ-class.

For each `N`-dim subspace of `Z(F)`, builds the corresponding CCZ
mapping `L` (per Canteaut-Perrin 2019) and applies it to the graph of
`F` via [`ccz_equivalent_function`](@ref). Non-admissible `L`'s (whose
image graph is not a function graph) are skipped.

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
    for basis in bases
        L = _ccz_mapping_from_basis(basis, N)
        A = F2AffineMap(L, UInt32(0))
        F_eq = ccz_equivalent_function(F, A)
        F_eq === nothing && continue
        push!(results, F_eq)
    end
    return results
end
