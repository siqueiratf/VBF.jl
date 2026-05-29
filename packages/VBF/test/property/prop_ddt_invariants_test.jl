@testitem "prop_ddt_invariants" begin
using VBFCatalog
using VBF
using Test
using Random

const RNG = MersenneTwister(0xBFA01)

@testset "DDT invariants on 5 random functions per N ∈ {3,4,5,6}" begin
    for N in (3, 4, 5, 6)
        for _ in 1:5
            s = random_function_sbox(RNG, Val(N))
            d = ddt(s)
            n = 1 << N

            # row 0 is (2^N, 0, …, 0)
            @test d[1, 1] == n
            @test all(==(0), view(d, 1, 2:n))

            # every row sums to 2^N
            @test all(a -> sum(view(d, a, :)) == n, 1:n)

            # all entries are even (N ≥ 2)
            @test all(iseven, d)

            # differential_uniformity matches direct max
            du = maximum(view(d, 2:n, 1:n))
            @test differential_uniformity(s) == du
        end
    end
end

@testset "DDT invariants on 3 random permutations per N ∈ {3,4,5,6}" begin
    for N in (3, 4, 5, 6)
        for _ in 1:3
            s = random_permutation_sbox(RNG, Val(N))
            @test is_permutation(s)
            d = ddt(s)
            n = 1 << N

            # for a permutation, column 0 is also (2^N, 0, …, 0):
            # F(x⊕a) ⊕ F(x) = 0 ⇔ x⊕a = x (injectivity) ⇔ a = 0
            @test d[1, 1] == n
            @test all(==(0), view(d, 2:n, 1))
        end
    end
end

end
