@testset "Section 4.5 bounded corpus evidence" begin
    include(joinpath(@__DIR__, "..", "section4_5.jl"))
    r = section4_5_report(; limit=2, check_ortho=true, timeout_seconds=120, io=devnull)
    @test r.available == 21_102
    @test length(r.records) == 2
    @test r.invalid == 0
    @test r.outcome isa BudgetHit
    @test !r.table_reproduced
    @test !r.pairwise_distinguished
    @test all(sum(last, row.extended_walsh) == 256 * 255 for row in r.records)
    @test all(row.extended_walsh in SECTION45_PUBLISHED_WALSH for row in r.records)
    missing = section4_5_report(; corpora=["does_not_exist"], io=devnull)
    @test missing.outcome isa BudgetHit
    @test !missing.complete
    @test !missing.table_reproduced
    @test_throws ArgumentError section4_5_report(; limit=-1, io=devnull)
end
