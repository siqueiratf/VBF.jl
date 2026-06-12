# Top-level paper report for Yu et al. (2020)
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
# VBF API used: all — aggregates results from per-claim files

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem2.jl"))
include(joinpath(@__DIR__, "proposition1.jl"))
include(joinpath(@__DIR__, "algorithm1.jl"))
include(joinpath(@__DIR__, "table1.jl"))
include(joinpath(@__DIR__, "table2.jl"))
include(joinpath(@__DIR__, "table3.jl"))
include(joinpath(@__DIR__, "table4.jl"))

"""
    paper_report(io; full_search)

Print the full reproduction report.
Reproduction scope:
  - Exact: Theorem 2 (cyclic structure), Proposition 1 (Frobenius-squared EA-equiv),
           APN verification for all Tables 1–4, EA-mugshot inequivalence for s₁,s₂
  - Bounded: Algorithm 1 demo for n=6 (exhaustive), n=7 (not run in report)
  - Not executed: n=7 full exhaustive search, n=8,9 exhaustive search
"""
function paper_report(io::IO = stdout; full_search::Bool = false)
    println(io, "# Yu, Kaleyski, Budaghyan, Li (2020)")
    println(io, "# Classification of quadratic APN functions with F₂ coefficients, n≤9")
    println(io, "# Julia version: $(VERSION)")
    println(io, "# Date: $(Dates.today())")
    println(io)
    println(io, "Reproduction scope:")
    println(io, "  Exact:   Theorem 2, Proposition 1, APN checks Tables 1–4, EA-mugshot s₁,s₂")
    println(io, "  Bounded: Algorithm 1 demo n=6 (exhaustive ≤2^24 candidates)")
    println(io, "  Not run: n=7 exhaustive search, n=8/9 exhaustive search")

    theorem2_report(io)
    proposition1_report(io)
    algorithm1_report(io)
    table1_report(io)
    table2_report(io)
    table3_report(io)
    table4_report(io)

    println(io, "\n## Summary")
    println(io, "  See per-section [PASS]/[FAIL] above.")
end

using Dates

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
