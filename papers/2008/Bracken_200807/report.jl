# Paper report entry point.
# Paper: Bracken, Byrne, Markin, McGuire (2008),
#        "New Families of Quadratic Almost Perfect Nonlinear Trinomials and Multinomials",
#        Finite Fields and Their Applications 14 (2008), 703–714
# VBF API used: (all via theorem files)

include(joinpath(@__DIR__, "theorem4.jl"))
include(joinpath(@__DIR__, "theorem6.jl"))

using Dates


function paper_report(io::IO = stdout; full_search::Bool = false)
    print_banner(io,
                 "Bracken, Byrne, Markin, McGuire (2008):",
                 "New Families of Quadratic APN Trinomials and Multinomials",
                 "Finite Fields and Their Applications 14 (2008), 703–714")
    print_kv("Family 1 field", "GF(2^{2k}), k and s odd, gcd(k,s)=1", io)
    print_kv("Family 2 field", "GF(2^{3k}), gcd(s,3k)=1, 3∤k, 3|(k+s)", io)
    print_kv("Julia",          string(VERSION), io)
    print_kv("date",           string(Dates.today()), io)
    println(io)
    println(io, "Reproduction scope:")
    println(io, "  [sampled]     Theorem 1 — Family 1 APN: n=6 (k,s)=(3,1) sampled over")
    println(io, "                            150 528 valid (b,c,r₁,r₂) tuples (all of them")
    println(io, "                            with full_search=true); n=10 single instance")
    println(io, "  [exact]       Theorem 1 — each hypothesis shown necessary (n=6)")
    println(io, "  [exact]       Lemma 2   — seventh-power properties (k=2)")
    println(io, "  [exhaustive]  Theorem 3 — Family 2 APN: all 144 valid (u,v) pairs at n=6")
    println(io, "  [bounded]     Theorem 3 — n=12: 2 of 27 648 valid (u,v) pairs")
    println(io, "  [exact]       Theorem 4 — Tr(v·f) bent for Family 1 (n=6), including")
    println(io, "                            cube b where Theorem 1's APN claim fails")
    println(io, "  [exact]       Theorem 6 — Walsh spectrum = Gold (n=6)")
    println(io, "  [exact]       Theorem 6 — CCZ: Family 1 ↔ Dillon T1, Family 2 ↔ T2/Gold (n=6)")
    println(io, "  [exact]       Theorem 6 — forward direction f ~ g ⇒ [Ĉ_f]=[Ĉ_g], via an")
    println(io, "                            explicit X = [[1,0],[γ,M]] (n=6)")
    println(io, "  [partial]     Theorem 6 — converse [Ĉ_f]=[Ĉ_g] ⇒ f ~ g: only the weight-")
    println(io, "                            enumerator necessary condition; deciding it needs")
    println(io, "                            binary code permutation-equivalence (Leon), which")
    println(io, "                            VBF does not implement")

    theorem1_report(io; full_search)
    theorem3_report(io)
    theorem4_report(io)
    theorem6_report(io)

    println(io, "\n" * "=" ^ 72)
end


if abspath(PROGRAM_FILE) == @__FILE__
    paper_report(; full_search = "--full" in ARGS)
end
