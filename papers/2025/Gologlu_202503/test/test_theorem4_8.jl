@testset "theorem4_8_test" begin
    include(joinpath(@__DIR__, "..", "theorem4_8.jl"))

    io = IOBuffer()
    r = theorem4_8_report(io; m = 5)
    @test r.hypotheses_ok
    @test r.positive_ok
    @test r.negative_total > 0             # the negative half is non-empty
    @test r.negative_sound == r.negative_total
    @test r.search_hits > 0
    @test r.all_ok

    fld = BiField(5)
    m = 5

    # POSITIVE: F1(q) and F1(q_bar) are linearly equivalent, and the search
    # returns a witness of the shape the theorem forces, re-verified pointwise.
    F = family_f1(fld, 1)
    G = family_f1(fld, 4)                  # q_bar = 2^{5-1}
    hits = linear_equiv_thm48(F, G)
    @test !isempty(hits)
    @test thm48_exponent_condition(F, G)
    @test mugshot_of(F) == mugshot_of(G)

    # the witness really satisfies F ∘ M = L ∘ G on all 2^10 points
    h = first(hits)
    M = BlockMap(
        MonoMap(frob(fld, h.c[1], h.t), h.t),
        MonoMap(frob(fld, h.c[2], h.t), h.t),
        MonoMap(frob(fld, h.c[3], h.t), h.t),
        MonoMap(frob(fld, h.c[4], h.t), h.t),
    )
    L =
        h.shape === :diagonal ?
        BlockMap(MonoMap(h.d1, h.s1), zero_mono(), zero_mono(), MonoMap(h.d2, h.s2)) :
        BlockMap(zero_mono(), MonoMap(h.d1, h.s1), MonoMap(h.d2, h.s2), zero_mono())
    @test el_identity_holds(F, M, L, G)
    @test block_invertible(fld, M)

    # NEGATIVE: a pair violating the exponent condition is CCZ-inequivalent, and
    # the search finds nothing for it.
    T = taniguchi(fld, 1, findfirst(x -> taniguchi_valid(fld, 1, x), 0:31) - 1)
    Gold = gold_odd(fld, 1)
    @test !thm48_exponent_condition(Gold, T)
    @test mugshot_of(Gold) != mugshot_of(T)
    @test isempty(linear_equiv_thm48(Gold, T))

    # hypotheses: they hold at m=5 and fail at m=4 (l = 2 = m/2 there)
    @test thm48_hypotheses_ok(family_f1(fld, 1))
    @test !thm48_hypotheses_ok(family_f1(BiField(4), 3))
end
