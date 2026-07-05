# Implements Theorem 4.3, Theorem 4.4 and Proposition 4.5.
# Paper: Calderini, Budaghyan, Carlet (2021), pp. 79–105
# Section: 4 — Theorem 4.3 (pentanomial class == hexanomial class)
#              Theorem 4.4 (bivariate Carlet EA-equiv to a hexanomial-class member)
#              Proposition 4.5 (EA-equivalence for different non-cube b values)
#
# Pseudocode (Theorem 4.3):
#   1. For all (i,c): pentanomial condition <=> APN (same condition as Theorem 3.1)
#   2. EA-mugshot set of APN pentanomials == EA-mugshot set of APN hexanomials
#
# Pseudocode (Theorem 4.4):
#   1. Enumerate APN bivariate Carlet SBoxes at n=2m: F = (xy, x^{2^i+1}+a*x*y^{2^i}+b*y^{2^i+1})
#   2. Enumerate APN hexanomial SBoxes at n=2m: H from Theorem 3.1 (exact form)
#   3. Verify biv mugshot set is a SUBSET of the hexanomial mugshot set (the
#      theorem direction); report whether the sets in fact coincide.
#
# Pseudocode (Proposition 4.5):
#   For m even, i with gcd(i,m)=1: ALL non-cube b give EA-equivalent
#   F(x,y)=(xy, x^{2^i+1}+b*y^{2^i+1})  =>  a single EA-mugshot per i.
#
# VBF API used: gf_is_dth_power, differential_uniformity, apn_ea_mugshot,
#               print_section, print_check, print_kv, APNEAMugshot

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem4_4_report([io]; m) -> NamedTuple

Verify Theorem 4.3 (pentanomial class), Theorem 4.4 (bivariate Carlet EA-classes
lie inside the hexanomial EA-class set) and Proposition 4.5 (m even) at n=2m.
"""
function theorem4_4_report(io::IO = stdout; m::Int = 3)
    print_section("Theorems 4.3/4.4 — pentanomial and bivariate Carlet classes (m=$m, n=$(2m))", io)

    n     = 2m
    mod_n = primitive_polynomial(n)
    mod_m = primitive_polynomial(m)
    d = first(x for x in 1:(1 << n) - 1
              if gf_pow(x, 1 << m, n; modulus = mod_n) != x)

    # --- Theorem 4.3: pentanomial condition <=> APN, class == hexanomial class ---
    hex_mugs  = Set{APNEAMugshot}()
    pent_mugs = Set{APNEAMugshot}()
    pent_cond_fail = 0
    for i in 1:(m - 1)
        gcd(i, m) == 1 || continue
        for c in 0:(1 << n) - 1
            cond = hexanomial_condition(m, i, c; modulus = mod_n)
            P    = pentanomial_sbox(m, i, c, d; modulus = mod_n)
            apn  = (differential_uniformity(P) == 2)
            cond == apn || (pent_cond_fail += 1)
            if cond && apn
                push!(pent_mugs, apn_ea_mugshot(P))
                H = hexanomial_sbox(m, i, c, d; modulus = mod_n)
                differential_uniformity(H) == 2 && push!(hex_mugs, apn_ea_mugshot(H))
            end
        end
    end
    ok_pent_cond = (pent_cond_fail == 0)
    ok_classes   = (pent_mugs == hex_mugs)
    print_check("Thm 4.3: pentanomial condition <=> APN for all (i,c)", ok_pent_cond, io)
    print_check("Thm 4.3: pentanomial EA-classes == hexanomial EA-classes", ok_classes, io)
    print_kv("  pentanomial classes", length(pent_mugs), io)
    print_kv("  hexanomial classes",  length(hex_mugs), io)

    # --- Theorem 4.4: bivariate Carlet classes lie inside the hexanomial class set ---
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

    ok_subset  = issubset(biv_mugs, hex_mugs)
    sets_equal = (biv_mugs == hex_mugs)
    print_check("Thm 4.4: bivariate-Carlet EA-classes subset of hexanomial EA-classes", ok_subset, io)
    print_kv("  bivariate Carlet classes", length(biv_mugs), io)
    print_kv("  sets coincide (informational)", sets_equal, io)

    # --- Proposition 4.5: for m even, all non-cube b give one EA-class per i ---
    prop45_ok  = true
    prop45_ran = false
    if iseven(m)
        print_section("Proposition 4.5 — non-cube b values EA-equivalent (m=$m even)", io)
        non_cubes = [b for b in 1:(1 << m) - 1
                     if !gf_is_dth_power(b, 3, m; modulus = mod_m)]
        print_kv("  non-cubes in GF(2^$m)*", length(non_cubes), io)
        for i in 1:(m - 1)
            gcd(i, m) == 1 || continue
            mugs = Set(apn_ea_mugshot(bivariate_carlet_sbox(m, i, 0, b; modulus = mod_m))
                       for b in non_cubes)
            ok_i = (length(mugs) == 1)
            prop45_ok &= ok_i
            prop45_ran = true
            print_check("i=$i: all $(length(non_cubes)) non-cube b share one EA-class", ok_i, io)
        end
    else
        println(io, "  Proposition 4.5: applies only when m is even (m=$m odd, skipped)")
    end

    all_ok = ok_pent_cond && ok_classes && ok_subset && prop45_ok
    print_kv("completeness", "exhaustive for m=$m", io)
    (; all_ok, ok_pent_cond, ok_classes, ok_subset, sets_equal,
       biv_classes = length(biv_mugs), hex_classes = length(hex_mugs),
       pent_classes = length(pent_mugs), prop45_ok, prop45_ran)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem4_4_report(; m = 3)
    theorem4_4_report(; m = 4)
end
