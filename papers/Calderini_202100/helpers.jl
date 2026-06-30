# Implements shared helpers for the Calderini et al. (2021) reproduction.
# Paper: Calderini, Budaghyan, Carlet (2021),
#        "On Known Constructions of APN and AB Functions and Their Relation to Each Other",
#        RAD HAZU, Matematičke Znanosti, Vol. 25 = 546 (2021): 79–105
# Section: General — bivariate LUT builders, hexanomial, Theorem 6.2 family, report header
#
# Pseudocode (bivariate_carlet_sbox):
#   For each (x,y) in GF(2^m)×GF(2^m):
#     1. G(x,y) = x^{2^i+1} + a·x·y^{2^i} + b·y^{2^i+1}  (Prop 4.2 form)
#     2. pack: index = x|(y<<m), value = (xy)|(G<<m)
# VBF API used: gf_mul, gf_pow, primitive_polynomial, SBox,
#               print_banner, differential_uniformity, apn_ea_mugshot

using VBF
using Dates

function print_header(io::IO = stdout)
    print_banner(io,
        "Calderini, Budaghyan, Carlet (2021)",
        "On Known Constructions of APN and AB Functions and Their Relation to Each Other",
        "RAD HAZU, Matematičke Znanosti, Vol. 25 = 546 (2021): 79–105")
    println(io, "Julia $(VERSION)  |  $(today())")
    println(io)
    println(io, "Scope:")
    println(io, "  [exact]  Theorem 3.1: hexanomial APN iff no-zero condition (n=4,6)")
    println(io, "  [exact]  Theorem 4.4: bivariate Carlet EA-equiv hexanomial (n=8)")
    println(io, "  [exact]  Proposition 4.5: b-value EA-equivalence (n=8)")
    println(io, "  [exact]  Theorem 5.1: Zhou-Pott APN iff alpha non-cube (n=6,8)")
    println(io, "  [exact]  Theorem 5.6: F1/F2/F3 spot-checks (n=8)")
    println(io, "  [exact]  Theorem 6.2: new APN family condition (n=8)")
    println(io, "  [exact]  Section 6.1: n=8 exhaustive search + CCZ-distinctness")
    println(io, "  [note]   Proposition 7.5: Kaleyski-Li in Gologlu F2 (optional n=10)")
    println(io, "  [skip]   n=10,12,16 large CCZ-checks (Magma/out-of-scope)")
    println(io)
end

"""
    bivariate_carlet_sbox(m, i, a, b; modulus) -> SBox{2m}

Bivariate Carlet construction F(x,y) = (xy, G(x,y)) with the simplified G from
Proposition 4.2 / Theorem 4.4:
  G(x,y) = x^{2^i+1} + a*x*y^{2^i} + b*y^{2^i+1},  a in {0,1}, b != 0.
Over GF(2^m) x GF(2^m), packed as index = x|(y<<m), value = (xy)|(G<<m).
APN iff P(X) = X^{2^i+1} + aX + b has no root in GF(2^m).
"""
function bivariate_carlet_sbox(m::Int, i::Int, a::Int, b::Int;
                                modulus::Int = primitive_polynomial(m))
    n   = m
    mod = modulus
    Ei  = (1 << i) + 1
    Eiy = 1 << i
    len = 1 << n
    lut = Vector{Int}(undef, 1 << (2n))
    for x in 0:(len - 1), y in 0:(len - 1)
        xy  = gf_mul(x, y, n; modulus = mod)
        Gxy = gf_pow(x, Ei, n; modulus = mod) ⊻
              gf_mul(a, gf_mul(x, gf_pow(y, Eiy, n; modulus = mod), n; modulus = mod),
                     n; modulus = mod) ⊻
              gf_mul(b, gf_pow(y, Ei, n; modulus = mod), n; modulus = mod)
        lut[(x | (y << n)) + 1] = xy | (Gxy << n)
    end
    SBox{2n}(lut)
end

"""
    bivariate_carlet_condition(m, i, a, b; modulus) -> Bool

X^{2^i+1} + aX + b has no root in GF(2^m). True means F is APN.
"""
function bivariate_carlet_condition(m::Int, i::Int, a::Int, b::Int;
                                     modulus::Int = primitive_polynomial(m))
    n   = m
    mod = modulus
    Ei  = (1 << i) + 1
    for x in 0:(1 << n) - 1
        gf_pow(x, Ei, n; modulus = mod) ⊻
            gf_mul(a, x, n; modulus = mod) ⊻ b == 0 && return false
    end
    true
end

"""
    hexanomial_sbox(m, i, c, d; modulus) -> SBox{2m}

Hexanomial H(x) from Theorem 3.1 (Budaghyan-Carlet 2008 family, simplified 5-term form):
  H(x) = d*x^{2^{m+i}+2^i} + x^{2^i+1} + x^{2^{m+i}+2^m}
        + c*x^{2^{m+i}+1} + c^{2^m}*x^{2^i+2^m}
over GF(2^{2m}), gcd(i,m)=1, d not in GF(2^m).
APN iff hexanomial_condition(m,i,c) holds.
"""
function hexanomial_sbox(m::Int, i::Int, c::Int, d::Int;
                          modulus::Int = primitive_polynomial(2m))
    n   = 2m
    mod = modulus
    Cm  = gf_pow(c, 1 << m, n; modulus = mod)
    e1  = (1 << (m + i)) + (1 << i)
    e2  = (1 << i) + 1
    e3  = (1 << (m + i)) + (1 << m)
    e4  = (1 << (m + i)) + 1
    e5  = (1 << i) + (1 << m)
    lut = Vector{Int}(undef, 1 << n)
    for x in 0:(1 << n) - 1
        lut[x + 1] =
            gf_mul(d,  gf_pow(x, e1, n; modulus = mod), n; modulus = mod) ⊻
            gf_pow(x, e2, n; modulus = mod) ⊻
            gf_pow(x, e3, n; modulus = mod) ⊻
            gf_mul(c,  gf_pow(x, e4, n; modulus = mod), n; modulus = mod) ⊻
            gf_mul(Cm, gf_pow(x, e5, n; modulus = mod), n; modulus = mod)
    end
    SBox{n}(lut)
