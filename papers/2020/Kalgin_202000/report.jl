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
    println(io, "  [EXACT]   §3 Proposition 2 criterion (small n)")
    println(io, "  [EXACT]   §4 cyclic T matrix construction (n≤5)")
    println(io, "  [EXACT]   §4 new n=7 APN function (polynomial form)")
    println(io, "  [EXACT]   §6 Table 3 stacked APN examples (n=4,5,6)")
    println(io, "  [LOADED]  §5 classification counts (from paper; exhaustive=infeasible)")

    r2 = section3_report(io; save_results = save_results)
    r4 = section4_report(io; save_results = save_results)
    r5 = section5_report(io; save_results = save_results)
    r6 = table3_report(io; save_results = save_results)

    print_section("Overall pass/fail summary", io)
    print_check("§3 Proposition 2: n=3→n=4 extensions found", r2.n3_to_4_null_classes >= 1, io)
    print_check("§4 new n=7 function: APN", r4.new_n7_du == 2, io)
    print_check("§4 new n=7 function: quadratic", r4.new_n7_deg == 2, io)
    print_check("§4 new n=7 function: CCZ-distinct from Gold", r4.new_n7_distinct_from_gold, io)
    print_check("§5 total CCZ-classes = 488", r5.total_ccz_classes == 488, io)
    print_check("§6 Table 3 all examples verified", r6.all_ok, io)

    nothing
end

using Dates

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
