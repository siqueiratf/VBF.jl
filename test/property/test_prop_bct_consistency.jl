using BFA
using Test
using Random

const RNG = MersenneTwister(0xBFA03)

@testset "BCT ≥ DDT pointwise on 3 random permutations per N ∈ {3,4,5}" begin
    # (skip N=6 because 64×64×64 = 256k inner iterations × 3 × 4 = 3M;
    # plenty for unit-test budgets but redundant given the catalog tests
    # already cover up to N=8.)
    for N in (3, 4, 5)
        for _ in 1:3
            s = random_permutation_sbox(RNG, Val(N))
            B = bct(s)
            D = ddt(s)
            n = 1 << N

            @test all(B .≥ D)              # Cid et al. Lemma 1
            @test all(iseven, B)
            @test all(B[a, 1] == n for a in 1:n)
            @test all(B[1, b] == n for b in 1:n)
        end
    end
end

@testset "FBCT symmetry on 3 random functions per N ∈ {3,4,5}" begin
    for N in (3, 4, 5)
        for _ in 1:3
            s = random_function_sbox(RNG, Val(N))
            F = fbct(s)
            @test F == transpose(F)
            n = 1 << N
            @test all(F[a, a] == n for a in 1:n)
        end
    end
end
