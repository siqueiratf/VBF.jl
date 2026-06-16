@testset "theorem4_test" begin
    include(joinpath(@__DIR__, "..", "theorem4.jl"))

    # m=9, n=3, i=1: AB, degree n+2=5
    r = theorem4_check(; m = 9, n = 3, i = 1)
    @test r.is_ab
    @test r.deg == r.expected_deg   # n+2 = 5

    # m=9, n=3, i=2
    r = theorem4_check(; m = 9, n = 3, i = 2)
    @test r.is_ab
    @test r.deg == r.expected_deg

    # argument validation
    @test_throws ArgumentError theorem4_lut(4, 2, 1)   # m even
    @test_throws ArgumentError theorem4_lut(9, 9, 1)   # m == n
    @test_throws ArgumentError theorem4_lut(9, 4, 1)   # n ∤ m (4 ∤ 9)
    @test_throws ArgumentError theorem4_lut(9, 3, 3)   # gcd(3,9) ≠ 1
end
