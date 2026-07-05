@testset "proposition4_2_test" begin
    include(joinpath(@__DIR__, "..", "proposition4_2.jl"))

    r = proposition4_2_build(3, 1)
    @test r.all_wz
    @test r.trivial_ok

    # n = 9 spot checks with the Prop 3.1 predicate (cheap path).
    n, i = 9, 1
    dual = gold_dual_table(n, i)
    tm = trace_mask_table(n)
    xis = filter(x -> x != 0 && x != 1, subfield_elements(n, 3))
    for xi in xis[1:2], mu in (1, 5, 200)
        z = proposition4_2_span(xi, mu, n, i)
        @test length(z) == 1 << n
        @test is_wz_space_gold(z, n, i; dual, tm)
    end
    # ξ ∈ {0, 1} degenerates to Z_a0.
    @test proposition4_2_span(0, 3, n, i) == z_a0_span(n)
    @test proposition4_2_span(1, 3, n, i) == z_a0_span(n)
end
