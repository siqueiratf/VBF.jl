@testset "section2_test" begin
    include(joinpath(@__DIR__, "..", "section2.jl"))

    # Lemma 2.1: F is a permutation iff k/t is odd, t = gcd(3k, s)

    # n=6, k=2, s=4: t=gcd(6,4)=2, k/t=1 (odd) → permutation
    # (degenerate: exponents both reduce to 17, F is monomial (α+α^4)x^17)
    F6 = bracken_binomial_sbox(2, 4)
    @test is_permutation(F6)

    # n=12, k=4, s=2: t=gcd(12,2)=2, k/t=2 (even) → NOT a permutation
    F12 = bracken_binomial_sbox(4, 2)
    @test !is_permutation(F12)

    # n=15, k=5, s=1: t=gcd(15,1)=1, k/t=5 (odd) → permutation (non-degenerate APN)
    F15 = bracken_binomial_sbox(5, 1)
    @test is_permutation(F15)
end
