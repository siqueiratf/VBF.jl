@testset "proposition4_3_test" begin
    include(joinpath(@__DIR__, "..", "proposition4_3.jl"))

    r = proposition4_3_build(5, 1)
    @test r.all_wz
    @test r.all_dim
    # m = n = 5 gives the 31 permutation-type spaces of Section 6.1.
    @test r.per_m[5] == 31

    # n = 9, all divisors, a few μ, Prop 3.1 predicate path.
    n, i = 9, 1
    dual = gold_dual_table(n, i)
    tm = trace_mask_table(n)
    for m in (1, 3, 9), mu in (1, 7, 100)
        z = proposition4_3_span(m, mu, n, i)
        @test length(z) == 1 << n
        @test is_wz_space_gold(z, n, i; dual, tm)
    end
end
