@testset "observation1_test" begin
    include(joinpath(@__DIR__, "..", "observation1.jl"))

    C3 = build_c3_apn()
    C7 = build_c7_apn()

    # Observation 1: both quadrinomials are APN over GF(2^10)
    @test differential_uniformity(C3) == 2
    @test differential_uniformity(C7) == 2

    # Both are quadratic
    @test algebraic_degree(C3) == 2
    @test algebraic_degree(C7) == 2

    # Round-trip: C_3 and C_7 are built from build_ci_sbox with correct exponents
    @test C3 == build_ci_sbox(10, 3, 2)
    @test C7 == build_ci_sbox(10, 7, 0)

    # EA-mugshots differ → not EA-equivalent
    @test apn_ea_mugshot(C3) != apn_ea_mugshot(C7)

    # F(0) = 0 for both (as expected from the univariate form)
    @test C3.lut[1] == 0
    @test C7.lut[1] == 0
end
