@testset "section5_test" begin
    include(joinpath(@__DIR__, "..", "section5.jl"))

    F = gold_apn(5, 1)

    # kernel dimension ≥ 1 (non-trivial solutions exist)
    res = single_shift_solutions(F, 1; limit = 128)
    @test res.kernel_dim ≥ 1
    @test res.consistent

    # Empty set U (all-zero solution) always present — because F itself is APN
    @test UInt64(0) ∈ res.solutions

    # All non-trivial solutions give APN G
    for sol in res.solutions
        sol == 0 && continue
        U = [x for x = 0:31 if (sol >> x) & 1 == 1]
        V = fill(1, length(U))
        G = apply_modifications(F, U, V)
        @test differential_uniformity(G) == 2
    end

    # Round-trip: kernel vectors → APN check
    rows = build_single_shift_constraints(F, 1)
    basis = kernel_f2(rows; nbits = 32)
    @test length(basis) == res.kernel_dim

    # ── R9: the non-APN half (paper's steps 4–5) ────────────────────────────
    # For APN F the step 4–5 rows are empty; the system is homogeneous.
    rows_h, rhs_h = build_single_shift_system(F, 1)
    @test !any(rhs_h)
    @test sort(rows_h) == sort(rows)

    # H is x³ with H(0) flipped by 1 ⇒ DU = 4, i.e. NOT APN. The paper's method is
    # advertised for "an arbitrary function F (not only APN)".
    H = apply_modifications(F, [0], [1])
    @test differential_uniformity(H) == 4

    # The APN-only entry point must refuse it instead of silently returning a wrong system.
    @test_throws ErrorException build_single_shift_constraints(H, 1)

    rows_g, rhs_g = build_single_shift_system(H, 1)
    @test any(rhs_g)                       # steps 4–5 really do fire for a non-APN F

    resH = single_shift_solutions(H, 1)
    @test resH.consistent
    @test resH.exhaustive
    # THE discriminator: U = ∅ means G = H, and H is not APN — so ∅ must NOT be a
    # solution. A homogeneous-only system (the old implementation) always contains it.
    @test UInt64(0) ∉ resH.solutions
    # Undoing the flip (U = {0}, v = 1) recovers x³, which is APN ⇒ it must be a solution.
    @test UInt64(1) ∈ resH.solutions
    # Soundness: every solution really does give an APN G.
    for sol in resH.solutions
        U = [x for x = 0:31 if (sol >> x) & 1 == 1]
        G = apply_modifications(H, U, fill(1, length(U)))
        @test differential_uniformity(G) == 2
    end
    # Completeness spot-check: sets that are NOT solutions must NOT give an APN G.
    for bad in (UInt64(0), UInt64(0b11), UInt64(0b101), UInt64(0xff))
        bad ∈ resH.solutions && continue
        U = [x for x = 0:31 if (bad >> x) & 1 == 1]
        G = apply_modifications(H, U, fill(1, length(U)))
        @test differential_uniformity(G) != 2
    end

    # Inconsistent case: for H there is no U at all that works with the shift v = 2.
    resH2 = single_shift_solutions(H, 2)
    @test !resH2.consistent
    @test isempty(resH2.solutions)

    # v = 0 is out of scope (the paper takes v ∈ F₂ⁿ*).
    @test_throws ArgumentError build_single_shift_system(F, 0)

    # ── R10: the minimum-weight search must be exhaustive, not lucky ─────────
    # x³ over F₂⁵: min single-shift distance 8 (Tables II and III).
    mss = min_single_shift_distance(F)
    @test mss.distance == 8
    @test mss.apn                                    # re-verified with differential_uniformity
    @test length(mss.U) == 8
    G = apply_modifications(F, mss.U, fill(mss.v, 8))
    @test differential_uniformity(G) == 2
    @test hamming_distance(F, G) == 8

    # Exhaustiveness: no solution of ANY v, over the FULL kernel, has weight < 8 — and
    # weight 8 is actually attained. (The old code enumerated 64 of 2048 kernel vectors
    # for a single v and printed 8 as though established.)
    best = typemax(Int)
    attained = 0
    for v = 1:31
        r = single_shift_solutions(F, v)
        @test r.consistent
        @test r.exhaustive
        @test r.n_solutions == 1 << r.kernel_dim     # the whole kernel, not a prefix
        for sol in r.solutions
            sol == 0 && continue
            w = count_ones(sol)
            w < best && (best = w)
            w == 8 && (attained += 1)
        end
    end
    @test best == 8
    @test attained > 0

    # The same routine gives different (correct) answers for other functions, so `8`
    # is not baked in: x⁷ → 12, x¹⁵ → 10 (Table III).
    @test min_single_shift_distance(SBox{5}(gf_monomial_lut(5, 7))).distance == 12
    @test min_single_shift_distance(SBox{5}(gf_monomial_lut(5, 15))).distance == 10
end
