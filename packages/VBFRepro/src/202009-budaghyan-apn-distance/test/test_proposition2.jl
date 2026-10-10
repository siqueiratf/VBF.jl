@testset "proposition2_test" begin
    include(joinpath(@__DIR__, "..", "proposition2.jl"))

    F = gold_apn(5, 1)

    # K=1: single point modification — sample check
    for (u, v) in [(3, 1), (7, 2), (0, 5), (15, 3), (31, 1), (10, 7)]
        G = apply_modifications(F, [u], [v])
        cond = check_apn_conditions(F, [u], [v])
        direct = differential_uniformity(G) == 2
        @test cond == direct
    end

    # K=2: two-point modification — sample check
    seeds = [(3, 7, 1, 2), (0, 15, 3, 5), (5, 10, 7, 1), (1, 30, 2, 4)]
    for (u1, u2, v1, v2) in seeds
        u1 == u2 && continue
        G = apply_modifications(F, [u1, u2], [v1, v2])
        cond = check_apn_conditions(F, [u1, u2], [v1, v2])
        direct = differential_uniformity(G) == 2
        @test cond == direct
    end

    # K=1 with APN F known: any v ∈ domain should give valid G (not always APN)
    # Check that conditions match direct test on all 31 nonzero shifts for u=5
    u = 5
    for v = 1:31
        G = apply_modifications(F, [u], [v])
        cond = check_apn_conditions(F, [u], [v])
        direct = differential_uniformity(G) == 2
        @test cond == direct
    end

    # ── Positive (true-APN) instance ─────────────────────────────────────────
    # Everything above is vacuous on its own: at n=5, m_F = 15 makes the Corollary 2
    # bound 6, so NO K ≤ 2 modification of x³ can be APN and every `cond == direct`
    # collapses to `false == false`. An implementation returning a constant `false`
    # would pass. The instance below is APN (Section IV-A, Example (b)), so it pins
    # the other direction: `check_apn_conditions` must return `true` here.
    U = collect(0:7)                    # ⟨1, α, α²⟩
    v_apn = 25                          # α²⁵

    G_apn = apply_modifications(F, U, fill(v_apn, 8))
    @test differential_uniformity(G_apn) == 2                    # G really is APN
    @test check_apn_conditions(F, U, fill(v_apn, 8)) == true     # ← fails a constant-false impl

    # Negative controls on the same U: neighbouring shifts are not APN, so a
    # constant-true implementation fails here.
    for v_bad in (24, 26, 1)
        G_bad = apply_modifications(F, U, fill(v_bad, 8))
        @test differential_uniformity(G_bad) != 2
        @test check_apn_conditions(F, U, fill(v_bad, 8)) == false
    end

    # Both outcomes occur across the 32 uniform shifts of U, and the conditions agree
    # with a direct APN test on every one of them.
    outcomes = [check_apn_conditions(F, U, fill(v, 8)) for v = 0:31]
    directs = [differential_uniformity(apply_modifications(F, U, fill(v, 8))) == 2 for v = 0:31]
    @test outcomes == directs
    @test any(outcomes) && !all(outcomes)
    # Exactly two "true"s: the trivial v=0 (G = F) and v = α²⁵ = 25.
    @test count(outcomes) == 2
    @test [v for v = 0:31 if outcomes[v+1]] == [0, 25]

    # Non-uniform shifts on the same U: Proposition 2 must still track the direct test,
    # and both outcomes must be represented (they are: v=(25,...,25) is the only APN one).
    for V in ([25, 25, 25, 25, 25, 25, 25, 24], [25, 24, 25, 24, 25, 24, 25, 24])
        G = apply_modifications(F, U, V)
        @test check_apn_conditions(F, U, V) == (differential_uniformity(G) == 2)
    end
end
