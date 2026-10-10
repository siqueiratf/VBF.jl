@testset "theorem3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3.jl"))

    modulus = primitive_polynomial(6)
    k, s    = 2, 1

    # Lemma 2 checks for k=2, n=6
    n   = 6
    u   = 2
    sub = subfield_elements(n, k; modulus)                     # GF(4) ⊂ GF(64)
    @test sub == [0, 1, 58, 59]

    # (i) Every θ ∈ GF(4) is a 7th power *of an element of GF(4)*: 3∤k=2 so
    #     7∤(2^k−1)=3 and x ↦ x^7 permutes GF(4). This must be evaluated inside
    #     GF(2^k); `gf_is_dth_power(θ, 7, n)` answers a different question (7th
    #     powers in GF(2^{3k})), which is also true but is not Lemma 2(i).
    @test Set(gf_pow(θ, 7, n; modulus) for θ in sub) == Set(sub)

    # (ii) u=2 (primitive in GF(64)) is NOT a 7th power [7 | 63]
    @test is_primitive_element(u, n; modulus)
    @test !gf_is_dth_power(u, 7, n; modulus)

    # (iii) u^{2^k−1} = u^3 is NOT a 7th power
    @test !gf_is_dth_power(gf_pow(u, (1 << k) - 1, n; modulus), 7, n; modulus)

    # (iv) u^{2^t−1} IS a 7th power when 3∣t (check t=3)
    @test gf_is_dth_power(gf_pow(u, (1 << 3) - 1, n; modulus), 7, n; modulus)

    # `v` is an ω-power, not a `subfield_elements` index (which would always be 1).
    @test gf_pow(2, 21, n; modulus) == 59
    @test gf_pow(2, 273, 12; modulus = primitive_polynomial(12)) == 1971

    # Theorem 3: Family 2 APN checks (n=6)
    # v=0 → binomial
    F_bin = theorem3_sbox(k, s, nothing)
    @test differential_uniformity(F_bin) == 2

    # v=ω^{21}=59 → trinomial
    F_tri = theorem3_sbox(k, s, 21)
    @test differential_uniformity(F_tri) == 2
    @test F_tri != F_bin

    # Larger instance: n=12 (k=4, s=5) on GF(4096) — APN (~0.1s)
    @test differential_uniformity(theorem3_sbox(4, 5, nothing)) == 2   # binomial (v=0)
    @test differential_uniformity(theorem3_sbox(4, 5, 273)) == 2       # trinomial (v≠0)

    # ── Hypothesis validation: every violation must raise.
    @test_throws ArgumentError family2_lut(2, 5, 2, 1)      # k+s=7 ≢ 0 mod 3
    @test_throws ArgumentError family2_lut(2, 1, 1, 1)      # u=1 not primitive
    @test_throws ArgumentError family2_lut(2, 1, 6, 1)      # u=6 not primitive
    @test_throws ArgumentError family2_lut(2, 1, 2, 4)      # v=4 ∉ GF(4)
    @test_throws ArgumentError family2_lut(2, 1, 2, 7)      # v=7 ∉ GF(4)
    @test_throws ArgumentError family2_lut(3, 1, 2, 1)      # k ≡ 0 mod 3
    @test_throws ArgumentError family2_lut(2, 2, 2, 1)      # gcd(s,3k)=2 ≠ 1
    @test_throws ArgumentError theorem3_sbox(2, 1, 1)       # v=ω ∉ GF(4)

    # ── The hypotheses are necessary: each rejected tuple fails to be APN.
    for (kk, ss, uu, vv, _) in THEOREM3_VIOLATIONS
        m  = primitive_polynomial(3kk)
        du = differential_uniformity(
            SBox(family2_lut(kk, ss, uu, vv; modulus = m, validate = false)))
        @test du != 2
    end

    # ...but `u` primitive is sufficient, not necessary, at n=6: 72 of the 108
    # non-primitive (u,v) pairs are still APN (exactly ord(u) ∈ {7, 21}).
    @test theorem3_nonprimitive_n6(; modulus) == (72, 108)

    # ── Parameter-space coverage (Br-4): all 144 valid (u,v) pairs at n=6.
    tested, total, all_apn = theorem3_sweep_n6(; modulus)
    @test (tested, total) == (144, 144)      # 36 primitive u × 4 v ∈ GF(4)
    @test all_apn

    # Round-trip: v=0 LUT matches manually built binomial
    n6 = 3k
    u2k = gf_pow(u, 1 << k, n6; modulus)
    e1  = (1 << (n6 - k)) + (1 << (k + s))   # 2^4+2^3 = 24
    e2  = (1 << s) + 1                         # 2^1+1  = 3
    lut_ref = [
        gf_mul(u,   gf_pow(x, e1, n6; modulus), n6; modulus) ⊻
        gf_mul(u2k, gf_pow(x, e2, n6; modulus), n6; modulus)
        for x in 0:(1 << n6) - 1
    ]
    @test SBox(lut_ref) == F_bin
end
