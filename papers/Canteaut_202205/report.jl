# Aggregate report for Canteaut–Couvreur–Perrin (2022) reproduction.
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: General — aggregate report driver
#
# VBF API used: (delegated to included files)

using Dates

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition14.jl"))
include(joinpath(@__DIR__, "section3_2.jl"))
include(joinpath(@__DIR__, "proposition22.jl"))
include(joinpath(@__DIR__, "corollary24.jl"))
include(joinpath(@__DIR__, "algorithm1.jl"))
include(joinpath(@__DIR__, "section4_3.jl"))

"""
    paper_report(io; n_values, save_results) -> NamedTuple

Aggregate report for Canteaut–Couvreur–Perrin (2022).
Prints structured results for all reproducible claims.

Reproduction scope:
  - Proposition 14 — exact: derivative identity on Gold x^3 n=5,6
  - Section 3.2 — exact: Jac_lin chain rule for EA-equiv on Gold x^3 n=5,6
  - Proposition 22 — exact: rank_dist ↔ DDT distribution on Gold x^3 n=5,6
  - Corollary 24 — exact: APN ↔ Jac_lin rank n-1 on Gold x^3 n=5,6
  - Algorithm 1 — bounded: EA-recovery demo on Gold x^3 n=5 (exhaustive over triples)
  - Section 4.3 — exact: 6-bit APN partition into 13 EA-classes via ortho-derivative
  - 8-bit partitioning (21 102 functions) — SKIPPED (requires large corpus)
  - Timing benchmarks (Table 1) — SKIPPED
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
    println(io, "    Props 22 and 14, Section 3.2, Cor 24 — exact on Gold x^3 n=5,6")
    println(io, "    Algorithm 1 — bounded demo n=5 (exhaustive over rank-triples)")
    println(io, "    Section 4.3 — exact: 15 n=6 quadratic APN → 13 EA-classes")
    println(io, "    8-bit partitioning (21 102 fns) — SKIPPED (large corpus)")
    println(io, "    Timing benchmarks (Table 1) — SKIPPED")

    r_p35  = proposition14_report(; io, n_values)
    r_p37  = section3_2_report(; io, n_values)
    r_p312 = proposition22_report(; io, n_values)
    r_c314 = corollary24_report(; io, n_values)
    r_alg1 = algorithm1_report(; io, n=5)
    r_s43  = section4_3_report(; io)

    print_section("Summary", io)
    print_check("Prop 14: Δ_a F(x) ⊕ Δ_a F(0) = Jac_lin F(a)·x", r_p35.all_ok, io)
    print_check("Section 3.2: Jac_lin chain rule for EA-equiv functions", r_p37.all_ok, io)
    print_check("Prop 22: rank distribution ↔ DDT distribution", r_p312.all_ok, io)
    print_check("Cor 24: APN ↔ Jac_lin rank = n-1", r_c314.all_ok, io)
    print_check("Algorithm 1: EA triple recovered and verified", r_alg1.all_ok, io)
    print_check("Section 4.3: 6-bit APN partitioned into 13 EA-classes", r_s43.all_ok, io)

    overall = r_p35.all_ok && r_p37.all_ok && r_p312.all_ok &&
              r_c314.all_ok && r_alg1.all_ok && r_s43.all_ok
    print_check("Overall reproduction", overall, io)

    return (;
        proposition14  = r_p35,
        section3_2  = r_p37,
        proposition22 = r_p312,
        corollary24   = r_c314,
        algorithm1      = r_alg1,
        section4_3      = r_s43,
        overall,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
