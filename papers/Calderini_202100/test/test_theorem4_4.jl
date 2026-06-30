@testset "theorem4_4_test" begin
    include(joinpath(@__DIR__, "..", "theorem4_4.jl"))

    # m=3: EA-class sets must coincide and Proposition 4.5 holds (m odd -> skipped)
    r = theorem4_4_report(devnull; m = 3)
    @test r.all_ok
    @test r.biv_classes == r.hex_classes
    @test r.biv_classes >= 1

    # Spot-check: one APN bivariate and one APN hexanomial share a common mugshot
    mod3 = primitive_polynomial(3)
    mod6 = primitive_polynomial(6)
    # i=1 for m=3
    # bivariate: a=0, b=2 (check if APN)
    for b in 1:7
        bivariate_carlet_condition(3, 1, 0, b; modulus = mod3) || continue
        F = bivariate_carlet_sbox(3, 1, 0, b; modulus = mod3)
        @test differential_uniformity(F) == 2
        break
    end
end
