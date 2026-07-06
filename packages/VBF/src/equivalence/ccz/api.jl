"""
Public CCZ-equivalence API.

Two SBoxes `F, G : F₂ⁿ → F₂ⁿ` are **CCZ-equivalent** iff there exists
an invertible F₂-affine map `L : F₂²ⁿ → F₂²ⁿ` with `L(Γ_F) = Γ_G`,
where `Γ_F = {(x, F(x)) : x ∈ F₂ⁿ}` is the graph of `F` (the equivalence
introduced by [Carlet, Charpin and Zinoviev, 1998](@cite Carlet_199811)).
CCZ strictly
contains EA-equivalence, which strictly contains affine equivalence,
which contains linear equivalence.

# Functions
- [`are_ccz_equivalent`](@ref) — `Bool` decision procedure.

# Strategy

The only strategy at v0.1 is `:canteaut_perrin`, based on the framework
of [Canteaut and Perrin (2019)](@cite Canteaut_201906):

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
  (CCZ = EA on this class, [Yoshiara, 2012](@cite Yoshiara_201200)).
- **Exactly one quadratic APN** (e.g. the Kim function vs the Dillon
  permutation, a quadratic and a degree-4 permutation in one CCZ-class) —
  decided by enumerating the other side's CCZ-class and EA-testing its
  degree-2 representatives against the quadratic one. EA preserves algebraic
  degree, so only degree-2 reps can match, and EA between two quadratic APN is
  the reliable ortho-derivative test.
- **Neither quadratic APN, at least one a permutation** — the Canteaut–Perrin
  enumeration of `F`'s CCZ-class with the (Heggebakk) EA backend, testing each
  representative against the permutation side. This inherits Heggebakk's
  incompleteness on degenerate `k=4` partitions (signature `[2ⁿ-1, 1]`): for a
  class whose reps all have such partitions it can return `false` even when
  CCZ-equivalent.
- **Neither quadratic APN, neither a permutation** — both CCZ-classes are
  enumerated and their EA-class representatives are cross-matched. This decides
  the pair whenever the common CCZ-class contains *any* EA-class that
  `are_ea_equivalent` can settle — i.e. a quadratic-APN- or permutation-bearing
  representative (the usual case, since almost every APN CCZ-class contains a
  quadratic representative). It returns `false` (undecided) only for the residual
  frontier where no representative on either side is quadratic or a permutation;
  deciding those in general reduces to linear-code equivalence (Leon's
  algorithm).
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
    F::SBox,
    G::SBox;
    strategy::Symbol = :auto,
    ea_max_outer_per_sigma::Int = 10^6,
    max_class_reps::Int = 10^4,
)
    inputbits(F) == inputbits(G) || return false
    storage_type(F) == storage_type(G) || return false
    # Reflexivity short-circuit (identity CCZ-map), scoped to :auto.
    strategy === :auto && F.lut == G.lut && return true

    # CCZ = EA on the quadratic-APN class (Yoshiara 2012): the fast path.
    Fq = is_quadratic_apn(F)
    Gq = is_quadratic_apn(G)
    Fq && Gq && return are_ea_equivalent(F, G)

    s = strategy == :auto ? :canteaut_perrin : strategy
    s === :canteaut_perrin || throw(
        ArgumentError("are_ccz_equivalent: unknown strategy $(repr(strategy))"),
    )

    # Necessary CCZ-invariant rejects (cheap).
    walsh_zeroes_size(F) == walsh_zeroes_size(G) || return false
    sort(vec(ddt(F))) == sort(vec(ddt(G))) || return false

    # One side quadratic APN: EA preserves degree, so EA-test the degree-2 reps.
    Gq && return _ccz_match_quadratic(F, G, max_class_reps)
    Fq && return _ccz_match_quadratic(G, F, max_class_reps)

    # Neither side quadratic APN: Canteaut-Perrin enumeration. Enumerate
    # F's CCZ-class into EA-class representatives and try to match G's
    # class. `are_ea_equivalent` decides a pair only when a common EA-class
    # is quadratic-APN- or permutation-bearing, so we must cross the
    # enumeration against whichever side exposes such a representative.
    reps_F = enumerate_ccz_class(F)
    length(reps_F) > max_class_reps && return false

    # If G is a permutation, testing each F-rep against G directly suffices:
    # Heggebakk decides permutation-vs-permutation, and `reps_F` covers the
    # permutation EA-class of the (shared, if equivalent) CCZ-class.
    if is_permutation(G)
        for rep in reps_F
            rep == G && return true             # cheap exact-LUT path
            are_ea_equivalent(
                rep,
                G;
                max_outer_per_sigma = ea_max_outer_per_sigma,
            ) && return true
        end
        return false
    end

    # G is not a permutation. Enumerate G's class too and cross-match EA-
    # classes across both enumerations: a shared EA-class that is
    # quadratic-APN- (ortho-derivative) or permutation- (Heggebakk) bearing
    # is decided by `are_ea_equivalent`, recovering CCZ-equivalence whenever
    # the common CCZ-class has any decidable EA-representative. (The
    # symmetric permutation fast path above is the F-permutation case.)
    reps_G = enumerate_ccz_class(G)
    length(reps_G) > max_class_reps && return false
    for rf in reps_F
        for rg in reps_G
            rf == rg && return true             # cheap exact-LUT path
            are_ea_equivalent(
                rf,
                rg;
                max_outer_per_sigma = ea_max_outer_per_sigma,
            ) && return true
        end
    end
    return false
end

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
