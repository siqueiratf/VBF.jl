@testset "proposition18" begin
    include(joinpath(@__DIR__, "..", "proposition18.jl"))

    mod6 = conway_polynomial(6)

    # Gold x³ n=6: H = MᵀC_P M equals the derivative matrix, and the
    # displayed identity of Prop 18 holds in the bit basis.
    F = SBox{6}(terms_to_lut([(1, 3)], 6, mod6))
    H = ywl14_h_matrix([(1, 3)], 6, mod6)
    @test H == quadratic_apn_matrix(F)
    @test verify_proposition18(F, H)
    @test is_qam(F)

    # Kim mapping κ = x³ + x¹⁰ + αx²⁴
    K = kim_apn()
    HK = ywl14_h_matrix([(1, 3), (1, 10), (2, 24)], 6, mod6)
    @test HK == quadratic_apn_matrix(K)
    @test verify_proposition18(K, HK)
    @test is_qam(K)

    # Non-APN quadratic: identity still holds, matrix is not a QAM
    Q = pseudo_random_multirank_quadratic(6)
    @test verify_proposition18(Q, quadratic_apn_matrix(Q))
    @test !is_qam(Q)
end
