# Implements Section 3 — F is differentially 2^t uniform.
# Paper: Bracken, Tan, Tan (2012), "Binomial differentially 4 uniform permutations
#        with high nonlinearity", Finite Fields Appl. 18 (2012) 537–546
# Section: 3 — F is differentially 2^t uniform
#
# Pseudocode:
#   1. Build F = bracken_binomial_sbox(k, s)
#   2. Compute differential_uniformity(F) and verify == 2^t
#   3. n=6  (k=2, s=4, t=2): degenerate monomial (α+α^4)x^17, fast (64 elements)
#   4. n=15 (k=5, s=1, t=1): non-degenerate APN binomial; ~30 s exhaustive
# VBF API used: SBox, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))

# (k, s, label, expected_differential_uniformity)
# Both cases use core differential_uniformity, which scans one input difference
# at a time (O(2^n) memory) — it never materialises the full 2^n × 2^n DDT, so
# no separate streaming path is needed in this folder even at n=15.
const SECTION3_CASES = [
    (2, 4, "n=6,  k=2, s=4, t=2 → diff-4-uniform (degenerate monomial)", 4),
    (5, 1, "n=15, k=5, s=1, t=1 → APN diff-2-uniform (non-degenerate)",  2),
]

function section3_report(io::IO = stdout)
    print_section("Section 3 — F is differentially 2^t uniform (Lemma 3.1)", io)
    println(io, "  Lemma 3.1: differential_uniformity(F) = 2^t, t = gcd(3k, s).")
    println(io, "  n=15 via core differential_uniformity: one input difference at a")
    println(io, "  time, O(2^n) memory (no full 2^n × 2^n DDT materialised); exhaustive.")
    println(io)
    all_pass = true
    for (k, s, label, du) in SECTION3_CASES
        F   = bracken_binomial_sbox(k, s)
        got = differential_uniformity(F)
        ok  = got == du
        all_pass &= ok
        print_check(label * "  [got $got]", ok, io)
    end
    println(io)
    print_check("All Lemma 3.1 differential uniformity checks pass", all_pass, io)
    print_kv("completeness",
             "n=6 and n=15 both exhaustive via core differential_uniformity " *
             "(O(2^n) memory); t=2 non-degenerate (n=30) out-of-scope", io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    section3_report()
end
