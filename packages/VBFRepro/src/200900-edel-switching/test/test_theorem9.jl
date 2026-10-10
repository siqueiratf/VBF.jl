@testset "theorem9_test" begin
    include(joinpath(@__DIR__, "..", "theorem9.jl"))

    r = theorem9_report(devnull)
    @test r.constraint_ok                 # Theorem 9 "if": constraint ⇒ APN
    @test r.perturbed_apn_lost            # Theorem 9 "only if": break it ⇒ not APN
    @test r.all_apn                       # every listed switch neighbour is APN
    @test r.n_constraints > 0
end
