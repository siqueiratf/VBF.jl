"""
The known infinite families of **quadratic, non-monomial APN binomials** over
`GF(2ⁿ)` — the first APN polynomials proven CCZ-inequivalent to power functions.
Both have the binomial shape

    F(x) = x^{2ˢ+1} + w · x^{2^{ik} + 2^{tk+s}}

with `w ∈ GF(2ⁿ)*` of a prescribed multiplicative order. The two families differ
only in the divisor `p` of `n` and the parameter conditions:

| family | source                          | n    | conditions                                          | order of `w`            |
|--------|---------------------------------|------|-----------------------------------------------------|-------------------------|
| BCP    | Budaghyan–Carlet–Pott 2006      | 3k   | `gcd(k,3)=gcd(s,3k)=1`, `i=s·k mod 3`, `t=3−i`, `g₁≠g₂` | `2^{2k}+2ᵏ+1`        |
| BCL    | Budaghyan–Carlet–Leander 2008   | 4k   | `gcd(k,2)=gcd(s,2k)=1`, `s≤4k−1`, `i=s·k mod 4`, `t=4−i` | `2^{3k}+2^{2k}+2ᵏ+1` |

Here `α = 2` is the primitive element of the canonical representation, so a `w`
of order `2^{2k}+2ᵏ+1` (resp. `2^{3k}+2^{2k}+2ᵏ+1`) is `α^{2ᵏ−1}` — a non-`(2ᵏ−1)`-th
power, as required by the papers. The `g₁ ≠ g₂` test of the BCP family is

    d  = 2^{ik} + 2^{tk+s} − (2ˢ+1)
    g₁ = gcd(2^{3k}−1, d/(2ᵏ−1)),   g₂ = gcd(2ᵏ−1, d/(2ᵏ−1)).

References:
- L. Budaghyan, C. Carlet, A. Pott, "New classes of almost bent and almost
  perfect nonlinear polynomials", IEEE Trans. IT 52(3), 2006 — Theorem 2
  (the `n = 3k` family; the `n` divisible by 3 case of the unified binomial).
- L. Budaghyan, C. Carlet, G. Leander, "Two classes of quadratic APN binomials
  inequivalent to power functions", IEEE Trans. IT 54(9), 2008 — Theorem 1
  (`n = 3k`, Table II row 2) and Theorem 2 (`n = 4k`, Table II row 3).

Both members are quadratic (`algebraic_degree = 2`) and APN
(`differential_uniformity = 2`) under their stated conditions; the field
representation (`modulus`) is a basis choice and does not affect APN-ness, but it
does fix which integer is the primitive element used to build `w`.
"""

# Build the binomial  F(x) = x^{2ˢ+1} + w·x^{2^{ik}+2^{tk+s}}  over GF(2ⁿ).
function _apn_binomial_lut(n::Int, s::Int, k::Int, i::Int, t::Int, w::Int, modulus::Int)
    e1 = (1 << s) + 1
    e2 = (1 << (i * k)) + (1 << (t * k + s))
    out = Vector{Int}(undef, 1 << n)
    @inbounds for x in 0:(1 << n) - 1
        a = gf_pow(x, e1, n; modulus = modulus)
        b = gf_mul(w, gf_pow(x, e2, n; modulus = modulus), n; modulus = modulus)
        out[x + 1] = a ⊻ b
    end
    out
end

