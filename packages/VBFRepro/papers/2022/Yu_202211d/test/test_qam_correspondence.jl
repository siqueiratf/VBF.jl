using Test

@testset "QAM round-trip: quadratic_apn_matrix(qam_to_sbox(M)) == M" begin
    # At n=4 the homogeneous representative of Gold x^3 gives back the same M.
    F = gold_apn(4, 1)
    M = quadratic_apn_matrix(F)
    H = qam_to_sbox(M)
    M2 = quadratic_apn_matrix(H)
    @test M == M2
end

@testset "QAM/APN equivalence on Gold x³ (n = 5)" begin
    F = gold_apn(5, 1)
    M = quadratic_apn_matrix(F)
    H = qam_to_sbox(M)
    @test is_qam(M)
    @test differential_uniformity(H) == 2
    @test algebraic_degree(H) == 2
end

@testset "Non-QAM zero matrix is not APN" begin
    n = 4
    M_zero = zeros(Int, n, n)
    H_zero = qam_to_sbox(M_zero)
    @test !is_qam(M_zero)
    @test differential_uniformity(H_zero) != 2
end

@testset "is_qam(SBox) agrees with derivative matrix is_qam" begin
    for n in (4, 5)
        F = gold_apn(n, 1)
        M = quadratic_apn_matrix(F)
        H = qam_to_sbox(M)
        @test is_qam(H) == is_qam(M)
    end
end
