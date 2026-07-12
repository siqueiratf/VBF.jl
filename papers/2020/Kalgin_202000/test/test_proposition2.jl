@testset "proposition2_test" begin
    include(joinpath(@__DIR__, "..", "proposition2.jl"))
    include(joinpath(@__DIR__, "..", "section4.jl"))   # kalgin_T (cross-check below)

    # Rebuild a quadratic function's symmetric matrix from the paper's ANF: entry
    # (i,j) has bit k-1 set iff the term x_i·x_j occurs in coordinate g_k. The
    # source files store these matrices as integers; transcribing the ANF here
    # independently means a typo in either encoding is caught (a single corrupted
    # entry can easily leave Δ unchanged, so Δ-checks alone do NOT pin the data).
    function anf_matrix(n::Int, coords)
        M = zeros(Int, n, n)
        for (k, terms) in enumerate(coords), (i, j) in terms
            M[i, j] ⊻= 1 << (k - 1)
            M[j, i] = M[i, j]
        end
        M
    end

    # ── R7: the paper pins GF(2^7) = F_2[x]/(x^7 + x + 1) ────────────────────
    @test primitive_polynomial(7) == 0b10000011      # = 131 = x^7 + x + 1
    @test PAPER_MODULUS_N7 == 131

    # ── Theorem 1 (Beth–Ding): no zero off-diagonal entry in an APN matrix ───
    for n = 3:7
        @test beth_ding_all_terms_present(quadratic_apn_matrix(gold_apn(n)))
    end
    # …and the condition has teeth: killing one term destroys the APN property.
    # (If it did not, Theorem 1 would be a statement about nothing.)
    M5 = quadratic_apn_matrix(gold_apn(5))
    for i = 1:5, j = (i+1):5
        Z = copy(M5)
        Z[i, j] = Z[j, i] = 0
        @test !beth_ding_all_terms_present(Z)
        @test !proposition1_apn(Z)
        @test !is_qam(Z)
    end

    # ── Proposition 1, implemented as stated, vs is_qam and vs the DDT ───────
    for n = 3:7, k = 1:3
        gcd(k, n) == 1 || continue
        M = quadratic_apn_matrix(gold_apn(n, k))
        @test proposition1_apn(M)
        @test proposition1_apn(M) == is_qam(M)
        @test differential_uniformity(qam_to_sbox(M)) == 2
    end

    # Random symmetric zero-diagonal matrices: Proposition 1 must agree with
    # is_qam on every one of them, and the sample must contain BOTH outcomes —
    # otherwise this loop would prove nothing.
    let rng = MersenneTwister(7), n_apn = 0, n_not = 0
        for n in (4, 5), _ = 1:150
            M = zeros(Int, n, n)
            for i = 1:n, j = (i+1):n
                M[i, j] = M[j, i] = rand(rng, 0:(1<<n-1))
            end
            p1 = proposition1_apn(M)
            @test p1 == is_qam(M)
            p1 ? (n_apn += 1) : (n_not += 1)
            # cross-check against the definition of APN on the realised function
            p1 && @test differential_uniformity(qam_to_sbox(M)) == 2
        end
        @test n_apn > 0          # non-vacuity: some random matrices ARE QAMs
        @test n_not > 0          # non-vacuity: some are NOT
    end

    # ── Example 1 (§3): G = (x1x2+x2x3, x2x3, x1x2+x1x3) ─────────────────────
    G1 = example1_matrix()
    # the matrix must be exactly what the paper's ANF says it is
    @test G1 == anf_matrix(3, [
        [(1, 2), (2, 3)],          # g1 = x1x2 + x2x3
        [(2, 3)],                  # g2 = x2x3
        [(1, 2), (1, 3)],          # g3 = x1x2 + x1x3
    ])
    @test G1 == [0 5 4; 5 0 3; 4 3 0]
    @test G1 == permutedims(G1)                      # symmetric
    @test all(G1[i, i] == 0 for i = 1:3)             # zero diagonal
    @test is_qam(G1)                                 # the paper's claim: G is APN
    @test proposition1_apn(G1)
    @test differential_uniformity(qam_to_sbox(G1)) == 2
    @test algebraic_degree(qam_to_sbox(G1)) == 2
    # the matrix really encodes the stated ANF: entry (i,j) lists the coordinates
    # containing x_i x_j, so G's own QAM must reproduce it.
    @test quadratic_apn_matrix(qam_to_sbox(G1)) == G1

    # ── Example 2 (§3): the null-g4 extension of Example 1 to 4 variables ────
    F2 = example2_matrix()
    @test F2 == anf_matrix(4, [
        [(1, 2), (2, 3), (3, 4)],  # f1 = g1 + x3x4
        [(2, 3)],                  # f2 = g2
        [(1, 2), (1, 3), (2, 4)],  # f3 = g3 + x2x4
        [(1, 4), (3, 4)],          # f4 = x1x4 + x3x4
    ])
    @test F2 == [0 5 4 8; 5 0 3 4; 4 3 0 9; 8 4 9 0]
    E2 = qam_to_sbox(F2)
    @test differential_uniformity(E2) == 2           # paper: F is APN
    @test algebraic_degree(E2) == 2
    @test quadratic_apn_matrix(E2) == F2
    # it is an extension of Example 1: the low 3 bits of the 3×3 block are G
    @test [F2[i, j] & 0b111 for i = 1:3, j = 1:3] == G1
    # g_4 is null: the 4th coordinate contributes no term among x_1..x_3
    @test all((F2[i, j] >> 3) & 1 == 0 for i = 1:3, j = 1:3)
    # Example 2 is exactly the construction (1) with alpha = (F2[1,4],...,F2[3,4])
    alpha = [F2[i, 4] for i = 1:3]
    Q = build_extended_qam(G1, zero_extra_qam(3), alpha, 3)
    @test Q == F2
    @test is_qam(Q)

    # ── Proposition 2 == Proposition 1 on the extended matrix ────────────────
    # A concrete alpha that FAILS and one that PASSES — the criterion must
    # discriminate, not accept everything.
    Q_zero = build_extended_qam(G1, zero_extra_qam(3), zeros(Int, 3), 3)
    @test !is_qam(Q_zero)                            # alpha = 0 violates Theorem 1
    @test !proposition1_apn(Q_zero)
    @test !beth_ding_all_terms_present(Q_zero)
    @test is_qam(Q) && proposition1_apn(Q)           # alpha from Example 2 works

    # ── §3 search: n=3 Gold → n=4 ───────────────────────────────────────────
    g3 = gold_apn(3)
    M_extra = zero_extra_qam(3)
    fns = section3_search(g3, M_extra; limit = 50)
    @test length(fns) >= 1
    for f in fns
        @test differential_uniformity(f) == 2
        @test algebraic_degree(f) == 2
        @test proposition1_apn(quadratic_apn_matrix(f))
    end

    # Every APN extension found must satisfy Proposition 2 by construction, and
    # every alpha rejected must genuinely fail: check the criterion agrees with a
    # direct DDT computation on a sample of alphas (both accepted and rejected).
    let n_acc = 0, n_rej = 0
        for a1 = 0:3, a2 = 0:3, a3 = 0:15
            Qa = build_extended_qam(quadratic_apn_matrix(g3), M_extra, [a1, a2, a3], 3)
            ok = is_qam(Qa)
            @test ok == proposition1_apn(Qa)
            @test ok == (differential_uniformity(qam_to_sbox(Qa)) == 2)
            ok ? (n_acc += 1) : (n_rej += 1)
        end
        @test n_acc > 0
        @test n_rej > 0
    end

    # n=4 has exactly ONE CCZ-class of quadratic APN functions (Brinkmann–Leander
    # 2008), and the §3 construction from Gold n=3 reaches it — for both the null
    # and the all-quadratic choice of g_4.
    all_null = dedup_ea(section3_search(g3, zero_extra_qam(3)))
    @test length(all_null) == 1
    all_allq = dedup_ea(section3_search(g3, allquad_extra_qam(3)))
    @test length(all_allq) == 1
    @test are_ea_equivalent_quadratic(
        SBox{4}(Int.(all_null[1].lut)),
        SBox{4}(Int.(all_allq[1].lut)),
    )
    @test are_ea_equivalent_quadratic(SBox{4}(Int.(all_null[1].lut)), gold_apn(4))

    # ── R5: the n=4 → n=5 null result is EXPECTED, and the search is exhaustive
    # 2^20 = 1,048,576 alpha vectors, no limit: 0 APN extensions of Gold n=4 for
    # g_5 = null and for g_5 = all-quadratic. Both n=5 classes (Gold x^3, x^5) are
    # therefore out of reach of this particular G — a result, not a failure.
    @test isempty(section3_search(gold_apn(4), zero_extra_qam(4)))
    @test isempty(section3_search(gold_apn(4), allquad_extra_qam(4)))
    # the same code DOES find extensions when they exist (guards against the test
    # passing because section3_search is broken and always returns nothing)
    @test !isempty(section3_search(gold_apn(3), zero_extra_qam(3); limit = 1))

    # ── Proposition 3: the paper's explicit 5-variable G is diff. 4-uniform ──
    G3 = proposition3_example_matrix()
    # Pin the transcription against the paper's ANF. (Δ_G = 4 alone does NOT pin
    # it: corrupting entry (4,5) from 31 to 30 still leaves Δ_G = 4.)
    @test G3 == anf_matrix(5, [
        [(1, 2), (3, 5), (4, 5)],                  # g1 = x1x2 + x3x5 + x4x5
        [(1, 3), (4, 5)],                          # g2 = x1x3 + x4x5
        [(2, 3), (1, 4), (3, 5), (4, 5)],          # g3 = x2x3 + x1x4 + x3x5 + x4x5
        [(2, 4), (1, 5), (4, 5)],                  # g4 = x2x4 + x1x5 + x4x5
        [(3, 4), (2, 5), (4, 5)],                  # g5 = x3x4 + x2x5 + x4x5
    ])
    # It is a completion of §4's cyclic matrix T: every *known* entry of T(5)
    # agrees, only the two unknowns t_{3,5} = 5 and t_{4,5} = 31 are filled in.
    let (T5, known5) = kalgin_T(5)
        @test all(G3[i, j] == T5[i, j] for i = 1:5, j = 1:5 if known5[i, j])
        @test G3[3, 5] == 5 && G3[4, 5] == 31
    end
    @test G3 == permutedims(G3)
    @test all(G3[i, i] == 0 for i = 1:5)
    G3s = qam_to_sbox(G3)
    @test differential_uniformity(G3s) == 4          # Proposition 3's bound, attained
    @test algebraic_degree(G3s) == 2
    @test !is_qam(G3)                                # G is NOT APN
    @test !proposition1_apn(G3)
    # Proposition 3 says any G extendable by (1) to an APN F has Δ_G ≤ 4; this G
    # is the paper's witness that Δ_G = 4 actually occurs.
    @test differential_uniformity(G3s) <= 4
end
