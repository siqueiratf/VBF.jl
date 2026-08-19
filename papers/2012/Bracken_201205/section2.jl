# Implements Section 2 — F is a permutation.
# Paper: Bracken, Tan, Tan (2012), "Binomial differentially 4 uniform permutations
#        with high nonlinearity", Finite Fields Appl. 18 (2012) 537–546
# Section: 2 — F is a permutation (Lemma 2.1)
#
# Pseudocode:
#   1. For each admissible (k, s): t = gcd(3k, s), k_over_t = k ÷ t
#   2. Lemma 2.1: F is a permutation iff k/t is odd
#   3. Verify over the complete feasible grid n = 3k ≤ 15 (12 instances):
#      every (k,s) with 3∤k, 3|(k+s), t|k — see SECTION2_CASES
# VBF API used: SBox, is_permutation
#
# Runtime measured on this machine with @elapsed (Julia 1.12.6, AMD Ryzen 5
# 5600G): the whole 12-instance grid costs 0.18 s, dominated by the five n=15
# LUT builds (0.022 s each).

include(joinpath(@__DIR__, "helpers.jl"))

# The complete feasible grid for Theorem 1.2 with n = 3k ≤ 15: every (k,s) with
# 3∤k, 3|(k+s) and t = gcd(3k,s) | k.  Lemma 2.1 predicts `perm` from k/t alone;
# `degenerate` records whether the two exponents collide mod 2^n−1 (Paper Issue
# 2 — the paper never states that its own headline has no genuine binomial
# representative below n = 30).
#
# (k, s, expect_permutation, expect_degenerate)
const SECTION2_CASES = [
    (1, 2, true, true),    # n=3,  t=1, k/t=1 odd   — degenerate monomial
    (2, 1, false, false),  # n=6,  t=1, k/t=2 even  — genuine binomial
    (2, 4, true, true),    # n=6,  t=2, k/t=1 odd   — degenerate monomial (α+α⁴)x¹⁷
    (4, 2, false, false),  # n=12, t=2, k/t=2 even  — genuine binomial
    (4, 5, false, false),  # n=12, t=1, k/t=4 even  — genuine binomial
    (4, 8, true, true),    # n=12, t=4, k/t=1 odd   — degenerate monomial
    (4, 11, false, false), # n=12, t=1, k/t=4 even  — genuine binomial
    (5, 1, true, false),   # n=15, t=1, k/t=5 odd   — genuine binomial, APN
    (5, 4, true, false),   # n=15, t=1, k/t=5 odd   — genuine binomial, APN
    (5, 7, true, false),   # n=15, t=1, k/t=5 odd   — genuine binomial, APN
    (5, 10, true, true),   # n=15, t=5, k/t=1 odd   — degenerate monomial
    (5, 13, true, false),  # n=15, t=1, k/t=5 odd   — genuine binomial, APN
]

"""
    section2_case_label(k, s) -> String

`"n=6,  k=2, s=4, t=2, k/t=1 (odd)"` for the report tables.
"""
function section2_case_label(k::Int, s::Int)
    n = 3k
    t = gcd(n, s)
    q = k ÷ t
    string(
        rpad("n=$n,", 6),
        "k=$k, s=$s, t=$t, k/t=$q (",
        isodd(q) ? "odd" : "even",
        ") → ",
        isodd(q) ? "permutation    " : "not a permutation",
    )
end

function section2_report(io::IO = stdout)
    print_section("Section 2 — F is a permutation (Lemma 2.1)", io)
    println(io, "  F(x) = α·x^{2^s+1} + α^{2^k}·x^{2^{2k}+2^{k+s}}, α primitive in GF(2^n)")
    println(io, "  Lemma 2.1: F is a permutation iff k/t is odd, where t = gcd(3k, s).")
    println(io, "  Grid: all 12 feasible (k,s) with n = 3k ≤ 15.")
    println(io)
    all_pass = true
    for (k, s, expect, degen) in SECTION2_CASES
        Fb = bracken_binomial(k, s)
        F = SBox([Fb(x) for x = 0:((1 << Fb.n) - 1)])
        ok = is_permutation(F) == expect && is_degenerate(Fb) == degen
        all_pass &= ok
        tag = degen ? "  [degenerate monomial]" : "  [genuine binomial]"
        print_check(section2_case_label(k, s) * tag, ok, io)
    end
    println(io)
    print_check("All Lemma 2.1 permutation checks pass", all_pass, io)
    print_kv("completeness",
             "exhaustive over the complete feasible grid n = 3k ≤ 15 " *
             "(12 of 12 instances); n = 30 in theorem1_1.jl", io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    section2_report()
end
