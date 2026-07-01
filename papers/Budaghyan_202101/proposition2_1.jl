# Implements Section 2: Proposition 2.1 and Remark 2.1.
# Paper: Budaghyan, Calderini, Carlet, Coulter, Villa (2021),
#        "Generalized Isotopic Shift Construction for APN Functions"
# Section: 2 — Further results on the isotopic linear shift over F_{2^n}
#
# Pseudocode:
#   Remark 2.1:
#     1. F(x) = x^5 over GF(2^6); verify NOT APN (du=4)
#     2. L(x) = zeta*x^8; build F_L = F(x+L(x)) + F(x) + F(L(x))
#     3. Verify F_L = zeta*x^12 + zeta^4*x^33  (closed-form check)
#     4. Verify F_L is APN (du=2)
#   Proposition 2.1 (computational, from [6]):
#     Over F_{2^6}, any quadratic APN map is an isotopic shift of any other.
#     Not independently verified here (requires exhaustive search over all
#     linear permutations/2-to-1 maps of F_{2^6}).
# VBF API used: gf_monomial_lut, SBox, differential_uniformity, print_section,
#               print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

const MOD6 = primitive_polynomial(6)  # 67, zeta=2 has order 63

"""
    remark2_1_build() -> NamedTuple

Remark 2.1: F(x)=x^5 (not APN), L(x)=zeta*x^8 -> F_L(x) = zeta*x^12 + zeta^4*x^33 (APN).
"""
function remark2_1_build()
    n = 6
    mod = MOD6
    zeta = 2

    F_lut = gf_monomial_lut(n, 5; modulus=mod)
    du_F  = differential_uniformity(SBox{n}(F_lut))

    # L(x) = zeta * x^8
    zeta1 = gf_pow(zeta, 1, n; modulus=mod)
    L_lut = [gf_mul(zeta1, gf_pow(x, 8, n; modulus=mod), n; modulus=mod) for x in 0:63]

    FL_lut = isotopic_shift_lut(F_lut, L_lut)
    du_FL  = differential_uniformity(SBox{n}(FL_lut))

    # Closed-form: zeta*x^12 + zeta^4*x^33
    zeta4  = gf_pow(zeta, 4, n; modulus=mod)
    FL_formula = [gf_mul(zeta1, gf_pow(x, 12, n; modulus=mod), n; modulus=mod) ⊻
                  gf_mul(zeta4, gf_pow(x, 33, n; modulus=mod), n; modulus=mod) for x in 0:63]

    (; du_F, du_FL, formula_matches = FL_lut == FL_formula)
end

function proposition2_1_report(io::IO = stdout)
    print_section(io, "Section 2 — Proposition 2.1 & Remark 2.1")

    r = remark2_1_build()

    print_kv(io, "Field", "GF(2^6), poly=0x$(string(MOD6,base=16)), zeta=2 (order 63)")
    print_kv(io, "F(x)", "x^5  (Gold exponent 2^2+1 but gcd(2,6)=2 != 1, not APN)")
    print_check(io, "F(x)=x^5 is NOT APN over GF(2^6) (du=4)", r.du_F == 4)
    print_kv(io, "L(x)", "zeta*x^8")
    print_check(io, "F_L = zeta*x^12 + zeta^4*x^33  (formula check)", r.formula_matches)
    print_check(io, "F_L is APN over GF(2^6) (du=2)", r.du_FL == 2)

    print_section(io, "Proposition 2.1 (Section 2)")
    print_kv(io, "Claim", "Over F_{2^6}: for any two quadratic APN maps F,G, there exist")
    print_kv(io, "",       "L (permutation) and L' (2-to-1) s.t. F_L, F_{L'} are EA-equiv to G.")
    print_kv(io, "Status", "Computational result from [6] (Budaghyan et al. 2020).")
    print_kv(io, "Note",   "Not independently verified here (exhaustive over all lin maps of F_{2^6}).")
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition2_1_report()
end
