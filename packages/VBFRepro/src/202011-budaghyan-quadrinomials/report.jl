# Top-level report for Budaghyan–Helleseth–Kaleyski (2020).
# Calls all per-claim report functions and prints a summary.

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "observation1.jl"))
include(joinpath(@__DIR__, "proposition1.jl"))
include(joinpath(@__DIR__, "lemma3.jl"))
include(joinpath(@__DIR__, "theorem2.jl"))
include(joinpath(@__DIR__, "lemma4.jl"))
include(joinpath(@__DIR__, "corollary1.jl"))
include(joinpath(@__DIR__, "table3.jl"))

using Dates

function paper_report(io::IO = stdout)
    print_banner(io, PAPER_BANNER...)
    println(io, "  Date:          ", Dates.today())
    println(io, "  Julia:         ", VERSION)
    println(io, "  Field:         GF(2^10), primitive polynomial 0x", string(primitive_polynomial(10), base=16))
    println(io)
    println(io, "  Reproduction scope:")
    println(io, "    [exact]   Observation 1  — C_3, C_7 APN over GF(2^10)")
    println(io, "    [exact]   Proposition 1  — E_i trivial ⇒ C_i APN, all i ∈ 1..9")
    println(io, "    [exact]   Lemma 3        — P(N) has exactly the roots {0,1,S,S+1}")
    println(io, "    [exact]   Theorem 2      — four i-values give trivial E_i (n=10, n=14)")
    println(io, "    [exact]   Lemma 4        — odd k: i ∈ {m+2, m, (m+2)^-1}")
    println(io, "    [exact]   Corollary 1    — 7 of 8 items APN; item 8 is a PAPER ERRATUM")
    println(io, "    [partial] Table III      — all rows built and checked APN; Γ-ranks are")
    println(io, "                               transcribed (n=10 Γ-rank is out of reach)")
    println(io, "    [partial] Novelty        — C_3, C_7 separated from every QUADRATIC row")
    println(io, "                               by ortho-derivative mugshot; separation from")
    println(io, "                               x^57 / x^339 is NOT invariant-backed in-repo")

    observation1_report(io)
    proposition1_report(io)
    lemma3_report(io)
    theorem2_report(io)
    theorem2_scope_report(io)
    lemma4_report(io)
    corollary1_report(io)
    table3_report(io)

    println(io)
    println(io, "=" ^ 72)
    println(io, "Report complete.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
