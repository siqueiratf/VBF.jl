# Implements Section 3 — The Affine Equivalence Algorithm (AE).
# Paper: Biryukov et al. (2003), "A Toolbox for Cryptanalysis: Linear and Affine
#        Equivalence Algorithms", Eurocrypt 2003.
# Section: 3 — The Affine Equivalence Algorithm; 3.2 — Finding the Linear Representative
#
# Pseudocode:
#   1. linear_representative(F) is canonical: same for all G in the LE class of F.
#   2. Two permutations have the same affine_representative iff affine equivalent.
#   3. Gold x^3 and Kasami x^15 (n=5) are APN but in different affine classes.
# VBF API used: linear_representative, affine_representative, are_affine_equivalent,
#               load_apn_function

include(joinpath(@__DIR__, "helpers.jl"))

function section3_report(io::IO = stdout)
    print_section(io, "Section 3 — Affine Equivalence (AE) / Linear Representative (Sect. 3.2)")

    g3 = load_apn_function("n5_Gold_x3")
    g5 = load_apn_function("n5_Gold_x5")

    # Section 3.2: linear representative is canonical within the LE class.
    rep_g3a = linear_representative(g3).representative
    rep_g3b = linear_representative(g3).representative
    ok_stable = rep_g3a == rep_g3b
    print_check(io, "linear_representative(Gold x^3) is stable across calls", ok_stable)

    # x^3 and x^5 in GF(2^5) are in different linear classes.
    rep_g5 = linear_representative(g5).representative
    ok_diff_lin = rep_g3a != rep_g5
    print_check(
        io,
        "Gold x^3 and Gold x^5 (n=5) have different linear representatives",
        ok_diff_lin,
    )

    # AE check: a function is always affine-equivalent to itself.
    ok_self = are_affine_equivalent(g3, g3)
    print_check(io, "Gold x^3 affine equivalent to itself", ok_self)

    # Gold x^3 and Kasami x^15 (n=5): different APN families → not affine equivalent.
    k15 = load_apn_function("n5_Kasami_x15")
    ok_ne = !are_affine_equivalent(g3, k15)
    print_check(io, "Gold x^3 and Kasami x^15 (n=5) are NOT affine equivalent", ok_ne)

    # AE-equivalent pair: G = B^{-1} ∘ F ∘ A (via linear_representative maps).
    rep = linear_representative(g3)
    ok_ae_rep = are_affine_equivalent(g3, rep.representative)
    print_check(
        io,
        "Gold x^3 affine equivalent to its linear representative",
        ok_ae_rep,
    )

    # affine_representative is canonical (same for affine-equivalent permutations).
    ar1 = affine_representative(g3)
    ar2 = affine_representative(rep.representative)
    ok_ar = ar1 == ar2
    print_check(
        io,
        "affine_representative stable across affine-equivalent permutations",
        ok_ar,
    )

    print_kv(io, "completeness", "exhaustive over stated pairs")
    print_kv(
        io,
        "not run",
        "Sect. 3.3 (birthday-paradox AE variant): a distinct probabilistic " *
        "algorithm — 2^{3n/2} random 3-pair sets per S-box, expanded through " *
        "odd linear combinations, then collided — with no core entry point and " *
        "no printed numeric target beyond its O(n³·2^{3n/2}) estimate; it also " *
        "cannot certify inequivalence, so it does not subsume Sect. 3.2 " *
        "(0 collisions attempted)",
    )

    return ok_stable && ok_diff_lin && ok_self && ok_ne && ok_ae_rep && ok_ar
end

if abspath(PROGRAM_FILE) == @__FILE__
    ok = section3_report()
    exit(ok ? 0 : 1)
end
