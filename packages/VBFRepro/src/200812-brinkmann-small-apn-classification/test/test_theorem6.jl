@testset "theorem6_test" begin
    include(joinpath(@__DIR__, "..", "theorem6.jl"))

    F1, F2 = table2_luts()

    # n=4: F1 and F2 are CCZ-equivalent (exactly 1 CCZ-class for n=4, Theorem 6)
    @test are_ccz_equivalent(F1, F2)

    # n=5: x³, x⁵, x¹⁵ are pairwise CCZ-inequivalent (3 CCZ-classes, Theorem 6)
    mod5 = primitive_polynomial(5)
    G3  = SBox{5}([gf_pow(x,  3, 5; modulus = mod5) for x in 0:31])
    G5  = SBox{5}([gf_pow(x,  5, 5; modulus = mod5) for x in 0:31])
    G15 = SBox{5}([gf_pow(x, 15, 5; modulus = mod5) for x in 0:31])
    @test !are_ccz_equivalent(G3,  G5)
    @test !are_ccz_equivalent(G3,  G15)
    @test !are_ccz_equivalent(G5,  G15)

    # n=5: CCZ membership of remaining EA-classes
    G11  = SBox{5}([gf_pow(x, 11, 5; modulus = mod5) for x in 0:31])
    G7   = SBox{5}([gf_pow(x,  7, 5; modulus = mod5) for x in 0:31])
    f6_1 = formula6_n5(1; modulus = mod5)
    f6_2 = formula6_n5(2; modulus = mod5)
    @test are_ccz_equivalent(G11,  G3)
    @test are_ccz_equivalent(f6_1, G3)
    @test are_ccz_equivalent(G7,   G5)
    @test are_ccz_equivalent(f6_2, G5)
end
