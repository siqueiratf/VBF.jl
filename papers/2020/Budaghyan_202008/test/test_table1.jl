@testset "table1_test" begin
    include(joinpath(@__DIR__, "..", "table1.jl"))

    r = table1_check()
    @test r.n_entries == 8            # Table I has 8 rows = 7 known + 1 new
    @test r.all_apn
    @test r.all_quadratic             # needed for EA = CCZ (Yoshiara)
    @test r.all_distinct
    @test r.n_distinct == 8
    @test isempty(r.collisions)

    entries = table1_entries()
    @test length(entries) == 8
    @test entries[end].source == "Theorem VI.3"

    # The mugshot must actually discriminate: an entry compared with itself
    # collides, so distinctness above is not an artefact of the invariant being
    # unable to see anything.
    @test entries[1].mugshot == table1_entries()[1].mugshot
    @test entries[1].mugshot != entries[2].mugshot
end
