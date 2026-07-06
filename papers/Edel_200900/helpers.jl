# Implements paper-local helpers for the Edel & Pott (2009) reproduction.
# Paper: Edel, Pott (2009), "A new almost perfect nonlinear function which is
#        not quadratic", Adv. Math. Commun. 3(1):59-81.
# Section: General — field glue, Table-5 switching builders, report header.
#
# Pseudocode:
#   1. Fix GF(2^6) via Table 2: p(x) = x^6+x^4+x^3+x+1  (integer modulus 91),
#      primitive element u = x (bit pattern 2, multiplicative order 63).
#   2. Provide the paper's absolute trace (F_2^6 -> F_2) and the two subfield
#      traces tr_{8/2} (F_8 -> F_2) and tr_{4/2} (F_4 -> F_2) as Frobenius sums.
#   3. Build every Table-5 representative by Dillon switching: start from a base
#      APN and XOR a switching vector u^a times a Boolean function f(x).
# VBF API used: gf_pow, gf_mul, gf_trace, gf_monomial_lut, SBox,
#               absolute_walsh_spectrum, print_banner

using VBF

# ── Edel–Pott field GF(2^6): Table 2 ─────────────────────────────────────────
const EP_N       = 6
const EP_MODULUS = 91          # x^6+x^4+x^3+x+1 = 64+16+8+2+1
const EP_U       = 2           # primitive root u = x, ord(u) = 63

ep_pow(x, d) = gf_pow(x, d, EP_N; modulus = EP_MODULUS)
ep_mul(a, b) = gf_mul(a, b, EP_N; modulus = EP_MODULUS)
ep_U(k)      = ep_pow(EP_U, k)

# Absolute trace F_{2^6} -> F_2 (result 0/1).
ep_tr(x) = gf_trace(x, EP_N; modulus = EP_MODULUS)
# Subfield traces as Frobenius orbit sums, computed inside GF(2^6).
# tr_{8/2}(y) = y + y^2 + y^4  for y in F_8 ⊂ F_{2^6}  (result in F_2).
ep_tr82(y) = ep_pow(y, 1) ⊻ ep_pow(y, 2) ⊻ ep_pow(y, 4)
# tr_{4/2}(y) = y + y^2       for y in F_4 ⊂ F_{2^6}  (result in F_2).
ep_tr42(y) = ep_pow(y, 1) ⊻ ep_pow(y, 2)

_lut(f) = [f(x) for x = 0:(1 << EP_N) - 1]

# ── Table 5 (n = 6): switching representatives ───────────────────────────────
# Each `f_xy` is the point-evaluation of representative x.y. The "(No. x.y)+f(x)"
# notation of the paper maps to `f_prev(x) ⊻ (switch-vector · Boolean f(x))`.

# 1.1 = x^3
_f11(x) = ep_pow(x, 3)
# 1.2 = (1.1) + u( tr(u^56 x^3) + tr_{8/2}(u^18 x^9) )
_f12(x) = _f11(x) ⊻ ep_mul(ep_U(1),
    ep_tr(ep_mul(ep_U(56), ep_pow(x, 3))) ⊻ ep_tr82(ep_mul(ep_U(18), ep_pow(x, 9))))
# 2.1 = x^3 + u x^24 + x^10
_f21(x) = ep_pow(x, 3) ⊻ ep_mul(ep_U(1), ep_pow(x, 24)) ⊻ ep_pow(x, 10)
# 2.2 = (2.1) + u^3( tr(u^10 x^3 + u^53 x^5) + tr_{8/2}(u^36 x^9) )
_f22(x) = _f21(x) ⊻ ep_mul(ep_U(3),
    ep_tr(ep_mul(ep_U(10), ep_pow(x, 3)) ⊻ ep_mul(ep_U(53), ep_pow(x, 5))) ⊻
    ep_tr82(ep_mul(ep_U(36), ep_pow(x, 9))))
# 2.3 = (2.1) + [ tr(u^34 x^3 + u^48 x^5) + tr_{8/2}(u^9 x^9) ]   (switch vec = u^0)
_b23(x) = ep_tr(ep_mul(ep_U(34), ep_pow(x, 3)) ⊻ ep_mul(ep_U(48), ep_pow(x, 5))) ⊻
    ep_tr82(ep_mul(ep_U(9), ep_pow(x, 9)))
