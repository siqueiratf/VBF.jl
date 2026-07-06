@testset "helpers_test" begin
    include(joinpath(@__DIR__, "..", "helpers.jl"))

    # LUT builder shape + flagship APN.
    F5 = apn_x3_tr_x9(5)
    @test length(F5.lut) == 32
    @test differential_uniformity(F5) == 2          # APN check

    # gold_plus_trace matches the explicit construction.
    G = gold_plus_trace(5, 5, 3)
    @test all(G.lut[x+1] == (gf_pow(x,5,5) ⊻ gf_trace(gf_pow(x,3,5),5)) for x = 0:31)

    # φ_F kernel is {0,a} for an APN function (Remark 1).
    a = 7
    φ = phi(F5, a)
    @test φ[0+1] == 0 && φ[a+1] == 0                # 0 and a are in the kernel
    @test count(==(0), φ) == 2                       # exactly {0, a}

    # graph_affine_map with L(x,y)=(x+corr(y),y) is an involution ⇒ round-trip.
    corr = y -> gf_trace(y, 5)
    H  = graph_affine_map(F5, corr)
    H2 = graph_affine_map(H, corr)
    @test H2 !== nothing
    @test H2.lut == F5.lut                            # round-trip recovers F
end
