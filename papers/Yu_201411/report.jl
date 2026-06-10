# Aggregate report for the Yu-Wang-Li (2014) QAM reproduction.
# Paper: "A Matrix Approach for Constructing Quadratic APN Functions"
# Section: General - aggregate report driver
#
# Run: julia --project=../.. papers/Yu_201411/report.jl

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem1.jl"))
include(joinpath(@__DIR__, "algorithm1.jl"))
include(joinpath(@__DIR__, "exhaustive_search.jl"))

"""
    paper_report(io; save_results = false, run_full_n5 = true,
                 run_full_n6 = false) -> NamedTuple

Run the default reproducible checks for Yu-Wang-Li (2014).
"""
function paper_report(
    io::IO = stdout;
    save_results::Bool = false,
    algorithm1_n::Int = 5,
    algorithm1_limit::Integer = 1,
    max_nodes::Integer = typemax(Int),
    run_full_n5::Bool = true,
    run_full_n6::Bool = false,
    max_evaluations::Integer = 1 << 24,
)
    print_header(io)

    r_theorem = theorem1_report(io; save_results = false)
    r_alg = algorithm1_report(
        io;
        n = algorithm1_n,
        limit = algorithm1_limit,
        max_nodes,
        run_full_n5,
        run_full_n6,
        max_evaluations,
        save_results = false,
    )

    print_section("summary", io)
    print_check("Theorem 1 correspondence checks", r_theorem.all_ok, io)
    print_check("Algorithm 1 bounded reproduction", r_alg.all_ok, io)
    println(io, "\n  [NOTE] Heavy n = 6 exact search is opt-in; n = 7/8 discovery and")
    println(io, "  permutation-equivalence campaigns are outside the default report.")
    println(io, "  [NOTE] Long-running resumable searches are available via exhaustive_search.jl.")

    result = (;
        theorem1 = r_theorem,
        algorithm1 = r_alg,
        all_ok = r_theorem.all_ok && r_alg.all_ok,
    )

    if save_results
        path = write_results_toml(Dict("report" => result), "report.toml")
        println(io, "\n  Results written to: ", path)
    end

    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
