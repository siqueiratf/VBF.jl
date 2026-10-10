# Implements Theorem 5.6 — F1/F2/F3 canonical forms for bivariate APN.
# Paper: Calderini, Budaghyan, Carlet (2021), pp. 79-105
# Section: 5 — Theorem 5.6, Corollary 5.7, Proposition 5.8
#
# Theorem 5.6: Any F=(xy,G) APN with G monomial-linear is EA-equiv to one of:
#   F3(x,y) = (xy, x^{2^i+1} + c'*y^{2^{i+r}+2^r})                    [Zhou-Pott]
#   F2(x,y) = (xy, x^{2^i+1} + x^{2^k}*y^{2^{i+k}} + c'*y^{2^{i+r}+2^r})
#   F1(x,y) = (xy, x^{2^i+1} + x^{2^{i+h}}*y^{2^h} + b'*x^{2^k}*y^{2^{i+k}} + c'*y^{...})
#
# Corollary 5.7: F3 = Zhou-Pott (APN iff m even, r even, c' non-cube);
#                F2 with (k=i, r=2i) contains Taniguchi(a=1).
# Proposition 5.8: F1 with b=0, h=m-i, r=m-2i is EA-equiv to Taniguchi.
#
# These per-(m,i) checks also cover the Taniguchi identifications reported in
# Section 6.1.2 (n=10: i=1 h=4,r=3; i=2 h=3,r=1; F2 k=i,r=2i) and part of
# Section 6.1.3/6.1.4 (n=12: h=5,r=4 and k=1,r=2; n=16 claims are the same
# Prop 5.8 / Cor 5.7 patterns, not re-run: a single c-sweep at n=16 costs
# ~17 min (255 x ~4 s DDT) plus ~minutes per n=16 mugshot).
#
# Pseudocode (per i with gcd(i,m)=1, i<m/2):
#   1. m even: F3 (c' non-cube, r=0) is APN;  m odd: F3 is never APN (r=0 sweep)
#   2. F2 (Taniguchi a=1 representative via taniguchi_apn): APN
#   3. Corollary 5.7: f2_sbox(k=i, r=2i mod m) mugshot == Taniguchi mugshot
#   4. Prop 5.8: f1_sbox(b=0, h=m-i, r=m-2i) APN for some c', mugshot == Taniguchi
# VBF API used: taniguchi_apn, differential_uniformity, apn_ea_mugshot,
#               print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem5_6_report([io]; m) -> NamedTuple

Spot-check canonical forms F1/F2/F3 of Theorem 5.6, Corollary 5.7 and
Proposition 5.8 via EA-mugshots, for every i with gcd(i,m)=1 and i<m/2.
Works for m even and odd (F3/Zhou-Pott exists only for m even).
"""
function theorem5_6_report(io::IO = stdout; m::Int = 4)
    print_section("Theorem 5.6 — F1/F2/F3 canonical bivariate APN forms (m=$m, n=$(2m))", io)

    mod_m = primitive_polynomial(m)
    is    = [ii for ii in 1:(m - 1) if gcd(ii, m) == 1 && 2ii < m]
    len   = 1 << m

    # --- F3: Zhou-Pott (m even: c' non-cube is APN; m odd: no APN instance) ---
    ok_f3 = true
    if iseven(m)
        i0    = first(is)
        alpha = first(a for a in 1:(len - 1)
                      if !gf_is_dth_power(a, 3, m; modulus = mod_m))
        F3 = bivariate_carlet_sbox(m, i0, 0, alpha; modulus = mod_m)
        ok_f3 = (differential_uniformity(F3) == 2)
        print_check("F3 (Zhou-Pott, c'=$alpha non-cube, i=$i0) is APN", ok_f3, io)
    else
        # For m odd every element is a cube, so no F3 (r=0) instance is APN.
        i0 = first(is)
        ok_f3 = all(differential_uniformity(
                        bivariate_carlet_sbox(m, i0, 0, c; modulus = mod_m)) != 2
                    for c in 1:(len - 1))
        print_check("F3 has no APN instance for m=$m odd (r=0, all c')", ok_f3, io)
    end

    all_ok  = ok_f3
    results = NamedTuple[]
    for i in is
        # --- F2: Taniguchi(a=1) is type-F2 per Corollary 5.7 ---
        b_t = first(b for b in 1:(len - 1)
                    if bivariate_carlet_condition(m, i, 1, b; modulus = mod_m))
        T = taniguchi_apn(m, i, 1, b_t; modulus = mod_m)
        ok_f2 = (differential_uniformity(T) == 2)
        print_check("i=$i: F2 (Taniguchi a=1, b=$b_t) is APN", ok_f2, io)
        mg_T = apn_ea_mugshot(T)

        # --- Corollary 5.7: F2(k=i, r=2i mod m) has same EA-class as Taniguchi ---
        k2, r2 = i, mod(2i, m)
        F2k = f2_sbox(m, i, k2, r2, b_t; modulus = mod_m)
        ok_cor57_f2 = (differential_uniformity(F2k) == 2) &&
                      (apn_ea_mugshot(F2k) == mg_T)
        print_check("i=$i: Cor 5.7: F2(k=$k2,r=$r2) is APN and EA-class == Taniguchi",
                    ok_cor57_f2, io)

        # --- Proposition 5.8: F1(b=0, h=m-i, r=m-2i) is EA-equiv to Taniguchi ---
        h = m - i
        r = m - 2i
        c_prime = findfirst(
            c -> differential_uniformity(
                     f1_sbox(m, i, h, 0, r, 0, c; modulus = mod_m)) == 2,
            1:(len - 1))
        ok_f1 = c_prime !== nothing
        print_check("i=$i: F1 (Prop 5.8, b=0, h=$h, r=$r, c'=$c_prime) is APN", ok_f1, io)
        ok_p58 = ok_f1 &&
                 (apn_ea_mugshot(f1_sbox(m, i, h, 0, r, 0, c_prime;
                                         modulus = mod_m)) == mg_T)
        print_check("i=$i: F1 (Prop 5.8) EA-class == Taniguchi (F2 class)", ok_p58, io)

        all_ok &= ok_f2 && ok_cor57_f2 && ok_f1 && ok_p58
        push!(results, (; i, ok_f2, ok_cor57_f2, ok_f1, ok_p58))
    end

    print_kv("completeness", "spot-checks for m=$m, i in $(is)", io)
    (; all_ok, ok_f3, results)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem5_6_report(; m = 4)
    theorem5_6_report(; m = 5)
    theorem5_6_report(; m = 6)
end
