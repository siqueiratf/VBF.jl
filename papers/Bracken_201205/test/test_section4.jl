@testset "section4_test" begin
    include(joinpath(@__DIR__, "..", "section4.jl"))

    # Lemma 4.2: linearity(F) ≤ 2^{(n+t)/2} when n+t even

    # n=6, t=2, n+t=8 (even) → |F^W| ≤ 2^4 = 16 (fast: 64 elements)
    F6 = bracken_binomial_sbox(2, 4)
    @test linearity(F6) ≤ 16

    # n=15, t=1, n+t=16 (even) → |F^W| ≤ 2^8 = 256: the meaningful non-degenerate
    # case. Uses streaming linearity_rowwise (one LAT column at a time, O(2^n)
    # memory) since the full n=15 LAT would be ~8 GB; ~2 s here, fast-suite safe.
    F15 = bracken_binomial_sbox(5, 1)
    @test linearity_rowwise(F15) ≤ 256
end
