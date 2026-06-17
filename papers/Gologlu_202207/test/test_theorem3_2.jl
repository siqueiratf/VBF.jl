@testset "theorem3_2_test" begin
    include(joinpath(@__DIR__, "..", "theorem3_2.jl"))

    # F1 m=5 i=1: gcd(3,5)=1 ✓ → APN+quadratic
    F1_5_1 = f1_sbox(5, 1)
    @test differential_uniformity(F1_5_1) == 2
    @test algebraic_degree(F1_5_1) == 2

    # F1 m=5 i=2: gcd(6,5)=1 ✓
    F1_5_2 = f1_sbox(5, 2)
    @test differential_uniformity(F1_5_2) == 2
    @test algebraic_degree(F1_5_2) == 2

    # F2 m=5 i=1: gcd(3,5)=1, m=5 odd ✓
    F2_5_1 = f2_sbox(5, 1)
    @test differential_uniformity(F2_5_1) == 2
    @test algebraic_degree(F2_5_1) == 2

    # F2 m=5 i=2
    F2_5_2 = f2_sbox(5, 2)
    @test differential_uniformity(F2_5_2) == 2
    @test algebraic_degree(F2_5_2) == 2

    # F3 (sporadic, m=5)
    F3 = f3_sbox()
    @test differential_uniformity(F3) == 2
    @test algebraic_degree(F3) == 2

    # F1 i and m-i give same NF (paper Table I: i=1 and i=4 are paired)
    nf1 = drop_trailing_zeros(nonbent_signature(f1_sbox(5, 1)))
    nf4 = drop_trailing_zeros(nonbent_signature(f1_sbox(5, 4)))
    @test nf1 == nf4

    # F1 and F2 have distinct NF on n=10
    nf_f1 = drop_trailing_zeros(nonbent_signature(f1_sbox(5, 1)))
    nf_f2 = drop_trailing_zeros(nonbent_signature(f2_sbox(5, 1)))
    @test nf_f1 != nf_f2

    # Argument validation: gcd(3i,m) must be 1
    @test_throws ArgumentError f1_sbox(3, 1)   # gcd(3,3)=3 ≠ 1
    @test_throws ArgumentError f1_sbox(5, 5)   # i=5=m, gcd(15,5)=5 ≠ 1
    @test_throws ArgumentError f2_sbox(4, 1)   # m=4 even
end
