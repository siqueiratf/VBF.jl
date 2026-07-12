# Implements Section 4 — F is highly nonlinear.
# Paper: Bracken, Tan, Tan (2012), "Binomial differentially 4 uniform permutations
#        with high nonlinearity", Finite Fields Appl. 18 (2012) 537–546
# Section: 4 — F is highly nonlinear
#
# Pseudocode:
#   1. Build F = bracken_binomial_sbox(k, s)
#   2. Compute linearity(F) = max_{(a,b) ≠ (0,0)} |F^W(a,b)|
#   3. Lemma 4.2: |F^W(a,b)| ≤ 2^{(n+t)/2} when n+t even;
#                             ≤ 2^{(n+t-1)/2} when n+t odd
#   4. Verify:
#      n=6,  t=2, n+t=8  (even) → bound = 2^4 = 16
#      n=15, t=1, n+t=16 (even) → bound = 2^8 = 256
# VBF API used: SBox, linearity

include(joinpath(@__DIR__, "helpers.jl"))

# (k, s, t, walsh_bound, label, use_streaming)
# use_streaming=true: column-at-a-time O(2^n) memory (required for n≥13)
const SECTION4_CASES = [
    (2, 4, 2,  16, "n=6,  t=2, n+t=8  even → |F^W| ≤ 2^4  = 16",  false),
    (5, 1, 1, 256, "n=15, t=1, n+t=16 even → |F^W| ≤ 2^8  = 256", true),
]

function section4_report(io::IO = stdout)
    print_section("Section 4 — F is highly nonlinear (Lemma 4.2)", io)
    println(io, "  Lemma 4.2: |F^W(a,b)| ≤ 2^{(n+t)/2}   when n+t even")
    println(io, "             |F^W(a,b)| ≤ 2^{(n+t-1)/2} when n+t odd")
    println(io, "  n=15 uses column-at-a-time streaming (avoids 8 GB full LAT).")
    println(io)
    all_pass = true
    for (k, s, t, bound, label, streaming) in SECTION4_CASES
        F   = bracken_binomial_sbox(k, s)
        L   = streaming ? linearity_rowwise(F) : linearity(F)
        ok  = L ≤ bound
        all_pass &= ok
        print_check(label * "  [got $L]", ok, io)
    end
    println(io)
    print_check("All Lemma 4.2 Walsh spectrum bound checks pass", all_pass, io)
    print_kv("completeness",
             "n=6 exhaustive (full LAT); n=15 exhaustive (streaming rowwise); " *
             "t=2 non-degenerate (n=30) out-of-scope", io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    section4_report()
end