"""
    bcp_apn(k, s; modulus = primitive_polynomial(3k)) -> SBox{3k}

The quadratic APN binomial over `GF(2^{3k})`

    F(x) = x^{2ˢ+1} + w · x^{2^{ik} + 2^{tk+s}},   i = s·k mod 3,  t = 3 − i,

with `w = α^{2ᵏ−1}` (`α = 2`, so `w` has order `2^{2k}+2ᵏ+1`). This is the
`n` divisible by `3` class: [Budaghyan–Carlet–Pott (2006)](@cite BudaghyanCarletPott2006),
Theorem 2, refined as [Budaghyan–Carlet–Leander (2008)](@cite BudaghyanCarletLeander2008),
Theorem 1.

Requires `gcd(k, 3) = gcd(s, 3k) = 1` and the inequivalence guarantee
`g₁ ≠ g₂` (see the module docstring); throws `ArgumentError` otherwise.
"""
function bcp_apn(k::Integer, s::Integer; modulus::Integer = primitive_polynomial(3 * Int(k)))
    kk = Int(k); ss = Int(s)
    n = 3 * kk
    kk ≥ 1 || throw(ArgumentError("bcp_apn: need k ≥ 1, got k=$kk"))
    gcd(kk, 3) == 1 || throw(ArgumentError("bcp_apn: need gcd(k, 3) = 1, got k=$kk"))
    gcd(ss, n) == 1 || throw(ArgumentError("bcp_apn: need gcd(s, 3k) = 1, got s=$ss, 3k=$n"))
    i = mod(ss * kk, 3)
    i == 0 && throw(ArgumentError("bcp_apn: i = s·k mod 3 must be nonzero, got 0 (s=$ss, k=$kk)"))
    t = 3 - i
    d = (1 << (i * kk)) + (1 << (t * kk + ss)) - ((1 << ss) + 1)
    dd = d ÷ ((1 << kk) - 1)
    g1 = gcd((1 << (3 * kk)) - 1, dd)
    g2 = gcd((1 << kk) - 1, dd)
    g1 != g2 || throw(ArgumentError(
        "bcp_apn: APN guarantee needs g₁ ≠ g₂, got g₁=g₂=$g1 (k=$kk, s=$ss)"))
    w = gf_pow(2, (1 << kk) - 1, n; modulus = Int(modulus))  # order 2^{2k}+2ᵏ+1
    SBox{n}(_apn_binomial_lut(n, ss, kk, i, t, w, Int(modulus)))
end

"""
    bcl_apn(k, s; modulus = primitive_polynomial(4k)) -> SBox{4k}

The quadratic APN binomial over `GF(2^{4k})`

    F(x) = x^{2ˢ+1} + w · x^{2^{ik} + 2^{tk+s}},   i = s·k mod 4,  t = 4 − i,

with `w = α^{2ᵏ−1}` (`α = 2`, so `w` has order `2^{3k}+2^{2k}+2ᵏ+1`). This is the
`n` divisible by `4` class: [Budaghyan–Carlet–Leander (2008)](@cite BudaghyanCarletLeander2008),
Theorem 2.

Requires `gcd(k, 2) = gcd(s, 2k) = 1` (so `k` and `s` are odd) and
`s ≤ 4k − 1`; throws `ArgumentError` otherwise.
"""
function bcl_apn(k::Integer, s::Integer; modulus::Integer = primitive_polynomial(4 * Int(k)))
    kk = Int(k); ss = Int(s)
    n = 4 * kk
    kk ≥ 1 || throw(ArgumentError("bcl_apn: need k ≥ 1, got k=$kk"))
    gcd(kk, 2) == 1 || throw(ArgumentError("bcl_apn: need gcd(k, 2) = 1 (k odd), got k=$kk"))
    gcd(ss, 2 * kk) == 1 || throw(ArgumentError("bcl_apn: need gcd(s, 2k) = 1, got s=$ss, 2k=$(2kk)"))
    ss ≤ 4 * kk - 1 || throw(ArgumentError("bcl_apn: need s ≤ 4k − 1, got s=$ss, 4k−1=$(4kk - 1)"))
    i = mod(ss * kk, 4)
    i == 0 && throw(ArgumentError("bcl_apn: i = s·k mod 4 must be nonzero, got 0 (s=$ss, k=$kk)"))
    t = 4 - i
    w = gf_pow(2, (1 << kk) - 1, n; modulus = Int(modulus))  # order 2^{3k}+2^{2k}+2ᵏ+1
    SBox{n}(_apn_binomial_lut(n, ss, kk, i, t, w, Int(modulus)))
end
