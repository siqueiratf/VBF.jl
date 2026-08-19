# Top-level report for Brinkmann & Leander (2008) paper reproduction.
# Paper: "On the Classification of APN Functions up to Dimension Five"
# Designs, Codes and Cryptography 49(1-3):273-288. DOI: 10.1007/s10623-008-9194-6

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "lemma1.jl"))
include(joinpath(@__DIR__, "table1.jl"))
include(joinpath(@__DIR__, "table3.jl"))
include(joinpath(@__DIR__, "theorem3.jl"))
include(joinpath(@__DIR__, "theorem5.jl"))
include(joinpath(@__DIR__, "theorem6.jl"))
include(joinpath(@__DIR__, "algorithm1.jl"))
include(joinpath(@__DIR__, "section6.jl"))
include(joinpath(@__DIR__, "section7.jl"))
include(joinpath(@__DIR__, "section8.jl"))

"""
    paper_report(io)

Full reproduction report for Brinkmann & Leander (2008).
"""
function paper_report(io::IO = stdout)
    print_banner(
        io,
        "Brinkmann & Leander (2008) — On the Classification of APN Functions up to Dimension Five",
        "DOI: 10.1007/s10623-008-9194-6",
        "Julia $(VERSION)  |  Date: $(Dates.today())",
    )
    println(io, "# Reproduction scope:")
    println(io, "#   Lemma 1      exact   — APN ↔ 2D affine subspace sum ≠ 0")
    println(io, "#   Algorithm 1  exact   — stateful filter φ_APN; re-derives #APN(1..3)")
    println(io, "#   Table 1      exact   — 5 canonical APN permutations (n=5), OCR-reconstructed")
    println(io, "#   Table 3      exact   — 7 EA-canonical APN functions (n=5), OCR-reconstructed")
    println(io, "#   Theorem 3    exact   — n=4 non-existence proved via CCZ-to-permutation +")
    println(io, "#                          Theorem 6; n=5 affine classes + inverse relations")
    println(io, "#   Theorem 5    partial — 7 pairwise EA-inequiv classes, every pair decided;")
    println(io, "#                          completeness (exactly 7) out of scope")
    println(io, "#   Theorem 6    exact   — CCZ structure for n=4,5 verified")
    println(io, "#   Table 4      n=1,2,3 computed; n=4,5 derived from Σ|G|/|G_s| (Section 6)")
    println(io, "#   Section 7    exact   — 14 canonical n=6 classes, all 14 Γ-ranks reproduce")
    println(io, "#   Note 9       exact   — h₁,h₂,h₃ verified in H; |⟨h₁,h₂,h₃⟩| = 4960")
    println(io, "#   Section 8    exact   — Prop 11 recurrences, (20)-(24), Prop 12, Fig. 1")
    println(io, "#")
    println(io, "# Remaining gaps (out of scope, NOT reproduced):")
    println(io, "#   - Algorithm 2 (φ_π CCZ-equivalence backtrack) and Algorithm 3 (stabiliser")
    println(io, "#     generator search); Note 9's generators are verified, not searched for")
    println(io, "#   - Completeness of the classifications (the full template backtrack search)")

    lemma1_report(io)
    algorithm1_report(io)
    table1_report(io)
    table3_report(io)
    theorem3_report(io)
    theorem5_report(io)
    theorem6_report(io)
    section6_report(io)
    section7_report(io)
    section8_report(io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
