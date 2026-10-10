# Aggregate report for the Göloğlu–Kölsch (2025) reproduction.
# Paper: Faruk Göloğlu, Lukas Kölsch (2025), "Equivalences of biprojective
#        almost perfect nonlinear functions", Electron. J. Combin.
# Section: General — aggregate report driver
#
# VBF API used: print_banner, print_section, print_check, print_kv
#               (all computation delegated to the per-claim files)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "lemma2_1.jl"))
include(joinpath(@__DIR__, "lemma3_2.jl"))
include(joinpath(@__DIR__, "theorem3_3.jl"))
include(joinpath(@__DIR__, "lemma4_5.jl"))
include(joinpath(@__DIR__, "lemma4_7.jl"))
include(joinpath(@__DIR__, "lemmaA_1.jl"))
include(joinpath(@__DIR__, "theorem4_8.jl"))
include(joinpath(@__DIR__, "theorem5_1.jl"))
include(joinpath(@__DIR__, "theorem6_1.jl"))
include(joinpath(@__DIR__, "lemmaB_2.jl"))
include(joinpath(@__DIR__, "theoremB_3.jl"))
include(joinpath(@__DIR__, "theoremC_3.jl"))

using VBF
using Dates

"""
    paper_report(io = stdout; full_search = false, save_results = false) -> NamedTuple

Run every bounded reproduction check for Göloğlu–Kölsch (2025).

Reproduction scope
------------------
* EXACT   — Lemma 2.1, Lemma 3.2, Theorem 3.3 (m=6, exhaustive), Theorem C.3,
            Lemma 4.5, Lemma 4.7 (exhaustive at m=2), Lemma A.1, Theorem 4.8,
            Theorem 5.1(a,b,d), Theorem 6.1, Lemma B.1/B.2, Theorem B.3.
* BOUNDED — F₄ APN at m = 10, 14 (`full_search=true`); Lemma B.2 at m = 5
            (`full_search=true`); Theorem 6.1 including F₄ at m = 6.
* NOT RUN — nothing in the paper is deferred as Magma-only; the only claims not
            *tested* in their stated range are Theorem 5.1(c)/Cor 5.2 and
            Theorem 6.1-with-F₄, because F₄ needs m ≡ 2 (mod 4) while both
            theorems require m ≠ 6 — the two conditions have no computationally
            reachable overlap (the next case is m = 10, i.e. n = 20).
"""
function paper_report(io::IO = stdout; full_search::Bool = false, save_results::Bool = false)
    print_header(io)
    print_kv("Julia", string(VERSION), io)
    print_kv("date", string(Dates.today()), io)
    print_kv("field", "M = F_{2^m}, F = F_{2^{2m}} identified with M × M", io)
    print_kv("modulus", "VBF.primitive_polynomial(m) — the paper pins none", io)
    print_kv("full_search", full_search, io)

    r_l21 = lemma2_1_report(io)
    r_l32 = lemma3_2_report(io)
    r_t33 = theorem3_3_report(io; full_search = full_search, save_results = save_results)
    r_tc3 = theoremC_3_report(io)
    r_l45 = lemma4_5_report(io)
    r_l47 = lemma4_7_report(io)
    r_la1 = lemmaA_1_report(io)
    r_t48 = theorem4_8_report(io)
    r_t51 = theorem5_1_report(io)
    r_t61 = theorem6_1_report(io; include_f4 = full_search)
    r_lb2 = lemmaB_2_report(io; full_search = full_search)
    r_tb3 = theoremB_3_report(io)

    print_section("summary", io)
    print_check("Lemma 2.1  — biprojective APN criterion", r_l21.all_ok, io)
    print_check("Lemma 3.2  — gcd identities", r_l32.all_ok, io)
    print_check("Theorem 3.3 — F₄ is APN (NEW FAMILY)", r_t33.all_ok, io)
    print_check("Theorem C.3 — F₄ is 3-to-1, classical Walsh spectrum", r_tc3.all_ok, io)
    print_check("Lemma 4.5  — Z^{(q,r)} ≤ Aut_EL(F)", r_l45.all_ok, io)
    print_check("Lemma 4.7  — normalizer / centralizer of M, M_P", r_l47.all_ok, io)
    print_check("Lemma A.1  — C_F index, condition (C)", r_la1.all_ok, io)
    print_check("Theorem 4.8 — equivalence shape theorem", r_t48.all_ok, io)
    print_check("Theorem 5.1 — inequivalences within families", r_t51.all_ok, io)
    print_check("Theorem 6.1 — inequivalences between families", r_t61.all_ok, io)
    print_check("Lemma B.1/B.2 — root-free count, transitive G-action", r_lb2.all_ok, io)
    print_check("Theorem B.3 — Carlet (m even) ⊂ Zhou–Pott", r_tb3.all_ok, io)

    print_section("paper issues found", io)
    for line in [
        "1. Appendix C, classical extended Walsh spectrum. The multiplicity of",
        "   2^{(n+2)/2} is printed as (2ⁿ−1)·2ⁿ/3; the correct value is (2ⁿ−1)·2^{n−2}/3.",
        "   The printed multiset sums to 5·2^{n−2}(2ⁿ−1), which exceeds the 2ⁿ(2ⁿ−1)",
        "   pairs (b≠0, a) available — it cannot hold for ANY function. Verified on",
        "   Gold (n=6) and on F₄ (n=12). Theorem C.3's substance is unaffected.",
        "",
        "2. Proof of Theorem 5.1(a),(b), the explicit q ↔ q̄ maps. With M₂ = M₃ = x^{q̄}",
        "   and L₁ = x, the printed L₄ does not satisfy F_q ∘ M = L ∘ F_{q̄}:",
        "     F₁: printed L₄ = x^{q̄}  — correct L₄ = x^{q}",
        "     F₂: printed L₄ = x^{q}   — correct L₄ = x^{q²}",
        "   Corrected maps verified pointwise (m=5). The CONCLUSION (F_q ≅ F_{q̄}) holds.",
        "",
        "3. Proof of Theorem 5.1(c)(i), the F₄ map. Printed L₄ = (B^Q/a)·x^Q; the",
        "   correct coefficient is (a/B), i.e. L₄ = (a/B)·x^Q. M, L₁ and the target",
        "   a' = B^{Q+1}/a are all as printed. Corrected map verified pointwise (m=6).",
        "",
        "4. Theorem B.3's target is a Zhou–Pott function with j = 0 (its second",
        "   component is xy), but Table 2.1's Zhou–Pott note requires 0 < j < m; and the",
        "   construction yields the ZP pair with its two OUTPUT coordinates swapped.",
        "   Neither affects the theorem (an output swap is an EA-equivalence, and Lemma",
        "   A.1 explicitly contemplates 'Zhou–Pott with j ≠ 0'), but Table 2.1's stated",
        "   j-range and the theorem's target are inconsistent as written.",
        "",
        "5. Cosmetic: Eq. (A.6) writes the Taniguchi second component as x^{q²}y, while",
        "   Table 2.1 and the proof of Theorem 6.1 use x·y^{q²}. The two differ by",
        "   swapping x and y; the conclusion (c₂ = c₃ = 0) is the same either way.",
    ]
        println(io, "  ", line)
    end

    result = (;
        lemma2_1 = r_l21,
        lemma3_2 = r_l32,
        theorem3_3 = r_t33,
        theoremC_3 = r_tc3,
        lemma4_5 = r_l45,
        lemma4_7 = r_l47,
        lemmaA_1 = r_la1,
        theorem4_8 = r_t48,
        theorem5_1 = r_t51,
        theorem6_1 = r_t61,
        lemmaB_2 = r_lb2,
        theoremB_3 = r_tb3,
    )

    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "paper_report.txt"), "w") do fh
            paper_report(fh; full_search = full_search, save_results = false)
        end
    end
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
