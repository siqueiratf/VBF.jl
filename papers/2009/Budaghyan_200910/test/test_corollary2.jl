@testset "corollary2_test" begin
    include(joinpath(@__DIR__, "..", "corollary2.jl"))
    r = corollary2_report(devnull)
    @test r.all_ok
    # b=0 reduces to a·x³ + trₙ(a³x⁹): still APN.
    Llut = L_class_lut(:trace, 6)
    @test differential_uniformity(as_sbox(apn_corollary2(6, 2, 0, Llut), 6)) == 2
end
