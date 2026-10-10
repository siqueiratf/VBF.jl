# Implements Section 7: dimension 6 — 14 canonical APN CCZ classes (Table 5),
# one of which the paper reports as previously unknown.
# Paper: Brinkmann, Leander (2008), "On the Classification of APN Functions up to
#        Dimension Five", Designs, Codes and Cryptography 49(1-3):273-288.
# Section: 7 — Dimension 6
#
# Pseudocode:
#   1. All 14 reconstructed Table 5 LUTs are APN
#   2. Γ-rank (a CCZ invariant) reproduces the paper's Γ-rank row for all 14
#   3. Row 3 is CCZ equivalent to the Gold power function x³ (paper's `CCZ eq.` row)
#   4. Row 13 — the "new" class — has the unique Γ-rank 1300 and is the only
#      degree-3 row, so it is CCZ inequivalent to the other 13 by an invariant
# VBF API used: differential_uniformity, algebraic_degree, gamma_rank, delta_rank,
#               are_ccz_equivalent, gold_apn

isdefined(@__MODULE__, :table5_luts) || include(joinpath(@__DIR__, "table5.jl"))

"""
    section7_report(io)

Section 7 / Table 5: the 14 canonical n=6 APN CCZ classes.
"""
function section7_report(io::IO = stdout)
    print_section(io, "Section 7 / Table 5 — 14 canonical APN classes in F(F₂⁶,F₂⁶)")
    println(io, "  Reconstruction: shared 33-value prefix ++ per-row 31-value tail.")

    luts = table5_luts()
    ranks = table5_gamma_ranks()
    ccz = table5_ccz_column()

    all_apn = true
    all_rank = true
    for (i, F) in enumerate(luts)
        du = differential_uniformity(F)
        g = gamma_rank(F)
        all_apn &= (du == 2)
        all_rank &= (g == ranks[i])
        print_kv(io, "row $i",
                 "du=$du  deg=$(algebraic_degree(F))  Γ=$g (paper $(ranks[i]))  " *
                 "Δ-rank=$(delta_rank(F))  CCZ eq. $(ccz[i])")
    end
    print_check(io, "all 14 reconstructed LUTs are APN", all_apn)
    print_check(io, "all 14 Γ-ranks reproduce the paper's Γ-rank row", all_rank)

    print_section(io, "Section 7 — the paper's `CCZ eq.` claims")
    G3 = gold_apn(6, 1)
    print_check(io, "row 3 ~ x³ (Gold) CCZ-equivalent — paper's `x^3` entry",
                are_ccz_equivalent(luts[3], G3; on_inconclusive = :missing) === true)
    print_kv(io, "Γ-rank of gold_apn(6,1)", string(gamma_rank(G3)))

    print_section(io, "Section 7 — row 13, the class the paper reports as new")
    r13 = gamma_rank(luts[13])
    unique13 = count(==(r13), [gamma_rank(F) for F in luts]) == 1
    deg13 = algebraic_degree(luts[13])
    others = [algebraic_degree(luts[i]) for i in 1:14 if i != 13]
    print_check(io, "row 13 has the unique Γ-rank $r13 among the 14 rows", unique13)
    print_check(io, "row 13 is the only row of algebraic degree $deg13 (others all 2)",
                deg13 == 3 && all(==(2), others))
    println(io, "  Γ-rank is a CCZ invariant, so row 13 is CCZ inequivalent to rows 1..12,14.")
    println(io, "  The catalog already carries this class as `reprs6_13` (Γ=1300, Δ=152).")
end

if abspath(PROGRAM_FILE) == @__FILE__
    section7_report()
end
