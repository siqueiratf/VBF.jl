# Implements Section 5, Theorem 6: CCZ-equivalence classes for n=4 and n=5.
# Paper: Brinkmann, Leander (2008), "On the Classification of APN Functions up to
#        Dimension Five", Designs, Codes and Cryptography 49(1-3):273-288.
# Section: 5 — CCZ Equivalence
#
# Pseudocode:
#   1. n=4: F1 and F2 are CCZ-equivalent (1 CCZ class — Theorem 6 part 1)
#   2. n=5: x³, x⁵, x¹⁵ are pairwise CCZ-inequivalent (3 CCZ classes — Theorem 6 part 2)
#   3. n=5: {x¹¹, f6(i=1)} ↔ CCZ-class of x³; {x⁷, f6(i=2)} ↔ CCZ-class of x⁵
#   4. n=5: every function in our 7-element set is CCZ-equiv to one of {x³, x⁵, x¹⁵}
# VBF API used: are_ccz_equivalent, gf_pow, primitive_polynomial, SBox

isdefined(@__MODULE__, :table2_luts) || include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem6_n4_report(io)

Theorem 6 (n=4 part): all APN functions in F(F₂⁴, F₂⁴) are pairwise CCZ-equivalent
(i.e., there is exactly 1 CCZ-class for n=4).
"""
function theorem6_n4_report(io::IO = stdout)
    print_section(io, "Theorem 6 (n=4) — 1 CCZ-equivalence class")
    F1, F2 = table2_luts()
    ccz = are_ccz_equivalent(F1, F2)
    print_check(io, "F1 (Gold class) ~ F2 (non-power class) CCZ-equivalent", ccz)
    println(io, "  This confirms 1 CCZ-class for n=4 (both EA-classes are CCZ-equivalent).")
end

"""
    theorem6_n5_report(io)

Theorem 6 (n=5 part): exactly 3 CCZ-classes, represented by x³, x⁵, and x¹⁵.
"""
function theorem6_n5_report(io::IO = stdout)
    print_section(io, "Theorem 6 (n=5) — 3 CCZ-equivalence classes")
    mod5 = primitive_polynomial(5)
    G3  = power_sbox(5, 3;  modulus = mod5)
    G5  = power_sbox(5, 5;  modulus = mod5)
    G7  = power_sbox(5, 7;  modulus = mod5)
    G11 = power_sbox(5, 11; modulus = mod5)
    G15 = power_sbox(5, 15; modulus = mod5)
    f6_1 = formula6_n5(1; modulus = mod5)
    f6_2 = formula6_n5(2; modulus = mod5)

    print_check(io, "x³ ≁ x⁵  CCZ-inequivalent", !are_ccz_equivalent(G3,  G5))
    print_check(io, "x³ ≁ x¹⁵ CCZ-inequivalent", !are_ccz_equivalent(G3,  G15))
    print_check(io, "x⁵ ≁ x¹⁵ CCZ-inequivalent", !are_ccz_equivalent(G5,  G15))

    print_section(io, "Theorem 6 (n=5) — CCZ membership of remaining 4 EA-classes")
    print_check(io, "x¹¹   ~ x³  (CCZ class 1)", are_ccz_equivalent(G11,  G3))
    print_check(io, "f6(1) ~ x³  (CCZ class 1)", are_ccz_equivalent(f6_1, G3))
    print_check(io, "x⁷    ~ x⁵  (CCZ class 2)", are_ccz_equivalent(G7,   G5))
    print_check(io, "f6(2) ~ x⁵  (CCZ class 2)", are_ccz_equivalent(f6_2, G5))

    print_section(io, "Theorem 6 (n=5) — all 7 functions covered by 3 CCZ-classes")
    reps    = [G3, G5, G15]
    rep_lbl = ["x³", "x⁵", "x¹⁵"]
    fns     = [G3, G5, G7, G11, G15, f6_1, f6_2]
    labels  = ["x³", "x⁵", "x⁷", "x¹¹", "x¹⁵", "f6(1)", "f6(2)"]
    for (lbl, F) in zip(labels, fns)
        cls = findfirst(R -> are_ccz_equivalent(F, R), reps)
        print_kv(io, lbl, "CCZ-class of $(rep_lbl[cls])")
    end
    println(io, "  Any APN function in F(F₂⁵,F₂⁵) is CCZ-equiv to a power function (Thm 6).")
end

"""
    theorem6_report(io)

Full Theorem 6: 1 CCZ-class for n=4; 3 CCZ-classes for n=5.
"""
function theorem6_report(io::IO = stdout)
    theorem6_n4_report(io)
    theorem6_n5_report(io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem6_report()
end
