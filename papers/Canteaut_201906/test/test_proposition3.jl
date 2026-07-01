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
end
