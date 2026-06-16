@testset "theorem1_test" begin
    include(joinpath(@__DIR__, "..", "theorem1.jl"))

    # m=5, i=1: canonical AB case
    r = theorem1_check(; m = 5, i = 1)
    @test r.is_apn
    @test r.is_ab
    @test r.deg == 3
    @test r.prop4_ok

    # m=5, i=2
    r = theorem1_check(; m = 5, i = 2)
    @test r.is_apn
    @test r.is_ab
    @test r.deg == 3
    @test r.prop4_ok

    # m=7, i=1
    r = theorem1_check(; m = 7, i = 1)
    @test r.is_apn
    @test r.is_ab
    @test r.deg == 3
    @test r.prop4_ok

    # argument validation
    @test_throws ArgumentError theorem1_lut(4, 1)   # m even
    @test_throws ArgumentError theorem1_lut(3, 1)   # m ≤ 3
    @test_throws ArgumentError theorem1_lut(5, 5)   # gcd(i,m) ≠ 1
end
