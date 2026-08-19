@testset "problem5_1_test" begin
    include(joinpath(@__DIR__, "..", "problem5_1.jl"))

    # BTT-5: an open problem with an explicit finite instance is testable, not
    # "out of scope". At (k,s) = (5,1), n = 15, the admissible parameter space
    # is GF(2^5)² minus the 31 pairs with vw = 1.
    k, s = PROBLEM51_K, PROBLEM51_S
    pairs = problem5_1_pairs(k)
    @test length(pairs) == 993 == 32 * 32 - 31
    @test (0, 0) in pairs
    @test all(p -> gf_mul(p[1], p[2], 3k) != 1, pairs)

    # v = w = 0 collapses G to u · F of Theorem 1.2, which is why it is the one
    # permutation the full scan finds.
    @test problem5_1_lut(k, s, 2, 0, 0) == bracken_binomial_lut(k, s)

    # Permutation half — REFUTED at t = 1. The default path samples `limit`
    # pairs (an n=15 build is 0.049 s); the full 993-pair scan is opt-in via
    # full_search = true and costs 52.5 s on this machine.
    scan = problem5_1_permutation_scan(k, s; limit = 32)
    @test scan.admissible == 993
    @test scan.scanned == 32
    @test !scan.exhaustive
    @test scan.permutations == [(0, 0)]        # only the degenerate point

    # Differential half — SUPPORTED. Sampled pairs with v,w ≠ 0 (the genuinely
    # new members) all have differential spectrum {0, 2^t} = {0, 2}.
    d = problem5_1_differential_scan(k, s; samples = 2)
    @test d.t == 1 && d.n == 15
    @test length(d.rows) == 2
    @test all(r -> r.v != 0 && r.w != 0, d.rows)
    @test all(r -> r.spectrum == [0, 2], d.rows)
    @test d.ok
end
