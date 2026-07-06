# Implements Theorem 1 — APN property of Family 1.
# Paper: Bracken, Byrne, Markin, McGuire (2008),
#        "New Families of Quadratic Almost Perfect Nonlinear Trinomials and Multinomials",
#        Finite Fields and Their Applications 14 (2008), 703–714
# Section: 2 — Proof of APN property for family (1)
#
# Pseudocode:
#   For each (k, s) with k,s odd and gcd(k,s)=1:
#     1. b ← primitive element ω of GF(2^{2k})  [not a cube since ord(ω)=2^{2k}−1]
#     2. c ← ω^2  [not in GF(2^k) since ord(ω^2)=2^{2k}−1, which does not divide 2^k−1]
#     3. r_i ← subfield elements in GF(2^k) (including zero for the pure trinomial)
#     4. F ← family1_lut(k, s, b, c, r)
#     5. assert differential_uniformity(SBox(F)) == 2
# VBF API used: SBox, differential_uniformity, gf_pow, gf_is_dth_power, in_subfield

include(joinpath(@__DIR__, "helpers.jl"))


# Smallest valid (k,s) pairs: both odd, gcd(k,s)=1.
# k=3 (n=6) is the smallest k≥1 that yields a non-degenerate polynomial over GF(2^{2k})
# (k=1 gives degenerate exponents mod 2^2−1=3).

const THEOREM1_CASES = [
    # (k, s, label, r_indices_into_GF(2^k)_nonzero [0=zero])
    # --- n=6, k=3, s=1 ---
    (3, 1, "n=6  k=3 s=1  trinomial  (r=0)",      [0, 0]),
    (3, 1, "n=6  k=3 s=1  pentanomial (r1=ω^9, r2=1)", [1, 0]),
    # --- n=6, k=3, s=5 (also odd, gcd(3,5)=1) ---
    (3, 5, "n=6  k=3 s=5  trinomial",              [0, 0]),
    # --- n=10, k=5, s=1 (bounded demo) ---
    (5, 1, "n=10 k=5 s=1  trinomial",              [0, 0, 0, 0]),
]


"""
    theorem1_sbox(k, s, r_idx; modulus) -> SBox

Build a Family 1 SBox with b=2 (primitive, not a cube), c=4 (=ω^2, not in GF(2^k)),
and r[i] chosen as the r_idx[i]-th nonzero element of GF(2^k) (0 → zero element).
"""
function theorem1_sbox(k::Int, s::Int, r_idx::Vector{Int};
                        modulus::Int = primitive_polynomial(2k))
    n     = 2k
    subf  = filter(!iszero, subfield_elements(n, k; modulus))
    r     = [i == 0 ? 0 : subf[mod1(i, length(subf))] for i in r_idx]
    b, c  = 2, gf_pow(2, 2, n; modulus)   # b=ω, c=ω^2
    SBox(family1_lut(k, s, b, c, r; modulus))
end


function theorem1_report(io::IO = stdout)
    print_section("Theorem 1 — Family 1 quadratic APN multinomials (Section 2)", io)
    println(io, "  F(x) = b·x^{2^s+1} + b^{2^k}·x^{2^{k+s}+2^k} + c·x^{2^k+1}")
    println(io, "         + Σ_{i=1}^{k−1} r_i·x^{2^{i+k}+2^i}")
    println(io, "  Conditions: k,s odd, gcd(k,s)=1, b not a cube, c ∉ GF(2^k), r_i ∈ GF(2^k).")
    println(io)

    all_pass = true
    for (k, s, label, ridx) in THEOREM1_CASES
        modulus = primitive_polynomial(2k)
        n       = 2k
        b, c    = 2, gf_pow(2, 2, n; modulus)
        # verify parameter conditions
        @assert !gf_is_dth_power(b, 3, n; modulus)       "b=$b must not be a cube in GF(2^$n)"
        @assert !in_subfield(c, k, n; modulus) "c=$c must not lie in GF(2^$k)"
        F   = theorem1_sbox(k, s, ridx; modulus)
        apn = differential_uniformity(F) == 2
        all_pass &= apn
        print_check(label, apn, io)
    end
    println(io)
    print_check("All Theorem 1 instances APN", all_pass, io)
    print_kv("b", "2 = ω (primitive)", io)
    print_kv("c", "4 = ω² (not in GF(2^k))", io)
    print_kv("completeness",
             "n=6 exhaustive over listed (k,s,r) tuples; n=10 bounded demo", io)
end


if abspath(PROGRAM_FILE) == @__FILE__
    theorem1_report()
end
