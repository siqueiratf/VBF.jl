# Implements Section 2 — F is a permutation.
# Paper: Bracken, Tan, Tan (2012), "Binomial differentially 4 uniform permutations
#        with high nonlinearity", Finite Fields Appl. 18 (2012) 537–546
# Section: 2 — F is a permutation
#
# Pseudocode:
#   1. For each (k, s): compute t = gcd(3k, s), k_over_t = k ÷ t
#   2. Lemma 2.1: F is a permutation iff k/t is odd
#   3. Verify:
#      n=6,  k=2, s=4, t=2, k/t=1 (odd)  → permutation      [degenerate monomial]
#      n=12, k=4, s=2, t=2, k/t=2 (even) → not a permutation [non-degenerate]
#      n=15, k=5, s=1, t=1, k/t=5 (odd)  → permutation       [non-degenerate APN]
# VBF API used: SBox, is_permutation

include(joinpath(@__DIR__, "helpers.jl"))

# (k, s, label, expect_permutation)
const SECTION2_CASES = [
    (2, 4, "n=6,  k=2, s=4, t=2, k/t=1 (odd)  → permutation",      true),
    (4, 2, "n=12, k=4, s=2, t=2, k/t=2 (even) → not a permutation", false),
    (5, 1, "n=15, k=5, s=1, t=1, k/t=5 (odd)  → permutation",       true),
]

function section2_report(io::IO = stdout)
    print_section("Section 2 — F is a permutation (Lemma 2.1)", io)
    println(io, "  F(x) = α·x^{2^s+1} + α^{2^k}·x^{2^{2k}+2^{k+s}}, α primitive in GF(2^n)")
    println(io, "  Lemma 2.1: F is a permutation iff k/t is odd, where t = gcd(3k, s).")
    println(io)
    all_pass = true
    for (k, s, label, expect) in SECTION2_CASES
        F    = bracken_binomial_sbox(k, s)
        ok   = is_permutation(F) == expect
        all_pass &= ok
        print_check(label, ok, io)
    end
    println(io)
    print_check("All Lemma 2.1 permutation checks pass", all_pass, io)
    print_kv("completeness", "exhaustive over listed (k,s) triples", io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    section2_report()
end
