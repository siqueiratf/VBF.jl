@testset "theorem2_test" begin
    include(joinpath(@__DIR__, "..", "theorem2.jl"))

    # m=1 guard: GF(2) not supported — ArgumentError from primitive_polynomial(1)
    @test_throws Exception theorem2_sbox(1)

    # gcd(3,m)=1 guard: m=3 must error
    @test_throws ErrorException theorem2_sbox(3)

    # f(0,0) = (0,0): zero maps to zero
    for m in [2, 4]
        F = theorem2_sbox(m)
        @test F.lut[1] == 0
    end

    # Theorem 2 APN: differential uniformity = 2 for m=2 (fast)
    F2 = theorem2_sbox(2)
    @test differential_uniformity(F2) == 2
    @test algebraic_degree(F2) <= 2

    # m=4 (n=8, Table IV row 12 in paper): APN
    F4 = theorem2_sbox(4)
    @test differential_uniformity(F4) == 2
    @test algebraic_degree(F4) <= 2
end
