@testset "corollary1_test" begin
    include(joinpath(@__DIR__, "..", "corollary1.jl"))
    r = corollary1_report(devnull; full_search = false)
    @test r.all_ok
    # eqs (4),(5) APN quadratic over GF(2⁶).
    @test differential_uniformity(as_sbox(apn_eq4(6), 6)) == 2
    @test differential_uniformity(as_sbox(apn_eq5(6), 6)) == 2
end
