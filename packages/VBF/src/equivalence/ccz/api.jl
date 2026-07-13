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
- **Neither quadratic APN, both permutations** — the Canteaut–Perrin
  enumeration with the (Heggebakk) EA backend. This inherits Heggebakk's
  incompleteness on degenerate `k=4` partitions (signature `[2ⁿ-1, 1]`): for a
  class whose reps all have such partitions it can return `false` even when
  CCZ-equivalent.
- **Neither quadratic APN, not both permutations** — a positive
  [`are_ea_equivalent`](@ref) result is a sufficient CCZ-certificate and is
  returned as `true` (the complete non-permutation EA decision covers e.g.
  degree-≥3 non-permutation APN). Otherwise the pair is **not decided**:
  EA-inequivalence does not imply CCZ-inequivalence (EA ⊊ CCZ), so a `false`
  here would be a fabricated negative. Deciding this case in general reduces to
  linear-code equivalence (Leon's algorithm), a documented frontier. See
  `on_inconclusive` for how undecided is reported.

# A `false` is not always a proof

Every `false` this function returns from a *decided* query is either a failed
necessary CCZ-invariant (sound) or an exhausted class enumeration (sound). But
some pairs it cannot settle. By default an undecided query **warns and returns a
best-effort `false`** (`on_inconclusive = :best_effort`) — the caller cannot tell
that guess from a proof, so a novelty pipeline reading "not equivalent" from it
can invent a discovery (this is not hypothetical — it is how four "new" APN
functions were added to this repo's catalog and later withdrawn). Code that needs
certainty must pass `on_inconclusive = :throw` (raise
[`InconclusiveEquivalence`](@ref)) or `:missing`, or use a complete decision
(for quadratic APN, [`ea_mappings_from_ortho_derivative`](@ref) /
[`ea_class_orbits`](@ref)). The default stays a `Bool` so existing predicate
callers are not broken.
"""

"""
    are_ccz_equivalent(F::SBox, G::SBox; strategy = :auto,
                        ea_max_outer_per_sigma = 10^6,
                        max_class_reps = 10^4,
                        on_inconclusive = :throw) -> Bool

Decide CCZ-equivalence of `F` and `G`.

`max_class_reps` caps the number of EA-class representatives enumerated from
`F`'s CCZ-class. Exceeding it means the class was **not** exhausted, so no
conclusion is available and the query is inconclusive (it used to return
`false`). `ea_max_outer_per_sigma` is forwarded to each EA-equivalence call.

`on_inconclusive` controls what an undecided query does: `:best_effort` (default
— warn and return `false`), `:throw` (raise [`InconclusiveEquivalence`](@ref)),
or `:missing`.

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
    on_inconclusive::Symbol = :best_effort,
)
    inputbits(F) == inputbits(G) || return false
    storage_type(F) == storage_type(G) || return false
    # Reflexivity short-circuit (identity CCZ-map), scoped to :auto.
    strategy === :auto && F.lut == G.lut && return true

    # CCZ = EA on the quadratic-APN class (Yoshiara 2012): the fast path.
    Fq = is_quadratic_apn(F)
    Gq = is_quadratic_apn(G)
    Fq && Gq && return are_ea_equivalent(F, G; on_inconclusive = on_inconclusive)

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

    # EA-equivalence is a sufficient CCZ-certificate (EA ⊂ CCZ). The complete
    # non-permutation EA decision settles many pairs — including degree-≥3
    # non-permutation APN — that the permutation-only enumeration below cannot
    # reach, keeping the two oracles consistent (EA-equiv ⇒ CCZ-equiv).
    # A `false` here is *not* a CCZ-negative (EA ⊊ CCZ), so it only means "no
    # EA-certificate"; the decision continues below.
    are_ea_equivalent(
        F,
        G;
        max_outer_per_sigma = ea_max_outer_per_sigma,
        on_inconclusive = :best_effort,
    ) && return true

    # Neither side quadratic APN: the Canteaut-Perrin enumeration needs
    # permutations. For a non-permutation pair we have no decision procedure —
    # EA-inequivalence does NOT imply CCZ-inequivalence (EA ⊊ CCZ), so a `false`
    # here would be a fabricated negative, not a result.
    if !(is_permutation(F) && is_permutation(G))
        return _ccz_undecided(
            "neither input is a permutation and neither is quadratic APN, so the \
Canteaut-Perrin enumeration does not apply and no EA-certificate was found. \
EA-inequivalence does not imply CCZ-inequivalence.",
            on_inconclusive,
        )
    end
    reps = enumerate_ccz_class(F)
    if length(reps) > max_class_reps
        return _ccz_undecided(
            "the CCZ-class enumeration exceeded max_class_reps = $max_class_reps \
before the class was exhausted, so no conclusion is available. Raise \
max_class_reps to decide.",
            on_inconclusive,
        )
    end
    for rep in reps
        rep == G && return true                 # cheap exact-LUT path
        are_ea_equivalent(
            rep,
            G;
            max_outer_per_sigma = ea_max_outer_per_sigma,
            on_inconclusive = :best_effort,
        ) && return true
    end
    # The class was enumerated exhaustively and G matched no representative ⇒
    # a sound negative.
    return false
end

# A CCZ query the implementation cannot settle. Mirrors `are_ea_equivalent`'s
# `on_inconclusive`, so uncertainty is never silently reported as `false`.
function _ccz_undecided(why::AbstractString, on_inconclusive::Symbol)
    on_inconclusive === :best_effort && return false
    on_inconclusive === :missing && return missing
    on_inconclusive === :throw && throw(InconclusiveEquivalence(
        "are_ccz_equivalent: " * why * " Pass `on_inconclusive = :best_effort` to \
restore the old best-effort `false`, or `:missing` to propagate the uncertainty."))
    throw(ArgumentError("are_ccz_equivalent: unknown on_inconclusive = \
$(repr(on_inconclusive)) (expected :throw, :best_effort or :missing)"))
end

function _ccz_match_quadratic(F::SBox, Gq::SBox, max_class_reps::Int)
    reps = enumerate_ccz_class(F)
    length(reps) > max_class_reps && return false
    for r in reps
        r == Gq && return true
        is_quadratic_apn(r) || continue
        # A `false` from any single representative is not a CCZ-negative; only
        # exhausting the class is. Keep the loop going rather than throwing.
        are_ea_equivalent(r, Gq; on_inconclusive = :best_effort) && return true
    end
    return false
end
