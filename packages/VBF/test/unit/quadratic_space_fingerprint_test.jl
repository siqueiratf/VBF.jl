@testitem "quadratic_space_fingerprint" begin
    using VBF, Test, Random
    Q = VBF.QuadraticExtensions
    rng = Xoshiro(525208182)
    @testset "necessary invariant under input and output basis changes" begin
        for n in 3:8
            G = Q.geometry(n)
            d = min(5, n, G.N)
            V = first(Q.rref(rand(rng, UInt32, d) .& ((UInt32(1)<<G.N)-UInt32(1))))
            for max_rounds in (0, 1, 4)
                key = quadratic_space_fingerprint(G, V; max_rounds)
                @test length(key) == 64
                @test quadratic_space_fingerprint(G, reverse(V); max_rounds) == key
                for _ in 1:3
                    L = random_linear_permutation(rng, Val(n))
                    W = transform_quadratic_space(G, V, L.cols)
                    @test quadratic_space_fingerprint(G, W; max_rounds) == key
                end
                changed_basis = copy(V)
                if length(V) >= 2
                    changed_basis[1] ⊻= changed_basis[2]
                    push!(changed_basis, V[1])
                end
                @test quadratic_space_fingerprint(G, changed_basis; max_rounds) == key
            end
        end
    end
    @testset "separation does not assert completeness or equivalence" begin
        G = Q.geometry(4)
        star, triangle = UInt32[1,2,4], UInt32[1,2,8]
        @test quadratic_space_rank_signature(G, star) == quadratic_space_rank_signature(G, triangle)
        @test quadratic_space_fingerprint(G, star) != quadratic_space_fingerprint(G, triangle)
        @test length(quadratic_space_fingerprint(G, UInt32[])) == 64
        @test quadratic_space_fingerprint(G, UInt32[]) == quadratic_space_fingerprint(G, UInt32[0])
        @test_throws ArgumentError quadratic_space_fingerprint(G, star; max_rounds=-1)
        @test_throws ArgumentError quadratic_space_fingerprint(G, star; max_rounds=33)
        @test_throws ArgumentError quadratic_space_fingerprint(G, star; min_active_hyperplanes=-1)
        @test_throws ArgumentError quadratic_space_fingerprint(G, UInt32[1,2,4,8,16])
    end
end
