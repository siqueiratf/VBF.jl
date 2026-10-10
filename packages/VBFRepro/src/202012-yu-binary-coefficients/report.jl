# Top-level paper report for Yu et al. (2020)
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
# VBF API used: all — aggregates results from per-claim files

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem1.jl"))
include(joinpath(@__DIR__, "theorem2.jl"))
include(joinpath(@__DIR__, "example1.jl"))
include(joinpath(@__DIR__, "proposition1.jl"))
include(joinpath(@__DIR__, "algorithm1.jl"))
include(joinpath(@__DIR__, "table1.jl"))
include(joinpath(@__DIR__, "table2.jl"))
include(joinpath(@__DIR__, "table3.jl"))
include(joinpath(@__DIR__, "table4.jl"))

"""
    paper_report(io; full_search)

Print the full reproduction report. See each section's header comment for the precise
scope; the summary below is deliberately conservative about what is and is not proven.
"""
function paper_report(io::IO = stdout; full_search::Bool = false)
    println(io, "# Yu, Kaleyski, Budaghyan, Li (2020)")
    println(io, "# Classification of quadratic APN functions with F₂ coefficients, n≤9")
    println(io, "# Julia version: $(VERSION)")
    println(io, "# Date: $(Dates.today())")
    println(io)
    println(io, "Reproduction scope:")
    println(io, "  Proven:    Theorem 1 (δ = 2^(n−min row-rank), APN and non-APN alike);")
    println(io, "             Example 1 (n=6 QAM shape, c ∈ GF(2³), 2¹⁵ search space);")
    println(io, "             Proposition 1 (Frobenius-squared QAM ⟹ EA-equivalent);")
    println(io, "             Tables 1–4 all APN + quadratic; n=7 and n=9 rows all AB;")
    println(io, "             n=7: source Algorithm1 exhausts its Frobenius quotient and")
    println(io, "               reproduces Table2's14invariantbuckets; bucket equality does")
    println(io, "               not establish positive equivalence or a complete class count;")
    println(io, "             n=8: 7 distinct CCZ classes, and the two near-identical")
    println(io, "               trinomials ARE CCZ-inequivalent (σ-mismatch).")
    println(io, "  Partial:   Table4 verifies8publicationrepresentatives as APN,quadratic,AB.")
    println(io, "               Exact invariant tuples separate s₁,s₂ from each other and")
    println(io, "               the explicitly enumerated quadratic n9 catalog functions.")
    println(io, "               Matching tuples require equivalence queries; nonquadratic")
    println(io, "               references and literature/construction completeness remain")
    println(io, "               unresolved. This is scoped separation, not global novelty.")
    println(io, "             n=8 Table 3's two POSITIVE CCZ-equivalences to Edel–Pott forms:")
    println(io, "               σ-match only here (a necessary condition); the complete EA")
    println(io, "               decision proves them but costs ~265 s/pair — `make table3_full`.")
    println(io, "  NOT done:  Theorem 2's iff — it is a NORMAL-basis statement and VBF's")
    println(io, "               quadratic_apn_matrix is bit-basis; the gap is asserted, not")
    println(io, "               papered over (see theorem2.jl).")
    println(io, "  Exact:     Algorithm1 odd-n traversal: GetNoneSquare, span and proper")
    println(io, "               submatrix pruning. Small complete candidate-set controls pass.")
    println(io, "  Partial:   Even-n source pseudocode is absent; the core odometer remains.")
    println(io, "               Full n8/n9 regeneration and exact n7 class counts not run.")
    println(io, "             PAPER ERRATUM: Table 2 prints x³+x⁹+x¹⁸+x⁶⁶ twice (rows 4, 10)")
    println(io, "               and omits a class; the recovered 15th is x³+x⁵+x⁹+x⁴⁰+x⁹⁶.")

    theorem1_report(io)
    theorem2_report(io)
    example1_report(io)
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
