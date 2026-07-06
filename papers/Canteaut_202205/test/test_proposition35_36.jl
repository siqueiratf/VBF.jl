@testset "proposition35_36" begin
    include(joinpath(@__DIR__, "..", "proposition35_36.jl"))

    # Prop 35: π_F(a) is the unique nonzero left-kernel vector of Jac_lin F(a)
    @test verify_proposition35(gold_apn(5))
    @test verify_proposition35(gold_apn(6))
    @test verify_proposition35(kim_apn())

    # Prop 36: π_G = (A₀ᵀ)⁻¹ ∘ π_F ∘ B₀
    @test verify_proposition36(gold_apn(5))
    @test verify_proposition36(gold_apn(6))
    @test verify_proposition36(kim_apn())

    # Lemma 34 (negative direction): non-APN quadratic has no ortho-derivative
    Q = pseudo_random_multirank_quadratic(6)
    @test ortho_derivative(Q) === nothing
end
