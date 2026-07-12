# Implements shared helpers for Canteaut, Perrin, Tian (2019) reproduction.
# Paper: Canteaut, Perrin, Tian (2019), "If a Generalised Butterfly is APN then it Operates on 6 Bits",
#        Cryptography and Communications, 11(6), pp.1147-1164.
# Section: General — butterfly LUT builders (Definition 1), tau exponent, beta condition
#
# Pseudocode (butterfly_closed_lut):
#   R(x,y) = (x + alpha*y)^{2^i+1} + beta*y^{2^i+1}
#   V_{alpha,beta}(x,y) = (R(x,y), R(y,x))
#   Packed as z = x|(y<<n) -> R(x,y)|(R(y,x)<<n)
# Pseudocode (butterfly_open_lut):
#   H_R(x,y) = (R_{R_y^{-1}(x)}(y), R_y^{-1}(x))
#   Packed as z = x|(y<<n) -> with u = R_y^{-1}(x): R(y,u)|(u<<n)
#
# Standing hypothesis of the paper (guarded below): n odd, 0 < i < n, gcd(i,n) = 1.
# VBF API used: gf_mul, gf_pow, gf_inv, gf_trace, primitive_polynomial, SBox,
#               is_permutation, compositional_inverse

using VBF
using Dates

"""
    check_params(n, i)

Enforce the paper's standing hypothesis: `n` odd, `0 < i < n`, `gcd(i, n) = 1`
(Definition 1 and every subsequent statement assume all three).  Without this
guard, e.g. `proposition6_build(4, 1)` returns a silently meaningless result.
"""
function check_params(n::Int, i::Int)
    @assert isodd(n) "paper hypothesis violated: n must be odd, got n=$n"
    @assert 0 < i < n "paper hypothesis violated: need 0 < i < n, got i=$i, n=$n"
    @assert gcd(i, n) == 1 "paper hypothesis violated: need gcd(i,n)=1, got i=$i, n=$n"
    nothing
end

"""
    butterfly_closed_lut(n, i, alpha, beta; modulus) -> SBox{2n}

Closed butterfly V_{alpha,beta}(x,y) = (R(x,y), R(y,x)) where
R_y(x) = (x + alpha*y)^{2^i+1} + beta*y^{2^i+1}, with gcd(i,n)=1.
Encoding: z = x|(y<<n), output = R(x,y)|(R(y,x)<<n).
"""
function butterfly_closed_lut(n::Int, i::Int, alpha::Int, beta::Int;
                               modulus::Int = primitive_polynomial(n))
    check_params(n, i)
    e   = (1 << i) + 1
    len = 1 << n
    mul_(a, b) = gf_mul(a, b, n; modulus = modulus)
    pow_(a, e) = gf_pow(a, e, n; modulus = modulus)
    R(x, y) = pow_(x ⊻ mul_(alpha, y), e) ⊻ mul_(beta, pow_(y, e))

    lut = Vector{Int}(undef, 1 << (2 * n))
    for x in 0:len-1, y in 0:len-1
        lut[(x | (y << n)) + 1] = R(x, y) | (R(y, x) << n)
    end
    SBox{2 * n}(lut)
end

"""
    butterfly_open_lut(n, i, alpha, beta; modulus) -> SBox{2n}

Open butterfly of Definition 1:

    H_R(x, y) = (R_{R_y^{-1}(x)}(y), R_y^{-1}(x)),

the second half of the paper's Definition 1 (the closed butterfly V_R being the
first).  Writing u = R_y^{-1}(x), the output is (R(y, u), u).  R_y : x ↦ R(x,y)
is a permutation of F_{2^n} for every y — the exponent 2^i+1 is a permutation
exponent because gcd(2^i+1, 2^n-1) = 1 for n odd and gcd(i,n) = 1 — so
`compositional_inverse` is well defined (and throws if it ever were not).

The tex states that H_R "is an involution and, as such, a permutation"; it is
CCZ-equivalent to V_R, hence APN exactly when V_R is.  This is what makes the
paper's negative result a statement about APN *permutations*.
Encoding: z = x|(y<<n), output = R(y,u)|(u<<n).
"""
function butterfly_open_lut(n::Int, i::Int, alpha::Int, beta::Int;
                            modulus::Int = primitive_polynomial(n))
    check_params(n, i)
    e   = (1 << i) + 1
    len = 1 << n
    mul_(a, b) = gf_mul(a, b, n; modulus = modulus)
    pow_(a, e) = gf_pow(a, e, n; modulus = modulus)
    R(x, y) = pow_(x ⊻ mul_(alpha, y), e) ⊻ mul_(beta, pow_(y, e))

    # R_y^{-1} for every y (compositional_inverse throws unless R_y is a permutation)
    Rinv = [compositional_inverse(SBox{n}([R(x, y) for x in 0:len-1])) for y in 0:len-1]

    lut = Vector{Int}(undef, 1 << (2 * n))
    for x in 0:len-1, y in 0:len-1
        u = Int(Rinv[y + 1].lut[x + 1])          # u = R_y^{-1}(x)
        lut[(x | (y << n)) + 1] = R(y, u) | (u << n)
    end
    SBox{2 * n}(lut)
