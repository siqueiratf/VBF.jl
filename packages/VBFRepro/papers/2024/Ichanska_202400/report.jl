# Top-level report for Ichanska et al. (2024/2025)
# Paper: "Pushing the QAM method for finding APN functions further"
# VBF API used: all sub-modules

using Dates

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem2.jl"))
include(joinpath(@__DIR__, "theorem3.jl"))
include(joinpath(@__DIR__, "lemma1.jl"))
include(joinpath(@__DIR__, "algorithm1.jl"))
include(joinpath(@__DIR__, "section5_1.jl"))
include(joinpath(@__DIR__, "section5_3.jl"))

function paper_report(io::IO = stdout)
    println(io, "# Ichanska, Berg, Kaleyski, Yu (2024/2025)")
    println(io, "# Pushing the QAM method for finding APN functions further")
    println(io, "#")
    println(io, "# Julia version : ", VERSION)
    println(io, "# Date          : ", Dates.today())
    println(io, "# Conway poly   : n=8 → ", conway_polynomial(8), "  (paper Section 4.1: x⁸+x⁴+x³+x²+1 ✓)")
    println(io, "#")
    println(io, "# Scope")
    println(io, "#   exact        : Theorem 2, Theorem 3, Lemma 1, Algorithm 1,")
    println(io, "#                  new function ODDS+NL, n=10 three CCZ classes")
    println(io, "#   out of scope : full QAM search (weeks), Δ/Γ-rank (Magma),")
    println(io, "#                  all 27 Simon-Berg reps (repo not available)")

    theorem2_report(io)
    theorem3_report(io)
    lemma1_report(io)
    algorithm1_report(io)
    section5_1_report(io)
    section5_3_report(io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
