# Paper report entry point.
# Paper: Bracken, Tan, Tan (2012), "Binomial differentially 4 uniform permutations
#        with high nonlinearity", Finite Fields Appl. 18 (2012) 537–546
# VBF API used: (all via section2.jl … section5.jl, theorem1_1.jl, problem5_1.jl)

include(joinpath(@__DIR__, "section2.jl"))
include(joinpath(@__DIR__, "section3.jl"))
include(joinpath(@__DIR__, "section4.jl"))
include(joinpath(@__DIR__, "section5.jl"))
include(joinpath(@__DIR__, "theorem1_1.jl"))
include(joinpath(@__DIR__, "problem5_1.jl"))

using Dates

# `full_search=true` widens the small grid and Problem 5.1. The n30 reduced
# certificate has its own opt-in; it never triggers a 2^30-input bitmap scan.
function paper_report(
    io::IO = stdout;
    full_search::Bool = false,
    n30_full_search::Bool = false,
)
    print_banner(io,
        "Bracken, Tan, Tan (2012): Binomial Differentially 4 Uniform Permutations",
        "  with High Nonlinearity — Finite Fields Appl. 18 (2012) 537–546")
    print_kv("field",  "GF(2^(3k)), n=3k, α=2 primitive, t=gcd(3k,s)", io)
    print_kv("Julia",  string(VERSION), io)
    print_kv("date",   string(Dates.today()), io)
    print_kv("timings", "every runtime printed below is measured on THIS machine " *
                        "with @elapsed; figures from the paper or from another " *
                        "machine are labelled where they appear", io)
    println(io)
    println(io, "Reproduction scope:")
    println(io, "  [exact]       Lemma 2.1  — permutation iff k/t odd; all 12 feasible")
    println(io, "                  (k,s) with n = 3k ≤ 15, t ∈ {1,2,4,5}")
    println(io, "  [exact]       Lemma 3.1  — differential SPECTRUM = {0, 2^t} (the full")
    println(io, "                  two-valued set, not just its maximum)")
    println(io, "  [exact]       Lemma 4.1  — ≤ 2^d roots of Σ r_i x^{2^{si}} (randomised)")
    println(io, "  [exact]       Lemma 4.2  — Walsh bound, on the k/t odd rows it covers")
    println(io, "  [exact]       Theorem 1.1 Walsh SET claim at n=6 ⊆ {0,±2^{n/2},±2^{(n+2)/2}}")
    println(io, "  [exact]       Table 1    — all 4 prior rows recomputed, plus this paper's")
    println(io, "  [exact]       Section 5  — CCZ separation from the inverse function via")
    println(io, "                  the Walsh value set")
    println(io, "  [note]        n=6 (k=2,s=4): F is a MONOMIAL DEGENERATION, not a")
    println(io, "                  genuine binomial — both exponents ≡ 17 (mod 63), so")
    println(io, "                  F = (α+α^4)·x^17, which core are_linear_equivalent")
    println(io, "                  confirms is linear-equivalent to Table 1's first row")
    println(io, "                  (Gold x^5). Paper Issue 2: the paper never says so.")
    println(io, "  [bounded]     Theorem 1.1 at n=30: verified field and coefficient cosets;")
    println(io, "                  default checks 256 normalized coefficients. Global")
    println(io, "                  DU4, permutation and Walsh support require all 49,981.")
    println(io, "                  n30_full_search=true attempts that complete finite certificate.")
    println(io, "  [refuted]     Problem 5.1 — the permutation half is FALSE at t=1:")
    println(io, "                  over all 993 admissible (v,w) the only permutation is")
    println(io, "                  v=w=0. The differential half holds on every sample.")
    println(io, "  [transcribed] t=2 CCZ-inequivalence to Gold/Kasami, which the paper")
    println(io, "                  itself only 'expects'; no novelty conclusion follows.")
    println(io, "  [transcribed] the Section 1 general family")
    println(io, "                  G(x) = αx^{2^s+1} + α^{2^k}x^{2^{ik}+2^{tk+s}}")
    println(io, "                  (i ≡ ks, t ≡ −i mod 3): its hypotheses coincide with")
    println(io, "                  Theorem 1.1's (gcd(3k,s)=2), so its smallest instance")
    println(io, "                  is also n=30; general parameter-family certification is not performed.")

    section2_report(io)
    section3_report(io; full_search = full_search)
    section4_report(io; full_search = full_search)
    section5_report(io)
    theorem1_1_report(io; full_search = n30_full_search)
    problem5_1_report(io; full_search = full_search)

    println(io, "\n" * "=" ^ 72)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
