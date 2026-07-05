@testset "theorem4_4_test" begin
    include(joinpath(@__DIR__, "..", "theorem4_4.jl"))

    # m=3: Thm 4.3 + Thm 4.4 hold; class sets coincide (m odd; Prop 4.5 skipped)
    r3 = theorem4_4_report(devnull; m = 3)
    @test r3.all_ok
    @test r3.ok_pent_cond
    @test r3.ok_classes
    @test r3.ok_subset
    @test r3.sets_equal
    @test r3.biv_classes == r3.hex_classes
    @test r3.biv_classes >= 1
    @test !r3.prop45_ran      # m odd: Proposition 4.5 does not apply

    # m=4 (even): Proposition 4.5 must actually run and hold
    r4 = theorem4_4_report(devnull; m = 4)
    @test r4.all_ok
    @test r4.ok_pent_cond
    @test r4.ok_classes
    @test r4.ok_subset
    @test r4.prop45_ran
    @test r4.prop45_ok

    # Spot-check: one APN bivariate instance
    mod3 = primitive_polynomial(3)
    for b in 1:7
        bivariate_carlet_condition(3, 1, 0, b; modulus = mod3) || continue
        F = bivariate_carlet_sbox(3, 1, 0, b; modulus = mod3)
        @test differential_uniformity(F) == 2
        break
    end

    # exact-form spot check: pentanomial and hexanomial differ as LUTs but
    # share the EA-class (Theorem 4.3)
    mod6 = primitive_polynomial(6)
    d6   = first(x for x in 1:63 if gf_pow(x, 8, 6; modulus = mod6) != x)
    c6   = first(c for c in 0:63 if hexanomial_condition(3, 1, c; modulus = mod6))
    H = hexanomial_sbox(3, 1, c6, d6; modulus = mod6)
    P = pentanomial_sbox(3, 1, c6, d6; modulus = mod6)
    @test H.lut != P.lut
    @test apn_ea_mugshot(H) == apn_ea_mugshot(P)
end
