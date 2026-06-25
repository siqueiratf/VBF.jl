@testset "proposition2_test" begin
    include(joinpath(@__DIR__, "..", "proposition2.jl"))

    for (n, i) in [(4, 1), (4, 2), (6, 1)]
        N = n + 1
        F = gold_apn(N, i)
        fu_lut, _ = build_fu(F.lut, 1, N)
        Fu = SBox{n}(fu_lut)
        Fu_inv = sbox_inverse(Fu)
        @test algebraic_degree(Fu_inv) <= 3
    end
end
