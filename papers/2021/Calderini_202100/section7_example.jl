# Implements the Section 7 dimension-6 example — bent-based bivariate APN and
# its non-quadratic switch.
# Paper: Calderini, Budaghyan, Carlet (2021), pp. 79–105
# Section: 7 (opening example, from [29] with G. Leander)
#
# Over GF(2^3) x GF(2^3) with alpha primitive in GF(2^3):
#   B(x,y) = x^3 + y^3 + x^2*y + alpha^9*x*y^2
#   G(x,y) = alpha^54*x^5 + alpha^54*x*y^4 + alpha^45*y^5
#   F  = (B, G)      is a (quadratic) APN function;
#   F' = (B, G + f)  with the 27-term Boolean-switch f below is a
#                    non-quadratic APN function, CCZ-equivalent to the
#                    Edel-Pott function of [39].
#
# Verified here: F is APN of degree 2; F' is APN of degree > 2.
# Unverifiable here: CCZ-equivalence of F' to the Edel-Pott function — no
# representative of [39] is available in this repo (documented skip).
# VBF API used: gf_mul, gf_pow, primitive_polynomial, SBox,
#               differential_uniformity, algebraic_degree,
#               print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

# f(x,y) terms as (power of alpha, x-exponent, y-exponent), from Section 7.
const _SECTION7_F_TERMS = [
    (9, 7, 0), (18, 6, 4), (18, 6, 2), (45, 6, 1), (27, 5, 4),
    (18, 5, 2), (27, 5, 1), (54, 4, 6), (45, 4, 5), (27, 4, 3),
    (27, 3, 4), (45, 3, 2), (45, 3, 1), (27, 2, 6), (18, 2, 5),
    (0, 2, 3), (45, 1, 6), (36, 1, 5), (18, 1, 3), (27, 6, 0),
    (45, 4, 2), (54, 4, 1), (0, 3, 0), (9, 2, 4), (54, 1, 1),
    (54, 0, 6), (36, 0, 3),
]

"""
    section7_example_report([io]) -> NamedTuple

Verify the Section 7 dimension-6 example: F=(B,G) is quadratic APN and the
switched F'=(B,G+f) is non-quadratic APN.
"""
function section7_example_report(io::IO = stdout)
    m     = 3
    mod_m = primitive_polynomial(m)
    alpha = 2                       # class of x, primitive in GF(2^3)
    a(k)  = gf_pow(alpha, k, m; modulus = mod_m)
    mul(u, v) = gf_mul(u, v, m; modulus = mod_m)
    pw(u, e)  = gf_pow(u, e, m; modulus = mod_m)

    print_section("Section 7 — dimension-6 bent-based example and its switch", io)

    len   = 1 << m
    lutF  = Vector{Int}(undef, 1 << (2m))
    lutFp = Vector{Int}(undef, 1 << (2m))
    for x in 0:(len - 1), y in 0:(len - 1)
        B = pw(x, 3) ⊻ pw(y, 3) ⊻ mul(pw(x, 2), y) ⊻ mul(a(9), mul(x, pw(y, 2)))
        G = mul(a(54), pw(x, 5)) ⊻ mul(a(54), mul(x, pw(y, 4))) ⊻
            mul(a(45), pw(y, 5))
        f = 0
        for (k, ex, ey) in _SECTION7_F_TERMS
            f ⊻= mul(a(k), mul(pw(x, ex), pw(y, ey)))
        end
        idx = (x | (y << m)) + 1
        lutF[idx]  = B | (G << m)
        lutFp[idx] = B | ((G ⊻ f) << m)
    end
    F  = SBox{2m}(lutF)
    Fp = SBox{2m}(lutFp)

    ok_F  = (differential_uniformity(F) == 2)
    dF    = algebraic_degree(F)
    ok_Fp = (differential_uniformity(Fp) == 2)
    dFp   = algebraic_degree(Fp)
    print_check("F = (B, G) is APN", ok_F, io)
    print_kv("  algebraic degree of F", dF, io)
    print_check("F' = (B, G+f) is APN", ok_Fp, io)
    print_kv("  algebraic degree of F'", dFp, io)
    ok_deg = (dF == 2) && (dFp > 2)
    print_check("F quadratic, switch F' non-quadratic", ok_deg, io)
    println(io, "  [skip] CCZ-equivalence of F' to the Edel-Pott function [39]:")
    println(io, "         no reference representative available in this repo")

    all_ok = ok_F && ok_Fp && ok_deg
    print_kv("completeness", "exact LUT check at n=6; CCZ link to [39] unverified", io)
    (; all_ok, ok_F, ok_Fp, deg_F = dF, deg_Fp = dFp)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    section7_example_report()
end
