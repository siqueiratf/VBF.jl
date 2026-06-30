# Implements Theorem 4.4 and Proposition 4.5.
# Paper: Calderini, Budaghyan, Carlet (2021), pp. 79–105
# Section: 4 — Theorem 4.4 (bivariate Carlet EA-equiv hexanomial class)
#              Proposition 4.5 (EA-equivalence for different non-cube b values)
#
# Pseudocode (Theorem 4.4):
#   1. Enumerate APN bivariate Carlet SBoxes at n=2m: F = (xy, x^{2^i+1}+a*x*y^{2^i}+b*y^{2^i+1})
#   2. Enumerate APN hexanomial SBoxes at n=2m: H from Theorem 3.1
#   3. Collect EA-mugshots of each set; verify the sets coincide.
#
# Pseudocode (Proposition 4.5):
#   For m even, b and b' both non-cubes in GF(2^m)*:
#   F(x,y)=(xy,x^{2^i+1}+b*y^{2^i+1}) and F'=(xy,x^{2^i+1}+b'*y^{2^i+1}) are EA-equivalent.
#   => apn_ea_mugshot(F) == apn_ea_mugshot(F')
#
# VBF API used: gf_is_dth_power, differential_uniformity, apn_ea_mugshot,
#               print_section, print_check, print_kv, APNEAMugshot

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem4_4_report([io]; m) -> NamedTuple

Verify Theorem 4.4: the EA-class set of APN bivariate Carlet functions (Proposition 4.2 form)
equals the EA-class set of APN hexanomials (Theorem 3.1) at the same n=2m.
"""
function theorem4_4_report(io::IO = stdout; m::Int = 3)
    print_section("Theorem 4.4 — Bivariate Carlet EA-equiv hexanomial class (m=$m, n=$(2m))", io)

    n     = 2m
    mod_n = primitive_polynomial(n)
    mod_m = primitive_polynomial(m)

    # EA-mugshots of APN bivariate Carlet functions (a in {0,1}, all b)
    biv_mugs = Set{APNEAMugshot}()
    for i in 1:(m - 1)
        gcd(i, m) == 1 || continue
        for a in 0:1, b in 1:(1 << m) - 1
            bivariate_carlet_condition(m, i, a, b; modulus = mod_m) || continue
            F = bivariate_carlet_sbox(m, i, a, b; modulus = mod_m)
            differential_uniformity(F) == 2 || continue
            push!(biv_mugs, apn_ea_mugshot(F))
        end
    end

    # EA-mugshots of APN hexanomials (fixed d not in GF(2^m), all i,c)
    d = first(x for x in 1:(1 << n) - 1
              if gf_pow(x, 1 << m, n; modulus = mod_n) != x)
    hex_mugs = Set{APNEAMugshot}()
    for i in 1:(m - 1)
        gcd(i, m) == 1 || continue
        for c in 0:(1 << n) - 1
            hexanomial_condition(m, i, c; modulus = mod_n) || continue
            H = hexanomial_sbox(m, i, c, d; modulus = mod_n)
            differential_uniformity(H) == 2 || continue
            push!(hex_mugs, apn_ea_mugshot(H))
        end
    end

    ok_sets = (biv_mugs == hex_mugs)
    all_ok  = ok_sets
    print_check("bivariate-Carlet EA-classes == hexanomial EA-classes", ok_sets, io)
    print_kv("  bivariate Carlet classes", length(biv_mugs), io)
    print_kv("  hexanomial classes",       length(hex_mugs), io)

    # Proposition 4.5: for m even, non-cube b and b' give EA-equiv F3 functions
    prop45_ok = true
    if iseven(m)
        print_section("Proposition 4.5 — non-cube b values EA-equivalent (m=$m even)", io)
        non_cubes = [b for b in 1:(1 << m) - 1
                     if !gf_is_dth_power(b, 3, m; modulus = mod_m)]
        if length(non_cubes) >= 2
            i = first(i for i in 1:(m - 1) if gcd(i, m) == 1)
            b1, b2 = non_cubes[1], non_cubes[2]
            F1 = bivariate_carlet_sbox(m, i, 0, b1; modulus = mod_m)
            F2 = bivariate_carlet_sbox(m, i, 0, b2; modulus = mod_m)
            mg1, mg2 = apn_ea_mugshot(F1), apn_ea_mugshot(F2)
            prop45_ok = (mg1 == mg2)
            print_check("F(b=$(b1)) and F(b=$(b2)) same EA-class", prop45_ok, io)
            print_kv("  i", i, io)
        else
            println(io, "  [skip] fewer than 2 non-cubes found at m=$m")
        end
        all_ok &= prop45_ok
    else
        println(io, "  Proposition 4.5: applies only when m is even (m=$m odd, skipped)")
    end

    print_kv("completeness", "exhaustive for m=$m", io)
    (; all_ok, biv_classes = length(biv_mugs), hex_classes = length(hex_mugs), prop45_ok)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem4_4_report()
end
