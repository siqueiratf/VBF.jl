@testset "theorem5_test" begin
    include(joinpath(@__DIR__, "..", "theorem5.jl"))
    include(joinpath(@__DIR__, "..", "theorem2.jl"))

    for (n, i) in [(4, 1), (4, 2), (6, 1)]
        Fu_prime = theorem5_build(n, i; u = 1)
        Fu_prime_inv = compositional_inverse(Fu_prime)
        deg_expected = (n + 2) ÷ 2

        @test is_permutation(Fu_prime)
        @test differential_uniformity(Fu_prime) == 4
        @test algebraic_degree(Fu_prime) == deg_expected
        @test algebraic_degree(Fu_prime_inv) == deg_expected
    end

    # EA-equivalence with F_u: same NL
    Fu4     = theorem2_build(4, 1; u = 1)
    Fu4_p   = theorem5_build(4, 1; u = 1)
    @test linearity(Fu4) == linearity(Fu4_p)
end
