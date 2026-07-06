@testset "proposition6_test" begin
    include(joinpath(@__DIR__, "..", "proposition6.jl"))
    r = proposition6_report(devnull)
    @test r.all_ok
    # Zero map ⇒ identity permutation; predicate true.
    @test predicate_prop6(zeros(Int, 32), 5)
end
