@testset "example4_2_test" begin
    include(joinpath(@__DIR__, "..", "example4_2.jl"))

    n = 8; mod = PAPER_MODULUS_8; N = 1 << n
    β = alpha_power(85, n, mod)
    β2 = gf_mul(β, β, n; modulus=mod)

    # β is in GF(4)\GF(2)
    @test (β2 ⊻ β ⊻ 1) == 0

    # Build G via cosets
    F_lut = [gf_pow(x, 3, n; modulus=mod) for x in 0:N-1]
    α85 = alpha_power(85, n, mod)
    coset_values = [0, 1, β, β2]
    a = [0, 0, gf_mul(α85, β, n; modulus=mod), gf_mul(α85, β2, n; modulus=mod)]

    G_lut = Vector{Int}(undef, N)
    for x in 0:N-1
        tr = gf_relative_trace(x, n, 2; modulus=mod)
        idx = findfirst(==(tr), coset_values)
        G_lut[x+1] = F_lut[x+1] ⊻ a[idx]
    end

    G = SBox(G_lut)
    @test differential_uniformity(G) == 2
    @test algebraic_degree(G) == 2

    # Simplified form
    G_simple = Vector{Int}(undef, N)
    for x in 0:N-1
        tr1 = gf_trace(x, n; modulus=mod)
        tr2 = gf_relative_trace(x, n, 2; modulus=mod)
        G_simple[x+1] = F_lut[x+1] ⊻ gf_mul(gf_mul(α85, tr1, n; modulus=mod), tr2, n; modulus=mod)
    end
    @test G_lut == G_simple

    # EA-inequivalent to Gold
    @test apn_ea_mugshot(G) != apn_ea_mugshot(SBox(F_lut))
end
