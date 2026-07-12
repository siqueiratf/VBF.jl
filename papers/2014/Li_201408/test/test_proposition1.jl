@testset "proposition1_test" begin
    include(joinpath(@__DIR__, "..", "proposition1.jl"))

    for (n, i) in [(4, 1), (4, 2), (6, 1)]
        N = n + 1
        F = gold_apn(N, i)
        fu_lut, _ = build_fu(F.lut, 1, N)
        Fu = SBox{n}(fu_lut)
        @test algebraic_degree(Fu) == (n + 2) ÷ 2
    end
end