end

"""
    tau_exp(n, i) -> Int

Return τ such that τ(2^i - 1) ≡ 1 mod (2^n - 1).
Used in trace conditions throughout the paper.
"""
function tau_exp(n::Int, i::Int)
    check_params(n, i)
    invmod(2^i - 1, 2^n - 1)
end

"""
    beta_pair(n, i, alpha; modulus) -> (beta1, beta2)

The two beta values that satisfy Proposition 3:
  beta1 = alpha^{2^i - 1} + alpha^{2^i + 1}
  beta2 = alpha^{1 - 2^i} + alpha^{2^i + 1}
If V_{alpha,beta} is APN then beta in {beta1, beta2} (Proposition 3).
"""
function beta_pair(n::Int, i::Int, alpha::Int; modulus::Int = primitive_polynomial(n))
    check_params(n, i)
    q = 1 << i
    b1 = gf_pow(alpha, q - 1, n; modulus = modulus) ⊻
         gf_pow(alpha, q + 1, n; modulus = modulus)
    b2_exp = (1 - q + (2^n - 1)) % (2^n - 1)
    b2 = gf_pow(alpha, b2_exp, n; modulus = modulus) ⊻
         gf_pow(alpha, q + 1, n; modulus = modulus)
    (b1, b2)
end

"""
    refined_trace_cond(n, i, alpha; modulus) -> Bool

Proposition 5: V_{alpha,beta} is APN (for beta=beta1) if and only if
  Tr(F_D(t)^tau) = 1 for all t not in {0, 1, D}
where F_D(t) = (t + t^{2^i+1}) / (t + D) and D = 1/(1 + alpha^2).
Returns true if this condition holds for the given alpha.

This is a 2^n-element check that needs no LUT: it is the cheap surrogate for
APN-ness used by the Theorem 1 sweep (see `theorem1_rtc_sweep`).
"""
function refined_trace_cond(n::Int, i::Int, alpha::Int;
                             modulus::Int = primitive_polynomial(n))
    check_params(n, i)
    tau = tau_exp(n, i)
    alpha2 = gf_mul(alpha, alpha, n; modulus = modulus)
    denom  = 1 ⊻ alpha2
    denom == 0 && return false               # α = 1: D undefined
    D = gf_inv(denom, n; modulus = modulus)
    e = (1 << i) + 1
    all(0:((1 << n) - 1)) do t
        (t == 0 || t == 1 || t == D) && return true
        Ft_num = t ⊻ gf_pow(t, e, n; modulus = modulus)
        Ft_den = t ⊻ D                        # ≠ 0: t == D is excluded above
        Ft = gf_mul(Ft_num, gf_inv(Ft_den, n; modulus = modulus), n; modulus = modulus)
        gf_trace(gf_pow(Ft, tau, n; modulus = modulus), n; modulus = modulus) == 1
    end
end

"""
    coprime_exponents(n) -> Vector{Int}

All i with 0 < i < n and gcd(i, n) = 1 — the exponents the paper admits.
"""
coprime_exponents(n::Int) = [i for i in 1:n-1 if gcd(i, n) == 1]

function paper_banner(io::IO = stdout)
    print_banner(
        io,
        "Canteaut, Perrin, Tian (2019)",
        "If a Generalised Butterfly is APN then it Operates on 6 Bits",
        "Cryptography and Communications, 11(6), pp.1147-1164",
        "Julia $(VERSION)  |  $(Dates.today())",
    )
end
