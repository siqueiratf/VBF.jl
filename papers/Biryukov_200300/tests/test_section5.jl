@testset "section5_cipher_applications" begin
    include(joinpath(@__DIR__, "..", "section5.jl"))

    sp = load_serpent_sboxes()

    # Three affine-equivalent pairs (Table 3 left).
    @test are_affine_equivalent(sp.S2, sp.S6)
    @test are_affine_equivalent(sp.S3, sp.S7)
    @test are_affine_equivalent(sp.S4, sp.S5)

    # Inverse-equivalent pair.
    S1_inv = _serpent_inverse(sp.S1)
    @test are_affine_equivalent(sp.S0, S1_inv)

    # S0 and S1 are NOT directly affine equivalent.
    @test !are_affine_equivalent(sp.S0, sp.S1)

    # Cross-pair: S2 and S3 are not equivalent.
    @test !are_affine_equivalent(sp.S2, sp.S3)

    # Full report passes.
    @test section5_report(devnull)
end
