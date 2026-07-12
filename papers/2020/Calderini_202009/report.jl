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
    println(io, "  EXACT:  Observation 1 + Procedure 2 (k=1), Proposition 1, Corollary 1")
    println(io, "          (n=4,5), C₁..C₄ dimensions, Theorem 5/6 (WE level + complete")
    println(io, "          AE decisions), Table 1 EA-class counts + degrees (rows 1-13),")
    println(io, "          Section 5.1 (13 EA / 2 perm EA / 4 perm affine classes, F₁-F₃,")
    println(io, "          Remark 4, component degrees + Walsh spectra),")
    println(io, "          Theorem 7 (n=5..9), Theorem 8 (n=5), Remarks 5-7 (cosets +")
    println(io, "          inverse-function simplex counts)")
    println(io, "  DISCREPANCY: Remark 5's x^57 cyclotomic/affine claim is refuted by")
    println(io, "          direct computation (57⁻¹=78 ∉ coset(57); x^57 ≁AE x^78);")
    println(io, "          the exact count for x^57 (1 vs 2) stays MAGMA-only.")
    println(io, "  BOUND:  Table 1 row 14 (Corollary-1 bound 25 = paper's exact count)")
    println(io, "  MAGMA-ONLY: Tables 2/3/4 upper-bound columns; direct code-equivalence")
    println(io, "          checks; AB-monomial (n ≥ 7) and x^57 (n=8) simplex counts —")
    println(io, "          each measured > 30 min. ζ = Conway generator (MAGMA default).")
    println(io, "=" ^ 70)
end

"""
    paper_report(io)

Aggregate report for Calderini (2020). The Section 6 part enumerates
Walsh-zero subspaces for x^{-1} up to n=9 (~4 minutes for n=9); expect
roughly 10 minutes of total runtime.
"""
function paper_report(io::IO = stdout)
    print_header(io)
    section3_report(io)
    section4_report(io)
    section5_report(io)
    section6_report(io)
    println(io, "\n" * "=" ^ 70)
    println(io, "Report complete.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end