end

"""
    hexanomial_condition(m, i, c; modulus) -> Bool

APN condition for Theorem 3.1:
x^{2^i+1} + c*x^{2^i} + c^{2^m}*x + 1 has no solution x with x^{2^m+1}=1.
"""
function hexanomial_condition(m::Int, i::Int, c::Int;
                               modulus::Int = primitive_polynomial(2m))
    n   = 2m
    mod = modulus
    Cm  = gf_pow(c, 1 << m, n; modulus = mod)
    Eq1 = (1 << m) + 1
    Ei1 = (1 << i) + 1
    Ei  = 1 << i
    for x in 0:(1 << n) - 1
        gf_pow(x, Eq1, n; modulus = mod) == 1 || continue
        val = gf_pow(x, Ei1, n; modulus = mod) ⊻
              gf_mul(c,  gf_pow(x, Ei, n; modulus = mod), n; modulus = mod) ⊻
              gf_mul(Cm, x, n; modulus = mod) ⊻ 1
        val == 0 && return false
    end
    true
end

"""
    zhou_pott_sbox(m, i, j, alpha; modulus) -> SBox{2m}

Zhou-Pott APN: F(x,y) = (xy, x^{2^i+1} + alpha*y^{(2^i+1)*2^j}) over GF(2^m) x GF(2^m).
APN when m even, gcd(i,m)=1, j even, alpha not a cube in GF(2^m)*.
This is the F3 canonical form (Corollary 5.7).
"""
function zhou_pott_sbox(m::Int, i::Int, j::Int, alpha::Int;
                         modulus::Int = primitive_polynomial(m))
    n   = m
    mod = modulus
    Ei  = (1 << i) + 1
    Ey  = Ei * (1 << j)
    len = 1 << n
    lut = Vector{Int}(undef, 1 << (2n))
    for x in 0:(len - 1), y in 0:(len - 1)
        xy  = gf_mul(x, y, n; modulus = mod)
        Gxy = gf_pow(x, Ei, n; modulus = mod) ⊻
              gf_mul(alpha, gf_pow(y, Ey, n; modulus = mod), n; modulus = mod)
        lut[(x | (y << n)) + 1] = xy | (Gxy << n)
    end
    SBox{2n}(lut)
end

"""
    theorem6_2_sbox(m, i, b, c; modulus) -> SBox{2m}

New APN family from Theorem 6.2 (n=2m, m even, i<m/2, gcd(i,m)=1):
  F(x,y) = (xy, x^{2^i+1} + x^{2^{i+m/2}}*y^{2^{m/2}} + b*xy^{2^i} + c*y^{2^i+1})
over GF(2^m) x GF(2^m).
APN iff theorem6_2_condition(m,i,b,c) holds.
"""
function theorem6_2_sbox(m::Int, i::Int, b::Int, c::Int;
                          modulus::Int = primitive_polynomial(m))
    n   = m
    mod = modulus
    h   = m ÷ 2
    Ei1 = (1 << i) + 1
    Ex  = 1 << (i + h)
    Ey  = 1 << h
    Eyi = 1 << i
    len = 1 << n
    lut = Vector{Int}(undef, 1 << (2n))
    for x in 0:(len - 1), y in 0:(len - 1)
        xy  = gf_mul(x, y, n; modulus = mod)
        Gxy = gf_pow(x, Ei1, n; modulus = mod) ⊻
              gf_mul(gf_pow(x, Ex, n; modulus = mod),
                     gf_pow(y, Ey, n; modulus = mod), n; modulus = mod) ⊻
              gf_mul(b, gf_mul(x, gf_pow(y, Eyi, n; modulus = mod), n; modulus = mod),
                     n; modulus = mod) ⊻
              gf_mul(c, gf_pow(y, Ei1, n; modulus = mod), n; modulus = mod)
        lut[(x | (y << n)) + 1] = xy | (Gxy << n)
    end
    SBox{2n}(lut)
end

"""
    theorem6_2_condition(m, i, b, c; modulus) -> Bool

APN condition from Theorem 6.2:
P(X) = (cX^{2^i+1} + bX^{2^i} + 1)^{2^{m/2}+1} + X^{2^{m/2}+1} has no zero in GF(2^m).
Requires m even.
"""
function theorem6_2_condition(m::Int, i::Int, b::Int, c::Int;
                               modulus::Int = primitive_polynomial(m))
    n   = m
    mod = modulus
    h   = m ÷ 2
    Ei1 = (1 << i) + 1
    Ei  = 1 << i
    Eh1 = (1 << h) + 1
    for x in 0:(1 << n) - 1
        inner = gf_mul(c, gf_pow(x, Ei1, n; modulus = mod), n; modulus = mod) ⊻
                gf_mul(b, gf_pow(x, Ei,  n; modulus = mod), n; modulus = mod) ⊻ 1
        val   = gf_pow(inner, Eh1, n; modulus = mod) ⊻
                gf_pow(x,     Eh1, n; modulus = mod)
        val == 0 && return false
    end
    true
end
