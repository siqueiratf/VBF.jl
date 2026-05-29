"""
Public API for affine-equivalence testing.

Two SBoxes `F, G : F₂ⁿ → F₂ⁿ` are *affine equivalent* iff there exist
invertible F₂-affine maps `A₁(y) = L₁(y) ⊕ c₁`, `A₂(x) = L₂(x) ⊕ c₂`
such that

    G = A₁ ∘ F ∘ A₂.

# Functions
- [`are_affine_equivalent`](@ref) — `Bool` decision procedure.
- [`affine_representative`](@ref) — canonical-form representative.
- [`affine_class_signature`](@ref) — full signature (set of linear
  representatives across anchor shifts).
"""

"""
    are_affine_equivalent(F::SBox, G::SBox; strategy = :auto) -> Bool

Decide affine equivalence of `F` and `G`.

# Type checks

SBoxes of different `N` or storage `T` cannot be affine-equivalent and
return `false` without throwing.

# Strategies

- `:auto`           — at v0.1 delegates to `:stennes_shift`.
- `:stennes_shift`  — 2ⁿ-fold reduction to linear equivalence via the
  zero-anchored shift `F̃_a(x) = F(x ⊕ a) ⊕ F(a)`. Calls
  `linear_representative` up to `2ⁿ + 1` times. Permutations only;
  non-permutations return `false`.

# Examples

```jldoctest
julia> using VBF

julia> F = load_apn_function("n5_Gold_x3");

julia> are_affine_equivalent(F, F)
true

julia> are_affine_equivalent(F, load_apn_function("n5_Kasami_x15"))
false
```
"""
function are_affine_equivalent(F::SBox, G::SBox; strategy::Symbol = :auto)
    inputbits(F) == inputbits(G) || return false
    storage_type(F) == storage_type(G) || return false

    s = strategy == :auto ? :stennes_shift : strategy
    if s === :stennes_shift
        return _are_affine_equivalent_shift(F, G)
    end
    throw(ArgumentError("are_affine_equivalent: unknown strategy $(repr(strategy))"))
end
