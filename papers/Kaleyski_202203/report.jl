# Aggregate report for the Kaleyski (2022) reproduction.
# Paper: Kaleyski, N. (2022), "Deciding EA-equivalence via invariants",
#        Cryptography and Communications, 2021
# Section: General — aggregate report driver
#
# VBF API used: (delegated to included files)

using Dates
using TOML

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition1.jl"))
include(joinpath(@__DIR__, "proposition4.jl"))
include(joinpath(@__DIR__, "algorithm1.jl"))
include(joinpath(@__DIR__, "algorithm2.jl"))
include(joinpath(@__DIR__, "algorithm3.jl"))
include(joinpath(@__DIR__, "section5.jl"))


"""
    paper_report(io::IO = stdout; n_values, save_results) -> NamedTuple

Aggregate report for Kaleyski (2022). Prints structured results for all
reproducible claims. Returns a NamedTuple with per-claim results.

Timing experiments (Table 1 timing columns, Table 2) are excluded per
reproduction scope (skip expensive benchmarks).
"""
function paper_report(
    io::IO = stdout;
    n_values::Vector{Int} = [5, 6],
    save_results::Bool = false,
)
    print_header(io)
    println(io, "  Julia: ", VERSION)
    println(io, "  Date:  ", Dates.today())
    println(io)
    println(io, "  Reproduction scope:")
    println(io, "    Propositions 1,2,4 — exact verification on Gold x^3 n=5,6")
    println(io, "    Algorithms 1,2,3   — exact on catalog APN, n=5,6")
    println(io, "    Section 5          — bounded: catalog quadratic APN, n=5,6")
    println(io, "    Table 1 timing     — SKIPPED (timing experiments excluded)")
    println(io, "    Table 2            — SKIPPED (timing experiments excluded)")

    r_p1  = proposition1_report(; io)
    r_p4  = proposition4_report(; io, n_values, k_values = [4, 6])
    r_a1  = algorithm1_report(; io, n_values)
    r_a2  = algorithm2_report(; io, n = (6 in n_values ? 6 : n_values[1]))
    r_a3  = algorithm3_report(; io)
    r_s5  = section5_report(; io, n_values)

    print_section("Summary", io)
    print_check(
        "Prop 1/Cor 3: sigma multiset EA-invariant (k=2,3,4,6)",
        r_p1.r1.all_ok && r_p1.r2.ok,
        io,
    )
    print_check(
        "Prop 4: Walsh formula == direct enumeration",
        r_p4.all_ok,
        io,
    )
    print_check(
        "Alg 1: partition signatures equal for EA-equiv pairs",
        r_a1.all_ok,
        io,
    )
    print_check(
        "Alg 2: Gold x^3 n=6 |K| == 1008 (Table 1, row 1.1)",
        r_a2.gold_ok,
        io,
    )
    print_check(
        "Alg 3: inner_permutation recovers A2 (n=5)",
        r_a3.recovered_ok,
        io,
    )
    print_check(
        "Sec 5: odd-n partitions are trivial (2-bucket)",
        r_s5.odd_trivial_ok,
        io,
    )
    print_check(
        "Sec 5: Gold x^3 even-n partitions are Gold-like (3-bucket)",
        r_s5.gold_ok,
        io,
    )

    result = (;
        proposition1 = r_p1,
        proposition4 = r_p4,
        algorithm1   = r_a1,
        algorithm2   = r_a2,
        algorithm3   = r_a3,
        section5     = r_s5,
    )

    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "report.toml"), "w") do f
            TOML.print(
                f,
                Dict(
                    "paper"        => "Kaleyski_202203",
                    "prop1_ok"     => r_p1.r1.all_ok,
                    "prop4_ok"     => r_p4.all_ok,
                    "alg2_gold_ok" => r_a2.gold_ok,
                    "alg3_ok"      => r_a3.recovered_ok,
                    "sec5_odd_ok"  => r_s5.odd_trivial_ok,
                    "sec5_gold_ok" => r_s5.gold_ok,
                ),
            )
        end
    end

    return result
end


if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
