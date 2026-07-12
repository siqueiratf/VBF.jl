@testset "theorem2_test" begin
    include(joinpath(@__DIR__, "..", "theorem2.jl"))

    # m=4, i=1
    r = theorem2_check(; m = 4, i = 1)
    @test r.is_apn
    @test r.deg == 3
    @test r.prop4_ok

    # m=4, i=3
    r = theorem2_check(; m = 4, i = 3)
    @test r.is_apn
    @test r.deg == 3
    @test r.prop4_ok

    # m=6, i=1
    r = theorem2_check(; m = 6, i = 1)
    @test r.is_apn
    @test r.deg == 3
    @test r.prop4_ok

    # m=6, i=5
    r = theorem2_check(; m = 6, i = 5)
    @test r.is_apn
    @test r.deg == 3
    @test r.prop4_ok

    # argument validation
    @test_throws ArgumentError theorem2_lut(3, 1)   # m < 4
    @test_throws ArgumentError theorem2_lut(5, 1)   # m odd
    @test_throws ArgumentError theorem2_lut(6, 2)   # gcd(2,6) = 2 ≠ 1
end
