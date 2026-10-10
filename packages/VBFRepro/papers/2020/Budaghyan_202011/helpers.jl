# Implements shared helpers for the Budaghyan–Helleseth–Kaleyski (2020) reproduction.
# Paper: Budaghyan, Helleseth, Kaleyski (2020), "A New Family of APN Quadrinomials",
#        IEEE Trans. Inf. Theory 66(11):7081–7087
# Section: General — field utilities, quadrinomial builder
#
# Pseudocode:
#   1. β ← α^((2^n−1)/3) in GF(2^n), the primitive element of GF(2^2)
#   2. C(x) ← x^3 + a·(x^(2^i+1))^(2^k) + b·x^(3·2^m) + c·(x^(2^(i+m)+2^m))^(2^k)
#      (the F13 quadrinomial of Corollary 1; a, b, c ∈ GF(4))
#   3. y ∈ β·GF(2^m) iff y^(2^m) = β·y  (for n=2m, m odd, 3∤m)
#   4. E_i^(k): a^3(x^2+x) ∈ β·GF(2^m) and (a^(2^i+1)(x^(2^i)+x))^(2^k) ∈ β·GF(2^m)
# VBF API used: gf_pow, gf_mul, primitive_polynomial, terms_to_lut, SBox, print_banner

using VBF

# ── Report formatting ────────────────────────────────────────────────────────
# The banner itself is VBF's `print_banner`; only the paper's title lines live here.

const PAPER_BANNER = (
    "Budaghyan, Helleseth, Kaleyski (2020): A New Family of APN Quadrinomials",
    "IEEE Trans. Inf. Theory 66(11):7081–7087, November 2020",
)

# ── GF(2^n) field helpers ────────────────────────────────────────────────────

"""
    beta_in_gfn(n) -> (β, β²)

Returns the primitive element β of GF(2^2) embedded in GF(2^n), together with
β² = β^{-1}. Requires 3 ∣ (2^n−1), i.e., n even. Under the canonical primitive
polynomial, β = α^((2^n−1)/3) where α = 2 is the field generator.

Satisfies: β^3 = 1, β ≠ 1, β ∉ GF(2^m) for n = 2m with m odd.
"""
function beta_in_gfn(n::Int; modulus::Int = primitive_polynomial(n))
    q = (1 << n) - 1
    q % 3 == 0 || error("3 ∤ 2^n−1 for n=$n; n must be even")
    b  = gf_pow(2, q ÷ 3, n; modulus)
    b2 = gf_mul(b, b, n; modulus)
    return b, b2
end

"""
    in_beta_coset(y, β, n, m; modulus) -> Bool

Checks whether y ∈ β·GF(2^m). For n = 2m with m odd and 3 ∤ m, this holds iff
y^(2^m) = β·y (Frobenius criterion via the GF(2^m) minimal polynomial of β).
"""
function in_beta_coset(y::Int, β::Int, n::Int, m::Int; modulus::Int = primitive_polynomial(n))
    gf_pow(y, 1 << m, n; modulus) == gf_mul(β, y, n; modulus)
end

# ── Quadrinomial builder ─────────────────────────────────────────────────────

"""
    ci_exponents(n, i, k) -> (e2, e3, e4)

The three non-cubic exponents of the F13 quadrinomial, reduced mod (2^n − 1):

    e2 = (2^i + 1)·2^k,   e3 = 3·2^m,   e4 = (2^(i+m) + 2^m)·2^k

Computed in `Int128` so that `i + m` may exceed 62 without wrapping (the paper's
experimental range reaches n = 46, where i = n−1 gives i + m = 3n/2 − 1 = 68).
A reduced exponent of 0 is reported as 2^n − 1 so that `x ↦ x^e` still maps 0 ↦ 0.
"""
function ci_exponents(n::Int, i::Int, k::Int)
    m = n ÷ 2
    q = Int128(1) << n - 1
    ii, kk = mod(i, n), mod(k, n)   # 2^n ≡ 1 (mod 2^n−1), so only i, k mod n matter
    reduce_exp(e) = (r = Int(mod(e, q)); r == 0 ? Int(q) : r)
    e2 = reduce_exp(((Int128(1) << ii) + 1) * (Int128(1) << kk))
    e3 = reduce_exp(Int128(3) * (Int128(1) << m))
    e4 = reduce_exp(((Int128(1) << (ii + m)) + (Int128(1) << m)) * (Int128(1) << kk))
    return e2, e3, e4
end

"""
    build_ci_sbox(n, i, k=0; a, b, c, modulus) -> SBox{n}

Builds the S-box for the F13 quadrinomial of Corollary 1,

    C(x) = x^3 + a·(x^(2^i+1))^(2^k) + b·x^(3·2^m) + c·(x^(2^(i+m)+2^m))^(2^k)

over GF(2^n), n = 2m, with a, b, c ∈ GF(4). Coefficients default to the
(a, b, c) = (β, β², 1) of Observation 1 / eq. (1); a zero coefficient drops its
term, so `build_ci_sbox(10, 3, 2; b=0, c=0)` is the binomial B(x) = x^3 + β·x^36
of Corollary 1 item 1.
"""
function build_ci_sbox(
    n::Int, i::Int, k::Int = 0;
    a::Union{Int,Nothing} = nothing,
    b::Union{Int,Nothing} = nothing,
    c::Union{Int,Nothing} = nothing,
    modulus::Int = primitive_polynomial(n),
)
    β, β² = beta_in_gfn(n; modulus)
    ca = a === nothing ? β  : a
    cb = b === nothing ? β² : b
    cc = c === nothing ? 1  : c
    e2, e3, e4 = ci_exponents(n, i, k)
    terms = Tuple{Int,Int}[(1, 3)]
    ca != 0 && push!(terms, (ca, e2))
    cb != 0 && push!(terms, (cb, e3))
    cc != 0 && push!(terms, (cc, e4))
    SBox{n}(terms_to_lut(terms, n, modulus))
end

"""
    system_Ei_trivial(n, i; k=0) -> Bool

Returns true iff the system E_i^(k) has only trivial solutions x ∈ GF(2), i.e.
no (a ≠ 0, x ∉ GF(2)) pair satisfies both conditions:

    a^3·(x^2+x) ∈ β·GF(2^m)   and   (a^(2^i+1)·(x^(2^i)+x))^(2^k) ∈ β·GF(2^m).

`k = 0` is the system E_i of Proposition 1 (eq. 2); general `k` is system (16),
whose odd-k instance is Lemma 4's system (17). Exhaustive over a ∈ GF(2^n)*,
x ∈ GF(2^n) \\ GF(2).
"""
function system_Ei_trivial(n::Int, i::Int; k::Int = 0, modulus::Int = primitive_polynomial(n))
    m  = n ÷ 2
    q  = (1 << n) - 1
    b, _ = beta_in_gfn(n; modulus)
    check(y) = in_beta_coset(y, b, n, m; modulus)
    ei1 = (1 << i) + 1       # exponent 2^i + 1
    tk  = 1 << mod(k, n)     # the 2^k Frobenius power applied to the second equation
    for a in 1:q
        a3  = gf_pow(a, 3, n; modulus)
        ai1 = gf_pow(a, ei1, n; modulus)
        for x in 2:q  # skip x ∈ {0, 1} = GF(2)
            A = gf_mul(a3, gf_pow(x, 2, n; modulus) ⊻ x, n; modulus)
            check(A) || continue
            B = gf_mul(ai1, gf_pow(x, 1 << i, n; modulus) ⊻ x, n; modulus)
            check(gf_pow(B, tk, n; modulus)) && return false  # non-trivial solution
        end
    end
    true
end
