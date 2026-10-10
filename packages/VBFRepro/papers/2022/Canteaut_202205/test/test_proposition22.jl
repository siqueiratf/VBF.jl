@testset "proposition22" begin
    include(joinpath(@__DIR__, "..", "proposition22.jl"))

    # Gold x^3 n=5 (APN): all nonzero a should have rank 4 = n-1
    F5 = gold_apn(5)
    @test verify_proposition22(F5)
    rdist5 = rank_distribution(F5)
    @test rdist5 == Dict(4 => 31)  # all 31 nonzero a have rank 4

    # Gold x^3 n=4 (APN)
    F4 = gold_apn(4)
    @test verify_proposition22(F4)

    # Non-degenerate case: quadratic with a multi-valued rank distribution —
    # the formula is exercised at several ranks r simultaneously.
    Q = pseudo_random_multirank_quadratic(6)
    @test length(rank_distribution(Q)) ≥ 2
    @test verify_proposition22(Q)

    # Spot-check formula for n=5 APN: R_dist[4] * 2^4 = D_dist[2^1] = D_dist[2]
    ddist5 = ddt_distribution(F5)
    @test rdist5[4] * 16 == ddist5[2]
end
