# Top-level report for Budaghyan, Carlet, Pott (2006).
# Paper: "New Classes of Almost Bent and Almost Perfect Nonlinear Polynomials"
#        IEEE Transactions on Information Theory, 52(3):762–777.
# Section: All — Section 5 Theorems 1–4, Remark 4

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem1.jl"))
include(joinpath(@__DIR__, "remark4.jl"))
include(joinpath(@__DIR__, "theorem2.jl"))
include(joinpath(@__DIR__, "theorem3.jl"))
include(joinpath(@__DIR__, "theorem4.jl"))

"""
    paper_report(io) -> Nothing

Full reproduction report for Budaghyan–Carlet–Pott (2006).

Scope:
- exact:   Theorems 1–4, Remark 4, Proposition 4 criterion
- bounded: Remark 4 default uses random sample (full_search=true for exhaustive)
- skipped: CCZ-class enumeration, timing tables
"""
function paper_report(io::IO = stdout)
    print_header(io)
    println(io, "Julia version : ", VERSION)
    println(io, "Date          : ", Dates.today())
    println(io)
    println(io, "Scope: Theorems 1–4, Remark 4, Proposition 4 criterion")
    println(io, "       CCZ-class enumeration and timing tables: not executed")
    println(io, "Checks: Theorem 3 F1⁻¹ formula tested exhaustively on GF(2^6);")
    println(io, "        Theorem 4 reproduced via permutation inversion (see notes below)")

    theorem1_report(io)
    remark4_report(io)
    theorem2_report(io)
    theorem3_report(io)
    theorem4_report(io)

    println(io, "\n", "=" ^ 72)
    println(io, "Done.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
