"""
Public CCZ-equivalence API.

Two SBoxes `F, G : F₂ⁿ → F₂ⁿ` are **CCZ-equivalent** iff there exists
an invertible F₂-affine map `L : F₂²ⁿ → F₂²ⁿ` with `L(Γ_F) = Γ_G`,
where `Γ_F = {(x, F(x)) : x ∈ F₂ⁿ}` is the graph of `F`. CCZ strictly
contains EA-equivalence (Phase 8), which strictly contains affine
equivalence (Phase 7), which contains linear equivalence (Phase 6).

# Functions
- [`are_ccz_equivalent`](@ref) — `Bool` decision procedure.

# Strategy

The only strategy at v0.1 is `:canteaut_perrin`, based on the framework
of Canteaut & Perrin (FFA 2019):

  1. **Necessary conditions** — both `walsh_zeroes_size(F) ==
     walsh_zeroes_size(G)` and `sort(vec(ddt(F))) == sort(vec(ddt(G)))`
     must hold. Either failing rules out CCZ-equivalence. (The
     thickness spectrum is *not* a CCZ-invariant in general — see
     [`thickness_spectrum`](@ref) — so it cannot be used here.)
  2. **Sufficient condition** — enumerate every EA-class representative
     in `F`'s CCZ-class via [`enumerate_ccz_class`](@ref) and check
     [`are_ea_equivalent`](@ref) (Phase 8) against `G`. The Canteaut-
     Perrin theorem guarantees this enumeration hits at least one
     representative per EA-class.

# Limitations inherited

Phase 8's `are_ea_equivalent` short-circuits on degenerate `k=4`
partitions (signature `[2ⁿ-1, 1]`, characteristic of monomial APN).
Phase 9 inherits this: for inputs whose CCZ-class contains only such
partitions, the decision returns `false` even if CCZ-equivalent.
Phase 10 invariants (orthoderivative, Δ-rank, …) address this case.
"""

"""
    are_ccz_equivalent(F::SBox, G::SBox; strategy = :auto,
                        ea_max_outer_per_sigma = 10^6,
                        max_class_reps = 10^4) -> Bool

Decide CCZ-equivalence of `F` and `G`.

`max_class_reps` caps the number of EA-class representatives we'll
enumerate from `F`'s CCZ-class; the search short-circuits if exceeded
(returning `false`). `ea_max_outer_per_sigma` is forwarded to each
EA-equivalence call.

Permutations only at v0.1.
"""
function are_ccz_equivalent(
    F::SBox, G::SBox;
    strategy::Symbol = :auto,
    ea_max_outer_per_sigma::Int = 10^6,
    max_class_reps::Int = 10^4,
)
    inputbits(F) == inputbits(G) || return false
    storage_type(F) == storage_type(G) || return false
    if !(is_permutation(F) && is_permutation(G))
        # CCZ = EA on the quadratic-APN class (Yoshiara), and EA now handles
        # non-permutations; route there. Otherwise the permutation-only
        # Canteaut–Perrin enumeration does not apply.
        if algebraic_degree(F) == 2 && algebraic_degree(G) == 2 &&
           ortho_derivative(F) !== nothing && ortho_derivative(G) !== nothing
            return are_ea_equivalent(F, G)
        end
        return false
    end

    s = strategy == :auto ? :canteaut_perrin : strategy
    if s === :canteaut_perrin
        # Necessary fast rejects (both are CCZ-invariants).
        walsh_zeroes_size(F) == walsh_zeroes_size(G) || return false
        sort(vec(ddt(F))) == sort(vec(ddt(G))) || return false
        # Sufficient: enumerate F's CCZ-class and check EA-equivalence with G.
        reps = enumerate_ccz_class(F)
        length(reps) > max_class_reps && return false
        for rep in reps
            # Cheap path: exact LUT equality.
            rep == G && return true
            # Otherwise defer to Phase 8's EA test. Phase 8 rejects
            # non-permutations cheaply; only the thickness-N reps
            # (permutations) trigger real work.
            if are_ea_equivalent(rep, G;
                                  max_outer_per_sigma = ea_max_outer_per_sigma)
                return true
            end
        end
        return false
    end
    throw(ArgumentError("are_ccz_equivalent: unknown strategy $(repr(strategy))"))
end
