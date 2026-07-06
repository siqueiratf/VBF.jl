# Top-level report for Zha, Hu, Sun (2014)
# Paper: Zhengbang Zha, Lei Hu, Siwei Sun (2014),
#        "Constructing new differentially 4-uniform permutations from the inverse function",
#        Finite Fields and Their Applications, 25, 64–71
#
# Pseudocode:
#   1. Print banner with paper info
#   2. Run all theorem/table reports in order
# VBF API used: print_banner

using Dates

include(joinpath(@__DIR__, "helpers.jl"))

include(joinpath(@__DIR__, "theorem1.jl"))
include(joinpath(@__DIR__, "theorem2.jl"))
include(joinpath(@__DIR__, "theorem3.jl"))
include(joinpath(@__DIR__, "theorem4.jl"))
include(joinpath(@__DIR__, "theorem5.jl"))
include(joinpath(@__DIR__, "theorem6.jl"))
include(joinpath(@__DIR__, "example1.jl"))
include(joinpath(@__DIR__, "table1.jl"))
include(joinpath(@__DIR__, "table2.jl"))

function paper_report(io::IO = stdout)
    print_header(io)
    println(io, "Julia $(VERSION), $(Dates.today())")
    println(io, "Reproduction scope: Theorems 1–6, Example 1, Tables 1–2")
    println(io, "Parameter range: sn ≤ 8 (exact), sn ≤ 10 (bounded)")
    println(io)

    theorem1_report(io)
    theorem2_report(io; params = [(1, 3), (1, 5), (1, 7), (3, 3)])
    theorem3_report(io; params = [(1, 2), (1, 4), (1, 6), (1, 8), (3, 2)])
    theorem4_report(io)
    theorem5_report(io; params = [(1, 3), (1, 5), (1, 7), (3, 3)])
    theorem6_report(io)
    example1_report(io)
    table1_report(io)
    table2_report(io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
