@testset "proposition1_test" begin
    include(joinpath(@__DIR__, "..", "proposition1.jl"))

    F = dillon_apn_permutation()

    # Table 1: Dillon perm matches VBF
    @test F.lut[1] == 0    # F(0) = 0
    @test F.lut[2] == 54   # F(1) = 54
    @test F.lut[64] == 22  # F(63) = 22
    @test is_permutation(F)
    @test differential_uniformity(F) == 2

    # Example 1: F_{(0,1)} has δ=4, A=54
    G01 = swap_function(F, 0, 1)
    @test differential_uniformity(G01) == 4
    @test parameter_A_from_ddt(G01) == 54

    # Spot-check: a few more swaps give δ ∈ {2,4}
    for (i, j) in [(0, 2), (1, 3), (10, 20), (30, 50)]
        G = swap_function(F, i, j)
        @test differential_uniformity(G) in (2, 4)
    end
end
