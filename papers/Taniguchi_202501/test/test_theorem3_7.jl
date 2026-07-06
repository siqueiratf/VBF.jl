@testset "theorem3_7_test" begin
    include(joinpath(@__DIR__, "..", "theorem3_7.jl"))

    entries = table3_1_coefficients(6, PAPER_MODULUS_6)

    # Eq.(3.1) must hold for all 13 Table 3.1 entries
    for entry in entries
        r = theorem3_7_check(entry.coeffs, 6, PAPER_MODULUS_6)
        @test r.holds
    end

    # Negative test: random non-APN L should fail
    # L(x) = x (identity) with G(x) = x^3 + Tr(x)·x
    L_id = [1, 0, 0, 0, 0, 0]
    r = theorem3_7_check(L_id, 6, PAPER_MODULUS_6)
    G_lut = build_g_lut([gf_pow(x, 3, 6; modulus=PAPER_MODULUS_6) for x in 0:63],
                        L_id, 6, PAPER_MODULUS_6)
    du = differential_uniformity(SBox(G_lut))
    # If not APN, Eq.(3.1) should fail; if APN, it should hold
    @test r.holds == (du == 2)
end
