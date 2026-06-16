# Paper report entry point.
# Paper: Bracken, Tan, Tan (2012), "Binomial differentially 4 uniform permutations
#        with high nonlinearity", Finite Fields Appl. 18 (2012) 537–546
# VBF API used: (all via section2.jl, section3.jl, section4.jl)

include(joinpath(@__DIR__, "section2.jl"))
include(joinpath(@__DIR__, "section3.jl"))
include(joinpath(@__DIR__, "section4.jl"))

using Dates

function paper_report(io::IO = stdout)
    print_header(io)
    print_kv("field",  "GF(2^(3k)), n=3k, α=2 primitive, t=gcd(3k,s)", io)
    print_kv("Julia",  string(VERSION), io)
    print_kv("date",   string(Dates.today()), io)
    println(io)
    println(io, "Reproduction scope:")
    println(io, "  [exact]       Lemma 2.1  — permutation iff k/t odd (n=6,12,15)")
    println(io, "  [exact]       Lemma 3.1  — diff-2^t-uniform (n=6 t=2; n=15 t=1 APN)")
    println(io, "  [exact]       Lemma 4.2  — Walsh spectrum bound (n=6, n=15)")
    println(io, "  [note]        n=6 (k=2,s=4): F degenerates to monomial (α+α^4)x^17;")
    println(io, "                  smallest non-degenerate case: n=15 (k=5,s=1,t=1)")
    println(io, "  [out-of-scope] Theorem 1.1 t=2 non-degenerate (n=30, 2^30 elements)")
    println(io, "  [out-of-scope] Problem 5.1 — open problem, no proof available")

    section2_report(io)
    section3_report(io)
    section4_report(io)

    println(io, "\n" * "=" ^ 72)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
