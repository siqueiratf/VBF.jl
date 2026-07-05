@testset "proposition3_test" begin
    include(joinpath(@__DIR__, "..", "proposition3.jl"))

    res = proposition3_build(3, 1)
    # 6 non-identity α values in GF(8)\{0,1}
    @test length(res) == 6
    # Prop 3 holds for every α
    @test all(r.prop3_holds for r in res)
    # Exactly 6 APN (α,β) pairs total for n=3 i=1
    @test sum(r.n_apn_total for r in res) == 6
    # Each APN α contributes exactly 2 APN betas (β₁ and β₂)
    apn_alphas = filter(r -> r.n_apn_total > 0, res)
    @test all(r.n_apn_total == 2 for r in apn_alphas)

    # n=5 full β sweep: Prop 3 holds and there are no APN butterflies at all
    res5 = proposition3_build(5, 1)
    @test length(res5) == 30
    @test all(r.prop3_holds for r in res5)
    @test sum(r.n_apn_total for r in res5) == 0

    # α=1 exclusion (paper: 3-round Feistel ⟹ diff. uniformity ≥ 4, never APN)
    for n in (3, 5)
        a1 = alpha1_build(n, 1)
        @test a1.min_du >= 4
        @test a1.n_apn == 0
    end
end
