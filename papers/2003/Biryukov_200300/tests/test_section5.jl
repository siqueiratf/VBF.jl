@testset "section5_cipher_applications" begin
    include(joinpath(@__DIR__, "..", "section5.jl"))

    sp = load_serpent_sboxes()

    # Three affine-equivalent pairs (Table 3 left).
    @test are_affine_equivalent(sp.S2, sp.S6)
    @test are_affine_equivalent(sp.S3, sp.S7)
    @test are_affine_equivalent(sp.S4, sp.S5)

    # Inverse-equivalent pair.
    S1_inv = compositional_inverse(sp.S1)
    @test are_affine_equivalent(sp.S0, S1_inv)

    # S0 and S1 are NOT directly affine equivalent.
    @test !are_affine_equivalent(sp.S0, sp.S1)

    # Cross-pair: S2 and S3 are not equivalent.
    @test !are_affine_equivalent(sp.S2, sp.S3)

    # Table 3 (left) self-equivalence counts s: S0,S1,S2,S6 have s=4; S3,S4,S5,S7 have s=1.
    s_counts = Dict(
        :S0 => length(self_affine_equivalences(sp.S0)),
        :S1 => length(self_affine_equivalences(sp.S1)),
        :S2 => length(self_affine_equivalences(sp.S2)),
        :S3 => length(self_affine_equivalences(sp.S3)),
        :S4 => length(self_affine_equivalences(sp.S4)),
        :S5 => length(self_affine_equivalences(sp.S5)),
        :S6 => length(self_affine_equivalences(sp.S6)),
        :S7 => length(self_affine_equivalences(sp.S7)),
    )
    @test s_counts[:S0] == 4
    @test s_counts[:S1] == 4
    @test s_counts[:S2] == 4
    @test s_counts[:S6] == 4
    @test s_counts[:S3] == 1
    @test s_counts[:S4] == 1
    @test s_counts[:S5] == 1
    @test s_counts[:S7] == 1

    # Full report passes.
    @test section5_report(devnull)
end
