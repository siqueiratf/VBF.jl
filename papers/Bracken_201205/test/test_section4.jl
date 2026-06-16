@testset "section4_test" begin
    include(joinpath(@__DIR__, "..", "section4.jl"))

    # Lemma 4.2: linearity(F) ≤ 2^{(n+t)/2} when n+t even

    # n=6, t=2, n+t=8 (even) → |F^W| ≤ 2^4 = 16 (fast: 64 elements)
    F6 = bracken_binomial_sbox(2, 4)
    @test linearity(F6) ≤ 16
end
