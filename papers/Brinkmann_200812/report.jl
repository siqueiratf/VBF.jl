# Top-level report for Brinkmann & Leander (2008) paper reproduction.
# Paper: "On the Classification of APN Functions up to Dimension Five"
# Designs, Codes and Cryptography 49(1-3):273-288. DOI: 10.1007/s10623-008-9194-6

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "lemma1.jl"))
include(joinpath(@__DIR__, "theorem3.jl"))
include(joinpath(@__DIR__, "theorem5.jl"))
include(joinpath(@__DIR__, "theorem6.jl"))
include(joinpath(@__DIR__, "section6.jl"))

"""
    paper_report(io)

Full reproduction report for Brinkmann & Leander (2008).
"""
function paper_report(io::IO = stdout)
    println(io, "# Brinkmann & Leander (2008)")
    println(io, "# On the Classification of APN Functions up to Dimension Five")
    println(io, "# DOI: 10.1007/s10623-008-9194-6")
    println(io, "# Julia $(VERSION)  |  Date: $(Dates.today())")
    println(io)
    println(io, "# Reproduction scope:")
    println(io, "#   Lemma 1      exact   — APN ↔ 2D affine subspace sum ≠ 0")
    println(io, "#   Theorem 3    partial — specific APN (non-)permutations verified;")
    println(io, "#                          completeness requires backtrack search (out of scope)")
    println(io, "#   Theorem 5    partial — ≥7 pairwise EA-inequiv classes confirmed;")
    println(io, "#                          completeness (exactly 7) out of scope")
    println(io, "#   Theorem 6    exact   — CCZ structure for n=4,5 verified")
    println(io, "#   Table 4      n=1,2 exact; n=3 takes ~2 min (see section6_n3 target);")
    println(io, "#                n=4,5 loaded from paper (infeasible to compute)")

    lemma1_report(io)
    theorem3_report(io)
    theorem5_report(io)
    theorem6_report(io)
    section6_report(io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
