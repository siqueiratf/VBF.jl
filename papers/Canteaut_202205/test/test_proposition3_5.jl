@testset "proposition3_5" begin
    include(joinpath(@__DIR__, "..", "proposition3_5.jl"))

    # Gold x^3 n=5: verify Δ_a F(x) ⊕ Δ_a F(0) = Jac_lin F(a)·x for all a,x
    F5 = gold_apn(5)
    @test verify_proposition3_5(F5)

    # Also check n=4 (small, fast, exhaustive)
    F4 = gold_apn(4)
    @test verify_proposition3_5(F4)

    # Spot-check: a=3, x=5 for n=5
    a, x = 3, 5
    F = F5
    lhs = F.lut[(x ⊻ a)+1] ⊻ F.lut[x+1] ⊻ F.lut[a+1] ⊻ F.lut[1]
    rhs = jac_lin_apply(jac_lin_cols(F, a), x)
    @test lhs == rhs
end
