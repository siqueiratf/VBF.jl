@testset "section5_test" begin
    include(joinpath(@__DIR__, "..", "section5.jl"))
    include(joinpath(@__DIR__, "..", "section4.jl"))   # new_apn_function_n7, σ-classification

    row1 = first_row_n7()
    cases = second_row_cases_n7()

    # ── §5's opening claim, COMPUTED, not assumed ───────────────────────────
    # "the first row of ℱ can be taken equal to (0 1 2 4 8 16 32) up to
    # EA-equivalence". Build the linear map that does it and check the result is
    # still a QAM of the same function's EA-class, on real n=7 quadratic APNs.
    for F in (gold_apn(7, 1), gold_apn(7, 2), gold_apn(7, 3), new_apn_function_n7())
        M = quadratic_apn_matrix(F)
        Mn = normalize_first_row(M)
        Fn = qam_to_sbox(Mn)
        @test Mn[1, :] == row1                    # first row IS the standard basis
        @test Mn == permutedims(Mn)               # still symmetric
        @test all(Mn[i, i] == 0 for i = 1:7)      # still zero-diagonal
        @test is_qam(Mn)                          # still an APN function's matrix
        @test Mn[2, 1] == 1                       # forces every case's row2[1] = 1
        @test differential_uniformity(Fn) == 2
        # the normalised matrix is a genuine EA-transform: same CCZ-class as F
        # (σ is a CCZ-invariant, so a mismatch here would prove L broke the class)
        @test sigma_hash(SBox{7}(Int.(Fn.lut))) == sigma_hash(F)
        @test row_offdiag_independent(Mn[1, :], 1)
        @test row_offdiag_independent(Mn[2, :], 2)
    end
    # …and settle one of them with the exact EA decision, not just the invariant
    @test are_ea_equivalent_quadratic(
        SBox{7}(Int.(qam_to_sbox(normalize_first_row(quadratic_apn_matrix(gold_apn(7, 1)))).lut)),
        gold_apn(7, 1),
    )
    # normalize_first_row must reject a degenerate first row rather than "work"
    @test_throws ArgumentError normalize_first_row(zeros(Int, 7, 7))

    # ── The five second-row cases ───────────────────────────────────────────
    @test row1 == [0, 1, 2, 4, 8, 16, 32]
    @test length(cases) == 5
    @test length(unique(first.(cases))) == 5      # pairwise distinct

    for (row2, _) in cases
        # Every case must satisfy the necessary conditions Proposition 1 and
        # Theorem 1 impose on the first two rows of a QAM. These are real
        # constraints: a mangled row is rejected below.
        @test first_two_rows_compatible(row1, row2)
        @test row2[1] == row1[2]                              # symmetry, M[2,1] = 1
        @test row2[2] == 0                                    # zero diagonal
        @test all(row2[j] != 0 for j in eachindex(row2) if j != 2)   # Theorem 1
        @test row_offdiag_independent(row2, 2)                # Proposition 1, x = e_2
        @test row_offdiag_independent(row1, 1)                # Proposition 1, x = e_1
        @test all(0 <= v < 128 for v in row2)                 # entries live in F_2^7
    end

    # MUTATION TEST — the checks above are not tautologies. Perturbing a single
    # entry of a real case into an F_2-dependent one must be REJECTED.
    let bad = [1, 0, 4, 6, 16, 32, 20]      # 20 = 16 ⊕ 4 ⇒ {4,16,20} dependent
        @test !row_offdiag_independent(bad, 2)
        @test !first_two_rows_compatible(row1, bad)
    end
    let bad = [1, 0, 4, 6, 16, 32, 0]       # zero off-diagonal ⇒ Theorem 1 fails
        @test !first_two_rows_compatible(row1, bad)
    end
    let bad = [2, 0, 4, 6, 16, 32, 64]      # M[2,1] = 2 ≠ M[1,2] = 1 ⇒ asymmetric
        @test !first_two_rows_compatible(row1, bad)
    end
    let bad = [1, 3, 4, 6, 16, 32, 64]      # nonzero diagonal
        @test !first_two_rows_compatible(row1, bad)
    end
    # a first row that is F_2-dependent must also be rejected
    @test !first_two_rows_compatible([0, 1, 2, 3, 8, 16, 32], first(cases[1]))

    # Case 1's second row is exactly the cyclic-T shape (0,e1,…) shifted by one —
    # consistent with §4's T, whose second row is (e1, 0, e3, e4, e5, e6, e7).
    @test first(cases[1]) == [1, 0, 4, 8, 16, 32, 64]

    # ── Counts: TRANSCRIBED from §5, not recomputed ─────────────────────────
    # The P1/P2 lexicographic minimisation that produced these ran on a
    # supercomputer. We check the arithmetic and the corpus size only.
    counts = [c for (_, c) in cases]
    @test counts == [3, 2, 0, 220, 263]
    @test sum(counts) == 488

    # …and the paper's 488 is corroborated INDEPENDENTLY: the n=7 corpus holds at
    # least that many quadratic APN representatives (≥, not ==, since the catalog
    # gains named reps of already-known classes over time — the σ-class count is
    # the paper's invariant, the corpus row count is not).
    @test n7_sigma_classification(new_apn_function_n7()).total >= 488

    # Gold n=7 is one of them (sanity)
    g7 = gold_apn(7)
    @test differential_uniformity(g7) == 2
    @test algebraic_degree(g7) == 2
end
