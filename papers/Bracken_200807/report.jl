# Paper report entry point.
# Paper: Bracken, Byrne, Markin, McGuire (2008),
#        "New Families of Quadratic Almost Perfect Nonlinear Trinomials and Multinomials",
#        Finite Fields and Their Applications 14 (2008), 703–714
# VBF API used: (all via theorem files)

include(joinpath(@__DIR__, "theorem4.jl"))
include(joinpath(@__DIR__, "theorem5.jl"))

using Dates


function paper_report(io::IO = stdout)
    print_header(io)
    print_kv("Family 1 field", "GF(2^{2k}), k and s odd, gcd(k,s)=1", io)
    print_kv("Family 2 field", "GF(2^{3k}), gcd(s,3k)=1, 3∤k, 3|(k+s)", io)
    print_kv("Julia",          string(VERSION), io)
    print_kv("date",           string(Dates.today()), io)
    println(io)
    println(io, "Reproduction scope:")
    println(io, "  [exact]       Theorem 1 — Family 1 APN (n=6 exhaustive, n=10 bounded)")
    println(io, "  [exact]       Lemma 2   — seventh-power properties (k=2)")
    println(io, "  [exact]       Theorem 3 — Family 2 APN (n=6 and n=12 exhaustive)")
    println(io, "  [exact]       Theorem 4 — Tr(f) bent for Family 1 (n=6)")
    println(io, "  [exact]       Theorem 5 — Walsh spectrum = Gold (n=6)")
    println(io, "  [exact]       Theorem 5 — CCZ: Family 1 ↔ Dillon T1, Family 2 ↔ T2/Gold (n=6)")
    println(io, "  [out of scope] Theorem 5 — CCZ via code equivalence (requires Magma)")

    theorem1_report(io)
    theorem3_report(io)
    theorem4_report(io)
    theorem5_report(io)

    println(io, "\n" * "=" ^ 72)
end


if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
