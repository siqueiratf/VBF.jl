# Implements Section 4, Theorem 3: APN permutations in dimensions 4 and 5.
# Paper: Brinkmann, Leander (2008), "On the Classification of APN Functions up to
#        Dimension Five", Designs, Codes and Cryptography 49(1-3):273-288.
# Section: 4 — Affine Equivalence
#
# Pseudocode:
#   1. n=4: both EA-canonical representatives (Table 2) are APN but not permutations,
#      and neither is CCZ equivalent to a permutation — with Theorem 6's single CCZ
#      class this *proves* there is no APN permutation in F(F₂⁴,F₂⁴)
#   2. n=5: x³,x⁵,x⁷,x¹¹,x¹⁵ are all APN permutations, and the family attribution of
#      x¹¹ (Kasami) and x¹⁵ (Inverse) is proved by affine equivalence
#   3. n=5: pairwise *affine*-inequivalence — the relation Theorem 3 is stated in —
#      decided exactly by `are_affine_equivalent` (all five are permutations)
#   4. n=5: Table 1's inverse relations (no. 1 ≅ its inverse; no. 2 (3) ≅ inverse of
#      no. 4 (5))
# VBF API used: differential_uniformity, is_permutation, algebraic_degree,
#               are_affine_equivalent, is_ccz_equivalent_to_permutation,
#               compositional_inverse, kasami_apn, inverse_apn, SBox

isdefined(@__MODULE__, :table1_luts) || include(joinpath(@__DIR__, "table1.jl"))

"""
    theorem3_n4_report(io)

Theorem 3 (n=4 part): there are no APN permutations in F(F₂⁴, F₂⁴).

The two EA-canonical APN functions from Table 2 are APN but not permutations, and
neither is CCZ equivalent to a permutation. Theorem 6 puts every n=4 APN function
in a single CCZ class, and "CCZ equivalent to a permutation" is a CCZ-class
property, so that closes the statement — no backtrack search needed.
"""
function theorem3_n4_report(io::IO = stdout)
    print_section(io, "Theorem 3 (n=4) — No APN permutations in F(F₂⁴, F₂⁴)")
    F1, F2 = table2_luts()
    for (label, F) in [("F1 (Gold x³ class)", F1), ("F2 (non-power class)", F2)]
        du = differential_uniformity(F)
        perm = is_permutation(F)
        print_check(io, "$label: APN (du=$du)", du == 2)
        print_check(io, "$label: NOT a permutation", !perm)
        print_check(io, "$label: NOT CCZ equivalent to a permutation",
                    !is_ccz_equivalent_to_permutation(F))
    end
    println(io, "  Proof of completeness: `is_ccz_equivalent_to_permutation` is exact —")
    println(io, "  it enumerates the n-dimensional Walsh-zero subspaces and looks for a")
    println(io, "  complementary pair (Canteaut-Perrin), the exact criterion. Theorem 6")
    println(io, "  gives a single CCZ class for n=4, and being CCZ equivalent to a")
    println(io, "  permutation is invariant on a CCZ class. So no APN function in")
    println(io, "  F(F₂⁴,F₂⁴) is CCZ — let alone affine — equivalent to a permutation.")
end

"""
    theorem3_n5_report(io)

Theorem 3 (n=5 part): there are exactly 5 APN permutations in F(F₂⁵, F₂⁵) up to
affine equivalence, all affine-equivalent to power functions; no. 1 is equivalent
to its inverse, and no. 2 (resp. 3) to the inverse of no. 4 (resp. 5).
"""
function theorem3_n5_report(io::IO = stdout)
    print_section(io, "Theorem 3 (n=5) — 5 APN permutation classes in F(F₂⁵, F₂⁵)")
    mod5 = primitive_polynomial(5)
    labels = n5_power_labels()
    fns = n5_power_sboxes()

    for (lbl, F) in zip(labels, fns)
        du = differential_uniformity(F)
        deg = algebraic_degree(F)
        perm = is_permutation(F)
        print_check(io, "$lbl: APN (du=$du) and permutation (deg=$deg)", du == 2 && perm)
    end

    print_section(io, "Theorem 3 (n=5) — family attribution of x¹¹ and x¹⁵")
    # The Kasami exponent 2^{2k}−2^k+1 at k=2 is 13, not 15: x¹¹ is the Kasami
    # class (coset {11,13,21,22,26}) and x¹⁵ is the Inverse class (coset
    # {15,23,27,29,30}, which also holds the Dobbertin exponent 29).
    print_check(io, "x¹¹ ~affine kasami_apn(5,2) = x¹³ (so x¹¹ is Kasami)",
                are_affine_equivalent(fns[4], kasami_apn(5, 2; modulus = mod5)))
    print_check(io, "x¹⁵ ~affine inverse_apn(5) = x³⁰ (so x¹⁵ is Inverse, not Kasami)",
                are_affine_equivalent(fns[5], inverse_apn(5; modulus = mod5)))
    print_check(io, "x¹¹ ≁affine x¹⁵ — Γ-rank $(gamma_rank(fns[4])) vs $(gamma_rank(fns[5]))",
                gamma_rank(fns[4]) != gamma_rank(fns[5]))

    print_section(io, "Theorem 3 (n=5) — pairwise affine-inequivalence")
    # Theorem 3 classifies APN permutations up to *affine* equivalence, and all
    # five are permutations, so `are_affine_equivalent` (via `affine_representative`)
    # decides every pair exactly. The earlier EA-based test left two pairs to a
    # capped search whose best-effort `false` was read as a proof.
    all_distinct = true
    for i = 1:length(fns), j = (i+1):length(fns)
        if are_affine_equivalent(fns[i], fns[j])
            print_check(io, "$(labels[i]) ~ $(labels[j]) affine: UNEXPECTED EQUIVALENCE", false)
            all_distinct = false
        end
    end
    n_pairs = length(fns) * (length(fns) - 1) ÷ 2
    print_kv(io, "pairs decided", "$n_pairs/$n_pairs by affine_representative (exact)")
    print_check(io, "All 5 power functions pairwise affine-inequivalent (5 classes)", all_distinct)
    println(io, "  Cross-check: x^d ~affine x^e iff the cyclotomic cosets of e and d, or of")
    println(io, "  e and d⁻¹, coincide mod 31 — e.g. 7's coset {7,14,28,25,19} and 7⁻¹=9's")
    println(io, "  coset {9,18,5,10,20} are both disjoint from 11's {11,22,13,26,21}.")

    print_section(io, "Theorem 3 (n=5) — Table 1 and its inverse relations")
    T1 = table1_luts()
    exps = table1_affine_exponents()
    for (i, F) in enumerate(T1)
        P = SBox{5}(gf_monomial_lut(5, exps[i]; modulus = mod5))
        print_check(io, "Table 1 no. $i is an APN permutation ~affine x^$(exps[i])",
                    differential_uniformity(F) == 2 && is_permutation(F) &&
                    are_affine_equivalent(F, P))
    end
    print_check(io, "no. 1 ~affine its own compositional inverse",
                are_affine_equivalent(T1[1], compositional_inverse(T1[1])))
    print_check(io, "no. 2 ~affine the inverse of no. 4",
                are_affine_equivalent(T1[2], compositional_inverse(T1[4])))
    print_check(io, "no. 3 ~affine the inverse of no. 5",
                are_affine_equivalent(T1[3], compositional_inverse(T1[5])))
    println(io, "  Note: completeness (no sixth class) requires the paper's backtrack")
    println(io, "        search over templates — out of scope.")
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
