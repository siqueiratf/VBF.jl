# Top-level paper report for Yu, Li, Ichanska, Kaleyski (2025)
# "Classification of quadratic APN functions with coefficients in F₂ in dimension 10"
# Springer Designs, Codes and Cryptography (2025)
#
# Invokes all section-level report functions and prints a reproduction header.
# VBF API used: (all APIs used by the included files)

include(joinpath(@__DIR__, "theorem1.jl"))
include(joinpath(@__DIR__, "proposition1.jl"))
include(joinpath(@__DIR__, "theorem2.jl"))
include(joinpath(@__DIR__, "example1.jl"))
include(joinpath(@__DIR__, "corollary1.jl"))
include(joinpath(@__DIR__, "example2.jl"))
include(joinpath(@__DIR__, "algorithm2.jl"))
include(joinpath(@__DIR__, "table1.jl"))
include(joinpath(@__DIR__, "table2.jl"))
include(joinpath(@__DIR__, "algorithm3.jl"))
include(joinpath(@__DIR__, "table3.jl"))

function paper_report(io::IO = stdout)
    println(io, "# Yu, Li, Ichanska, Kaleyski (2025)")
    println(io, "# Classification of quadratic APN functions with coefficients in F₂ in dimension 10")
    println(io, "# Designs, Codes and Cryptography (2025), Springer")
    println(io)
    println(io, "Julia version : ", VERSION)
    println(io, "Date          : ", Dates.today())
    println(io)
    println(io, "Reproduction scope:")
    println(io, "  EXACT      — Theorem 1, Proposition 1, Theorem 2, Example 1,")
    println(io, "               Corollary 1, Example 2, Algorithm 1, Algorithm 2 (n=5,6),")
    println(io, "               Table 1 (n=10, 3 CCZ-reps verified APN + CCZ-inequivalent)")
    println(io, "  BOUNDED    — Table 2 (n=6 exact; n=7,8 budget-limited),")
    println(io, "               Algorithm 3 demo (n=6,7)")
    println(io, "  CONJECTURED— Table 3 (n=11 APN + CCZ-inequivalence evidence; no exhaustive search)")
    println(io, "  OUT OF SCOPE — Table 2 n=9,10 (days); Table 3 full n=11 search (70+ years on 1 core)")
    println(io)
    println(io, "Note: paper writes 'x^4' as first entry in Table 1 and Table 3.")
    println(io, "      x^4=x^{2^2} is a linear map (DDT max=2^n); x^3=x^{2^1+1} (Gold k=1) is used here.")

    theorem1_report(io)
    proposition1_report(io)
    theorem2_report(io)
    example1_report(io)
    corollary1_report(io)
    example2_report(io)
    algorithm2_report(io)
    table1_report(io)
    table2_report(io)
    algorithm3_report(io)
    table3_report(io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    using Dates
    paper_report()
end
