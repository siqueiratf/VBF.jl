@testset "table1_test" begin
    include(joinpath(@__DIR__, "..", "table1.jl"))

    m = 5

    # F1 NF values match Table I (spot-check i=1 and i=2)
    nf_f1_1 = drop_trailing_zeros(nonbent_signature(f1_sbox(m, 1)))
    @test nf_f1_1 == TABLE_I_EXPECTED["F1_i14"]

    nf_f1_2 = drop_trailing_zeros(nonbent_signature(f1_sbox(m, 2)))
    @test nf_f1_2 == TABLE_I_EXPECTED["F1_i23"]

    # F2 NF values match Table I (spot-check i=1 and i=2)
    nf_f2_1 = drop_trailing_zeros(nonbent_signature(f2_sbox(m, 1)))
    @test nf_f2_1 == TABLE_I_EXPECTED["F2_i14"]

    nf_f2_2 = drop_trailing_zeros(nonbent_signature(f2_sbox(m, 2)))
    @test nf_f2_2 == TABLE_I_EXPECTED["F2_i23"]

    # F3 NF value
    nf_f3 = drop_trailing_zeros(nonbent_signature(f3_sbox()))
    @test nf_f3 == TABLE_I_EXPECTED["F3"]

    # Table III: Gold x^3 n=10
    nf_g3 = drop_trailing_zeros(nonbent_signature(gold_apn(10, 1)))
    @test nf_g3 == TABLE_III_EXPECTED["x3"]

    # Table III: Gold x^9 n=10 (k=3, gcd(3,10)=1)
    nf_g9 = drop_trailing_zeros(nonbent_signature(gold_apn(10, 3)))
    @test nf_g9 == TABLE_III_EXPECTED["x9"]

    # Distinctness: F1, F2, F3 have pairwise different NF on n=10
    @test nf_f1_1 != nf_f2_1
    @test nf_f1_1 != nf_f3
    @test nf_f2_1 != nf_f3
end
