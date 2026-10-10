@testset "theorem4_test" begin
    include(joinpath(@__DIR__, "..", "theorem4.jl"))

    modulus = primitive_polynomial(6)
    k, s    = 3, 1
    n       = 2k
    subf    = filter(!iszero, subfield_elements(n, k; modulus))
    c       = gf_pow(2, 2, n; modulus)

    # GF(8) has 7 nonzero elements
    @test length(subf) == 7

    # Theorem 4: Tr(F(x)) is bent (v=1) for trinomial instance
    F = theorem1_sbox(k, s, [nothing, nothing]; modulus)
    @test trace_component_is_bent(F, 1; modulus)

    # Extended claim: all v ∈ GF(8)* → Tr(v·F(x)) bent
    @test all(trace_component_is_bent(F, v; modulus) for v in subf)

    # Also holds for the quadrinomial and the genuine pentanomial
    for r_exp in ([9, nothing], [9, 18])
        F2 = theorem1_sbox(k, s, r_exp; modulus)
        @test trace_component_is_bent(F2, 1; modulus)
        @test all(trace_component_is_bent(F2, v; modulus) for v in subf)
    end

    # ── Theorem 4 is strictly weaker than Theorem 1 (Br-5): it puts no condition
    #    on b. `theorem1_sbox` hard-codes the non-cube b=ω and so cannot express
    #    this; `theorem4_sbox` can. For b a cube the function is still bent but is
    #    no longer APN, which is exactly what separates the two hypothesis sets.
    for b in (1, 3, 8)
        @test gf_is_dth_power(b, 3, n; modulus)                  # b really is a cube
        @test_throws ArgumentError family1_lut(k, s, b, c, [0, 0]; modulus)
        Fb = theorem4_sbox(k, s, b, c, [0, 0]; modulus)
        @test all(trace_component_is_bent(Fb, v; modulus) for v in subf)
        @test differential_uniformity(Fb) != 2
    end

    # Theorem 4's own hypotheses are still enforced.
    @test_throws ArgumentError theorem4_sbox(k, s, 1, 1, [0, 0]; modulus)   # c ∈ GF(8)
    @test_throws ArgumentError theorem4_sbox(k, s, 1, c, [2, 0]; modulus)   # r₁ ∉ GF(8)
    @test_throws ArgumentError theorem4_sbox(k, s, 1, c, [0, 0, 0]; modulus)  # |r| > k−1

    # With a non-cube b, theorem4_sbox reproduces the Theorem 1 function exactly.
    @test theorem4_sbox(k, s, 2, c, [0, 0]; modulus) == F

    # Sanity: Tr maps to {0,1} for all field elements
    @test all(gf_trace(x, n; modulus) ∈ (0, 1) for x in 0:(1<<n)-1)
end
