# Implements full paper report
# Paper: Kaleyski, Nesheim, Stănică (2022), "A doubly-infinite family of 0-APN monomials"
# Section: All
#
# Pseudocode:
#   1. Print header with scope/date
#   2. Run theorem1_report, remark2_report, remark3_report
# VBF API used: print_banner, print_section, print_kv

using Dates

include(joinpath(@__DIR__, "theorem1.jl"))
include(joinpath(@__DIR__, "remark2.jl"))
include(joinpath(@__DIR__, "remark3.jl"))

function paper_report(io::IO = stdout; max_n::Int = 100)
    print_header(io)
    println(io)
    print_kv(io, "Julia", string(VERSION))
    print_kv(io, "date", string(Dates.today()))
    print_kv(io, "scope", "Theorem 1, Remarks 1–3; Section 3 out-of-scope (odd char)")
    print_kv(io, "max_n", string(max_n))
    println(io)

    theorem1_report(io; max_n)
    println(io)
    remark2_report(io; max_n)
    println(io)
    remark3_report(io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
