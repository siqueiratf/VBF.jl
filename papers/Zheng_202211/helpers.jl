# Implements paper-local helpers for the Zheng–Kan–Li–Peng–Tang (2022) reproduction.
# Paper: Zheng, Kan, Li, Peng, Tang (2022), "Constructing new APN functions through
#        relative trace functions", arXiv:2101.11535v1 [cs.IT]
# Section: General — field utilities, trace-form LUT builder, report formatting
#
# Pseudocode:
#   1. n=2m, q=2^m, Tr_m^n(x) = x + x^q (relative trace F_{2^n} → F_{2^m})
#   2. f_s(x) = a·Tr_m^n(bx^3) + a^q·Tr_m^n(cx^{2^s+1})
#            = (a·b)x^3 + (a·b^q)x^{3q} + (a^q·c)x^{2^s+1} + (a^q·c^q)x^{(2^s+1)q}
#   3. F15 (Table II, new family): s=3, c=b^3, b non-cube, a ∉ F_q
# VBF API used: gf_mul, gf_pow, primitive_polynomial, SBox

using VBF

function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Zheng, Kan, Li, Peng, Tang (2022): Constructing New APN Functions")
    println(io, "  through Relative Trace Functions — arXiv:2101.11535v1 [cs.IT]")
    println(io, "=" ^ 72)
end

"""
    zheng_lut(m, s, a, b, c; modulus) -> Vector{Int}

LUT for the Zheng et al. trace-form quadrinomial over GF(2^{2m}):

    f_s(x) = a·Tr_m^n(b·x^3) + a^q·Tr_m^n(c·x^{2^s+1})
           = (a·b)x^3 + (a·b^q)x^{3q} + (a^q·c)x^{2^s+1} + (a^q·c^q)x^{(2^s+1)q}

where n=2m, q=2^m.

Conditions for APN (Theorem 3.3 Case iii — new family F15):
  s=3, b non-cube in F_{2^n}, c/b^3 ∈ F*_{2^m}, a ∉ F_{2^m}.
"""
function zheng_lut(m::Int, s::Int, a::Int, b::Int, c::Int;
                   modulus::Int = primitive_polynomial(2m))::Vector{Int}
    n  = 2m
    q  = 1 << m
    ab   = gf_mul(a, b, n; modulus)
    abq  = gf_mul(a, gf_pow(b, q, n; modulus), n; modulus)
    aqc  = gf_mul(gf_pow(a, q, n; modulus), c, n; modulus)
    aqcq = gf_mul(gf_pow(a, q, n; modulus), gf_pow(c, q, n; modulus), n; modulus)
    e1 = 3
    e2 = 3q
    e3 = (1 << s) + 1
    e4 = ((1 << s) + 1) * q
    [gf_mul(ab,   gf_pow(x, e1, n; modulus), n; modulus) ⊻
     gf_mul(abq,  gf_pow(x, e2, n; modulus), n; modulus) ⊻
     gf_mul(aqc,  gf_pow(x, e3, n; modulus), n; modulus) ⊻
     gf_mul(aqcq, gf_pow(x, e4, n; modulus), n; modulus)
     for x in 0:(1 << n) - 1]
end

"""
    f15_sbox(m; a, b, modulus) -> SBox

Build the F15 (Table II) family SBox: f₃(x) = a·Tr_m^n(b·x³) + a^q·Tr_m^n(b³·x⁹),
s=3, c=b^3. Default: a=2, b=2.

- a=2: primitive element of GF(2^n), satisfies a ∉ F_{2^m} for m<n.
- b=2: non-cube when 3 | 2^n-1 (holds for all n here since 3 | 2^{2m}-1).
"""
function f15_sbox(m::Int; a::Int = 2, b::Int = 2,
                  modulus::Int = primitive_polynomial(2m))
    n = 2m
    c = gf_pow(b, 3, n; modulus)   # c = b^3, so c/b^3 = 1 ∈ F*_{2^m}
    SBox(zheng_lut(m, 3, a, b, c; modulus))
end

