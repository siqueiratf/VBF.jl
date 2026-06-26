# Implements paper-local helpers for the Bracken–Tan–Tan (2012) reproduction.
# Paper: Bracken, Tan, Tan (2012), "Binomial differentially 4 uniform permutations
#        with high nonlinearity", Finite Fields Appl. 18 (2012) 537–546
# Section: General — field utilities, binomial LUT builder, report formatting
#
# Pseudocode:
#   1. n = 3k, α = 2 (primitive element of GF(2^n))
#   2. 2^{-k} ≡ 2^{2k} (mod 2^n−1) since n = 3k
#   3. F(x) = α·x^{2^s+1} + α^{2^k}·x^{2^{2k}+2^{k+s}}
#   4. t = gcd(3k, s); F is diff-2^t-uniform permutation when k/t is odd
# VBF API used: gf_mul, gf_pow, primitive_polynomial, SBox

using VBF

function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Bracken, Tan, Tan (2012): Binomial Differentially 4 Uniform Permutations")
    println(io, "  with High Nonlinearity — Finite Fields Appl. 18 (2012) 537–546")
    println(io, "=" ^ 72)
end

"""
    bracken_binomial_lut(k, s; modulus) -> Vector{Int}

LUT for the Bracken–Tan–Tan binomial family over GF(2^{3k}):

    F(x) = α·x^{2^s+1} + α^{2^k}·x^{2^{2k}+2^{k+s}}

where α = 2 (primitive element) and 2^{-k} ≡ 2^{2k} (mod 2^{3k}−1) since n = 3k.

Conditions (Theorem 1.2): t = gcd(3k, s), t | k, k/t odd, 3 | k+s.
When k/t is odd, F is a differentially 2^t uniform permutation.
When k/t is even, F is not a permutation (Lemma 2.1 converse).

Degenerate case: when s ≡ 2k (mod 3k), both exponents reduce to 2^{2k}+1 and F
collapses to a monomial. Smallest non-degenerate case: k=5, n=15, s=1 (t=1).
"""
function bracken_binomial_lut(k::Int, s::Int;
                               modulus::Int = primitive_polynomial(3k))::Vector{Int}
    n  = 3k
    e1 = (1 << s) + 1                       # 2^s + 1
    e2 = (1 << (2k)) + (1 << (k + s))       # 2^{2k} + 2^{k+s}  (= 2^{-k}+2^{k+s} mod 2^n−1)
    c1 = 2                                    # α = 2 (primitive element)
    c2 = gf_pow(2, 1 << k, n; modulus)       # α^{2^k}
    [gf_mul(c1, gf_pow(x, e1, n; modulus), n; modulus) ⊻
     gf_mul(c2, gf_pow(x, e2, n; modulus), n; modulus)
     for x in 0:(1 << n) - 1]
end

"""
    bracken_binomial_sbox(k, s; modulus) -> SBox
"""
function bracken_binomial_sbox(k::Int, s::Int;
                                modulus::Int = primitive_polynomial(3k))
    SBox(bracken_binomial_lut(k, s; modulus))
end

"""
    linearity_rowwise(F::SBox) -> Int

Streaming linearity (max |LAT[a,b]| outside (0,0)): computes one LAT column at a
time via Walsh-Hadamard transform, reusing a single work vector. O(2^n) memory vs
O(2^{2n}) for the full LAT matrix. Required for n≥13 where LAT exceeds available RAM.
"""
function linearity_rowwise(F::SBox)
    lut = F.lut
    n   = length(lut)
    max_L = 0
    v = zeros(Int, n)
    @inbounds for b in 0:(n - 1)
        for x in 0:(n - 1)
            v[x + 1] = count_ones(b & lut[x + 1]) & 1 == 0 ? 1 : -1
        end
        walsh_hadamard!(v)
        for a in 0:(n - 1)
            (a == 0 && b == 0) && continue
            abs_val = abs(v[a + 1])
            abs_val > max_L && (max_L = abs_val)
        end
    end
    max_L
end
