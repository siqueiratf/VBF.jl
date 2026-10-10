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

    # The r-coefficients are ω-powers, not `subfield_elements` indices: the latter
    # is sorted by integer value, so index 1 is the element 1 and never a power of ω.
    @test gf_pow(2, 9, n; modulus) == 24
    @test gf_pow(2, 18, n; modulus) == 15
    @test subfield_elements(n, k; modulus) == [0, 1, 14, 15, 22, 23, 24, 25]

    # Trinomial (r=[0,0]): b·x^3 + b^8·x^{24} + c·x^9
    F_tri = theorem1_sbox(k, s, [nothing, nothing]; modulus)
    @test differential_uniformity(F_tri) == 2

    # Quadrinomial (r=[ω^9, 0]): adds r1·x^{18}
    F_quad = theorem1_sbox(k, s, [9, nothing]; modulus)
    @test differential_uniformity(F_quad) == 2

    # Genuine pentanomial (r=[ω^9, ω^18], both nonzero): adds r1·x^{18}+r2·x^{36},
    # exercising the "up to k+2 nonzero coefficients" claim of Section 1.
    F_penta = theorem1_sbox(k, s, [9, 18]; modulus)
    @test differential_uniformity(F_penta) == 2
    @test F_penta != F_quad && F_quad != F_tri

    # Different (k,s): k=3, s=5
    F_s5 = theorem1_sbox(3, 5, [nothing, nothing]; modulus)
    @test differential_uniformity(F_s5) == 2

    # Larger instance: n=10 (k=5, s=1) trinomial — APN on GF(1024) (~0.2s)
    F_n10 = theorem1_sbox(5, 1, [nothing, nothing, nothing, nothing])
    @test differential_uniformity(F_n10) == 2

    # ── Hypothesis validation: every violation must raise, not silently return a
    #    non-APN function.
    @test_throws ArgumentError family1_lut(3, 1, 1, 4, [0, 0]; modulus)   # b=1 a cube
    @test_throws ArgumentError family1_lut(3, 1, 3, 4, [0, 0]; modulus)   # b=3 a cube
    @test_throws ArgumentError family1_lut(3, 1, 2, 1, [0, 0]; modulus)   # c=1 ∈ GF(8)
    @test_throws ArgumentError family1_lut(3, 1, 2, 0, [0, 0]; modulus)   # c=0 ∈ GF(8)
    @test_throws ArgumentError family1_lut(3, 1, 2, 4, [2, 0]; modulus)   # r₁ ∉ GF(8)
    @test_throws ArgumentError family1_lut(3, 1, 2, 4, [0, 0, 1]; modulus)  # |r| > k−1
    @test_throws ArgumentError family1_lut(2, 1, 2, 4, Int[])             # k even
    @test_throws ArgumentError family1_lut(3, 2, 2, 4, [0, 0]; modulus)   # s even
    @test_throws ArgumentError family1_lut(3, 3, 2, 4, [0, 0]; modulus)   # gcd(k,s)≠1
    @test_throws ArgumentError theorem1_sbox(3, 1, [1, nothing]; modulus) # r₁=ω ∉ GF(8)

    # ── The hypotheses are necessary, not decorative: `validate=false` builds the
    #    rejected instances and every one of them fails to be APN.
    for (bb, cc, rr, _) in THEOREM1_VIOLATIONS
        du = differential_uniformity(
            SBox(family1_lut(k, s, bb, cc, rr; modulus, validate = false)))
        @test du != 2
    end

    # ── Parameter-space coverage (Br-4): the sweep reports the true fraction.
    bs, cs, rs = theorem1_valid_parameters_n6(; modulus)
    @test length(bs) == 42          # non-cubes of GF(64)*
    @test length(cs) == 56          # elements outside GF(8)
    @test length(rs) == 8           # GF(8), including 0
    tested, total, all_apn = theorem1_sweep_n6(; sample = 200)
    @test total == 42 * 56 * 64 == 150_528
    @test tested == 200
    @test all_apn

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
