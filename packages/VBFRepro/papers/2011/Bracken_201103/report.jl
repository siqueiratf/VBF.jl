# Paper report entry point.
# Paper: Bracken, Byrne, Markin, McGuire (2011), "A Few More Quadratic APN Functions",
#        Cryptography and Communications 3:43–53
# VBF API used: (all via theorem1.jl and section3.jl)

include(joinpath(@__DIR__, "section3.jl"))

using Dates


function paper_report(io::IO = stdout)
    print_banner(io,
        "Bracken, Byrne, Markin, McGuire (2011): A Few More Quadratic APN Functions",
        "Cryptography and Communications 3:43–53, 2011")
    print_kv("field", "GF(2^(3k)), k not divisible by 3", io)
    print_kv("Julia", string(VERSION), io)
    print_kv("date",  string(Dates.today()), io)
    println(io)
    println(io, "Reproduction scope:")
    println(io, "  [exact]   Theorem 1 — APN verification for n=6 and n=12 instances")
    println(io, "  [computed] Table 2 (n=6) — delta-ranks computed here by VBF.jl")
    println(io, "  [exact]   Table 2 (n=12) — APN check")
    println(io, "  [loaded]  Table 3 (n=12) — delta-ranks TRANSCRIBED from the paper's")
    println(io, "            original Magma computation (NOT computed in this repo)")
    println(io, "  [out of scope] Full CCZ-inequivalence proof (Feulner canonical forms,")
    println(io, "                 Family 7 vs 8W distinction) — requires code-equivalence tools")
    println(io)
    println(io, "  " * "!"^68)
    println(io, "  NOVELTY-GAP: the 'NEW / CCZ-inequivalent' claim for n=12 rests on [loaded]")
    println(io, "  Magma Δ-ranks, not values computed here. Family 7 vs 8W is UNVERIFIED in")
    println(io, "  this repo: Δ-rank provably cannot split them (they share it). See section3.")
    println(io, "  " * "!"^68)

    theorem1_report(io)
    section3_report(io)

    println(io, "\n" * "=" ^ 72)
end


if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
