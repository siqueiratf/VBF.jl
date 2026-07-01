# Paper-specific helpers for Budaghyan_202101.
# Paper: Budaghyan, Calderini, Carlet, Coulter, Villa (2021),
#        "Generalized Isotopic Shift Construction for APN Functions"
#
# Pseudocode:
#   1. fm_polynomial_lut  — L(x) = Σ A_j x^{2^{jm}}   (F_{2^m}-polynomial, §3.1)
#   2. gen_shift_lut      — F(x) = x·L1(x)^{2^i} + x^{2^i}·L2(x)  (Thm 3.1, Eq. 3)
#   3. zeta_poly_lut      — LUT from zeta-exponent notation (Tables 1 & 3)
#   4. isotopic_shift_lut — F_L(x) = F(x+L(x)) + F(x) + F(L(x))   (Eq. 1)
#   5. s_of_f             — S(F) = {b : exists a, W_F(a,b)=0}       (Section 3.3)
#   6. nonlinear_gold_shift_lut — G_{i,L} with L(x)=a*x^d           (Eq. 4)
# VBF API used: gf_mul, gf_pow, walsh_zeroes, SBox, print_banner

using VBF
using Dates

"""
    fm_polynomial_lut(n, m, coeffs; modulus) -> Vector{Int}

LUT for F_{2^m}-polynomial L(x) = sum_{j=0}^{k-1} coeffs[j+1]*x^{2^{jm}} over GF(2^n).
k = n div m.  coeffs[j+1] in GF(2^n) (zero-based integer).
"""
function fm_polynomial_lut(
    n::Int, m::Int, coeffs::AbstractVector{<:Integer};
    modulus::Int = primitive_polynomial(n),
)
    k = div(n, m)
    length(coeffs) == k || error("fm_polynomial_lut: need $k coefficients")
    N = 1 << n
    lut = zeros(Int, N)
    for j in 0:k-1
        c = Int(coeffs[j+1])
        iszero(c) && continue
        exp = 1 << (j * m)
        for x in 0:N-1
            lut[x+1] = lut[x+1] ⊻ gf_mul(c, gf_pow(x, exp, n; modulus), n; modulus)
        end
    end
    lut
end

"""
    gen_shift_lut(n, i, L1_lut, L2_lut; modulus) -> Vector{Int}

LUT for F(x) = x*L1(x)^{2^i} + x^{2^i}*L2(x)  (Theorem 3.1, Equation 3).
"""
function gen_shift_lut(
    n::Int, i::Int,
    L1_lut::AbstractVector{<:Integer},
    L2_lut::AbstractVector{<:Integer};
    modulus::Int = primitive_polynomial(n),
)
    N = 1 << n
    pow2i = 1 << i
    lut = Vector{Int}(undef, N)
    for x in 0:N-1
        l1 = gf_pow(Int(L1_lut[x+1]), pow2i, n; modulus)
        l2 = Int(L2_lut[x+1])
        xp = gf_pow(x, pow2i, n; modulus)
        lut[x+1] = gf_mul(x, l1, n; modulus) ⊻ gf_mul(xp, l2, n; modulus)
    end
    lut
end

"""
    zeta_poly_lut(n, terms; modulus, zeta=2) -> Vector{Int}

Build LUT from a polynomial in zeta-exponent notation.
terms = [(coeff_exp, power)] where coeff_exp::Union{Int,Nothing};
nothing encodes coefficient 1.

Example: zeta^136*x^66 + x^3  =>  [(136,66),(nothing,3)]
"""
function zeta_poly_lut(
    n::Int, terms::AbstractVector;
    modulus::Int = primitive_polynomial(n), zeta::Int = 2,
)
    precoeffs = [(ce === nothing ? 1 : gf_pow(zeta, Int(ce), n; modulus), Int(pw))
                 for (ce, pw) in terms]
    N = 1 << n
    lut = zeros(Int, N)
    for x in 0:N-1
        acc = 0
        for (c, pw) in precoeffs
            acc = acc ⊻ gf_mul(c, gf_pow(x, pw, n; modulus), n; modulus)
        end
        lut[x+1] = acc
    end
    lut
end

"""
    isotopic_shift_lut(F_lut, L_lut) -> Vector{Int}

F_L(x) = F(x xor L(x)) xor F(x) xor F(L(x))  (isotopic shift, Eq. 1).
"""
function isotopic_shift_lut(F_lut::AbstractVector{<:Integer}, L_lut::AbstractVector{<:Integer})
    [F_lut[(x ⊻ L_lut[x+1])+1] ⊻ F_lut[x+1] ⊻ F_lut[L_lut[x+1]+1]
     for x in 0:length(F_lut)-1]
end

"""
    s_of_f(F::SBox) -> Vector{Int}

S(F) = {b in GF(2^n) : exists a, W_F(a,b)=0}  (Section 3.3, Proposition 3.2).
Returns sorted vector of distinct integers in 0..2^n-1 (includes 0).
"""
function s_of_f(F::SBox{N}) where {N}
    mask = (1 << N) - 1
    Z = walsh_zeroes(F)
    sort!(unique!(Int[Int(z & mask) for z in Z]))
end

"""
    nonlinear_gold_shift_lut(n, i, a, d; modulus) -> Vector{Int}

G_{i,L}(x) = x^{2^i}*L(x) + x*L(x)^{2^i} with monomial L(x) = a*x^d  (Eq. 4).
Expands to a*x^{2^i+d} + a^{2^i}*x^{d*2^i+1}.
Used in Theorem 3.2 to recover known APN power families from Gold isotopic shifts.
"""
function nonlinear_gold_shift_lut(
    n::Int, i::Int, a::Integer, d::Integer;
    modulus::Int = primitive_polynomial(n),
)
    pow2i = 1 << i
    a_int = Int(a)
    a2i = gf_pow(a_int, pow2i, n; modulus)
    e1 = pow2i + d
    e2 = d * pow2i + 1
    N = 1 << n
    [gf_mul(a_int, gf_pow(x, e1, n; modulus), n; modulus) ⊻
     gf_mul(a2i,   gf_pow(x, e2, n; modulus), n; modulus) for x in 0:N-1]
end

function paper_banner(io::IO = stdout)
    print_banner(io,
        "Budaghyan, Calderini, Carlet, Coulter, Villa (2021)",
        "Generalized Isotopic Shift Construction for APN Functions",
        "Julia $(VERSION)  |  $(Dates.today())",
    )
end
