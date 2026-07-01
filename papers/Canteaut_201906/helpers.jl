# Implements shared helpers for Canteaut, Perrin, Tian (2019) reproduction.
# Paper: Canteaut, Perrin, Tian (2019), "If a Generalised Butterfly is APN then it Operates on 6 Bits",
#        Cryptography and Communications, 11(6), pp.1147-1164.
# Section: General — butterfly LUT builder, tau exponent, beta condition
#
# Pseudocode (butterfly_closed_lut):
#   R(x,y) = (x + alpha*y)^{2^i+1} + beta*y^{2^i+1}
#   V_{alpha,beta}(x,y) = (R(x,y), R(y,x))
#   Packed as z = x|(y<<n) -> R(x,y)|(R(y,x)<<n)
# VBF API used: gf_mul, gf_pow, gf_inv, gf_trace, primitive_polynomial, SBox

using VBF
using Dates

"""
    butterfly_closed_lut(n, i, alpha, beta; modulus) -> SBox{2n}

Closed butterfly V_{alpha,beta}(x,y) = (R(x,y), R(y,x)) where
R_y(x) = (x + alpha*y)^{2^i+1} + beta*y^{2^i+1}, with gcd(i,n)=1.
Encoding: z = x|(y<<n), output = R(x,y)|(R(y,x)<<n).
"""
function butterfly_closed_lut(n::Int, i::Int, alpha::Int, beta::Int;
                               modulus::Int = primitive_polynomial(n))
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
    tau_exp(n, i) -> Int

Return τ such that τ(2^i - 1) ≡ 1 mod (2^n - 1).
Used in trace conditions throughout the paper.
"""
tau_exp(n::Int, i::Int) = invmod(2^i - 1, 2^n - 1)

"""
    beta_pair(n, i, alpha; modulus) -> (beta1, beta2)

The two beta values that satisfy Proposition 3:
  beta1 = alpha^{2^i - 1} + alpha^{2^i + 1}
  beta2 = alpha^{1 - 2^i} + alpha^{2^i + 1}
If V_{alpha,beta} is APN then beta in {beta1, beta2} (Proposition 3).
"""
function beta_pair(n::Int, i::Int, alpha::Int; modulus::Int = primitive_polynomial(n))
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
"""
function refined_trace_cond(n::Int, i::Int, alpha::Int;
                             modulus::Int = primitive_polynomial(n))
    tau = tau_exp(n, i)
    alpha2 = gf_mul(alpha, alpha, n; modulus = modulus)
    denom  = 1 ⊻ alpha2
    denom == 0 && return false
    D = gf_inv(denom, n; modulus = modulus)
    e = (1 << i) + 1
    all(0:((1 << n) - 1)) do t
        (t == 0 || t == 1 || t == D) && return true
        Ft_num = t ⊻ gf_pow(t, e, n; modulus = modulus)
        Ft_den = t ⊻ D
        Ft_den == 0 && return true
        Ft = gf_mul(Ft_num, gf_inv(Ft_den, n; modulus = modulus), n; modulus = modulus)
        gf_trace(gf_pow(Ft, tau, n; modulus = modulus), n; modulus = modulus) == 1
    end
end

function paper_banner(io::IO = stdout)
    print_banner(
        io,
        "Canteaut, Perrin, Tian (2019)",
        "If a Generalised Butterfly is APN then it Operates on 6 Bits",
        "Cryptography and Communications, 11(6), pp.1147-1164",
        "Julia $(VERSION)  |  $(Dates.today())",
    )
end
