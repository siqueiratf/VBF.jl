@testset "theorem10_test" begin
    include(joinpath(@__DIR__, "..", "theorem10.jl"))

    r = theorem10_report(devnull)
    # 2.11: |M|=8 divisible by neither 63 (power map) nor 64 (quadratic).
    @test r.v211_not_power
    @test r.v211_not_quad
    # x^3 (1.1) is a power map: n(2^n-1)=378 | |M|=24192.
    @test EP_MULTIPLIER_ORDER_N6["1.1"] % (EP_N * ((1 << EP_N) - 1)) == 0
end
