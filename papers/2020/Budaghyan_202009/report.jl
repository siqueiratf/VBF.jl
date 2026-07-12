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
    r_alg1 = algorithm1_report(; io, n = 6, K = 1)
    r_alg1b = algorithm1_report(; io, n = 5, K = 2)
    r_cor2 = corollary2_report(; io)
    r_prop6 = proposition6_report(; io)
    r_t2 = table2_report(; io)
    r_s5 = section5_report(; io, n = 5, v = 1)

    print_section("Summary", io)
    print_check("Prop 2 — APN conditions K=1 (n=5, 30 trials)", r_prop2.all_ok, io)
    print_check("Prop 2 — APN conditions K=2 (n=5, 20 trials)", r_prop2b.all_ok, io)
    print_check("Alg 1  — Filtering reduces shift domain", r_alg1.all_ok, io)
    print_check("Prop 3 — CCZ-invariance of Π_F", r_cor2.r3.all_ok, io)
    print_check("Prop 4 — EA-invariance of Π_F^β", r_cor2.r4.all_ok, io)
    print_check("Prop 5 — Quadratic: Π_F^β shift-independent", r_cor2.r5.all_ok, io)
    print_check("Cor 2  — Lower bounds for Gold x^3 n=3..6", r_cor2.rc.all_ok, io)
    print_check("Prop 6 — Gold formula + Table I (n=3..10)", r_prop6.all_ok, io)
    print_check("Table II — m_F for monomial representatives", r_t2.all_ok, io)
    print_check("Sec V  — Single shift kernel dim ≥ 1", r_s5.all_ok, io)

    println(io, "\n  Reproduction scope:")
    println(io, "    [EXACT]   Prop 2 (APN conditions), Alg 1 (filtering)")
    println(io, "    [EXACT]   Props 3/4/5 (invariance), Prop 6 + Table I")
    println(io, "    [EXACT]   Section V structure (single shift system)")
    println(io, "    [BOUNDED] Table II (monomial reps; n=6 polynomial reps need VBFCatalog)")
    println(io, "    [SKIPPED] Full n≤8 invariant table, Table III (expensive search), timing")

    (;
        proposition2 = r_prop2,
        proposition2_k2 = r_prop2b,
        algorithm1 = r_alg1,
        invariance = r_cor2,
        proposition6 = r_prop6,
        table2 = r_t2,
        section5 = r_s5,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    using Dates
    paper_report()
end
