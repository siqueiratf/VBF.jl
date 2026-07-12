@testset "table2_test" begin
    include(joinpath(@__DIR__, "..", "table2.jl"))
    result = table2_verify()
    for (desc, ok) in result.checks
        @test ok
    end

    # The old assertion here was `@test result.n_verified == 14`, where n_verified was
    # `length(TABLE2_FUNCTIONS)` — a transcribed literal compared against itself. It
    # could not fail. Replaced with claims about the mathematics, all of which can:

    # 15 representatives, 14 σ-classes, 15 CCZ classes (the Gold x³/x⁹ split restores
    # the one σ cannot see). The paper says 15 and the paper is right.
    @test result.n_representatives == 15
    @test result.n_sigma_classes == 14
    @test result.gold_split_settled === true
    @test result.n_ccz_classes == 15

    # The recovered 15th representative really is APN, quadratic, AB — and really is a
    # class of its own (σ-distinct from all 14 printed rows).
    rec = sbox_from_exponents(7, [3, 5, 9, 40, 96])
    @test differential_uniformity(rec) == 2
    @test algebraic_degree(rec) == 2
    @test is_almost_bent(rec)
    printed = Set(sigma_hash(sbox_from_exponents(7, exps))
                  for (exps, _) in TABLE2_FUNCTIONS[1:14])
    @test !(sigma_hash(rec) in printed)

    # The paper erratum (P1) itself: rows 4 and 10 of the published table ARE the same
    # polynomial. We assert the fact that makes it an erratum — that a 15th class exists
    # and is absent from the printed rows — rather than restating the transcription.
    @test length(printed) == 13   # 14 printed rows, but x³ and x⁹ share a σ
end
