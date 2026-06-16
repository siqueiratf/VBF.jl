@testset "section3_test" begin
    include(joinpath(@__DIR__, "..", "section3.jl"))

    # Lemma 3.1: differential_uniformity(F) = 2^t

    # n=6, k=2, s=4, t=2 → diff-4-uniform (fast: 64 elements DDT)
    # Degenerate monomial case; still correctly 4-uniform per Theorem 1.1
    F6 = bracken_binomial_sbox(2, 4)
    @test differential_uniformity(F6) == 4
end
