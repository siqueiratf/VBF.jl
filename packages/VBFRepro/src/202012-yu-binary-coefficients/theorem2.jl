# Implements Section 3.1, Theorem 2 — WITH A DOCUMENTED BASIS CAVEAT.
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
#
# ─── WHAT THEOREM 2 SAYS ──────────────────────────────────────────────────────
# Let H = Mα^t C_F Mα, where α = {α₀,…,α_{n-1}} is a NORMAL basis (α_{i+1} = α_i²).
# Then      H[u+1, v+1] = H[u, v]²  for all u,v   ⟺   c_{i,t} ∈ F₂ for all i,t.
#
# ─── WHAT THIS FILE CAN AND CANNOT TEST ───────────────────────────────────────
# The "iff" is a statement about H in a NORMAL basis. VBF has no normal-basis QAM
# builder: `quadratic_apn_matrix` works in the BIT basis bᵢ = 2^{i-1} of
# `primitive_polynomial(n)`. Theorem 2's iff DOES NOT TRANSFER between bases, and we do
# not have the basis it needs. So **this file does not test Theorem 2's iff** — it would
# be dishonest to claim otherwise, and an earlier version of this reproduction did:
# it fed a matrix from `qam_from_cyclic` (which applies Frobenius along each orbit *by
# construction*) into `has_f2_cyclic_structure` and reported the tautology as a pass.
#
# Instead we assert, as falsifiable checks, exactly what IS true in the bit basis:
#
#   (1) CONSTRUCTOR INVARIANT (not Theorem 2): qam_from_cyclic(n,1,·) always yields a
#       matrix with the Frobenius-shift structure. True by construction — labelled as
#       such, and kept only because it is the invariant that defines the search space.
#
#   (2) THE BASIS MISMATCH IS REAL: has_f2_cyclic_structure(quadratic_apn_matrix(x³), n)
#       is FALSE for n = 6,7,8,9 — although x³ plainly HAS F₂ coefficients (asserted
#       separately via has_f2_coefficients). If Theorem 2's criterion applied to the bit
#       basis, this would have to be true. It is not. This is the honest, falsifiable
#       statement of the gap.
#
#   (3) THE CONVERSE FAILS TOO: the functions returned by search_qam(n,1) do NOT have
#       F₂ coefficients (F(x²) ≠ F(x)²), so they are not literally "the F₂-coefficient
#       functions" the paper enumerates.
#
#   (4) BUT THE CLASSIFICATION IS STILL FAITHFUL UP TO EA: those same functions ARE in
#       the EA-class of the paper's functions. The matrix set is basis-independent, and
#       reading a cyclic QAM in the bit basis yields F ∘ L for a linear L — an
#       EA-transformation. Asserted for n = 6,7 against x³ and, at n=7, against the
#       whole of Table 2 (see algorithm1.jl / test_algorithm1.jl).
#
# Consequence for the rest of the paper: the EA/CCZ classes search_qam finds are the
# right ones, so the classification stands; what is NOT reproduced is the claim that the
# recovered representatives are the F₂-coefficient ones. Closing this properly needs a
# normal-basis QAM pair in core (quadratic_apn_matrix_normal / qam_to_sbox_normal) —
# out of scope for this paper directory; recorded in the README.
#
# VBF API used: qam_from_cyclic, qam_cyclic_orbits, quadratic_apn_matrix, search_qam,
#   apn_ea_mugshot, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))

"""
    cyclic_qam_has_structure(n, m, values) -> Bool

Whether `qam_from_cyclic(n, m, values)` satisfies the Frobenius-shift property. This
holds **by construction** (`qam_from_cyclic` walks each orbit applying `x ↦ x^(2^m)`);
it is a constructor invariant, *not* a test of Theorem 2.
"""
function cyclic_qam_has_structure(n::Int, m::Int, values::Vector{Int})
    has_f2_cyclic_structure(qam_from_cyclic(n, m, values), n)
end

"""
    theorem2_examples() -> NamedTuple

Assert what is actually true about the bit-basis reading of Theorem 2 — including the
two directions in which it **fails**, which is the point.
"""
function theorem2_examples()
    checks = Tuple{String,Bool}[]

    # (1) Constructor invariant — labelled honestly, not sold as Theorem 2.
    for (n, vals) in [(6, [1, 1, 1]), (7, [1, 1, 1])]
        ok = cyclic_qam_has_structure(n, 1, vals)
        push!(
            checks,
            ("n=$n: qam_from_cyclic output has Frobenius-shift structure (constructor invariant, NOT Theorem 2)",
             ok),
        )
    end

    # (2) x³ HAS F₂ coefficients …
    for n = 6:9
        push!(checks, ("n=$n: x³ has F₂ coefficients (F(x²)=F(x)²)",
                       has_f2_coefficients(sbox_from_exponents(n, [3]))))
    end

    # … yet its BIT-BASIS matrix does NOT satisfy the Frobenius-shift criterion.
    # Theorem 2's criterion is normal-basis-only; this asserts the gap is real.
    for n = 6:9
        broken = !has_f2_cyclic_structure(quadratic_apn_matrix(sbox_from_exponents(n, [3])), n)
        push!(
            checks,
            ("n=$n: BASIS GAP — bit-basis QAM of x³ fails the Frobenius-shift criterion, though x³ has F₂ coefficients",
             broken),
        )
    end

    # (3) Converse fails: search_qam(n,1) outputs do NOT have F₂ coefficients …
    # (4) … but they DO land in the EA-class of the paper's function. Classification
    #     faithful up to EA.
    for n in [6, 7]
        classes = search_solutions(search_qam(n, 1; max_evaluations = 1 << 24))
        gold_mug = apn_ea_mugshot(sbox_from_exponents(n, [3]))

        none_f2 = !isempty(classes) && all(!has_f2_coefficients(F) for F in classes)
        push!(
            checks,
            ("n=$n: search_qam(n,1) outputs do NOT literally have F₂ coefficients (bit-basis reading)",
             none_f2),
        )

        found = any(apn_ea_mugshot(F) == gold_mug for F in classes)
        push!(checks, ("n=$n: search_qam(n,1) finds the EA-class of x³ (faithful up to EA)", found))
    end

    # Every cyclic-QAM function recovered at n=6 is APN.
    classes6 = search_solutions(search_qam(6, 1; max_evaluations = 1 << 24))
    push!(checks, ("n=6: all cyclic-QAM functions are APN",
                   all(differential_uniformity(F) == 2 for F in classes6)))

    (; checks,
       caveat = "Theorem 2's iff is NOT tested: it is a normal-basis statement and VBF's " *
                "quadratic_apn_matrix is bit-basis. Checks above assert the constructor " *
                "invariant, the (real) basis gap, and EA-faithfulness of the search.")
end

function theorem2_report(io::IO = stdout)
    print_section(io, "Theorem 2 — normal-basis statement; bit-basis reproduction (see caveat)")
    result = theorem2_examples()
    print_kv(io, "caveat", result.caveat)
    for (desc, ok) in result.checks
        print_check(io, desc, ok)
    end
    all_pass = all(ok for (_, ok) in result.checks)
    print_kv(io, "overall", all_pass ? "all checks pass" : "SOME CHECKS FAILED")
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem2_report()
end
