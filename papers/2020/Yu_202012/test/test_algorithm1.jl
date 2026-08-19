@testset "algorithm1_test" begin
    include(joinpath(@__DIR__, "..", "algorithm1.jl"))
    include(joinpath(@__DIR__, "..", "table2.jl"))

    # ── n=6: exhaustive search must find exactly 1 EA-class (x³) ──────────────
    outcome6 = algorithm1_run(6; max_evaluations = 1 << 24)
    # The sweep must have actually finished for the count to test the paper's
    # figure rather than the budget.
    @test is_exhausted(outcome6)
    classes6 = search_solutions(outcome6)
    @test length(classes6) == 1
    @test differential_uniformity(classes6[1]) == 2
    @test apn_ea_mugshot(classes6[1]) == apn_ea_mugshot(sbox_from_exponents(6, [3]))

    # NOTE: the old round-trip assertion here —
    #   @test has_f2_cyclic_structure(quadratic_apn_matrix(classes6[1]), 6)
    # — was a TAUTOLOGY: classes6[1] is qam_to_sbox(M) for a matrix M that
    # qam_from_cyclic built with that very structure, and quadratic_apn_matrix is the
    # inverse of qam_to_sbox. It could not fail. Removed; theorem2.jl now asserts the
    # substantive (and failing!) direction instead.

    # ── n=7: THE CLASSIFICATION TEST ──────────────────────────────────────────
    # This exhaustive sweep (~16 s) used to be run and then thrown away with no
    # assertion at all. It is the one place the paper's classification can actually be
    # tested, so it is tested here.
    outcome7 = algorithm1_run(7; max_evaluations = 1 << 24)
    @test is_exhausted(outcome7)
    classes7 = search_solutions(outcome7)

    # 14, not 15: search_qam de-duplicates by apn_ea_mugshot, which merges the
    # CCZ-inequivalent Gold pair x³/x⁹. This length is a LOWER BOUND on the CCZ count.
    @test length(classes7) == 14

    @test all(differential_uniformity(F) == 2 for F in classes7)
    @test all(algebraic_degree(F) == 2 for F in classes7)
    @test all(is_almost_bent(F) for F in classes7)          # every n=7 class is AB

    # The real content: the exhaustively-found σ-classes are EXACTLY the σ-classes of the
    # 15 Table-2 representatives (15 reps → 14 σ, the Gold pair x³/x⁹ sharing one).
    # This is what independently VALIDATES THE RECOVERED 15th ROW: if x³+x⁵+x⁹+x⁴⁰+x⁹⁶
    # were the wrong function, or if a class were missing, these two sets would differ.
    found_sigmas = Set(sigma_hash(F) for F in classes7)
    table2_sigmas = Set(sigma_hash(sbox_from_exponents(7, exps))
                        for (exps, _) in TABLE2_FUNCTIONS)
    @test length(found_sigmas) == 14
    @test length(table2_sigmas) == 14
    @test found_sigmas == table2_sigmas

    # Mutation guard — the equality above MUST be able to fail. Drop the recovered
    # representative and the σ-set shrinks to 13, which is no longer what the search
    # found. (If this test passed with the recovered row omitted, the assertion above
    # would be worthless.)
    sigmas_without_recovered = Set(sigma_hash(sbox_from_exponents(7, exps))
                                   for (exps, _) in TABLE2_FUNCTIONS[1:14])
    @test length(sigmas_without_recovered) == 13
    @test found_sigmas != sigmas_without_recovered
    @test setdiff(found_sigmas, sigmas_without_recovered) ==
          Set([sigma_hash(sbox_from_exponents(7, [3, 5, 9, 40, 96]))])
end
