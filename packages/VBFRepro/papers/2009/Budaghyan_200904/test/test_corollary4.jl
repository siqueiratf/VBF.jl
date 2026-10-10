@testset "corollary4_test" begin
    include(joinpath(@__DIR__, "..", "corollary4.jl"))

    # Headline: the n=7 Δ-rank of x³+tr(x⁹) is exactly 212.
    F = apn_x3_tr_x9(7)
    @test differential_uniformity(F) == 2                     # APN
    @test delta_rank(F) == 212                                # CCZ-invariant certificate
end
