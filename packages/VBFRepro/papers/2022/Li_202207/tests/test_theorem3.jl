@testset "theorem3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3.jl"))

    # m=1 has no valid μ: norm_exp = 2^2+2^1+1 = 7 = |F*_{2^3}|, so μ^7=1 for all μ
    μ1, found1 = find_valid_mu(1, 1)
    @test !found1
    @test μ1 == -1

    # m=3, s=1: valid μ must exist (Bartoli et al.; Remark 1 in paper)
    μ3, found3 = find_valid_mu(3, 1)
    @test found3
    @test μ3 > 0

    # f(0) = 0: zero maps to zero
    for m in [2, 3]
        μ, found = find_valid_mu(m, 1)
        found || continue
        F = theorem3_sbox(m, 1, μ, 1)
        @test F.lut[1] == 0
    end

    # Theorem 3 APN: differential uniformity = 2 for m=2,3
    for m in [2, 3]
        μ, found = find_valid_mu(m, 1)
        found || continue
        F  = theorem3_sbox(m, 1, μ, 1)
        du = differential_uniformity(F)
        @test du == 2
        @test algebraic_degree(F) <= 2
    end
end
