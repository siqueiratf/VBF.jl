@testset "example1_test" begin
    include(joinpath(@__DIR__, "..", "example1.jl"))

    n = EXAMPLE1_N

    # U_max for n=8: Table 4 says NL = 100
    u_max = build_u_max(n)
    F_max = construction1_sbox(n, u_max)
    @test is_permutation(F_max)
    @test differential_uniformity(F_max) == 4
    @test nonlinearity(F_max) == TABLE4_NL_UMAX

    # U_{m0} for n=8: Table 4 says NL = 102
    u_m0 = build_u_m0(n)
    F_m0 = construction1_sbox(n, u_m0)
    @test differential_uniformity(F_m0) == 4
    @test nonlinearity(F_m0) == TABLE4_NL_UM0

    # U_{m1} for n=8: Table 4 says NL = 102
    u_m1 = build_u_m1(n)
    F_m1 = construction1_sbox(n, u_m1)
    @test differential_uniformity(F_m1) == 4
    @test nonlinearity(F_m1) == TABLE4_NL_UM1
end
