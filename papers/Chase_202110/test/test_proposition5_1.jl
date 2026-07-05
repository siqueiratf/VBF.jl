@testset "proposition5_1_test" begin
    include(joinpath(@__DIR__, "..", "proposition5_1.jl"))

    r = proposition5_1_build(3, 1)
    @test r.all_ok
    @test r.exhaustive

    # n = 9 spot check via the Prop 3.1 predicate + trivial intersection.
    n, i = 9, 1
    dual = gold_dual_table(n, i)
    tm = trace_mask_table(n)
    xi = first(filter(x -> x != 0 && x != 1, subfield_elements(n, 3)))
    Y, Z = proposition5_1_pair(xi, 17, n, i)
    @test is_wz_space_gold(Y, n, i; dual, tm)
    @test is_wz_space_gold(Z, n, i; dual, tm)
    @test intersects_trivially(Y, Z)
end
