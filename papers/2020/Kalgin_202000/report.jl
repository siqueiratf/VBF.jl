# Top-level report driver for the Kalgin–Idrisova (2020) reproduction.
# Paper: Kalgin, Idrisova (2020), "The classification of quadratic APN functions
#        in 7 variables", Cryptography and Communications 14, pp. 691–715.
# VBF API used: (see individual section files)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition2.jl"))
include(joinpath(@__DIR__, "section4.jl"))
include(joinpath(@__DIR__, "section5.jl"))
include(joinpath(@__DIR__, "table3.jl"))

"""
    paper_report(io; save_results) -> Nothing

Full reproduction report for Kalgin–Idrisova (2020).
Runs all sections; completes in a few minutes without full_search.
"""
function paper_report(io::IO = stdout; save_results::Bool = false)
    print_header(io)
    println(io)
    println(io, "Julia $(VERSION)  |  Date: $(Dates.today())")
    println(io)
    println(io, "Reproduction scope:")
    println(io, "  [EXACT]   §3 Theorem 1, Proposition 1 (implemented as stated),")
    println(io, "            Examples 1-2, Proposition 3's 5-variable G")
    println(io, "  [EXACT]   §3 Proposition 2 extension search (small n)")
    println(io, "  [SUBST]   §3 n=5→6 uses VBF's extend_quadratic_apn")
    println(io, "            (Beierle-Leander-Perrin tree search), NOT Kalgin's §3")
    println(io, "            pruned Proposition-2 search; bounded sample only")
    println(io, "  [EXACT]   §4 cyclic T matrix construction (n≤5): covers all")
    println(io, "            quadratic-APN CCZ-classes — 1/1, 1/1, 2/2")
    println(io, "  [EXACT]   §4 new n=7 APN function (polynomial form) + σ-based")
    println(io, "            CCZ-inequivalence to the other 487 known n=7 classes")
    println(io, "  [PARTIAL] §5 first-row normalisation computed; the 5 second-row")
    println(io, "            cases checked against Theorem 1 / Proposition 1")
    println(io, "  [LOADED]  §5 per-case counts 3+2+0+220+263 = 488 transcribed from")
    println(io, "            the paper — NOT recomputed (supercomputer search)")
    println(io, "  [EXACT]   §6 Table 3 stacked APN examples (n=4,5,6), §6.1 quadratic")
    println(io, "            parts (Dillon/Kasami/inverse), §6.2 explicit n=6 example")
    println(io, "  [ABSENT]  §3's headline n=5→6 all-13-classes search (needs the")
    println(io, "            paper's incremental pruning), §5's P1/P2 minimisation,")
    println(io, "            Propositions 4-6, Theorem 2/3, Corollaries 1-2")

    r2 = section3_report(io; save_results = save_results)
    r4 = section4_report(io; save_results = save_results)
    r5 = section5_report(io; save_results = save_results)
    r6 = table3_report(io; save_results = save_results)

    print_section("Overall pass/fail summary", io)
    print_check("§3 Theorem 1 holds on every APN matrix checked", r2.theorem1_holds, io)
    print_check("§3 Proposition 1 ⟺ is_qam", r2.proposition1_agrees_with_is_qam, io)
    print_check("§3 Proposition 3: paper's G is differentially 4-uniform", r2.proposition3_du == 4, io)
    print_check("§3 Proposition 2: n=3→n=4 covers the single n=4 class",
                r2.n3_to_4_null_classes == 1, io)
    print_check("§4 cyclic T covers all quadratic-APN CCZ-classes for n=4 (1/1) and n=5 (2/2)",
                r4.n4_ea_classes == 1 && r4.n5_ea_classes == 2 &&
                r4.n5_covers_gold_x3 && r4.n5_covers_gold_x5, io)
    print_check("§4 new n=7 function: APN", r4.new_n7_du == 2, io)
    print_check("§4 new n=7 function: quadratic", r4.new_n7_deg == 2, io)
    print_check("§4 new n=7 function: CCZ-inequivalent to the other " *
                "$(r4.n7_sigma_mismatches) of the $(r4.n7_catalog_classes) known n=7 classes",
                r4.n7_sigma_mismatches == r4.n7_catalog_classes - 1, io)
    print_check("§5 first row of a quadratic APN normalises to (0,1,2,4,8,16,32)",
                r5.first_row_normalisation_ok, io)
    print_check("§5 the 5 second-row cases satisfy Theorem 1 / Proposition 1",
                r5.all_cases_compatible, io)
    print_check("§5 total CCZ-classes = 488 (transcribed)", r5.total_ccz_classes == 488, io)
    print_check("§6 Table 3 + §6.1 + §6.2 all verified", r6.all_ok, io)

    nothing
end

using Dates

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
