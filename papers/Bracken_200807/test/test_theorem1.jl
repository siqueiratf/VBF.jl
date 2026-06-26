@testset "theorem1_test" begin
    include(joinpath(@__DIR__, "..", "theorem1.jl"))

    modulus = primitive_polynomial(6)
    n, k, s = 6, 3, 1

    b = 2
    c = gf_pow(2, 2, n; modulus)   # ω^2

    # b not a cube in GF(64): b^{(64−1)/3} = b^{21} ≠ 1
    @test !gf_is_dth_power(b, 3, n; modulus)

    # c not in GF(8): c^{2^3} ≠ c (i.e., ω^2 has order 63 which does not divide 7)
    @test !in_subfield(c, k, n; modulus)

    # Trinomial (r=[0,0]): b·x^3 + b^8·x^{24} + c·x^9
    F_tri = theorem1_sbox(k, s, [0, 0]; modulus)
    @test differential_uniformity(F_tri) == 2

    # Pentanomial (r=[ω^9, 0]): adds r1·x^{18} term
    F_penta = theorem1_sbox(k, s, [1, 0]; modulus)
    @test differential_uniformity(F_penta) == 2

    # Full pentanomial (r=[ω^9, 1]): adds r1·x^{18}+r2·x^{36}
    F_full = theorem1_sbox(k, s, [1, 1]; modulus)  # r2=1 ∈ GF(8)*
    @test differential_uniformity(F_full) == 2

    # Different (k,s): k=3, s=5
    F_s5 = theorem1_sbox(3, 5, [0, 0]; modulus)
    @test differential_uniformity(F_s5) == 2

    # Round-trip: trinomial LUT == manually built LUT
    b2k  = gf_pow(b, 1 << k, n; modulus)
    e1, e2, e3 = 3, 24, 9   # 2^1+1, 2^4+2^3, 2^3+1
    lut_ref = [
        gf_mul(b,   gf_pow(x, e1, n; modulus), n; modulus) ⊻
        gf_mul(b2k, gf_pow(x, e2, n; modulus), n; modulus) ⊻
        gf_mul(c,   gf_pow(x, e3, n; modulus), n; modulus)
        for x in 0:63
    ]
    @test SBox(lut_ref) == F_tri
end
