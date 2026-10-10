@testset "Bounded simplex upper bounds" begin
    include(joinpath(@__DIR__, "..", "table_bounds.jl"))
    exact = simplex_bound_evidence(power_sbox(4, 3); max_nodes=1_000_000, timeout_seconds=60)
    @test exact.complete
    @test exact.upper_bound == 16
    @test exact.outcome isa Exhausted
    stopped = simplex_bound_evidence(power_sbox(7, 3); max_nodes=0)
    @test !stopped.complete
    @test stopped.upper_bound === nothing
    @test stopped.outcome isa BudgetHit
    report = table_bounds_report(; limit=2, max_nodes=0, io=devnull)
    @test length(report.records) == 2
    @test all(row.matches === nothing for row in report.records)
    @test !report.full_tables_reproduced
end
