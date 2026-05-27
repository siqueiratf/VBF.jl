"""
Public API for linear-equivalence testing.

Two S-boxes `F, G : F₂ⁿ → F₂ⁿ` are *linearly equivalent* iff there
exist invertible F₂-linear maps `L₁, L₂` such that

    G = L₁ ∘ F ∘ L₂.

This file dispatches the public entry points to the underlying
algorithm strategies. At v0.1 two strategies are available — propagation-
pruned backtracking (Phase 5) and Stennes' canonical-representative
algorithm (Phase 6); the affine-partition strategy follows in a later
phase.

# Functions
- [`are_linear_equivalent`](@ref) — `Bool` decision procedure.
"""

"""
    are_linear_equivalent(F::SBox{N,T}, G::SBox{N,T}; strategy = :auto) -> Bool

Decide whether `F` and `G` are linearly equivalent.

# Type-checks
S-boxes of different `N` are never linearly equivalent — the dispatched
fallback returns `false`. Different storage types `T₁ ≠ T₂` at the same
`N` likewise return `false`; reload one of them with the other's type
if you want a comparison.

# Strategies
- `:auto` — picks a strategy from `(N, is_permutation(F))`. At v0.1
  permutations with `N ≥ 5` route to `:stennes`; everything else to
  `:lpp_backtracking`.
- `:lpp_backtracking` — propagation-pruned backtracking over the
  basis images of `L₂`. Works for permutations; non-permutations
  return `false`. See [`are_linearly_equivalent_perm`](@ref).
- `:stennes` — Stennes' canonical-representative algorithm
  (`linear_representative(F).representative == linear_representative(G).representative`).
  Permutations only; non-permutations return `false`. Asymptotically
  faster than `:lpp_backtracking` once `N ≥ 6`.

# Examples
```jldoctest
julia> using BFA

julia> a, b = load_apn_function("n5_Gold_x3"), load_apn_function("n5_Gold_x3");

julia> are_linear_equivalent(a, b)
true

julia> a, b = load_apn_function("n5_Gold_x3"), load_apn_function("n5_Gold_x5");

julia> are_linear_equivalent(a, b)
false
```
"""
function are_linear_equivalent(F::SBox, G::SBox; strategy::Symbol = :auto)
    # Different input bit-widths or storage types cannot be equivalent —
    # return false without throwing (matching the spirit of the predicate).
    inputbits(F) == inputbits(G) || return false
    storage_type(F) == storage_type(G) || return false

    s = strategy
    if s === :auto
        s = (is_permutation(F) && is_permutation(G) && inputbits(F) ≥ 5) ?
            :stennes : :lpp_backtracking
    end
    if s === :lpp_backtracking
        return are_linearly_equivalent_perm(F, G)
    elseif s === :stennes
        # Stennes works on permutations only; non-permutations are never
        # linearly equivalent to a permutation, and two non-permutations
        # don't admit the canonical-form construction. Defer to false.
        (is_permutation(F) && is_permutation(G)) || return false
        return linear_representative(F).representative ==
               linear_representative(G).representative
    end
    throw(ArgumentError("are_linear_equivalent: unknown strategy $(repr(strategy))"))
end
