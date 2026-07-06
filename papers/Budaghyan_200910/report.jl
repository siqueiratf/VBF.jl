# Aggregate report for the Budaghyan–Carlet–Leander (2009) reproduction.
# Paper: Budaghyan, Carlet, Leander (2009), "On a construction of quadratic APN
#        functions", IEEE Trans. Inf. Theory 55(9):4218-4229.
# Section: General — aggregate report driver.
#
# VBF API used: (all calls delegated to included claim files)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition1.jl"))
include(joinpath(@__DIR__, "proposition2.jl"))
include(joinpath(@__DIR__, "proposition3.jl"))
include(joinpath(@__DIR__, "proposition4.jl"))
include(joinpath(@__DIR__, "proposition5.jl"))
include(joinpath(@__DIR__, "proposition6.jl"))
include(joinpath(@__DIR__, "proposition7.jl"))
include(joinpath(@__DIR__, "proposition8.jl"))
include(joinpath(@__DIR__, "corollary1.jl"))
include(joinpath(@__DIR__, "corollary2.jl"))
include(joinpath(@__DIR__, "corollary3.jl"))
include(joinpath(@__DIR__, "corollary4.jl"))

"""
    paper_report(io=stdout; full_search=false, save_results=false) -> NamedTuple

Run every bounded/default reproducible check for Budaghyan–Carlet–Leander (2009)
and print a structured report. `full_search=true` enables the gated large-n and
full-CCZ paths.
"""
function paper_report(io::IO = stdout; full_search::Bool = false, save_results::Bool = false)
    print_header(io)
    println(io, "Julia ", VERSION, " — reproduction scope:")
    println(io, "  EXACT: Prop 1,2,4,5,6,7,8; Cor 1,2; APN-ness of eqs (4)-(8).")
    println(io, "  BOUNDED: Cor 3/4 CCZ via ortho-derivative; Prop 3 superfield injectivity.")
    println(io, "  NOT RUN: Open Problem 1 (search to n=14); full linear-code CCZ (gated).")

    r = (;
        proposition1 = proposition1_report(io; full_search, save_results),
        proposition2 = proposition2_report(io; save_results),
        proposition3 = proposition3_report(io; save_results),
        proposition4 = proposition4_report(io; save_results),
        proposition5 = proposition5_report(io; save_results),
        proposition6 = proposition6_report(io; save_results),
        proposition7 = proposition7_report(io; save_results),
        proposition8 = proposition8_report(io; save_results),
        corollary1 = corollary1_report(io; full_search, save_results),
        corollary2 = corollary2_report(io; save_results),
        corollary3 = corollary3_report(io; full_search, save_results),
        corollary4 = corollary4_report(io; full_search, save_results),
    )

    print_section("summary", io)
    for (name, res) in pairs(r)
        print_check(String(name), res.all_ok, io)
    end
    println(io, "\n  [NOTE] n=9 eqs (7),(8) are catalog-gap candidates (new quadratic APN")
    println(io, "         families, CCZ-distinct from Gold/base by ortho-derivative).")
    println(io, "         NOT written to VBFCatalog by this reproduction.")

    all_ok = all(res.all_ok for res in r)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "report.toml"), "w") do f
            println(f, "# Budaghyan-Carlet-Leander (2009) aggregate report")
            println(f, "all_ok = $all_ok")
            for (name, res) in pairs(r)
                println(f, "$(name)_ok = $(res.all_ok)")
            end
        end
    end
    (; all_ok, r...)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
