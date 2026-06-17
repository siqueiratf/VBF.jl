@testset "theorem3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3.jl"))

    # IFF check on half=4 (8-bit S-boxes, exhaustive over all 240 pairs)
    r = theorem3_verify(; half=4, m=1)
    @test r.ok
    @test r.apn_count > 0
    @test r.non_apn_count > 0

    # Three CCZ-classes on F₂⁸, two of them new (a≠0)
    r3 = theorem3_ccz_classes(4)
    @test r3.n_classes == 3
    @test r3.n_new == 2
    @test r3.all_quadratic

    # Spot-check: known APN instance (n=4, m=1, a=0, b=1) — P(x)=x³+1, no root since x³+1=0 has x=-1=1 (char 2)...
    # Actually x³+1=0 → x³=1 → x=1 is a root!  So a=0,b=1 should NOT be APN.
    @test differential_uniformity(taniguchi_apn(4, 1, 0, 1)) > 2

    # Spot-check: a=0, b=2 — check if P(x)=x³+2 rootless in GF(2⁴)
    rootless_0_2 = _P_rootless(4, 1, 0, 2)
    F02 = taniguchi_apn(4, 1, 0, 2)
    @test (differential_uniformity(F02) == 2) == rootless_0_2
end
