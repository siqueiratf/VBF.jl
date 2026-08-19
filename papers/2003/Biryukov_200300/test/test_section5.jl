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

    # Remaining Table 3 memberships: the inverse row, the self-inverse rows and
    # the inverted S4/S5 row.
    @test are_affine_equivalent(compositional_inverse(sp.S0), sp.S1)
    @test are_affine_equivalent(sp.S2, compositional_inverse(sp.S2))
    @test are_affine_equivalent(sp.S6, compositional_inverse(sp.S6))
    @test are_affine_equivalent(sp.S3, compositional_inverse(sp.S3))
    @test are_affine_equivalent(sp.S7, compositional_inverse(sp.S7))
    @test are_affine_equivalent(compositional_inverse(sp.S4), compositional_inverse(sp.S5))

    # The {S4,S5} and {S4^{-1},S5^{-1}} rows are genuinely different classes.
    @test !are_affine_equivalent(sp.S4, compositional_inverse(sp.S4))

    # Khazad row: P and Q are involutions, so {P,P^{-1},Q,Q^{-1}} is one class.
    kz = khazad_sboxes()
    @test is_permutation(kz.P) && is_permutation(kz.Q)
    @test compositional_inverse(kz.P) == kz.P
    @test compositional_inverse(kz.Q) == kz.Q
    @test are_affine_equivalent(kz.P, kz.Q)
    @test length(self_affine_equivalences(kz.P)) == 4
    @test length(self_affine_equivalences(kz.Q)) == 4
    @test !are_affine_equivalent(kz.P, sp.S0)
    @test !are_affine_equivalent(kz.P, sp.S2)

    # Every Table 3 row: members share one affine class and one value of s.
    for (cipher, label, members, s_paper) in table3_rows()
        head = first(members).second
        @test all(are_affine_equivalent(head, m.second) for m in members)
        @test all(length(self_affine_equivalences(m.second)) == s_paper for m in members)
    end

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