_f23(x) = _f21(x) ⊻ _b23(x)
# 2.4 = (2.1) + u^2( tr(u^24 x^3 + u^28 x^5) + tr_{8/2}(x^9) )
_f24(x) = _f21(x) ⊻ ep_mul(ep_U(2),
    ep_tr(ep_mul(ep_U(24), ep_pow(x, 3)) ⊻ ep_mul(ep_U(28), ep_pow(x, 5))) ⊻
    ep_tr82(ep_pow(x, 9)))
# 2.5 = (2.3) + u^42( tr(u^10 x^3 + u^51 x^5) + tr_{8/2}(u^9 x^9) )
_f25(x) = _f23(x) ⊻ ep_mul(ep_U(42),
    ep_tr(ep_mul(ep_U(10), ep_pow(x, 3)) ⊻ ep_mul(ep_U(51), ep_pow(x, 5))) ⊻
    ep_tr82(ep_mul(ep_U(9), ep_pow(x, 9))))
# 2.6 = (2.3) + u^23( tr(u^31 x^3 + u^49 x^5) + tr_{8/2}(u^9 x^9) )
_f26(x) = _f23(x) ⊻ ep_mul(ep_U(23),
    ep_tr(ep_mul(ep_U(31), ep_pow(x, 3)) ⊻ ep_mul(ep_U(49), ep_pow(x, 5))) ⊻
    ep_tr82(ep_mul(ep_U(9), ep_pow(x, 9))))
# 2.7 = (2.3) + u^12( tr(u^42 x^3 + u^13 x^5) + tr_{8/2}(u^54 x^9) )
_f27(x) = _f23(x) ⊻ ep_mul(ep_U(12),
    ep_tr(ep_mul(ep_U(42), ep_pow(x, 3)) ⊻ ep_mul(ep_U(13), ep_pow(x, 5))) ⊻
    ep_tr82(ep_mul(ep_U(54), ep_pow(x, 9))))
# 2.8 = (2.3) + u( tr(u^51 x^3 + u^60 x^5) + tr_{8/2}(u^18 x^9) )
_f28(x) = _f23(x) ⊻ ep_mul(ep_U(1),
    ep_tr(ep_mul(ep_U(51), ep_pow(x, 3)) ⊻ ep_mul(ep_U(60), ep_pow(x, 5))) ⊻
    ep_tr82(ep_mul(ep_U(18), ep_pow(x, 9))))
# 2.9 = (2.3) + u^14( tr(u^18 x^3 + u^61 x^5) + tr_{8/2}(u^18 x^9) )
_f29(x) = _f23(x) ⊻ ep_mul(ep_U(14),
    ep_tr(ep_mul(ep_U(18), ep_pow(x, 3)) ⊻ ep_mul(ep_U(61), ep_pow(x, 5))) ⊻
    ep_tr82(ep_mul(ep_U(18), ep_pow(x, 9))))
# 2.10 = (2.3) + u^17( tr(u^50 x^3 + u^56 x^5) )
_f210(x) = _f23(x) ⊻ ep_mul(ep_U(17),
    ep_tr(ep_mul(ep_U(50), ep_pow(x, 3)) ⊻ ep_mul(ep_U(56), ep_pow(x, 5))))
# 2.11 = (2.3) + u^19( tr(u^11 x^3 + u^7 x^5 + u^38 x^7 + u^61 x^11 + u^23 x^13)
#                      + tr_{8/2}(u^54 x^9) + tr_{4/2}(u^42 x^21) )   [Theorem 11]
function _f211(x)
    a = ep_tr(ep_mul(ep_U(11), ep_pow(x, 3)) ⊻ ep_mul(ep_U(7), ep_pow(x, 5)) ⊻
        ep_mul(ep_U(38), ep_pow(x, 7)) ⊻ ep_mul(ep_U(61), ep_pow(x, 11)) ⊻
        ep_mul(ep_U(23), ep_pow(x, 13)))
    b = ep_tr82(ep_mul(ep_U(54), ep_pow(x, 9)))
    c = ep_tr42(ep_mul(ep_U(42), ep_pow(x, 21)))
    _f23(x) ⊻ ep_mul(ep_U(19), a ⊻ b ⊻ c)
