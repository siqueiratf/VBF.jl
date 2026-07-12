# Aggregate report for the Budaghyan et al. (2020) reproduction.
# Paper: Budaghyan, Carlet, Helleseth, Kaleyski (2020),
#        "On the Distance Between APN Functions", IEEE Trans. Inf. Theory
# Section: General — aggregate report driver
#
# VBF API used: (all calls delegated to included files)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition2.jl"))
include(joinpath(@__DIR__, "algorithm1.jl"))
include(joinpath(@__DIR__, "corollary2.jl"))
include(joinpath(@__DIR__, "proposition6.jl"))
include(joinpath(@__DIR__, "table2.jl"))
include(joinpath(@__DIR__, "table3.jl"))
include(joinpath(@__DIR__, "section5.jl"))

"""
    paper_report(io::IO = stdout; save_results::Bool = false) -> NamedTuple

Run all bounded/default reproducible checks for Budaghyan et al. (2020)
and print a structured report.
"""
function paper_report(io::IO = stdout; save_results::Bool = false)
    print_header(io)
    println(io, "  Julia ", VERSION, "   Date: ", Dates.today())

    r_prop2 = proposition2_random_check(; io, n = 5, K = 1, ntrials = 30)
    r_prop2b = proposition2_random_check(; io, n = 5, K = 2, ntrials = 20)
    r_prop2p = proposition2_positive_check(; io)
    r_alg1 = algorithm1_report(; io, n = 6, K = 1)
    r_alg1b = algorithm1_report(; io, n = 5, K = 2)
    r_ex = algorithm1_examples_report(; io)
    r_cor2 = corollary2_report(; io)
    r_prop6 = proposition6_report(; io)
    r_t2 = table2_report(; io)
    r_t3 = table3_report(; io)
    r_s5 = section5_report(; io, n = 5, v = 1)

    print_section("Summary", io)
    print_check("Prop 2 — APN conditions K=1 (n=5, 30 trials)", r_prop2.all_ok, io)
    print_check("Prop 2 — APN conditions K=2 (n=5, 20 trials)", r_prop2b.all_ok, io)
    print_check("Prop 2 — positive (APN) instance: U={0..7}, v=α²⁵", r_prop2p.all_ok, io)
    print_check("Alg 1  — Filtering reduces shift domain", r_alg1.all_ok, io)
    print_check("Alg 1  — Section IV-A Examples (a), (b), (c)", r_ex.all_ok, io)
    print_check("Prop 3 — CCZ-invariance of Π_F (CCZ-but-not-EA witness)", r_cor2.r3.all_ok, io)
    print_check("Prop 4 — EA-invariance of Π_F^β (non-trivial A₁, A₂, A)", r_cor2.r4.all_ok, io)
    print_check("Prop 5 — Quadratic: Π_F^β shift-independent", r_cor2.r5.all_ok, io)
    print_check("Cor 2  — Lower bounds for Gold x^3 n=3..6", r_cor2.rc.all_ok, io)
    print_check("Prop 6 — Gold eq. (9) + Table I (n=3..10)", r_prop6.table1.all_ok, io)
    print_check("Sec IV-E — Bound tightness for n ≤ 4 (P1 recorded)", r_prop6.witnesses.all_ok, io)
    print_check("Table II — n=4/5 monomials, n=6 row 1.1, all of n=7", r_t2.all_ok, io)
    print_check("Table III — F₂⁵ EA-representatives", r_t3.all_ok, io)
    print_check("Sec V  — Single-shift system + exhaustive minimum distance", r_s5.all_ok, io)

    println(io, "\n  Reproduction scope:")
    println(io, "    [EXACT]   Prop 2 (APN conditions, incl. a true-APN instance)")
    println(io, "    [EXACT]   Alg 1 (filtering) + Section IV-A Examples (a), (b), (c)")
    println(io, "    [EXACT]   Props 3/4/5 (invariance), Prop 6 + Table I + tightness witnesses")
    println(io, "    [EXACT]   Section V (APN and non-APN F; exhaustive single-shift distance)")
    println(io, "    [EXACT]   Table II: n=4/5 monomials, n=6 row 1.1, and the whole n=7 block")
    println(io, "    [EXACT]   Table III: m_F, lower-bound and single-shift-distance columns")
    println(io, "    [BLOCKED] Table II n=6 rows 1.2, 2.1-2.12 and all of n=8 — the Edel-Pott")
    println(io, "              representatives and their labels are absent from the catalog")
    println(io, "    [BLOCKED] Table III BCP-1 / BCP-2 rows — absent from VBF and the catalog")
    println(io, "    [QUOTED]  Table III \"actual distance\" / \"number of shifts\" columns")
    println(io, "    [PAPER]   P1 (n=3 tightness witness), P2 (eq. (9), b=β³ branch),")
    println(io, "              P3 (Example (c) is β-sensitive; β pinned to 7)")

    (;
        proposition2 = r_prop2,
        proposition2_k2 = r_prop2b,
        proposition2_positive = r_prop2p,
        algorithm1 = r_alg1,
        examples = r_ex,
        invariance = r_cor2,
        proposition6 = r_prop6,
        table2 = r_t2,
        table3 = r_t3,
        section5 = r_s5,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    using Dates
    paper_report()
end
