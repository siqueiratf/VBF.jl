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

    # Prop 4 is existential in c ("there exists c ∈ F*_{2^m} with
    # d°(tr(cF)) ∉ {0,1,d°(F)}"), so the check scans every c rather than only
    # c = 1 — a failure at c = 1 alone would not refute the criterion.
    r = theorem1_check(; m = 5, i = 1)
    @test r.prop4_scan_c
    @test r.n_witnesses > 0
    @test r.n_witnesses <= (1 << 5) - 1

    # gcd(i,m) = s > 1 remark (tex, after the Theorem 2 proof): the proofs do not
    # use gcd(i,m) = 1; when m/s is odd F' keeps the Gold three-valued Walsh
    # spectrum {0, ±2^{(m+s)/2}} and differential uniformity 2^s.
    for i in (3, 6)                       # gcd(i,9) = 3, m/s = 3 odd
        g = theorem1_gcd_remark_check(; m = 9, i = i)
        @test g.s == 3
        @test g.ms_odd
        @test g.walsh_values == [0, 64]   # 2^{(9+3)/2} = 64
        @test g.three_valued
        @test g.du == 8                   # 2^s
        @test g.deg == 3
        @test g.deg_tr == 2
        @test g.prop4_ok
    end

    # the relaxed builder is opt-in only
    @test theorem1_lut(9, 3; require_coprime = false) isa Vector{Int}

    # argument validation
    @test_throws ArgumentError theorem1_lut(4, 1)   # m even
    @test_throws ArgumentError theorem1_lut(3, 1)   # m ≤ 3
    @test_throws ArgumentError theorem1_lut(5, 5)   # gcd(i,m) ≠ 1
    @test_throws ArgumentError theorem1_lut(9, 3)   # gcd(i,m) ≠ 1 (still strict by default)
    @test_throws ArgumentError theorem1_lut(9, 9; require_coprime = false)  # i ≥ m
    @test_throws ArgumentError theorem1_lut(9, 0; require_coprime = false)  # i = 0
end
