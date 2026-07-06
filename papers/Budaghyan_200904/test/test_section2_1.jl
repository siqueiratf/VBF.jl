@testset "section2_1_test" begin
    include(joinpath(@__DIR__, "..", "section2_1.jl"))

    # n=5 example: x⁵+tr(x³) APN and CCZ-equivalent to Gold.
    F5 = gold_plus_trace(5, 5, 3)
    @test differential_uniformity(F5) == 2                    # APN
    @test are_ccz_equivalent(F5, gold_apn(5, 1))             # CCZ-equiv Gold

    # Opt-in dependence search at n=5: nonzero kernel, tested vectors give APN.
    r = dependence_search(devnull; n = 5, r = 1)
    @test r.kdim ≥ 1
    @test r.verified == r.checks
end