end
# 2.12 = (2.4) + u( tr(u^54 x^3 + u^47 x^5) + tr_{8/2}(u^9 x^9) )
_f212(x) = _f24(x) ⊻ ep_mul(ep_U(1),
    ep_tr(ep_mul(ep_U(54), ep_pow(x, 3)) ⊻ ep_mul(ep_U(47), ep_pow(x, 5))) ⊻
    ep_tr82(ep_mul(ep_U(9), ep_pow(x, 9))))

"""
    edelpott_table5() -> Vector{NamedTuple}

The 14 Edel–Pott (2009) Table-5 representatives on `GF(2⁶)`, built from the
paper's switching formulas. Each entry is `(name, sbox, gamma, delta, walsh)`
where `gamma`/`delta`/`walsh` are the *published* Table-6 invariants
(`walsh ∈ {:classical, :nonclassical}`) for cross-checking.
"""
function edelpott_table5()
    specs = (
        ("1.1",  _f11,  1102,  94, :classical),
        ("1.2",  _f12,  1146,  94, :classical),
        ("2.1",  _f21,  1166,  96, :classical),
        ("2.2",  _f22,  1168,  96, :classical),
        ("2.3",  _f23,  1170,  96, :classical),
        ("2.4",  _f24,  1172,  96, :classical),
        ("2.5",  _f25,  1158,  96, :classical),
        ("2.6",  _f26,  1170,  96, :nonclassical),
        ("2.7",  _f27,  1170,  96, :classical),
        ("2.8",  _f28,  1170,  96, :classical),
        ("2.9",  _f29,  1172,  96, :classical),
        ("2.10", _f210, 1174,  96, :classical),
        ("2.11", _f211, 1300, 152, :classical),   # Theorem 11 (non-quadratic)
        ("2.12", _f212, 1166,  94, :classical),
    )
    return [(; name, sbox = SBox(_lut(f)), gamma, delta, walsh)
            for (name, f, gamma, delta, walsh) in specs]
end

"""
    theorem11_function() -> SBox

The Theorem 11 / eq. (9) representative of the new non-quadratic APN function:

    F(x) = x^3 + u^17(x^17+x^18+x^20+x^24)
         + u^14( tr(u^52 x^3 + u^6 x^5 + u^19 x^7 + u^28 x^11 + u^2 x^13)
               + tr_{8/2}((u^2 x)^9) + tr_{4/2}(x^21) )

This is a *different* representative of the same class as Table-5 entry 2.11.
"""
function theorem11_function()
    function F(x)
        t = ep_pow(x, 3) ⊻ ep_mul(ep_U(17),
            ep_pow(x, 17) ⊻ ep_pow(x, 18) ⊻ ep_pow(x, 20) ⊻ ep_pow(x, 24))
        a = ep_tr(ep_mul(ep_U(52), ep_pow(x, 3)) ⊻ ep_mul(ep_U(6), ep_pow(x, 5)) ⊻
            ep_mul(ep_U(19), ep_pow(x, 7)) ⊻ ep_mul(ep_U(28), ep_pow(x, 11)) ⊻
            ep_mul(ep_U(2), ep_pow(x, 13)))
        b = ep_tr82(ep_pow(ep_mul(ep_U(2), x), 9))
        c = ep_tr42(ep_pow(x, 21))
        t ⊻ ep_mul(ep_U(14), a ⊻ b ⊻ c)
    end
    return SBox(_lut(F))
end

"""
    ep_gold_x3() -> SBox

Gold `x³` over the Edel–Pott field (representative 1.1, a power APN).
"""
ep_gold_x3() = SBox(_lut(_f11))

"""
    ep_is_classical(F::SBox) -> Bool

Whether `F` has the *classical* Walsh spectrum, i.e. the CCZ-invariant
`absolute_walsh_spectrum` equal to that of `x³` (Edel–Pott, comment after
Proposition 1).
"""
ep_is_classical(F::SBox) = absolute_walsh_spectrum(F) == absolute_walsh_spectrum(ep_gold_x3())

# ── Report header ────────────────────────────────────────────────────────────
"""Print the paper banner (title, venue, field parameters, scope)."""
function print_header(io::IO = stdout)
    print_banner(io,
        "Edel, Pott (2009): A new almost perfect nonlinear function",
        "which is not quadratic — Adv. Math. Commun. 3(1):59-81",
        "Field GF(2^6): p(x)=x^6+x^4+x^3+x+1 (modulus 91), u=x, ord(u)=63",
        "Julia $(VERSION)  ·  scope: exact n=6 (Tables 5,6; Thm 7,9,11; Prop 2)")
end
