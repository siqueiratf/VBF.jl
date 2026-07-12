# Implements Section 3.2, Table 2
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
# Section: 3.2, Table 2 — n=7: 15 CCZ-inequivalent classes
#
# ─── PAPER ERRATUM (P1), AND THE CLASS IT HID ─────────────────────────────────
# Rows 4 and 10 of the published Table 2 are the SAME polynomial, x³+x⁹+x¹⁸+x⁶⁶.
# Confirmed in the PDF, so this is an error in the paper, not an OCR artefact.
#
# The paper's *text* says 15 CCZ classes; its *table* prints only 14 distinct
# polynomials. The paper's count is RIGHT and the table is wrong: the duplicate row
# displaced a genuine 15th class, which is simply absent from the table. An earlier
# version of this file drew the opposite conclusion ("14 classes") and dropped it.
#
# The missing representative, recovered by exhaustive search:
#
#         x³ + x⁵ + x⁹ + x⁴⁰ + x⁹⁶        (n=7; APN, deg 2, AB)
#
# HOW IT WAS RECOVERED, AND HOW IT IS RE-VERIFIED HERE:
# Enumerating all 2²¹ homogeneous quadratics over GF(2⁷) with F₂ coefficients and testing
# each with is_qam gives 30,870 APN functions falling into 14 σ-classes. Thirteen of those
# σ-classes appear in Table 2; one appears in NO row — that one is the missing class, and
# x³+x⁵+x⁹+x⁴⁰+x⁹⁶ is its shortest representative. Independently re-derived in
# test_algorithm1.jl: the exhaustive search_qam(7,1) sweep returns 14 EA-classes whose
# σ-set equals, exactly, the σ-set of the 15 representatives below — which would FAIL if
# the recovered row were wrong.
#
# WHY 14 σ-CLASSES BUT 15 CCZ CLASSES: σ (the ortho-derivative signature) is a CCZ
# invariant but not a complete one. The Gold pair x³ and x⁹ SHARE a σ over GF(2⁷) (and a
# Γ-rank, and a Δ-rank) yet are CCZ-INEQUIVALENT. This is not a σ defect to be papered
# over — it is settled below by the COMPLETE decision for quadratic APN:
# ea_mappings_from_ortho_derivative(x³, x⁹) is EMPTY, and EA = CCZ for quadratic APN
# (Yoshiara). So: 14 σ-classes + 1 Gold split = 15 CCZ classes, exactly the paper's count.
#
# The corrected n=7 breakdown is 3 power functions + 2 trinomials + 5 quadrinomials +
# 4 pentanomials + 1 hexanomial. The paper's prose ("six quadrinomials, three
# pentanomials") is derived from its own corrupted table.
#
# Pseudocode:
#   1. Build the SBox for each of the 15 representatives over GF(2⁷)
#   2. Verify each is APN (δ=2), quadratic (deg 2), and AB (linearity 2⁴)
#   3. Verify they fall into exactly 14 σ-classes, the sole collision being {x³, x⁹}
#   4. Settle that collision with the complete EA decision → 15 CCZ classes
# VBF API used: sbox_from_exponents, differential_uniformity, algebraic_degree,
#   is_almost_bent, sigma_hash, ea_mappings_from_ortho_derivative

include(joinpath(@__DIR__, "helpers.jl"))

using VBFCatalog

# (exponents, label) — n=7 throughout. 15 rows: the paper's 14 distinct printed
# polynomials (its row 10 duplicates row 4 and is dropped) + the recovered 15th class.
const TABLE2_FUNCTIONS = [
    ([3],                       "x³"),
    ([9],                       "x⁹"),
    ([5],                       "x⁵"),
    ([3, 9, 18, 66],            "x³+x⁹+x¹⁸+x⁶⁶"),        # printed twice (rows 4 and 10)
    ([5, 18, 34],               "x⁵+x¹⁸+x³⁴"),
    ([3, 6, 20],                "x³+x⁶+x²⁰"),
    ([3, 17, 20, 34, 66],       "x³+x¹⁷+x²⁰+x³⁴+x⁶⁶"),
    ([3, 17, 33, 34],           "x³+x¹⁷+x³³+x³⁴"),
    ([3, 5, 10, 33, 34],        "x³+x⁵+x¹⁰+x³³+x³⁴"),
    ([3, 12, 17, 33],           "x³+x¹²+x¹⁷+x³³"),
    ([3, 20, 34, 66],           "x³+x²⁰+x³⁴+x⁶⁶"),
    ([3, 12, 40, 72],           "x³+x¹²+x⁴⁰+x⁷²"),
    ([3, 6, 34, 40, 72],        "x³+x⁶+x³⁴+x⁴⁰+x⁷²"),
    ([3, 5, 6, 12, 33, 34],     "x³+x⁵+x⁶+x¹²+x³³+x³⁴"),
    ([3, 5, 9, 40, 96],         "x³+x⁵+x⁹+x⁴⁰+x⁹⁶"),     # RECOVERED — missing from Table 2
]

# The one σ-collision among the 15, expected and explained (Gold x³ vs x⁹).
const TABLE2_GOLD_COLLISION = (["x³", "x⁹"], [3], [9])

