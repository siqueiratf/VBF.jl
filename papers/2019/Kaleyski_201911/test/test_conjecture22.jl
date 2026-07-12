@testset "conjecture22_test" begin
    include(joinpath(@__DIR__, "..", "helpers.jl"))
    include(joinpath(@__DIR__, "..", "conjecture22.jl"))

    # Fast check: limit=3, n=5 only
    r = conjecture22_report(; ns = [5], limit = 3, io = devnull)
    @test r.no_counterexample
    @test r.total_checked > 0

    # n=5 with limit=5: still no counterexample
    r5 = conjecture22_report(; ns = [5], limit = 5, io = devnull)
    @test r5.no_counterexample
    @test isempty(r5.counterexamples)
end
