@testset "theorem5_presemifield_test" begin
    include(joinpath(@__DIR__, "..", "theorem5_presemifield.jl"))

    # Find valid parameters and verify
    params = theorem5_find_params()
    @test params !== nothing

    a, b, α = params
    @test _P_rootless_T5(a, b)
    @test _norm(α) != 1

    # Lemma 2: circ multiplication has no zero-divisors
    @test lemma2_verify(α)

    # Theorem 5: full no-zero-divisor check
    r = theorem5_verify(a, b, α)
    @test r.ok

    # Sanity: zero*(anything) = (0,0)
    p1, p2 = presemi_mul(0, 0, 3, 5, a, b, α)
    @test p1 == 0 && p2 == 0
end
