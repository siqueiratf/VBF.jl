# Implements Section 4, Theorem 3: APN permutations in dimensions 4 and 5.
# Paper: Brinkmann, Leander (2008), "On the Classification of APN Functions up to
#        Dimension Five", Designs, Codes and Cryptography 49(1-3):273-288.
# Section: 4 — Affine Equivalence
#
# Pseudocode:
#   1. n=4: show that both EA-canonical representatives (Table 2) are APN but not permutations
#   2. n=5: show that x³,x⁵,x⁷,x¹¹,x¹⁵ are all APN permutations
#   3. n=5: show pairwise EA-inequivalence ⟹ pairwise affine-inequivalence (5 distinct classes)
# VBF API used: differential_uniformity, is_permutation, algebraic_degree,
#               are_ea_equivalent, SBox

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem3_n4_report(io)

Theorem 3 (n=4 part): there are no APN permutations in F(F₂⁴, F₂⁴).
The two EA-canonical APN functions from Table 2 are APN but not permutations.
"""
function theorem3_n4_report(io::IO = stdout)
    print_section(io, "Theorem 3 (n=4) — No APN permutations in F(F₂⁴, F₂⁴)")
    F1, F2 = table2_luts()
    for (label, F) in [("F1 (Gold x³ class)", F1), ("F2 (non-power class)", F2)]
        du = differential_uniformity(F)
        perm = is_permutation(F)
        print_check(io, "$label: APN (du=$du)", du == 2)
        print_check(io, "$label: NOT a permutation", !perm)
    end
    println(io, "  Note: completeness (no other APN functions exist for n=4) requires")
    println(io, "        the full backtrack search — out of scope here.")
end

"""
    theorem3_n5_report(io)

Theorem 3 (n=5 part): there are exactly 5 APN permutations in F(F₂⁵, F₂⁵) up to affine
equivalence, all affine-equivalent to power functions.
"""
function theorem3_n5_report(io::IO = stdout)
    print_section(io, "Theorem 3 (n=5) — 5 APN permutation classes in F(F₂⁵, F₂⁵)")
    mod5 = primitive_polynomial(5)
    exponents = [3, 5, 7, 11, 15]
    labels = ["x³ (Gold i=1)", "x⁵ (Gold i=2)", "x⁷ (Welch)", "x¹¹", "x¹⁵ (Kasami)"]
    fns = [power_sbox(5, d; modulus = mod5) for d in exponents]

    for (lbl, F) in zip(labels, fns)
        du  = differential_uniformity(F)
        deg = algebraic_degree(F)
        perm = is_permutation(F)
        print_check(io, "$lbl: APN (du=$du) and permutation (deg=$deg)", du == 2 && perm)
    end

    print_section(io, "Theorem 3 (n=5) — pairwise affine-inequivalence (via EA-inequivalence)")
    all_distinct = true
    for i in 1:length(fns), j in i+1:length(fns)
        eq = are_ea_equivalent(fns[i], fns[j])
        if eq
            print_check(io, "$(labels[i]) ~ $(labels[j]) EA: UNEXPECTED EQUIVALENCE", false)
            all_distinct = false
        end
    end
    print_check(io, "All 5 power functions pairwise EA-inequivalent (→ affine-inequivalent)", all_distinct)
    println(io, "  Note: x^d affine-equiv iff {d·2^k mod 31} or {d^{-1}·2^k mod 31} overlap.")
    println(io, "  Note: completeness requires backtrack search — out of scope.")
end

"""
    theorem3_report(io)

Full Theorem 3 report: no APN permutations in n=4; five classes in n=5.
"""
function theorem3_report(io::IO = stdout)
    theorem3_n4_report(io)
    theorem3_n5_report(io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem3_report()
end
