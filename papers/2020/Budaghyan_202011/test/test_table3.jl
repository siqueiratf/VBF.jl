@testset "table3_test" begin
    include(joinpath(@__DIR__, "..", "table3.jl"))

    funcs = table3_functions()

    # Table III, with the six F12 representatives expanded:
    # Gold x^3, Gold x^9, Kasami x^57, Dobbertin x^339, F3×2, F4×2, F12×6, B(x),
    # C_3, C_7 = 4 + 2 + 2 + 6 + 1 + 2 = 17 S-boxes.
    @test length(funcs) == 17
    @test count(f -> f.family == "F12", funcs) == 6   # tex:485, "six CCZ-inequivalent representatives"

    # Every row is genuinely APN over GF(2^10) — including the F3/F4 rows, whose
    # α-powers are representation-dependent and were never built before.
    for f in funcs
        @test differential_uniformity(f.sbox) == 2
    end

    # Degrees: 15 quadratic rows; Kasami x^57 (deg 4), Dobbertin x^339 (deg 5).
    degs = Dict(f.name => algebraic_degree(f.sbox) for f in funcs)
    @test degs["x^57"] == 4
    @test degs["x^339"] == 5
    @test count(f -> algebraic_degree(f.sbox) == 2, funcs) == 15

    # ── The paper's central claim, actually checked ──────────────────────────
    # For quadratic APN, CCZ-equivalence coincides with EA-equivalence (Yoshiara),
    # and the ortho-derivative mugshot is an EA-invariant. Pairwise-distinct
    # mugshots across all 15 quadratic rows ⇒ C_3 and C_7 are CCZ-inequivalent to
    # each other, to B(x), and to every other quadratic APN class over GF(2^10).
    quads = [f for f in funcs if algebraic_degree(f.sbox) == 2]
    mugs  = [apn_ea_mugshot(f.sbox) for f in quads]
    @test length(quads) == 15
    @test length(Set(mugs)) == 15    # pairwise distinct

    c3 = first(f.sbox for f in funcs if f.name == "C_3")
    c7 = first(f.sbox for f in funcs if f.name == "C_7")
    bx = first(f.sbox for f in funcs if f.name == "B(x)")
    @test apn_ea_mugshot(c3) != apn_ea_mugshot(c7)
    @test apn_ea_mugshot(c3) != apn_ea_mugshot(bx)
    @test apn_ea_mugshot(c7) != apn_ea_mugshot(bx)

    # Non-vacuity #1: the coarser CCZ-invariant (extended Walsh spectrum) separates
    # NONE of C_3, C_7, B(x). The ortho-derivative is what does the work, so the
    # mugshot assertions above are not passing for free.
    @test absolute_walsh_spectrum(c3) == absolute_walsh_spectrum(c7)
    @test absolute_walsh_spectrum(c3) == absolute_walsh_spectrum(bx)

    # Non-vacuity #2: the mugshot is not merely "everything differs" — EA-equivalent
    # functions must SHARE it. Conjugating C_3 by the Frobenius x ↦ x² on both sides
    # gives a different LUT but the same EA class, hence the same mugshot.
    mod10 = primitive_polynomial(10)
    sq(x) = gf_mul(x, x, 10; modulus = mod10)
    c3_frob = SBox{10}([sq(Int(c3.lut[sq(x) + 1])) for x in 0:1023])
    @test c3_frob != c3
    @test apn_ea_mugshot(c3_frob) == apn_ea_mugshot(c3)

    # ── What we CANNOT do: the non-quadratic rows ────────────────────────────
    # Kasami x^57 has the SAME extended Walsh spectrum as C_3 and C_7.
    # `apn_ea_mugshot` would "separate" them only through its quadratic /
    # non-quadratic struct TAG, which certifies nothing. Assert the obstruction so
    # that nobody later mistakes a tag mismatch for an invariant.
    k57  = first(f.sbox for f in funcs if f.name == "x^57")
    d339 = first(f.sbox for f in funcs if f.name == "x^339")
    @test absolute_walsh_spectrum(c3) == absolute_walsh_spectrum(k57)
    @test absolute_walsh_spectrum(c7) == absolute_walsh_spectrum(k57)
    @test absolute_walsh_spectrum(c3) != absolute_walsh_spectrum(d339)
    # Γ-rank would settle it, but VBF guards `gamma_rank` to n ≤ 7 (a dense
    # 2^20 × 2^20 F2 matrix is ~137 GB). Assert the guard instead of pretending
    # the capability is absent.
    @test_throws ArgumentError gamma_rank(c3)

    # ── Γ-ranks: TRANSCRIBED from Table III, NOT computed ────────────────────
    # Reference values copied from tex:471-493. We deliberately do NOT compare them
    # against each other and call the result "CCZ-inequivalence" — that would be a
    # tautology (the previous version of this test did exactly that). What we assert
    # is only that the transcription matches the paper, row by row.
    ranks = Dict(f.name => f.gamma_rank_paper for f in funcs)
    @test ranks["x^3"]   == 125042   # tex:471
    @test ranks["x^9"]   == 136492   # tex:473 — was mis-transcribed as 186416
    @test ranks["x^57"]  == 186416   # tex:475 — Kasami's rank; the row that leaked
    @test ranks["x^339"] == 280604   # tex:477
    @test ranks["F3 #1"] == 151216   # tex:479
    @test ranks["F3 #2"] == 153896   # tex:481
    @test ranks["F4 #1"] == 153896   # tex:483
    @test ranks["F4 #2"] == 164098   # tex:485
    @test ranks["B(x)"]  == 169984   # tex:489
    @test ranks["C_3"]   == 166068   # tex:491
    @test ranks["C_7"]   == 166168   # tex:493
    # The paper gives five Γ-ranks for six F12 reps ("two of these six ... have the
    # same Γ rank", tex:487), so no rank can be attached to a specific rep.
    @test all(f.gamma_rank_paper === nothing for f in funcs if f.family == "F12")
    @test F12_GAMMA_RANKS_PAPER == [162550, 163308, 163398, 163400, 164026]
    @test length(F12_GAMMA_RANKS_PAPER) == 5
end
