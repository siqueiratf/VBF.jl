@testset "proposition14" begin
    include(joinpath(@__DIR__, "..", "proposition14.jl"))

    # Gold x^3 n=5: verify Δ_a F(x) ⊕ Δ_a F(0) = Jac_lin F(a)·x for all a,x
    F5 = gold_apn(5)
    @test verify_proposition14(F5)
    @test verify_corollary15(F5)

    # Also check n=4 (small, fast, exhaustive)
    F4 = gold_apn(4)
    @test verify_proposition14(F4)

    # Non-APN quadratic with several Jac_lin ranks (non-degenerate case)
    Q = pseudo_random_multirank_quadratic(6)
    @test length(rank_distribution(Q)) ≥ 2
    @test verify_proposition14(Q)
    @test verify_corollary15(Q)

    # Spot-check: a=3, x=5 for n=5
    a, x = 3, 5
    F = F5
    lhs = F.lut[(x ⊻ a)+1] ⊻ F.lut[x+1] ⊻ F.lut[a+1] ⊻ F.lut[1]
    rhs = jac_lin_apply(jac_lin_cols(F, a), x)
    @test lhs == rhs
end
