# Implements paper-local helpers for the Bracken–Byrne–Markin–McGuire (2011) reproduction.
# Paper: Bracken, Byrne, Markin, McGuire (2011), "A Few More Quadratic APN Functions",
#        Cryptography and Communications 3:43–53
# Section: General — field utilities, quadrinomial builder, report formatting
#
# Pseudocode:
#   1. n = 3k; u primitive in GF(2^n); v,w ∈ GF(2^k) with vw ≠ 1
#   2. 2^{-k} ≡ 2^{2k} (mod 2^n−1) since n=3k
#   3. F(x) = u^{2^k} x^{2^{2k}+2^{k+s}}
#           + u x^{2^s+1}
#           + v x^{2^{2k}+1}
#           + w u^{2^k+1} x^{2^{k+s}+2^s}
# VBF API used: gf_mul, gf_pow, primitive_polynomial, SBox

using VBF

# Header/banner is rendered via core `print_banner` (see report.jl).
"""
    bracken_lut(k, s, u, v, w; modulus) -> Vector{Int}

LUT for the Bracken–Byrne–Markin–McGuire quadrinomial family over GF(2^(3k)):

    F(x) = u^{2^k} x^{2^{2k}+2^{k+s}}
          + u x^{2^s+1}
          + v x^{2^{2k}+1}
          + w u^{2^k+1} x^{2^{k+s}+2^s}

Conditions for APN (Theorem 1): (s,3k)=1, (3,k)=1, 3∣(k+s), u primitive
in GF(2^n), v,w ∈ GF(2^k) with vw≠1.

Subfamilies: v=w=0 → Family 1; v=0,w≠0 → Family 7; v≠0,w=0 → Family 8W;
             v≠0,w≠0,vw≠1 → Family 8 (new).

The exponent 2^{-k} mod (2^n−1) equals 2^{2k} when n=3k.
"""
function bracken_lut(k::Int, s::Int, u::Int, v::Int, w::Int;
                     modulus::Int = primitive_polynomial(3k))::Vector{Int}
    n = 3k
    1 <= k && n <= 16 && 1 <= s < n ||
        throw(ArgumentError("materialized construction requires 3k <= 16 and 1 <= s < 3k"))
    gcd(s,n) == 1 && gcd(k,3) == 1 && (k+s) % 3 == 0 ||
        throw(ArgumentError("inadmissible Theorem 1 parameters"))
    all(0 <= c < (1 << n) for c in (u,v,w)) || throw(ArgumentError("coefficient outside field"))
    gf_multiplicative_order(u,n; modulus) == (1 << n)-1 ||
        throw(ArgumentError("u must be primitive"))
    all(gf_pow(c,1 << k,n; modulus) == c for c in (v,w)) ||
        throw(ArgumentError("v and w must belong to the embedded subfield"))
    gf_mul(v,w,n; modulus) != 1 || throw(ArgumentError("Theorem 1 requires vw != 1"))
    e1 = (1 << (2k)) + (1 << (k + s))    # 2^{2k}+2^{k+s}
    e2 = (1 << s) + 1                      # 2^s+1
    e3 = (1 << (2k)) + 1                   # 2^{2k}+1
    e4 = (1 << (k + s)) + (1 << s)        # 2^{k+s}+2^s
    c1 = gf_pow(u, 1 << k, n; modulus)           # u^{2^k}
    c2 = u                                         # u
    c3 = v                                         # v
    c4 = gf_mul(w, gf_pow(u, (1 << k) + 1, n; modulus), n; modulus)  # w·u^{2^k+1}
    terms_to_lut([(c1,e1),(c2,e2),(c3,e3),(c4,e4)], n, modulus)
end

"""
    subfield_elem(n, k, i; modulus) -> Int

The i-th nonzero element of GF(2^k) embedded in GF(2^n) (requires k ∣ n), i.e.
u^(i·(2^n−1)/(2^k−1)) where u is a verified primitive element. Index i ∈ 0..2^k−2.

Note: this indexes GF(2^k)* by *powers of a verified primitive element*, which is a
different ordering from core `subfield_elements(n, k)` (that returns the whole
subfield, including 0, sorted by integer value). The two are therefore not
interchangeable by indexing.

The power ordering reproduces the paper parameter convention; the arithmetic
and generator verification are supplied by VBF.
"""
function subfield_elem(n::Int, k::Int, i::Int;
                        modulus::Int = primitive_polynomial(n))::Int
    1 <= k <= n <= 16 && n % k == 0 && 0 <= i < (1 << k)-1 ||
        throw(ArgumentError("invalid subfield dimension or power index"))
    norm = ((1 << n) - 1) ÷ ((1 << k) - 1)
    gf_pow(gf_primitive_element(n; modulus), (i * norm) % ((1 << n) - 1), n; modulus)
end
