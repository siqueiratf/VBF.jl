# Top-level report for Calderini, Li, Villa (2023) reproduction.
# Paper: Calderini, Li, Villa (2023), "Extending two families of bivariate APN functions",
#        Finite Fields and Their Applications.
#
# Pseudocode (paper_report):
#   1. Print banner
#   2. theorem3_report()   — Lemma 1 + Family F1 APN
#   3. theorem4_report()   — Lemma 2 (Williams) + Lemma 3 + Family F2 APN
#   4. theorem5_report()   — 3-to-1 / Gold-like Walsh spectra (Section 5)
#   5. section4_1_report(full_search) — N_F for F1/F2 at n=12 (opt-in)
#   6. table3_report(full_search)     — N_F of the 12 known families (opt-in)
#   7. remark1_report()    — CCZ collapse at n=8,10 (opt-in, ~minutes)
# VBF API used: print_banner, print_section, print_check, print_kv

include(joinpath(@__DIR__, "theorem3.jl"))
include(joinpath(@__DIR__, "theorem4.jl"))
include(joinpath(@__DIR__, "theorem5.jl"))
include(joinpath(@__DIR__, "section4_1.jl"))
include(joinpath(@__DIR__, "table3.jl"))
include(joinpath(@__DIR__, "remark1.jl"))

function paper_report(io::IO = stdout; full_search::Bool = false)
    paper_banner(io)
    println(io, "Scope (exact): Lemma 1, Theorem 3 F1 (m=3,4); Lemma 2 (Williams, m=3,4,5),")
    println(io, "               Lemma 3, Theorem 4 F2 (m=3,4); Theorem 5 spectra (n=6,8)")
    println(io, "Scope (opt-in): Section 4.1 N_F at n=12 + Table 3 known-family rows")
    println(io, "                (full_search=true); Remark 1 CCZ at n=8,10 (make remark1)")

    theorem3_report(io)
    theorem4_report(io)
    theorem5_report(io; full_search = full_search)
    section4_1_report(io; full_search = full_search)
    table3_report(io; full_search = full_search)
    if full_search
        remark1_report(io)
    else
        print_section("Remark 1 — CCZ-equivalence at n=8, 10", io)
        println(io, "  [SKIP] Set full_search=true or run 'make remark1' (CCZ checks take minutes)")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
