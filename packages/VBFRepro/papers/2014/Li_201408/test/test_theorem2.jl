@testset "theorem2_test" begin
    include(joinpath(@__DIR__, "..", "theorem2.jl"))

    # Gold x^3 over GF(2^5) → n=4 construction
    Fu4 = theorem2_build(4, 1; u = 1)
    @test is_permutation(Fu4)
    @test differential_uniformity(Fu4) == 4
    @test (1 << 3) - linearity(Fu4) ÷ 2 == (1 << 3) - (1 << 2)  # NL = 4

    # u != 1 also works
    Fu4_u2 = theorem2_build(4, 1; u = 2)
    @test is_permutation(Fu4_u2)
    @test differential_uniformity(Fu4_u2) == 4

    # n=6
    Fu6 = theorem2_build(6, 1; u = 1)
    @test is_permutation(Fu6)
    @test differential_uniformity(Fu6) == 4
    @test (1 << 5) - linearity(Fu6) ÷ 2 == (1 << 5) - (1 << 3)  # NL = 24
end
