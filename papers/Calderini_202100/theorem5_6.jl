# Implements Theorem 5.6 — F1/F2/F3 canonical forms for bivariate APN.
# Paper: Calderini, Budaghyan, Carlet (2021), pp. 79-105
# Section: 5 — Theorem 5.6, Corollary 5.7, Proposition 5.8
#
# Theorem 5.6: Any F=(xy,G) APN with G monomial-linear is EA-equiv to one of:
#   F3(x,y) = (xy, x^{2^i+1} + c'*y^{2^{i+r}+2^r})              [Zhou-Pott]
#   F2(x,y) = (xy, x^{2^i+1} + x^{2^k}*y^{2^{i+k}} + c'*y^{...})  [Taniguchi family k=1,r=2]
#   F1(x,y) = (xy, x^{2^i+1} + x^{2^{i+h}}*y^{2^h} + b'*x^{2^k}*y^{2^{i+k}} + c'*y^{...})
#
# Corollary 5.7: F3 = Zhou-Pott; F2 (k=1,r=2) contains Taniguchi(a=1).
# Proposition 5.8: F1 with b=0, h=m-i, r=m-2i is EA-equiv to Taniguchi.
#
# Pseudocode:
#   1. Build F3 (Zhou-Pott a=0): verify APN
#   2. Build F2 (Taniguchi a=1 representative): verify APN
#   3. Corollary 5.7: build F2(k=1,r=2) directly, verify mugshot == Taniguchi mugshot
#   4. Build F1(b=0, h=m-i, r=m-2i): search for valid c', verify mugshot == Taniguchi
# VBF API used: taniguchi_apn, differential_uniformity, apn_ea_mugshot,
#               print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem5_6_report([io]; m) -> NamedTuple

Spot-check canonical forms F1/F2/F3 of Theorem 5.6 and Corollary 5.7 via EA-mugshots.
"""
function theorem5_6_report(io::IO = stdout; m::Int = 4)
    iseven(m) || error("needs m even, got m=$m")
    print_section("Theorem 5.6 — F1/F2/F3 canonical bivariate APN forms (m=$m, n=$(2m))", io)

    mod_m = primitive_polynomial(m)
    i = first(ii for ii in 1:(m - 1) if gcd(ii, m) == 1)

    # --- F3: Zhou-Pott (c' non-cube, r=0) ---
    alpha = first(a for a in 1:(1 << m) - 1
                  if !gf_is_dth_power(a, 3, m; modulus = mod_m))
    F3 = bivariate_carlet_sbox(m, i, 0, alpha; modulus = mod_m)
    ok_f3 = (differential_uniformity(F3) == 2)
    print_check("F3 (Zhou-Pott, c'=$alpha non-cube, i=$i) is APN", ok_f3, io)

    # --- F2: Taniguchi(a=1) is type-F2 per Corollary 5.7 ---
    # Use taniguchi_apn as the canonical F2 representative.
    # APN condition: X^{2^i+1}+X+b has no root in GF(2^m).
    b_t = first(b for b in 1:(1 << m) - 1
                if bivariate_carlet_condition(m, i, 1, b; modulus = mod_m))
    T = taniguchi_apn(m, i, 1, b_t; modulus = mod_m)
    ok_f2 = (differential_uniformity(T) == 2)
    print_check("F2 (Taniguchi a=1, b=$b_t, i=$i) is APN", ok_f2, io)

    # --- Corollary 5.7: F2(k=1,r=2) has same EA-class as Taniguchi ---
    # F2(k=1,r=2): G = x^{2^i+1} + x^{2^k}*y^{2^{i+k}} + c'*y^{2^{i+r}+2^r}
    # = x^{2^i+1} + x^{2^1}*y^{2^{i+1}} + c'*y^{2^{i+2}+2^2}  (k=1, r=2)
    # Proof: Taniguchi \circ swap = F2(k=1,r=2) exactly (see Corollary 5.7 proof).
    k2 = 1; r2 = 2
    Ek2 = 1 << k2
    Eik2 = 1 << (i + k2)
    Eyr2 = ((1 << i) + 1) * (1 << r2)
    len = 1 << m
    lut_f2k = Vector{Int}(undef, 1 << (2m))
    for x in 0:(len - 1), y in 0:(len - 1)
        xy   = gf_mul(x, y, m; modulus = mod_m)
        Gxy  = gf_pow(x, (1 << i) + 1, m; modulus = mod_m) ⊻
               gf_mul(gf_pow(x, Ek2, m; modulus = mod_m),
                      gf_pow(y, Eik2, m; modulus = mod_m), m; modulus = mod_m) ⊻
               gf_mul(b_t, gf_pow(y, Eyr2, m; modulus = mod_m), m; modulus = mod_m)
        lut_f2k[(x | (y << m)) + 1] = xy | (Gxy << m)
    end
    F2k = SBox{2m}(lut_f2k)
    du_f2k = differential_uniformity(F2k)
    ok_cor57_f2 = (du_f2k == 2) &&
                  (apn_ea_mugshot(F2k) == apn_ea_mugshot(T))
    print_check("Cor 5.7: F2(k=$k2,r=$r2) is APN and EA-class == Taniguchi", ok_cor57_f2, io)

    # --- Proposition 5.8: F1(b=0, h=m-i, r=m-2i) is EA-equiv to Taniguchi ---
    h   = m - i
    r   = m - 2i
    Ei1 = (1 << i) + 1
    Eih = 1 << (i + h)   # may equal 2^m (Frobenius); gf_pow handles correctly
    Eyh = 1 << h
    Eyr = Ei1 * (1 << r)
    function build_f1_p58(cp)
        lut = Vector{Int}(undef, 1 << (2m))
        for x in 0:(len - 1), y in 0:(len - 1)
            xy  = gf_mul(x, y, m; modulus = mod_m)
            Gxy = gf_pow(x, Ei1, m; modulus = mod_m) ⊻
                  gf_mul(gf_pow(x, Eih, m; modulus = mod_m),
                         gf_pow(y, Eyh, m; modulus = mod_m), m; modulus = mod_m) ⊻
                  gf_mul(cp, gf_pow(y, Eyr, m; modulus = mod_m), m; modulus = mod_m)
            lut[(x | (y << m)) + 1] = xy | (Gxy << m)
        end
        SBox{2m}(lut)
    end
    c_prime = findfirst(c -> differential_uniformity(build_f1_p58(c)) == 2, 1:(len - 1))
    ok_f1 = c_prime !== nothing
    F1 = build_f1_p58(ok_f1 ? c_prime : 1)
    print_check("F1 (Prop 5.8, b=0, h=$h, r=$r, c'=$c_prime) is APN", ok_f1, io)
    ok_p58 = ok_f1 && (apn_ea_mugshot(F1) == apn_ea_mugshot(T))
    print_check("F1 (Prop 5.8) EA-class == Taniguchi (F2 class)", ok_p58, io)

    all_ok = ok_f3 && ok_f2 && ok_cor57_f2 && ok_f1 && ok_p58
    print_kv("completeness", "spot-checks for specific (m=$m, i=$i) parameters", io)
    (; all_ok, ok_f3, ok_f2, ok_cor57_f2, ok_f1, ok_p58)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem5_6_report()
end
