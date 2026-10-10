# Implements Section 3 — F is differentially 2^t uniform.
# Paper: Bracken, Tan, Tan (2012), "Binomial differentially 4 uniform permutations
#        with high nonlinearity", Finite Fields Appl. 18 (2012) 537–546
# Section: 3 — F is differentially 2^t uniform (Lemma 3.1)
#
# Pseudocode:
#   1. Build F = bracken_binomial_sbox(k, s)
#   2. Compute the differential *value set* (support of the DDT histogram)
#   3. Theorem 1.2 / Lemma 3.1: that set is exactly {0, 2^t}, t = gcd(3k, s)
#      — strictly stronger than differential_uniformity(F) == 2^t (BTT-2)
# VBF API used: SBox, differential_spectrum, sorted_pairs, differential_uniformity
#
# Runtime measured on this machine with @elapsed (Julia 1.12.6, AMD Ryzen 5
# 5600G, single-threaded).  ONE figure for the n=15 differential scan, used
# everywhere in this folder (BTT-9):
#   n=15 streaming differential value set : 1.7 s per instance
#   n=15 core differential_spectrum       : 10.6 s per instance (Dict-bound)
#   n=15 core differential_uniformity     : 1.0 s per instance (discards the set)
#   n=12 core differential_spectrum       : 0.3 s per instance
# The default grid (9 instances) therefore costs ~5 s; `full_search = true` adds
# the three redundant t=1 instances at n=15 for ~5 s more.

include(joinpath(@__DIR__, "helpers.jl"))

# (k, s, expected differential value set, heavy?)
# `heavy = true` marks instances that add no new claim — (5,4), (5,7), (5,13)
# repeat (5,1)'s t=1 shape — so they run only under `full_search = true`.
# The t=4 and t=5 rows are the only feasible evidence that Lemma 3.1's exponent
# is really 2^t and not "4 or 2"; both are in the default grid (BTT-10).
const SECTION3_CASES = [
    (1, 2, [0, 2], false),    # n=3,  t=1
    (2, 1, [0, 2], false),    # n=6,  t=1  (non-permutation branch)
    (2, 4, [0, 4], false),    # n=6,  t=2  (degenerate monomial)
    (4, 2, [0, 4], false),    # n=12, t=2
    (4, 5, [0, 2], false),    # n=12, t=1
    (4, 8, [0, 16], false),   # n=12, t=4  ← 2^t with t=4
    (4, 11, [0, 2], false),   # n=12, t=1
    (5, 1, [0, 2], false),    # n=15, t=1  (APN binomial)
    (5, 10, [0, 32], false),  # n=15, t=5  ← 2^t with t=5
    (5, 4, [0, 2], true),     # n=15, t=1
    (5, 7, [0, 2], true),     # n=15, t=1
    (5, 13, [0, 2], true),    # n=15, t=1
]

function section3_report(io::IO = stdout; full_search::Bool = false)
    print_section("Section 3 — F is differentially 2^t uniform (Lemma 3.1)", io)
    println(io, "  Theorem 1.2: the differential SPECTRUM of F is {0, 2^t}, t = gcd(3k, s).")
    println(io, "  We assert the whole two-valued set, not just its maximum:")
    println(io, "  differential_uniformity = 2^t alone would not exclude a stray 1 or 3.")
    println(io, "  n≤12 via core differential_spectrum; n=15 via the Dict-free streaming")
    println(io, "  variant (same one-difference-at-a-time scan, O(2^n) memory, 1.7 s here).")
    println(io)
    all_pass = true
    for (k, s, expected, heavy) in SECTION3_CASES
        (heavy && !full_search) && continue
        n, t = 3k, gcd(3k, s)
        F = bracken_binomial_sbox(k, s)
        got = differential_value_set(F)
        ok = got == expected && got == [0, 1 << t]
        all_pass &= ok
        print_check("n=$n, k=$k, s=$s, t=$t → spectrum {0, 2^$t} = {0, $(1 << t)}" *
                    "  [got $got]", ok, io)
    end
    println(io)
    print_check("All Lemma 3.1 differential spectrum checks pass", all_pass, io)
    print_kv("completeness",
             (full_search ? "12 of 12" : "9 of 12") *
             " feasible instances with n = 3k ≤ 15, each exhaustive over all " *
             "2^n−1 input differences; t ∈ {1,2,4,5} covered. " *
             "n = 30 (t=2, genuine binomial) in theorem1_1.jl", io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    section3_report()
end
