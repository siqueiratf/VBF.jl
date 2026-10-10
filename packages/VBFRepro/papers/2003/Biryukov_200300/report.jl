# Top-level report for Biryukov_200300 paper reproduction.
# Paper: Biryukov et al. (2003), "A Toolbox for Cryptanalysis: Linear and Affine
#        Equivalence Algorithms", Eurocrypt 2003.
#
# Pseudocode:
#   1. Print header with paper metadata and reproduction scope.
#   2. Run each section's report function.
#   3. Summarise pass/fail.
# VBF API used: (delegated to section files)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "section2.jl"))
include(joinpath(@__DIR__, "section3.jl"))
include(joinpath(@__DIR__, "section4.jl"))
include(joinpath(@__DIR__, "section5.jl"))
include(joinpath(@__DIR__, "section6.jl"))
include(joinpath(@__DIR__, "section7.jl"))
include(joinpath(@__DIR__, "table2.jl"))
include(joinpath(@__DIR__, "table4.jl"))

function paper_report(io::IO = stdout; full_search::Bool = false)
    print_header(io)

    ok2 = section2_report(io)
    ok3 = section3_report(io)
    ok4 = section4_report(io; full_search)
    ok5 = section5_report(io)
    ok6 = section6_report(io)
    ok7 = section7_report(io; full_search)
    okA = table2_report(io)
    okB = table4_report(io; full_search)

    println(io, "\n---")
    all_ok = ok2 && ok3 && ok4 && ok5 && ok6 && ok7 && okA && okB
    status = all_ok ? "PASS" : "FAIL"
    println(io, "Overall: [$status]")
    return all_ok
end

if abspath(PROGRAM_FILE) == @__FILE__
    full = lowercase(get(ENV, "FULL_SEARCH", "false")) == "true"
    ok = paper_report(; full_search = full)
    exit(ok ? 0 : 1)
end
