# Exact tree sizes T(n,m) against DFS, closed form and the Knuth estimators.
@testset "exact counts T(n,m) and Knuth" begin
    for ((n, m), T) in sort(collect(EXACT_T))
        @test QK.exact_count(n, m) == T
    end
    # n = 3: every nonzero vector of Lambda^2 is decomposable -> injective maps.
    for m in 3:5
        @test EXACT_T[(3, m)] == (2^m - 1) * (2^m - 2) * (2^m - 4)
    end
    # Mass of (4,4): T / |GL(4,2)|^2 = 1/360.
    @test EXACT_T[(4, 4)] // (QK.gl_order(4)^2) == 1 // 360

    rng = Xoshiro(20261008)
    for ((n, m), T) in sort(collect(EXACT_T))
        lw = [QK.probe(rng, n, m)[1] for _ in 1:20_000]
        est = mean(exp.(lw))
        se = std(exp.(lw)) / sqrt(length(lw))
        @test abs(est - T) <= max(5se, 1e-9 * T)
        # Knuth to n-1 variables + slow exact last step.
        lw2 = [QK2.probe_last_exact(rng, n, m)[1] for _ in 1:5_000]
        est2 = mean(exp.(lw2))
        se2 = std(exp.(lw2)) / sqrt(length(lw2))
        @test abs(est2 - T) <= max(5se2, 1e-9 * T)
    end
    # The estimator is exact on trees with constant branching: (3,3) has no dead ends.
    @test all(isfinite(QK.probe(rng, 3, 3)[1]) for _ in 1:100)
end
