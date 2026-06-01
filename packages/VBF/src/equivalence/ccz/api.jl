"""
Public CCZ-equivalence API.

Two SBoxes `F, G : F₂ⁿ → F₂ⁿ` are **CCZ-equivalent** iff there exists
an invertible F₂-affine map `L : F₂²ⁿ → F₂²ⁿ` with `L(Γ_F) = Γ_G`,
where `Γ_F = {(x, F(x)) : x ∈ F₂ⁿ}` is the graph of `F` (the equivalence
introduced by [Carlet, Charpin and Zinoviev, 1998](@cite CarletCharpinZinoviev1998)).
CCZ strictly
contains EA-equivalence, which strictly contains affine equivalence,
which contains linear equivalence.

# Functions
- [`are_ccz_equivalent`](@ref) — `Bool` decision procedure.

# Strategy

The only strategy at v0.1 is `:canteaut_perrin`, based on the framework
of [Canteaut and Perrin (2019)](@cite CanteautPerrin2019CCZ):

  1. **Necessary conditions** — both `walsh_zeroes_size(F) ==
     walsh_zeroes_size(G)` and `sort(vec(ddt(F))) == sort(vec(ddt(G)))`
     must hold. Either failing rules out CCZ-equivalence. (The
     thickness spectrum is *not* a CCZ-invariant in general — see
     [`thickness_spectrum`](@ref) — so it cannot be used here.)
  2. **Sufficient condition** — enumerate every EA-class representative
     in `F`'s CCZ-class via [`enumerate_ccz_class`](@ref) and check
     [`are_ea_equivalent`](@ref) against `G`. The Canteaut-Perrin
     theorem guarantees this enumeration hits at least one
     representative per EA-class.

# Decision coverage

- **Both quadratic APN** — decided exactly via the ortho-derivative EA test
  (CCZ = EA on this class, [Yoshiara, 2012](@cite Yoshiara2012)).
- **Exactly one quadratic APN** (e.g. the Kim function vs the Dillon
  permutation, a quadratic and a degree-4 permutation in one CCZ-class) —
  decided by enumerating the other side's CCZ-class and EA-testing its
  degree-2 representatives against the quadratic one. EA preserves algebraic
  degree, so only degree-2 reps can match, and EA between two quadratic APN is
  the reliable ortho-derivative test.
- **Neither quadratic APN, both permutations** — the Canteaut–Perrin
  enumeration with the (Heggebakk) EA backend. This inherits Heggebakk's
  incompleteness on degenerate `k=4` partitions (signature `[2ⁿ-1, 1]`): for a
  class whose reps all have such partitions it can return `false` even when
  CCZ-equivalent.
- **Neither quadratic APN, not both permutations** — not decided (returns
  `false`); deciding it in general reduces to linear-code equivalence (Leon's
  algorithm), a documented frontier.
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

# Examples

The Kim function (quadratic APN) and the Dillon permutation (degree 4)
lie in a single CCZ-class over `F₂⁶`, the first known APN permutation in
even dimension:

```jldoctest
julia> using VBF

julia> are_ccz_equivalent(kim_apn(), dillon_apn_permutation())
true
```
"""
function are_ccz_equivalent(
    F::SBox, G::SBox;
    strategy::Symbol = :auto,
    ea_max_outer_per_sigma::Int = 10^6,
    max_class_reps::Int = 10^4,
)
    inputbits(F) == inputbits(G) || return false
    storage_type(F) == storage_type(G) || return false
    # Reflexivity (identity CCZ-map) — also avoids enumerating the whole
    # CCZ-class and running EA on each rep for the F == G case. Scoped to :auto
    # so an explicitly requested (or invalid) strategy still reaches dispatch.
    strategy === :auto && F.lut == G.lut && return true

    # CCZ = EA on the quadratic-APN class (Yoshiara 2012): the fast, reliable path.
    Fq = is_quadratic_apn(F)
    Gq = is_quadratic_apn(G)
    Fq && Gq && return are_ea_equivalent(F, G)

    s = strategy == :auto ? :canteaut_perrin : strategy
    s === :canteaut_perrin ||
        throw(ArgumentError("are_ccz_equivalent: unknown strategy $(repr(strategy))"))

    # Necessary CCZ-invariant rejects (cheap).
    walsh_zeroes_size(F) == walsh_zeroes_size(G) || return false
    sort(vec(ddt(F))) == sort(vec(ddt(G))) || return false

    # Exactly one side is quadratic APN — e.g. the Kim function (quadratic) and
    # the Dillon permutation (degree 4) in the same CCZ-class. Enumerate the
    # OTHER side's CCZ-class and test EA against the quadratic one. EA preserves
    # algebraic degree, so only the degree-2 representatives can be EA-equivalent
    # to a quadratic target — and EA between two quadratic APN is the reliable
    # ortho-derivative test, sidestepping Heggebakk's incompleteness on the
    # higher-degree permutation representatives.
    Gq && return _ccz_match_quadratic(F, G, max_class_reps)
    Fq && return _ccz_match_quadratic(G, F, max_class_reps)

    # Neither side is quadratic APN: the permutation-only Canteaut–Perrin
    # enumeration (non-quadratic non-permutations are not decided — they reduce
    # to linear-code equivalence; see the module docstring).
    (is_permutation(F) && is_permutation(G)) || return false
    reps = enumerate_ccz_class(F)
    length(reps) > max_class_reps && return false
    for rep in reps
        rep == G && return true                 # cheap exact-LUT path
        are_ea_equivalent(rep, G; max_outer_per_sigma = ea_max_outer_per_sigma) &&
            return true
    end
    return false
end

# Decide whether the quadratic-APN `Gq` lies in `F`'s CCZ-class: enumerate class
# representatives and EA-test the degree-2 ones against `Gq`. EA preserves degree,
# so non-quadratic reps cannot match `Gq` and are skipped; EA between two
# quadratic APN is the (reliable) ortho-derivative test.
function _ccz_match_quadratic(F::SBox, Gq::SBox, max_class_reps::Int)
    reps = enumerate_ccz_class(F)
    length(reps) > max_class_reps && return false
    for r in reps
        r == Gq && return true
        is_quadratic_apn(r) || continue
        are_ea_equivalent(r, Gq) && return true
    end
    return false
end
