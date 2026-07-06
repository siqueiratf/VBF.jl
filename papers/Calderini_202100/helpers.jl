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
    println(io, "  [exact]  Theorem 3.1: hexanomial APN iff no-zero condition (n=4,6,8)")
    println(io, "  [exact]  Theorem 4.3: pentanomial APN condition + class == hexanomial class (n=6,8)")
    println(io, "  [exact]  Theorem 4.4: bivariate Carlet EA-subset of hexanomial class (n=6,8)")
    println(io, "  [exact]  Proposition 4.5: non-cube b-value EA-equivalence (n=8, m=4 even)")
    println(io, "  [exact]  Theorem 5.1: Zhou-Pott APN iff alpha non-cube (n=8; m even only)")
    println(io, "  [rand]   Theorem 5.4: general bivariate condition, seeded random sample (n=6,8)")
    println(io, "  [exact]  Theorem 5.6/Cor 5.7/Prop 5.8: F1/F2/F3 spot-checks (n=8,10,12)")
    println(io, "  [exact]  Theorem 6.2 + Lemma 6.1: new APN family condition (n=8)")
    println(io, "  [exact]  Section 6.1.1: n=8 exhaustive F1/F2 case classification +")
    println(io, "           CCZ-distinctness via ortho-derivative spectra (quadratic APN:")
    println(io, "           CCZ-equiv <=> EA-equiv, Yoshiara 2012)")
    println(io, "  [spot]   Section 6.1.3: n=12 targeted case checks (aggregate rank-screened")
    println(io, "           sweep opt-in: make section6_1_n12, threaded)")
    println(io, "  [exact]  Theorem 7.1: biprojective reduction f1-f4 (n=6, normalized coeffs)")
    println(io, "  [exact]  Theorem 7.2: Gologlu F1/F2 APN (n=8,10)")
    println(io, "  [exact]  Section 7: dimension-6 switching example (B, G, G+f)")
    println(io, "  [note]   Proposition 7.5: Kaleyski-Li in Gologlu F2 (optional n=10)")
    println(io, "  [skip]   Section 6.1.2 aggregate n=10 sweep (opt-in, ~15-30 min: make section6_1_deep)")
    println(io, "  [skip]   Section 6.1.4 n=16 sweep (est. years of CPU; claims are Prop 5.8/")
    println(io, "           Cor 5.7 instances verified here at m=4,5,6)")
    println(io, "  [skip]   Tables 1-2 (survey content); CCZ vs external n=8 catalogs [52,53]")
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

Exact hexanomial H(x) from Theorem 3.1 (Budaghyan-Carlet 2008 family):
  H(x) = d*x^{2^i(2^m+1)} + x^{2^m+1}
        + x^{2^i+1} + x^{2^m(2^i+1)} + c*x^{2^{m+i}+1} + c^{2^m}*x^{2^i+2^m}
over GF(2^{2m}), gcd(i,m)=1, d not in GF(2^m).
APN iff hexanomial_condition(m,i,c) holds.
"""
function hexanomial_sbox(m::Int, i::Int, c::Int, d::Int;
                          modulus::Int = primitive_polynomial(2m))
    n   = 2m
    mod = modulus
    Cm  = gf_pow(c, 1 << m, n; modulus = mod)
    e1  = (1 << (m + i)) + (1 << i)   # 2^i(2^m+1)
    e2  = (1 << m) + 1                # 2^m+1
    e3  = (1 << i) + 1                # 2^i+1
    e4  = (1 << (m + i)) + (1 << m)   # 2^m(2^i+1)
    e5  = (1 << (m + i)) + 1          # 2^{m+i}+1
    e6  = (1 << i) + (1 << m)         # 2^i+2^m
    lut = Vector{Int}(undef, 1 << n)
    for x in 0:(1 << n) - 1
        lut[x + 1] =
            gf_mul(d,  gf_pow(x, e1, n; modulus = mod), n; modulus = mod) ⊻
            gf_pow(x, e2, n; modulus = mod) ⊻
            gf_pow(x, e3, n; modulus = mod) ⊻
            gf_pow(x, e4, n; modulus = mod) ⊻
            gf_mul(c,  gf_pow(x, e5, n; modulus = mod), n; modulus = mod) ⊻
            gf_mul(Cm, gf_pow(x, e6, n; modulus = mod), n; modulus = mod)
    end
    SBox{n}(lut)
end

"""
    pentanomial_sbox(m, i, c, d; modulus) -> SBox{2m}

Exact pentanomial P(x) from Theorem 4.3 ([17]; same APN class as Theorem 3.1):
  P(x) = d*x^{2^m+1} + x^{2^i+1} + x^{2^m(2^i+1)}
        + c*x^{2^{m+i}+1} + c^{2^m}*x^{2^i+2^m}
