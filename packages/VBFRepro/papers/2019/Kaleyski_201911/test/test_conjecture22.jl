@testset "conjecture22_test" begin
    include(joinpath(@__DIR__, "..", "helpers.jl"))
    include(joinpath(@__DIR__, "..", "conjecture22.jl"))

    # n=5 exhaustive over ALL pairs (README R2): every n=5 catalog APN × 496
    # genuine pairs, none APN. (The old suite tested the single (0,1) swap.) The
    # claim is the *invariant* (zero APN swaps), not the catalog size — the counts
    # scale with however many n=5 APN the catalog holds, so assert the relation,
    # not a fixed number.
    r5 = conjecture22_report(; ns = [5], io = devnull)
    @test r5.no_counterexample
    @test isempty(r5.counterexamples)
    @test r5.total_checked >= 3          # every n=5 catalog APN, none skipped
    @test r5.total_swaps == r5.total_checked * 496   # C(32,2) genuine pairs each
    @test only(r5.summary).exhaustive
    @test only(r5.summary).n_apn_swaps == 0

    # n=4 CONTROL: the conjecture is stated for n ≥ 5, and Observation 27 says the
    # swap *can* be APN below that. If this found 0 APN swaps, the all-pairs search
    # would be silently broken. Each n=4 APN contributes 15 APN swaps (one class,
    # replicated across catalog entries), so assert > 0 and internal consistency.
    r4 = conjecture22_report(; ns = [4], io = devnull)
    @test only(r4.summary).n_apn_swaps > 0
    @test length(r4.counterexamples) == only(r4.summary).n_apn_swaps
    @test all(cx -> cx.n == 4, r4.counterexamples)
    @test r4.no_counterexample           # n<5 does not count against Conjecture 22

    mixed = conjecture22_report(; ns=[4,5], limit=1, io=devnull)
    @test all(all(cx.n == row.n for cx in search_solutions(row.outcome)) for row in mixed.summary)
    @test proves_emptiness(mixed.outcomes[2])
    @test !proves_emptiness(mixed.outcomes[1])

    # Sampled mode for the higher dimensions (all-pairs at n=7 is ≈3.9M swaps).
    r7 = conjecture22_report(; ns = [7], limit = 4, pair_samples = 8, io = devnull)
    @test r7.no_counterexample
    @test !only(r7.summary).exhaustive
    @test r7.total_swaps >= 4 * 8

    budget = conjecture22_report(; ns = [5], max_evaluations = 0, io = devnull)
    @test budget.total_swaps == 0
    @test only(budget.outcomes) isa BudgetHit
    @test !only(budget.summary).exhaustive
    @test only(r5.outcomes) isa Exhausted
    @test only(r7.outcomes) isa BudgetHit
    @test only(r7.summary).available_functions >= only(r7.summary).n_functions
    @test_throws ArgumentError conjecture22_report(; max_evaluations = -1, io = devnull)

    # Functions with F(0)=F(1) are covered, not discarded (README R3): every catalog
    # APN in the requested dimension contributes swaps.
    r6 = conjecture22_report(; ns = [6], limit = 6, exhaustive_max_n = 0,
                             pair_samples = 4, io = devnull)
    @test r6.total_checked == 6
    @test r6.no_counterexample
    @test all(row -> row.n_swaps >= 6 * 4, r6.summary)
end
