# Implements paper_report() for Calderini (2020) reproduction.
# Paper: Calderini (2020), "On the EA-classes of known APN functions in small dimensions"
# Cryptography and Communications 12:821-840
#
# VBF API used: see individual section files

include(joinpath(@__DIR__, "section3.jl"))
include(joinpath(@__DIR__, "section4.jl"))
include(joinpath(@__DIR__, "section5.jl"))
include(joinpath(@__DIR__, "section6.jl"))

using Dates

function print_header(io::IO = stdout)
    println(io, "=" ^ 70)
    println(
        io,
        "Calderini (2020) — On the EA-classes of known APN functions in small dimensions",
    )
    println(io, "Cryptography and Communications 12:821-840")
    println(io, "Julia $(VERSION)  |  $(Dates.today())")
    println(io, "=" ^ 70)
    println(io, "Reproduction scope:")
    println(io, "  EXACT:  Observation 1, Procedure 2 (all k) + Propositions 1/2/3 — the")
    println(io, "          paper's own pipeline (Procedure 2 → 𝒞_{F₁} filter → EA-classes:")
    println(io, "          Gold n=4 → 16 codes / 2 EA, Gold n=5 → 64 / 3, x¹⁵ n=5 → 2 / 1),")
    println(io, "          Corollary 1 (n=4,5), C₁..C₄ dimensions, Theorem 5/6 (WE level +")
    println(io, "          complete AE decisions), Table 1 EA-class counts + degrees (rows")
    println(io, "          1-13) + row 14 ↔ catalog reprs6_13 on CCZ invariants,")
    println(io, "          Section 5.1 (13 EA / 2 perm EA / 4 perm affine classes, F₁-F₃,")
    println(io, "          Remark 4, component degrees + Walsh spectra),")
    println(io, "          Theorem 7 (n=5..8 default; n=9 opt-in), Theorem 8 Frobenius/inverse orbit census (not full CCZ classification)")
    println(io, "          (n=5..9), Remarks 5-7")
    println(io, "  DISCREPANCY: Remark 5's x^57 cyclotomic/affine claim is refuted by")
    println(io, "          direct computation (57⁻¹=78 ∉ coset(57); x^57 ≁AE x^78);")
    println(io, "          the exact count for x^57 (1 vs 2) stays MAGMA-only.")
    println(io, "  BOUND:  Table 1 row 14 (Corollary-1 bound 25 = paper's exact count)")
    println(io, "  UNREPRODUCED: full Tables 2/3/4 upper-bound columns; direct code-equivalence")
    println(io, "          checks; AB-monomial (n ≥ 7) and x^57 (n=8) simplex counts —")
    println(io, "          use table_bounds for budgeted native power-row counts. ζ = Conway generator.")
    println(io, "=" ^ 70)
end

"""
    paper_report(io; full_search=false, max_nodes=10_000_000, timeout_seconds=60)

Aggregate report for Calderini (2020). The Section 6 part enumerates
Walsh-zero subspaces for x^{-1} up to n=8 by default. The n=9 scan is
opt-in and bounded; no partial enumeration yields a rank or class count.
"""
function paper_report(io::IO = stdout; full_search::Bool=false,
        max_nodes::Int=10_000_000, timeout_seconds::Real=60)
    print_header(io)
    section3_report(io)
    section4_report(io)
    section5_report(io)
    section6_report(io; full_search, max_nodes, timeout_seconds)
    println(io, "\n" * "=" ^ 70)
    println(io, "Report complete.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end