over GF(2^{2m}), gcd(i,m)=1, d not in GF(2^m).
APN iff hexanomial_condition(m,i,c) holds (same condition as Theorem 3.1).
"""
function pentanomial_sbox(m::Int, i::Int, c::Int, d::Int;
                           modulus::Int = primitive_polynomial(2m))
    n   = 2m
    mod = modulus
    Cm  = gf_pow(c, 1 << m, n; modulus = mod)
    e1  = (1 << m) + 1                # 2^m+1
    e2  = (1 << i) + 1                # 2^i+1
    e3  = (1 << (m + i)) + (1 << m)   # 2^m(2^i+1)
    e4  = (1 << (m + i)) + 1          # 2^{m+i}+1
    e5  = (1 << i) + (1 << m)         # 2^i+2^m
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
    f1_sbox(m, i, h, k, r, b, c; modulus) -> SBox{2m}

Canonical form F1 of Theorem 5.6:
  F1(x,y) = (xy, x^{2^i+1} + x^{2^{i+h}}*y^{2^h} + b*x^{2^k}*y^{2^{i+k}} + c*y^{2^{i+r}+2^r})
over GF(2^m) x GF(2^m). With b=0 the k parameter is irrelevant (F1 "b=0" subcase).
"""
function f1_sbox(m::Int, i::Int, h::Int, k::Int, r::Int, b::Int, c::Int;
                  modulus::Int = primitive_polynomial(m))
    n   = m
    mod = modulus
    Ei1 = (1 << i) + 1
    Exh = 1 << (i + h)   # gf_pow reduces via x^{2^m} = x
    Eyh = 1 << h
    Exk = 1 << k
    Eyk = 1 << (i + k)
    Eyr = ((1 << i) + 1) * (1 << r)
    len = 1 << n
    lut = Vector{Int}(undef, 1 << (2n))
    for x in 0:(len - 1), y in 0:(len - 1)
        xy  = gf_mul(x, y, n; modulus = mod)
        Gxy = gf_pow(x, Ei1, n; modulus = mod) ⊻
              gf_mul(gf_pow(x, Exh, n; modulus = mod),
                     gf_pow(y, Eyh, n; modulus = mod), n; modulus = mod) ⊻
              gf_mul(b, gf_mul(gf_pow(x, Exk, n; modulus = mod),
                               gf_pow(y, Eyk, n; modulus = mod), n; modulus = mod),
                     n; modulus = mod) ⊻
              gf_mul(c, gf_pow(y, Eyr, n; modulus = mod), n; modulus = mod)
        lut[(x | (y << n)) + 1] = xy | (Gxy << n)
    end
    SBox{2n}(lut)
end

"""
    f2_sbox(m, i, k, r, c; modulus) -> SBox{2m}

Canonical form F2 of Theorem 5.6:
  F2(x,y) = (xy, x^{2^i+1} + x^{2^k}*y^{2^{i+k}} + c*y^{2^{i+r}+2^r})
over GF(2^m) x GF(2^m), c != 0.
"""
function f2_sbox(m::Int, i::Int, k::Int, r::Int, c::Int;
                  modulus::Int = primitive_polynomial(m))
    n   = m
    mod = modulus
    Ei1 = (1 << i) + 1
    Exk = 1 << k
    Eyk = 1 << (i + k)
    Eyr = ((1 << i) + 1) * (1 << r)
    len = 1 << n
    lut = Vector{Int}(undef, 1 << (2n))
    for x in 0:(len - 1), y in 0:(len - 1)
        xy  = gf_mul(x, y, n; modulus = mod)
        Gxy = gf_pow(x, Ei1, n; modulus = mod) ⊻
              gf_mul(gf_pow(x, Exk, n; modulus = mod),
                     gf_pow(y, Eyk, n; modulus = mod), n; modulus = mod) ⊻
              gf_mul(c, gf_pow(y, Eyr, n; modulus = mod), n; modulus = mod)
        lut[(x | (y << n)) + 1] = xy | (Gxy << n)
    end
    SBox{2n}(lut)
end

"""
    hexanomial_class_mugshots(m; modulus) -> Set{APNEAMugshot}

EA-mugshot set of all APN hexanomials (exact Theorem 3.1 form) at n=2m,
over all i with gcd(i,m)=1 and all c, with a fixed d not in GF(2^m).
"""
function hexanomial_class_mugshots(m::Int; modulus::Int = primitive_polynomial(2m))
    n    = 2m
    d    = first(x for x in 1:(1 << n) - 1
                 if gf_pow(x, 1 << m, n; modulus = modulus) != x)
    mugs = Set{APNEAMugshot}()
    for i in 1:(m - 1)
        gcd(i, m) == 1 || continue
        for c in 0:(1 << n) - 1
            hexanomial_condition(m, i, c; modulus = modulus) || continue
            H = hexanomial_sbox(m, i, c, d; modulus = modulus)
            differential_uniformity(H) == 2 || continue
            push!(mugs, apn_ea_mugshot(H))
        end
    end
    mugs
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
