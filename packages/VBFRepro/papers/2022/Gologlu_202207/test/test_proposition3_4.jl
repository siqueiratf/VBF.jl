@testset "proposition3_4_test" begin
    include(joinpath(@__DIR__, "..", "proposition3_4.jl"))

    # Prop III.4 i: Gold x^3 n=10 (m=5, odd): η_m = (2^5+1)/3 = 11
    G10 = gold_apn(10, 1)
    @test eta_m(G10, 5) == 11

    # Prop III.4 i: Gold x^3 n=6 (m=3, odd): η_m = (2^3+1)/3 = 3
    G6 = gold_apn(6, 1)
    @test eta_m(G6, 3) == 3

    # Prop III.4 iii: F3 (m=5): η_m = 2
    F3 = f3_sbox()
    @test eta_m(F3, 5) == 2

    # Prop III.4 v: F2 m=5 i=1: η_m ≥ 1
    F2_5 = f2_sbox(5, 1)
    @test eta_m(F2_5, 5) >= 1

    # Prop III.4 v: F2 m=5 i=2: η_m ≥ 1
    F2_5b = f2_sbox(5, 2)
    @test eta_m(F2_5b, 5) >= 1
end
