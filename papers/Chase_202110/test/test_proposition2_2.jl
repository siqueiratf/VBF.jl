@testset "proposition2_2_test" begin
    include(joinpath(@__DIR__, "..", "proposition2_2.jl"))

    r = proposition2_2_build(5, 1; mus = [1, 2])
    for res in r.results
        @test res.trivially
        @test res.perm
        @test res.apn
        @test res.ccz === true
    end
    # The trivial pair {Z_a0, Z_0b} recovers a linear transform of f: degree 2.
    @test r.results[1].degree == 2

    # Round-trip sanity: the identity-like pair applied twice stays in class —
    # feeding the pair in swapped order yields the compositional inverse.
    F = gold_apn(5, 1)
    tm = trace_mask_table(5)
    S = z_a0_span(5)
    T = z_0b_span(5)
    g1 = wz_pair_to_permutation(F, S, T; tm)
    g2 = wz_pair_to_permutation(F, T, S; tm)
    @test g2 == compositional_inverse(g1)

    # Non-trivially-intersecting input must be rejected.
    @test_throws ArgumentError wz_pair_to_permutation(F, S, S; tm)
end
