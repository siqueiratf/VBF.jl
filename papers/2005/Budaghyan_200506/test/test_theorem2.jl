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

    # Prop 4 scanned over every c ∈ F*_{2^m}, not just c = 1
    r = theorem2_check(; m = 6, i = 1)
    @test r.prop4_scan_c
    @test r.n_witnesses > 0

    # gcd(i,m) = s > 1 remark, even-m half: m/s odd ⇒ three-valued Walsh
    # spectrum {0, ±2^{(m+s)/2}} and differential uniformity 2^s.
    g = theorem2_gcd_remark_check(; m = 6, i = 2)      # s=2, m/s=3 odd
    @test g.s == 2
    @test g.ms_odd
    @test g.walsh_values == [0, 16]                    # 2^{(6+2)/2} = 16
    @test g.three_valued
    @test g.du == 4                                    # 2^s
    @test g.deg == 3
    @test g.deg_tr == 2
    @test g.prop4_ok

    g = theorem2_gcd_remark_check(; m = 10, i = 2)     # s=2, m/s=5 odd
    @test g.ms_odd
    @test g.walsh_values == [0, 64]                    # 2^{(10+2)/2} = 64
    @test g.three_valued
    @test g.du == 4

    # negative control: m/s even ⇒ the remark does not apply and the spectrum is
    # NOT three-valued (F' even degenerates to degree 2 there).
    g = theorem2_gcd_remark_check(; m = 6, i = 3)      # s=3, m/s=2 even
    @test !g.ms_odd
    @test !g.three_valued
    @test length(g.walsh_values) > 2

    # the relaxed builder is opt-in only
    @test theorem2_lut(6, 2; require_coprime = false) isa Vector{Int}

    # argument validation
    @test_throws ArgumentError theorem2_lut(3, 1)   # m < 4
    @test_throws ArgumentError theorem2_lut(5, 1)   # m odd
    @test_throws ArgumentError theorem2_lut(6, 2)   # gcd(2,6) = 2 ≠ 1 (strict by default)
    @test_throws ArgumentError theorem2_lut(6, 6; require_coprime = false)  # i ≥ m
end
