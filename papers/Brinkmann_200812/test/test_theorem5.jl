@testset "theorem5_test" begin
    include(joinpath(@__DIR__, "..", "theorem5.jl"))

    F1, F2 = table2_luts()
    mod4 = primitive_polynomial(4)
    G3_4 = SBox{4}([gf_pow(x, 3, 4; modulus = mod4) for x in 0:15])

    # n=4: both APN
    @test differential_uniformity(F1) == 2
    @test differential_uniformity(F2) == 2

    # n=4: distinct algebraic degrees (EA invariant)
    @test algebraic_degree(F1) == 2
    @test algebraic_degree(F2) == 3

    # n=4: EA-inequivalent
    @test !are_ea_equivalent(F1, F2)

    # n=4: F1 is EA-equivalent to Gold x³
    @test are_ea_equivalent(F1, G3_4)

    # n=4: F2 is NOT EA-equivalent to x³ (the only power APN for n=4)
    @test !are_ea_equivalent(F2, G3_4)

    # n=5: 3 CCZ-canonical power reps pairwise EA-inequivalent
    mod5 = primitive_polynomial(5)
    G3  = SBox{5}([gf_pow(x,  3, 5; modulus = mod5) for x in 0:31])
    G5  = SBox{5}([gf_pow(x,  5, 5; modulus = mod5) for x in 0:31])
    G15 = SBox{5}([gf_pow(x, 15, 5; modulus = mod5) for x in 0:31])
    @test !are_ea_equivalent(G3,  G5)
    @test !are_ea_equivalent(G3,  G15)
    @test !are_ea_equivalent(G5,  G15)

    # n=5: formula6 functions are APN
    f6_1 = formula6_n5(1; modulus = mod5)
    f6_2 = formula6_n5(2; modulus = mod5)
    @test differential_uniformity(f6_1) == 2
    @test differential_uniformity(f6_2) == 2
end
