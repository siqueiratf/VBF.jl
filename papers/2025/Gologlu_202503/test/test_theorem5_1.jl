@testset "theorem5_1_test" begin
    include(joinpath(@__DIR__, "..", "theorem5_1.jl"))

    io = IOBuffer()

    # (a),(b) F1 and F2 on M = F_2^5: phi(5)/2 = 2 CCZ classes each
    ab = theorem5_1_ab(io; m = 5)
    @test length(ab) == 2
    for row in ab
        @test row.classes == row.expected == 2
        @test row.constructive              # the CORRECTED map holds pointwise
        @test !row.paper_map_holds          # the map AS PRINTED does not (paper bug)
    end

    # (c) F4 at m = 6
    c = theorem5_1_c(io; m = 6)
    @test c.instances == 252
    @test c.ci_ok                           # corrected (c)(i) map verified pointwise
    @test !c.ci_paper_ok                    # printed L4 = (B^Q/a)x^Q does not work
    @test c.cii                             # B is not an invariant
    @test c.max_aprime <= 6                 # (c)(iii): at most m choices of a'
    @test c.exact                           # upper and lower bounds meet
    @test c.classes == 1                    # F4 collapses to ONE class at m = 6
    @test c.bounds == (1, 6)
    @test c.in_bounds

    # (d) Carlet, m odd
    d = theorem5_1_d(io; m = 5)
    @test d.orbit_covers                    # Lemma B.2 gives every same-q pair a map
    @test d.same_mugshot
    @test d.classes == d.expected == 2
    @test d.all_ok

    # Direct check of the corrected explicit map for F1 at m=5, k=1:
    #   M2 = M3 = x^{qbar},  L1 = x,  L4 = x^{q}   (paper prints L4 = x^{qbar})
    fld = BiField(5)
    F, G = family_f1(fld, 1), family_f1(fld, 4)
    M = BlockMap(zero_mono(), MonoMap(1, 4), MonoMap(1, 4), zero_mono())
    @test el_identity_holds(F, M, BlockMap(MonoMap(1, 0), zero_mono(), zero_mono(), MonoMap(1, 1)), G)
    @test !el_identity_holds(F, M, BlockMap(MonoMap(1, 0), zero_mono(), zero_mono(), MonoMap(1, 4)), G)

    # Corollary 5.2's bounds are computed from phi(m) and 2^{m/2}, and the F4
    # count at m = 6 sits inside them.
    @test 1 <= c.classes <= 6
end
