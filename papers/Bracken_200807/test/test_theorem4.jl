@testset "theorem4_test" begin
    include(joinpath(@__DIR__, "..", "theorem4.jl"))

    modulus = primitive_polynomial(6)
    k, s    = 3, 1
    n       = 2k
    subf    = gf_subfield_nonzero_elements(n, k; modulus)

    # GF(8) has 7 nonzero elements
    @test length(subf) == 7

    # Theorem 4: Tr(F(x)) is bent (v=1) for trinomial instance
    F = theorem1_sbox(k, s, [0, 0]; modulus)
    @test trace_component_is_bent(F, 1; modulus)

    # Extended claim: all v ∈ GF(8)* → Tr(v·F(x)) bent
    @test all(trace_component_is_bent(F, v; modulus) for v in subf)

    # Also holds for pentanomial
    F2 = theorem1_sbox(k, s, [1, 0]; modulus)
    @test trace_component_is_bent(F2, 1; modulus)
    @test all(trace_component_is_bent(F2, v; modulus) for v in subf)

    # Sanity: Tr maps to {0,1} for all field elements
    @test all(gf_absolute_trace(x, n; modulus) ∈ (0, 1) for x in 0:(1<<n)-1)
end
