# Paper report entry point.
# Paper: Bracken, Byrne, Markin, McGuire (2011), "A Few More Quadratic APN Functions",
#        Cryptography and Communications 3:43–53
# VBF API used: (all via theorem1.jl and section3.jl)

include(joinpath(@__DIR__, "section3.jl"))

using Dates


function paper_report(io::IO = stdout)
    print_header(io)
    print_kv("field", "GF(2^(3k)), k not divisible by 3", io)
    print_kv("Julia", string(VERSION), io)
    print_kv("date",  string(Dates.today()), io)
    println(io)
    println(io, "Reproduction scope:")
    println(io, "  [exact]   Theorem 1 — APN verification for n=6 and n=12 instances")
    println(io, "  [exact]   Table 2 (n=6) — delta-ranks computed by VBF.jl")
    println(io, "  [exact]   Table 2 (n=12) — APN check")
    println(io, "  [loaded]  Table 3 (n=12) — delta-ranks from original Magma computation")
    println(io, "  [out of scope] Full CCZ-inequivalence proof (Feulner canonical forms,")
    println(io, "                 Family 7 vs 8W distinction) — requires code-equivalence tools")

    theorem1_report(io)
    section3_report(io)

    println(io, "\n" * "=" ^ 72)
end


if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
