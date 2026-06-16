@testset "theorem3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3.jl"))

    # F_8 computer check (exact, exhaustive, 21 pairs)
    r_f8 = theorem3_f8_check()
    @test r_f8.violations == 0
    @test r_f8.pairs_checked == 42   # i ∈ {1,2} × 7 u values × 3 w values

    # m=6, i=1: APN, degree 4
    r = theorem3_check(; m = 6, i = 1)
    @test r.is_apn
    @test r.deg == 4

    # m=6, i=5
    r = theorem3_check(; m = 6, i = 5)
    @test r.is_apn
    @test r.deg == 4

    # argument validation
    @test_throws ArgumentError theorem3_lut(5, 1)   # 6 ∤ 5
    @test_throws ArgumentError theorem3_lut(6, 2)   # gcd(2,6) ≠ 1
end
