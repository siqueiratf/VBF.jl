# Aggregate report for the Kaleyski (2019) reproduction.
# Paper: Kaleyski, N. (2019), "Changing APN functions at two points",
#        arXiv:1911.02608 / Des. Codes Cryptogr. 88(8):1387–1416
# Section: General — aggregate report driver
#
# VBF API used: (delegated to included files)

using Dates
using TOML

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem17.jl"))
include(joinpath(@__DIR__, "table2.jl"))
include(joinpath(@__DIR__, "table1.jl"))
include(joinpath(@__DIR__, "conjecture21.jl"))
include(joinpath(@__DIR__, "conjecture22.jl"))


"""
    paper_report(io::IO = stdout; save_results::Bool = false) -> NamedTuple

Run all bounded reproducible checks for Kaleyski (2019) and print a structured report.
Returns a NamedTuple of per-claim results.
"""
function paper_report(io::IO = stdout; save_results::Bool = false)
    print_header(io)
    println(io, "  Julia: ", VERSION)
    println(io, "  Date:  ", Dates.today())
    println(io)
    println(io, "  Reproduction scope:")
    println(io, "    Theorem 17    — exact verification on Gold x^3 n=5..8")
    println(io, "    Table 2       — exact: formula (34) vs DDT for n=1..10, formula to n=20")
    println(io, "    Table 1       — bounded demo: catalog APN functions n=5..8")
    println(io, "    Conjecture 21 — bounded demo: catalog power APN functions")
    println(io, "    Conjecture 22 — bounded demo: all catalog APN n=5..8")

    r_thm17  = theorem17_demo(; io)
    r_table2 = table2_report(; io)
    r_table1 = table1_report(; ns=[5,6,7,8], io)
    r_c21    = conjecture21_report(; io)
    r_c22    = conjecture22_report(; ns=[5,6,7,8], io)

    print_section("Summary", io)
    print_check("Theorem 17 condition fails for Gold x^3 n=5..8",     r_thm17.all_fail,     io)
    print_check("Table 2: formula (34) matches DDT for n=2..10",       r_table2.all_match,   io)
    print_check("Table 1: Theorem 17 cond. fails for all catalog APN", r_table1.all_ok,      io)
    print_check("Conjecture 21: power APN share S1 with x^3",          r_c21.all_match,      io)
    print_check("Conjecture 22: no counterexample in catalog n=5..8",  r_c22.no_counterexample, io)

    result = (;
        theorem17  = r_thm17,
        table2     = r_table2,
        table1     = r_table1,
        conj21     = r_c21,
        conj22     = r_c22,
    )

    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "report.toml"), "w") do f
            TOML.print(f, Dict(
                "paper"           => "Kaleyski_201911",
                "theorem17_ok"    => r_thm17.all_fail,
                "table2_ok"       => r_table2.all_match,
                "table1_ok"       => r_table1.all_ok,
                "conjecture21_ok" => r_c21.all_match,
                "conjecture22_ok" => r_c22.no_counterexample,
                "total_checked"   => r_c22.total_checked,
            ))
        end
    end

    return result
end


if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
