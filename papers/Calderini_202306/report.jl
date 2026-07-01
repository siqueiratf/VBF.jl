# Top-level report for Calderini, Li, Villa (2023) reproduction.
# Paper: Calderini, Li, Villa (2023), "Extending two families of bivariate APN functions",
#        Finite Fields and Their Applications.
#
# Pseudocode (paper_report):
#   1. Print banner
#   2. theorem3_report()  — Lemma 1 + Family F1 APN
#   3. theorem4_report()  — Lemma 3 + Family F2 APN
#   4. section4_1_report(full_search=false)  — N_F for n=12 skipped by default
# VBF API used: print_banner, print_section, print_check, print_kv

include(joinpath(@__DIR__, "theorem3.jl"))
include(joinpath(@__DIR__, "theorem4.jl"))
include(joinpath(@__DIR__, "section4_1.jl"))

function paper_report(io::IO = stdout; full_search::Bool = false)
    paper_banner(io)
    println(io, "Scope (exact): Lemma 1, Theorem 3 F1 (m=3,4); Lemma 3, Theorem 4 F2 (m=3,4)")
    println(io, "Scope (opt-in): Section 4.1 N_F for n=12 (full_search=true)")
    println(io, "Out-of-scope: Table 3 full comparison (all 12 known families); Remark 1")

    theorem3_report(io)
    theorem4_report(io)
    section4_1_report(io; full_search = full_search)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
