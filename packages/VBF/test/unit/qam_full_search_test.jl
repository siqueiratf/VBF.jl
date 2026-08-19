@testitem "qam_full_search" begin
using VBF
using Test

@testset "search_qam_full reproduces the n=5 classification (Gold x³)" begin
    outcome = search_qam_full(5; limit = 1)
    reps = search_solutions(outcome)
    @test outcome isa Found          # stopped at limit = 1, not a coverage claim
    @test length(reps) == 1
    F = reps[1]
    @test inputbits(F) == 5
    @test differential_uniformity(F) == 2          # APN
    @test algebraic_degree(F) == 2                 # quadratic
    @test is_qam(F)                                # its derivative matrix is a QAM
    gold = SBox{5}(gf_monomial_lut(5, 3))
    @test apn_ea_mugshot(F) == apn_ea_mugshot(gold)
end

@testset "search_qam_full: a budget stop is not a proof of emptiness" begin
    # A zero evaluation budget returns immediately with nothing examined. The
    # old contract here was `@test isempty(search_qam_full(6; max_evaluations = 0))`
    # — which asserted that a budget stop is indistinguishable from an empty
    # region. That is the collapse this type exists to prevent.
    outcome = search_qam_full(6; max_evaluations = 0)
    @test outcome isa BudgetHit
    @test isempty(search_solutions(outcome))     # nothing found …
    @test !proves_emptiness(outcome)             # … but nothing proved either
    @test_throws MethodError certified_empty_region(outcome)
    @test outcome.where_it_stopped.reason === :nodes
    @test occursin("UNKNOWN", coverage_note(outcome))
end
end
