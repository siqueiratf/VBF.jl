@testset "section3_test" begin
    include(joinpath(@__DIR__, "..", "section3.jl"))

    # Lemma 3.1: differential_uniformity(F) = 2^t

    # n=6, k=2, s=4, t=2 → diff-4-uniform (fast: 64 elements DDT)
    # Degenerate monomial case; still correctly 4-uniform per Theorem 1.1
    F6 = bracken_binomial_sbox(2, 4)
    @test differential_uniformity(F6) == 4

    # n=15, k=5, s=1, t=1 → APN (diff-2-uniform): the meaningful non-degenerate
    # case. Core differential_uniformity scans one input difference at a time
    # (O(2^n) memory, ~0.5 s here) — no full DDT, cheap enough for the fast suite.
    F15 = bracken_binomial_sbox(5, 1)
    @test differential_uniformity(F15) == 2
end
