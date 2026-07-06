@testset "table6_test" begin
    include(joinpath(@__DIR__, "..", "table6.jl"))

    # Full n=6 Γ/Δ-rank + Walsh sweep vs the paper (sub-second).
    r = table6_report(devnull)
    @test r.all_ok

    # Spot-check the headline invariants directly.
    byname = Dict(c.name => c for c in r.computed)
    @test byname["2.11"].gamma == 1300
    @test byname["2.11"].delta == 152
    @test byname["1.1"].gamma == 1102
    @test byname["2.6"].walsh == :nonclassical
    @test count(c -> c.walsh == :nonclassical, r.computed) == 1
end
