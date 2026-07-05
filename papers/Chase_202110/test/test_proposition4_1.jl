@testset "proposition4_1_test" begin
    include(joinpath(@__DIR__, "..", "proposition4_1.jl"))

    r = proposition4_1_build(5, 1)
    @test r.all_dim
    @test r.all_wz
    @test r.trivials_ok
    # Catalog at n=5: {0}, F_{2^5}, 31 spaces μF_2 → 33 distinct WZ spaces.
    @test r.n_catalog == 33
    @test r.n_distinct == 33

    # Gold-class sanity at n=9 (3 | 9): a scaled 2-dim F_8-subspace works too,
    # checked with the Prop 3.1 predicate (LAT-free fast path).
    n, i = 9, 1
    dual = gold_dual_table(n, i)
    tm = trace_mask_table(n)
    f8 = subfield_elements(n, 3)
    xi = first(filter(x -> x != 0 && x != 1, f8))
    S = sort([0, 1, xi, 1 ⊻ xi])            # 2-dim subspace of F_8
    z = proposition4_1_span(S, n, i; dual, tm)
    @test length(z) == 1 << n
    @test is_wz_space_gold(z, n, i; dual, tm)
end
