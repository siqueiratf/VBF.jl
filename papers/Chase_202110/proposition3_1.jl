# Implements Proposition 3.1 — Walsh zero test for Gold APN permutations
# Paper: Chase, Lisoněk (2021), "Construction of APN permutations via Walsh
#        zero spaces"
# Section: 3 — Walsh zeros of Gold functions
#
# Pseudocode:
#   For f(x) = x^{2^i+1}, n odd, gcd(i,n) = 1:
#     (a,b) is a Walsh zero of f  ⟺  Tr(a·b^{-1/(2^i+1)}) = 0  or  a ≠ b = 0.
#   Verify exhaustively against the actual LAT, plus the W_f(1,1) sign from
#   [Lahtonen-McGuire-Ward]: +2^{(n+1)/2} if n ≡ ±1 (mod 8), else -2^{(n+1)/2}.
# VBF API used: gold_apn, lat, gf_trace, gf_mul, parity, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition3_1_build(n, i; modulus) -> NamedTuple

Exhaustively compare the Proposition 3.1 predicate with `lat(gold_apn(n, i))`
over all 2^{2n} pairs `(a, b)` (field coordinates; the LAT is consulted at
the corresponding mask coordinates). Also checks the `W_f(1,1)` sign.
"""
function proposition3_1_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    gcd(i, n) == 1 || throw(ArgumentError("need gcd(i, n) = 1"))
    isodd(n) || throw(ArgumentError("need n odd"))
    F = gold_apn(n, i; modulus)
    L = lat(F)
    tm = trace_mask_table(n; modulus)
    dual = gold_dual_table(n, i; modulus)
    mismatches = 0
    n_zeros = 0
    for a = 0:(1<<n)-1, b = 0:(1<<n)-1
        pred = b == 0 ? (a != 0) : parity(tm[dual[b+1]+1] & a) == 0
        actual = L[tm[a+1]+1, tm[b+1]+1] == 0
        pred == actual || (mismatches += 1)
        actual && (n_zeros += 1)
    end
    # Expected |Z(f)|: (2^n - 1) from b = 0 plus (2^n - 1)·2^{n-1} from b ≠ 0.
    expected_zeros = (2^n - 1) + (2^n - 1) * 2^(n - 1)
    w11 = L[tm[2]+1, tm[2]+1]   # a = b = 1
    w11_expected = mod(n, 8) in (1, 7) ? 2^((n + 1) ÷ 2) : -(2^((n + 1) ÷ 2))
    (;
        n,
        i,
        mismatches,
        n_zeros,
        expected_zeros,
        zeros_match = n_zeros == expected_zeros,
        w11,
        w11_expected,
        w11_match = w11 == w11_expected,
    )
end

function proposition3_1_report(io::IO = stdout; n::Int = 5, i::Int = 1)
    r = proposition3_1_build(n, i)
    print_section("Proposition 3.1 — Walsh zero test for Gold x^{2^$i+1}, n=$n", io)
    print_check(io, "predicate == (LAT entry is 0) for all 2^{2n} pairs", r.mismatches == 0)
    print_check(io, "|Z(f)| = (2^n-1)(2^{n-1}+1) = $(r.expected_zeros)", r.zeros_match)
    print_check(io, "W_f(1,1) = $(r.w11_expected) (sign rule, n mod 8 = $(mod(n, 8)))", r.w11_match)
    print_kv(io, "mismatches", r.mismatches)
    print_kv(io, "completeness", "exhaustive over F_{2^$n} × F_{2^$n}")
end

if abspath(PROGRAM_FILE) == @__FILE__
    for (n, i) in ((5, 1), (5, 2), (7, 1), (7, 2), (7, 3), (9, 1))
        proposition3_1_report(; n, i)
    end
end
