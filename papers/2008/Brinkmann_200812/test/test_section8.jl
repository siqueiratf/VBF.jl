@testset "section8_test" begin
    include(joinpath(@__DIR__, "..", "section8.jl"))

    A, D = subspace_counts(64)

    # Prop 11's recurrences agree with brute-force enumeration on [0; k-1].
    for k in 0:16
        @test A[k+1] == count_affine_subspaces(collect(0:k-1))
    end
    @test all(A[k+1] == sum(D[1:k+1]) for k in 0:64)

    # Sequences (20) and (21), starting at i = 1.
    @test A[2:17] == [0, 0, 0, 1, 1, 3, 7, 14, 14, 18, 26, 39, 55, 77, 105, 140]
    @test D[2:17] == [0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 8, 13, 16, 22, 28, 35]

    # #A(F₂ⁿ) = C(2ⁿ,3)/4.
    for n in 1:6
        @test A[(1<<n)+1] == binomial(1 << n, 3) ÷ 4
    end
    @test [A[(1<<n)+1] for n in 1:6] == [0, 1, 14, 140, 1240, 10416]

    # Eq (22): Δ(2^k) = (1/6)(2^k − 3/2)² − 1/24, exactly over the rationals.
    for k in 1:6
        @test D[(1<<k)+1] == (1 // 6) * (big(1 << k) - 3 // 2)^2 - 1 // 24
    end
    @test [D[(1<<k)+1] for k in 1:6] == [0, 1, 7, 35, 155, 651]

    # Eq (23): Δ(2^k + j) = Δ(j) + (j−1)·2^k/2 for 0 < j < 2^k.
    for k in 1:5, j in 1:((1<<k)-1)
        @test D[(1<<k)+j+1] == D[j+1] + ((j - 1) * (1 << k)) ÷ 2
    end

    # Prop 12: #A(M) ≤ A(#M), exhaustively over F₂³.
    for m in 0:255
        M = [x for x in 0:7 if (m >> x) & 1 == 1]
        @test count_affine_subspaces(M) <= A[length(M)+1]
    end

    # ... and on a random sample of subsets of F₂⁴.
    rng = MersenneTwister(20081201)
    for _ in 1:500
        M = [x for x in 0:15 if rand(rng, Bool)]
        @test count_affine_subspaces(M) <= A[length(M)+1]
    end

    # Prop 2's model: P is monotone in Δ, is 0 when Δ = 0 and → 1 for large Δ.
    @test conflict_probability(6, 0) == 0.0
    @test conflict_probability(6, D[5]) ≈ 1 - (63 / 64)
    @test conflict_probability(6, 620) > 0.99993

    # Fig. 1: the model tracks the measured conflict counts for n = 6.
    meas = measure_conflicts(6; dives = 100)
    for k in [4, 8, 16, 17, 24, 32, 33]
        model = 64 * conflict_probability(6, D[k+1])
        @test !isnan(meas[k])
        @test abs(meas[k] - model) <= 0.1 * 64 + 1e-9
    end
end
