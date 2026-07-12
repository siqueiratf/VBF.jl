@testset "observation1_test" begin
    include(joinpath(@__DIR__, "..", "observation1.jl"))

    C3 = build_c3_apn()
    C7 = build_c7_apn()

    # Observation 1: both quadrinomials are APN over GF(2^10)
    @test differential_uniformity(C3) == 2
    @test differential_uniformity(C7) == 2

    # Both are quadratic
    @test algebraic_degree(C3) == 2
    @test algebraic_degree(C7) == 2

    # Round-trip: C_3 and C_7 are built from build_ci_sbox with correct exponents
    @test C3 == build_ci_sbox(10, 3, 2)
    @test C7 == build_ci_sbox(10, 7, 0)

    # ...and those exponents are the paper's, rebuilt straight from tex:172:
    #   C_3(x) = x^3 + β·x^36  + β²·x^96 + x^129
    #   C_7(x) = x^3 + β·x^129 + β²·x^96 + x^36
    mod10 = primitive_polynomial(10)
    β, β² = beta_in_gfn(10)
    @test ci_exponents(10, 3, 2) == (36, 96, 129)
    @test ci_exponents(10, 7, 0) == (129, 96, 36)
    @test C3 == SBox{10}(terms_to_lut([(1, 3), (β, 36), (β², 96), (1, 129)], 10, mod10))
    @test C7 == SBox{10}(terms_to_lut([(1, 3), (β, 129), (β², 96), (1, 36)], 10, mod10))

    # β is the order-3 element of GF(4) ⊂ GF(2^10), i.e. α^341 under 0x409
    @test gf_pow(β, 3, 10; modulus = mod10) == 1
    @test β != 1
    @test gf_mul(β, β, 10; modulus = mod10) == β²

    # ci_exponents must not wrap in Int64: at n=46, i=n-1 gives i+m = 68 > 63, so
    # 2^(i+m) overflows a hand-rolled Int64 computation (the old build_ci_sbox did
    # exactly that). Int128 arithmetic keeps every exponent inside [1, 2^n - 1].
    for (n, i, k) in ((46, 45, 0), (46, 45, 3), (46, 23, 1), (62, 61, 5))
        e2, e3, e4 = ci_exponents(n, i, k)
        q = (Int128(1) << n) - 1
        @test all(1 ≤ e ≤ q for e in (e2, e3, e4))
    end
    # Concretely: n=46, i=45 ⇒ i+m = 68. The correct value of (2^68 + 2^23) mod (2^46-1)
    # is computed in Int128; in Int64, 2^68 wraps to 0.
    let n = 46, m = 23, q = (Int128(1) << n) - 1
        @test ci_exponents(n, 45, 0)[3] ==
              Int(mod((Int128(1) << 68) + (Int128(1) << m), q))
        @test (2^68 + 2^23) % (2^46 - 1) != ci_exponents(n, 45, 0)[3]  # the old, wrapped value
    end

    # EA-mugshots differ → not EA-equivalent
    @test apn_ea_mugshot(C3) != apn_ea_mugshot(C7)

    # F(0) = 0 for both (as expected from the univariate form)
    @test C3.lut[1] == 0
    @test C7.lut[1] == 0
end
