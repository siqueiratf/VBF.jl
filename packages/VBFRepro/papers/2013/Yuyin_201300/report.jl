# Aggregate report for Yu, Wang, Li (2013) reproduction.
# Paper: Yu, Wang, Li (2013), "Constructing Differentially 4 Uniform
#        Permutations from Known Ones"
# Section: General — aggregate report driver
#
# VBF API used: (all calls delegated to included files)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition1.jl"))
include(joinpath(@__DIR__, "proposition3.jl"))
include(joinpath(@__DIR__, "theorem1.jl"))

function paper_report(io::IO = stdout; save_results::Bool = false)
    print_header(io)

    r_prop1   = proposition1_report(io)
    r_prop3   = proposition3_report(io)
    r_thm1    = theorem1_report(io)

    print_section("Summary", io)
    print_check(io, "Proposition 1: all swaps δ∈{2,4}",  r_prop1.all_valid)
    print_check(io, "Example 1: δ=4, A=54",              r_prop1.example1_ok)
    print_check(io, "1176 Problem 1 examples",            r_prop1.count_problem1 == 1176)
    print_check(io, "Theorem 1: trace condition verified", r_thm1.all_match)
    print_check(io, "Remark 2: 9180 diff-4-uniform (n=8)", r_thm1.count_du4 == 9180)

    result = (; proposition1=r_prop1, theorem1=r_thm1)

    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "report.toml"), "w") do f
            println(f, "# Yu, Wang, Li (2013) aggregate report")
            println(f, "proposition1_all_valid = $(r_prop1.all_valid)")
            println(f, "example1_ok = $(r_prop1.example1_ok)")
            println(f, "count_problem1 = $(r_prop1.count_problem1)")
            println(f, "theorem1_all_match = $(r_thm1.all_match)")
            println(f, "theorem1_count_du4 = $(r_thm1.count_du4)")
        end
    end

    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
