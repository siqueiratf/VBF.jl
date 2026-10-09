"""
Public CCZ-equivalence decisions and affine certificates.

`:auto` and `:partition_refinement` use the native Kaleyski–Sunde algorithm
(ePrint 2026/940, https://eprint.iacr.org/2026/940), applicable to arbitrary
square SBoxes. Every positive result has a verified affine graph witness;
every negative result requires exhaustive search or a mismatching invariant.
For two quadratic APN functions `:auto` first compares the ortho-derivative
mugshots, using CCZ = EA (Yoshiara 2012), before running the same recovery.

`:canteaut_perrin` retains the older CCZ-class enumeration for comparisons.
Its permutation EA backend can be incomplete on degenerate partitions, so
use the native strategy for exact classification.
"""

"""
    are_ccz_equivalent(F, G; strategy=:auto, max_nodes=10^6,
        timeout_seconds=60.0, min_active_hyperplanes=0,
        max_memory_bytes=512*1024^2, on_inconclusive=:best_effort,
        ea_max_outer_per_sigma=10^6, max_class_reps=10^4)

Decide CCZ equivalence using native Kaleyski–Sunde partition refinement.
`on_inconclusive=:throw` raises [`InconclusiveEquivalence`](@ref) on a budget
hit; `:missing` propagates uncertainty; the compatibility policy `:best_effort`
warns and returns `false`, which must not be interpreted as a proof.
The default remains `:best_effort` for compatibility with existing callers.
The legacy class/outer limits apply only to `strategy=:canteaut_perrin`.
See [`partition_refinement_equivalence`](@ref) for native budget semantics.

```jldoctest
julia> using VBF

julia> are_ccz_equivalent(kim_apn(), dillon_apn_permutation(); on_inconclusive=:throw)
true
```
"""
function are_ccz_equivalent(
    F::SBox, G::SBox; strategy::Symbol = :auto,
    ea_max_outer_per_sigma::Int = 10^6, max_class_reps::Int = 10^4,
    on_inconclusive::Symbol = :best_effort, max_nodes::Int = 10^6,
    timeout_seconds::Real = 60.0, min_active_hyperplanes::Int = 0,
    max_memory_bytes::Int = 512 * 1024^2,
    automorphisms = nothing, automorphism_timeout_seconds::Real = 0.0,
    threaded::Bool = false,
    algorithm::Symbol = :paper, rng::AbstractRNG = Xoshiro(940),
)
    strategy in (:auto, :partition_refinement, :canteaut_perrin) ||
        throw(ArgumentError("are_ccz_equivalent: unknown strategy $(repr(strategy))"))
    algorithm in (:paper,:optimized) || throw(ArgumentError("algorithm must be :paper or :optimized"))
    _pr_validate_policy(on_inconclusive)
    inputbits(F) == inputbits(G) || return false
    if strategy === :canteaut_perrin
        return _are_ccz_canteaut_perrin(F, G; strategy, ea_max_outer_per_sigma,
                                       max_class_reps, on_inconclusive)
    end
    if strategy === :auto
        F.lut == G.lut && return true
        if is_quadratic_apn(F) && is_quadratic_apn(G)
            apn_ea_mugshot(F) == apn_ea_mugshot(G) || return false
        end
    end
    result = partition_refinement_equivalence(F, G; max_nodes, timeout_seconds,
        min_active_hyperplanes, max_memory_bytes, automorphisms, automorphism_timeout_seconds, threaded, algorithm, rng)
    return _pr_decision(result, on_inconclusive, :are_ccz_equivalent)
end

"""
    ccz_equivalence_certificate(F, G; on_inconclusive=:throw, kwargs...)

Return a verified invertible `F2AffineMap` carrying `FunctionGraph(F)` onto
`FunctionGraph(G)`, or `nothing` after proving inequivalence. Search limits
are those of [`partition_refinement_equivalence`](@ref). A budget hit raises
[`InconclusiveEquivalence`](@ref) by default; `:missing` returns `missing`.
"""
function ccz_equivalence_certificate(F::SBox, G::SBox;
    on_inconclusive::Symbol = :throw, max_nodes::Int = 10^6,
    timeout_seconds::Real = 60.0, min_active_hyperplanes::Int = 0,
    max_memory_bytes::Int = 512 * 1024^2,
    automorphisms = nothing, automorphism_timeout_seconds::Real = 0.0,
    threaded::Bool = false,
    algorithm::Symbol = :paper, rng::AbstractRNG = Xoshiro(940),
)
    algorithm in (:paper,:optimized) || throw(ArgumentError("algorithm must be :paper or :optimized"))
    _pr_validate_policy(on_inconclusive)
    result = partition_refinement_equivalence(F, G; max_nodes, timeout_seconds,
        min_active_hyperplanes, max_memory_bytes, automorphisms, automorphism_timeout_seconds, threaded, algorithm, rng)
    return _pr_witness(result, on_inconclusive, :ccz_equivalence_certificate)
end

function _are_ccz_canteaut_perrin(
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
    Gq && return _ccz_match_quadratic(F, G, max_class_reps, on_inconclusive)
    Fq && return _ccz_match_quadratic(G, F, max_class_reps, on_inconclusive)

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

function _ccz_match_quadratic(F::SBox, Gq::SBox, max_class_reps::Int, on_inconclusive::Symbol)
    reps = enumerate_ccz_class(F)
    length(reps) > max_class_reps && return _ccz_undecided(
        "the CCZ-class enumeration exceeded max_class_reps = $max_class_reps.",
        on_inconclusive,
    )
    undecided = false
    for r in reps
        r == Gq && return true
        is_quadratic_apn(r) || continue
        # A `false` from any single representative is not a CCZ-negative; only
        # exhausting the class is. Keep the loop going rather than throwing.
        result = are_ea_equivalent(r, Gq; on_inconclusive = :missing)
        result === true && return true
        undecided |= ismissing(result)
    end
    undecided && return _ccz_undecided("an EA representative test was inconclusive.", on_inconclusive)
    return false
end
