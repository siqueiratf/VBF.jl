@testset "theorem3_3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3_3.jl"))

    m = 5
    n = 2m
    a = 2
    b = 2
    modulus = primitive_polynomial(n)

    # Parameter conditions must hold for m=5 (n=10)
    r_cond = verify_f15_conditions(m, a, b; modulus)
    @test r_cond.cond_m_odd
    @test r_cond.cond_gcd3m
    @test r_cond.cond_a_not_sf
    @test r_cond.cond_b_noncube
    @test r_cond.cond_ratio_sf
    @test r_cond.all_ok

    # F15 at n=10 is APN (full DDT)
    F = f15_sbox(m; a, b, modulus)
    @test differential_uniformity(F) == 2

    # Spot-check LUT: f(0) = 0
    @test F.lut[1] == 0

    # theorem3_3_apn_check agrees
    r_apn = theorem3_3_apn_check(m; a, b, streaming = false, io = devnull)
    @test r_apn.du == 2
    @test r_apn.is_apn

    # EA-mugshot of F15 is computable (not an error)
    μ = apn_ea_mugshot(F)
    @test μ.kind == :quadratic

    # Round-trip: LUT built from helpers vs zheng_lut directly agrees
    lut_direct = zheng_lut(m, 3, a, b, gf_pow(b, 3, n; modulus); modulus)
    @test F.lut == lut_direct
end
