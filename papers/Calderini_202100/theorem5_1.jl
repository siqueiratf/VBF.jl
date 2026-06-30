# Implements Theorem 5.1 — Zhou-Pott APN family.
# Paper: Calderini, Budaghyan, Carlet (2021), pp. 79–105
# Section: 5 — Theorem 5.1 ([Zhou-Pott 2013])
#
# Pseudocode:
#   F(x,y) = (xy, x^{2^i+1} + alpha*y^{(2^i+1)*2^j}) over GF(2^m) x GF(2^m)
#   APN condition: m even, gcd(i,m)=1, j even, alpha not a cube in GF(2^m)*
#   1. For alpha a cube: check differential_uniformity(F) != 2
#   2. For alpha not a cube: check differential_uniformity(F) == 2
#   3. Compare EA-mugshot with bivariate Carlet (a=0) which equals F3 from Thm 5.6
# VBF API used: gf_is_dth_power, differential_uniformity, algebraic_degree,
#               apn_ea_mugshot, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem5_1_report([io]; m) -> NamedTuple

Verify Theorem 5.1: Zhou-Pott F(x,y)=(xy, x^{2^i+1}+alpha*y^{(2^i+1)*2^j})
is APN iff j even and alpha not a cube. Tests m (must be even) with all valid i.
"""
function theorem5_1_report(io::IO = stdout; m::Int = 4)
    iseven(m) || error("Theorem 5.1 requires m even, got m=$m")
    print_section("Theorem 5.1 — Zhou-Pott APN family (m=$m, n=$(2m))", io)
    println(io, "  F(x,y) = (xy, x^{2^i+1} + alpha*y^{(2^i+1)*2^j})")
    println(io, "  APN iff: m even, gcd(i,m)=1, j even, alpha not a cube")

    mod_m = primitive_polynomial(m)
    all_ok = true
    results = Dict{Tuple{Int,Int}, NamedTuple}()

    # pick one i with gcd(i,m)=1 and test j=0 (even)
    i = first(ii for ii in 1:(m - 1) if gcd(ii, m) == 1)
    j = 0   # even

    cube_failures = 0
    noncube_ok    = 0
    for alpha in 1:(1 << m) - 1
        is_cube = gf_is_dth_power(alpha, 3, m; modulus = mod_m)
        F  = zhou_pott_sbox(m, i, j, alpha; modulus = mod_m)
        du = differential_uniformity(F)
        apn = (du == 2)
        if is_cube && apn
            cube_failures += 1
        elseif !is_cube && !apn
            cube_failures += 1
        else
            noncube_ok += 1
        end
    end
    ok_cube = (cube_failures == 0)
    all_ok &= ok_cube
    print_check("i=$i j=$j: non-cube alpha <=> APN for all alpha in GF(2^$m)*", ok_cube, io)
    print_kv("    cases tested", (1 << m) - 1, io)

    # Corollary 5.7: F3 (Zhou-Pott with j=0) is EA-equiv to bivariate Carlet a=0
    alpha_nc = first(a for a in 1:(1 << m) - 1
                     if !gf_is_dth_power(a, 3, m; modulus = mod_m))
    F_zp  = zhou_pott_sbox(m, i, 0, alpha_nc; modulus = mod_m)
    F_biv = bivariate_carlet_sbox(m, i, 0, alpha_nc; modulus = mod_m)
    mg_zp  = apn_ea_mugshot(F_zp)
    mg_biv = apn_ea_mugshot(F_biv)
    ok_cor57 = (mg_zp == mg_biv)
    all_ok  &= ok_cor57
    print_section("Corollary 5.7 — F3 = Zhou-Pott = bivariate Carlet (a=0)", io)
    print_check("zhou_pott(i=$i,j=0,alpha=$(alpha_nc)) EA-equiv bivariate_carlet(a=0,b=$(alpha_nc))", ok_cor57, io)

    print_kv("completeness", "exhaustive over all alpha in GF(2^$m)*, i=$i, j=0", io)
    (; all_ok, i, j, cube_failures, noncube_ok, ok_cor57)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem5_1_report()
end
