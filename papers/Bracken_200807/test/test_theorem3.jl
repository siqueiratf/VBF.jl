@testset "theorem3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3.jl"))

    modulus = primitive_polynomial(6)
    k, s    = 2, 1

    # Lemma 2 checks for k=2, n=6
    n   = 6
    u   = 2
    subf = gf_subfield_nonzero_elements(n, k; modulus)   # GF(4)* in GF(64)

    # (i) all GF(4)* elements are 7th powers in GF(4) [7 ∤ (2^2−1)=3]
    @test all(gf_is_seventh_power(θ, n; modulus) for θ in subf)

    # (ii) u=2 (primitive in GF(64)) is NOT a 7th power [7 | 63]
    @test !gf_is_seventh_power(u, n; modulus)

    # (iii) u^{2^k−1} = u^3 is NOT a 7th power
    @test !gf_is_seventh_power(gf_pow(u, (1 << k) - 1, n; modulus), n; modulus)

    # (iv) u^{2^t−1} IS a 7th power when 3∣t (check t=3)
    @test gf_is_seventh_power(gf_pow(u, (1 << 3) - 1, n; modulus), n; modulus)

    # Theorem 3: Family 2 APN checks (n=6)
    # v=0 → binomial
    F_bin = theorem3_sbox(k, s, 0)
    @test differential_uniformity(F_bin) == 2

    # v=ω^{21} → trinomial
    F_tri = theorem3_sbox(k, s, 1)
    @test differential_uniformity(F_tri) == 2

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