"""
    table2_verify(; settle_gold) -> NamedTuple

Verify all 15 n=7 representatives (the paper's 14 printed distinct rows + the recovered
one). `settle_gold` runs the complete EA decision on the x³/x⁹ σ-collision (~2 s).
"""
function table2_verify(; settle_gold::Bool = true)
    checks = Tuple{String,Bool}[]
    n = 7

    boxes = [(label, sbox_from_exponents(n, exps)) for (exps, label) in TABLE2_FUNCTIONS]

    # 1. Every representative — including the recovered one — is APN, quadratic and AB.
    for (label, F) in boxes
        push!(checks, ("$label: APN (δ=2)", differential_uniformity(F) == 2))
        push!(checks, ("$label: quadratic (deg 2)", algebraic_degree(F) == 2))
        push!(checks, ("$label: AB (linearity 2⁴=16)", is_almost_bent(F)))   # R7
    end

    push!(checks, ("Table 2 has 15 representatives (14 printed distinct + 1 recovered)",
                   length(TABLE2_FUNCTIONS) == 15))

    # 2. σ-classes: 15 representatives fall into exactly 14 σ-classes.
    sigmas = Dict{String,Vector{String}}()
    for (label, F) in boxes
        push!(get!(sigmas, sigma_hash(F), String[]), label)
    end
    collisions = [ls for ls in values(sigmas) if length(ls) > 1]

    push!(checks, ("the 15 representatives fall into exactly 14 σ-classes",
                   length(sigmas) == 14))
    push!(checks, ("exactly one σ-collision", length(collisions) == 1))
    push!(
        checks,
        ("the sole σ-collision is the Gold pair {x³, x⁹}",
         length(collisions) == 1 && sort(collisions[1]) == sort(TABLE2_GOLD_COLLISION[1])),
    )

    # Every other pair is σ-MISMATCHED. σ-mismatch is a rigorous CCZ-inequivalence
    # certificate (a σ-MATCH would prove nothing), so this establishes 14 distinct
    # CCZ classes outright.
    push!(
        checks,
        ("14 CCZ classes certified by σ-mismatch (rigorous direction)",
         length(sigmas) == 14),
    )

    # The recovered row must be a genuinely NEW class, i.e. σ-distinct from all 14
    # printed rows. If it merely duplicated one of them, this fails.
    rec = sbox_from_exponents(n, [3, 5, 9, 40, 96])
    rec_sigma = sigma_hash(rec)
    printed_sigmas = Set(sigma_hash(sbox_from_exponents(n, exps))
                         for (exps, _) in TABLE2_FUNCTIONS[1:14])
    push!(
        checks,
        ("recovered x³+x⁵+x⁹+x⁴⁰+x⁹⁶ is σ-distinct from all 14 printed rows " *
         "(CCZ-inequivalent to every one of them)",
         !(rec_sigma in printed_sigmas)),
    )

    # 3. Settle the Gold collision with the COMPLETE decision: for quadratic APN,
    #    EA = CCZ (Yoshiara), and ea_mappings_from_ortho_derivative is empty iff the
    #    two functions are EA-inequivalent. Empty ⟹ x³ and x⁹ are two CCZ classes.
    gold_settled = missing
    if settle_gold
        g3 = sbox_from_exponents(n, [3])
        g9 = sbox_from_exponents(n, [9])
        gold_settled = isempty(ea_mappings_from_ortho_derivative(g3, g9))
        push!(
            checks,
            ("Gold split: x³ and x⁹ share a σ but are CCZ-INEQUIVALENT " *
             "(complete EA decision returns no mapping; EA = CCZ for quadratic APN)",
             gold_settled),
        )
        # Sanity/mutation guard: the same decision procedure must find x³ ~EA x³.
        push!(
            checks,
            ("EA decision is not vacuously empty (x³ ~EA x³ yields mappings)",
             !isempty(ea_mappings_from_ortho_derivative(g3, g3))),
        )
        push!(
            checks,
            ("⟹ 14 σ-classes + 1 Gold split = 15 CCZ classes, matching the paper's text",
             length(sigmas) == 14 && gold_settled === true),
        )
    end

    (; checks,
       n_representatives = length(TABLE2_FUNCTIONS),
       n_sigma_classes = length(sigmas),
       n_ccz_classes = length(sigmas) + (gold_settled === true ? 1 : 0),
       gold_split_settled = gold_settled,
       erratum = "PAPER ERRATUM: rows 4 and 10 of Table 2 are both x³+x⁹+x¹⁸+x⁶⁶ " *
                 "(confirmed in the PDF). The duplicate displaced a real class; the " *
                 "missing 15th representative is x³+x⁵+x⁹+x⁴⁰+x⁹⁶. The paper's count " *
                 "of 15 is correct; its table is not.")
end

function table2_report(io::IO = stdout)
    print_section(io, "Table 2 — n=7 (15 CCZ classes; paper's table prints a duplicate and omits one)")
    result = table2_verify()
    print_kv(io, "erratum", result.erratum)
    print_kv(io, "representatives", result.n_representatives)
    print_kv(io, "σ-classes", result.n_sigma_classes)
    print_kv(io, "CCZ classes", "$(result.n_ccz_classes) (σ-classes + the Gold x³/x⁹ split)")
    for (desc, ok) in result.checks
        print_check(io, desc, ok)
    end
    all_pass = all(ok for (_, ok) in result.checks)
    print_kv(io, "overall", all_pass ? "all checks pass" : "SOME CHECKS FAILED")
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    table2_report()
end
