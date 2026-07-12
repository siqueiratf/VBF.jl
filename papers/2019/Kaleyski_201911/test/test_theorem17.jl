@testset "theorem17_test" begin
    include(joinpath(@__DIR__, "..", "helpers.jl"))
    using VBFCatalog

    # ── POSITIVE case (README R5): n=4, F = x^3 over F_16. ──────────────────────
    # S1=6, S2=6, 6·Δ(1,0)=12 ⇒ Eq. (29) HOLDS, and G = swap(F,0,1) IS APN.
    # Without this case the whole suite is vacuous: every catalog function with
    # n ≥ 5 gives `holds == false`, so a theorem17_holds hardcoded to `false`
    # would pass. Ground truth (differential_uniformity of the swapped function)
    # is computed independently of Eq. (29).
    s4 = load_apn_function("n4_Gold_x3")
    r4 = theorem17_holds(s4)
    @test r4.s1 == 6
    @test r4.s2 == 6
    @test 6 * r4.dd10 == 12
    @test r4.s1 + r4.s2 == 6 * r4.dd10
    @test r4.holds                                    # Eq. (29) holds
    g4 = swap_points(s4, 0, 1)
    @test differential_uniformity(g4) == 2            # ⇒ G is APN (ground truth)
    @test swap_is_apn(s4, 0, 1)
    @test g4.lut != s4.lut                            # the swap is a genuine change

    # Both halves of the biconditional, exhaustively over every genuine pair at n=4:
    #   Eq. (29) on normalize_apn(F,u₁,u₂)  ⟺  swap(F,u₁,u₂) is APN.
    apn_swaps_n4 = 0
    for (u1, u2) in genuine_pairs(s4)
        holds = theorem17_holds(normalize_apn(s4, u1, u2)).holds
        isapn = swap_is_apn(s4, u1, u2)
        @test holds == isapn
        isapn && (apn_swaps_n4 += 1)
    end
    @test apn_swaps_n4 == 15        # Observation 27: G is APN for n=4 (15 such swaps)

    # ── NEGATIVE cases: n ≥ 5, condition must fail AND the swap must not be APN. ─
    s5 = load_apn_function("n5_Gold_x3")
    r5 = theorem17_holds(s5)
    @test !r5.holds
    @test !swap_is_apn(s5, 0, 1)
    @test r5.dd10 >= 0
    @test r5.s1 >= 0
    @test r5.s2 >= 0

    s6 = load_apn_function("n6_Gold_x3")
    r6 = theorem17_holds(s6)
    @test !r6.holds
    @test !swap_is_apn(s6, 0, 1)

    # Biconditional over every genuine pair at n=5 (496 pairs): no APN swap at all.
    for (u1, u2) in genuine_pairs(s5)
        @test theorem17_holds(normalize_apn(s5, u1, u2)).holds == swap_is_apn(s5, u1, u2)
    end
    @test !any(swap_is_apn(s5, u1, u2) for (u1, u2) in genuine_pairs(s5))

    # ── Observation 7 (README R1): the input map A₂(x) = x(u₁+u₂) + u₁. ─────────
    # normalize_apn(F, u₁, u₂) must land on F'(0)=0, F'(1)=1 for ANY genuine pair,
    # and must reduce to the old output-only normalisation at (0,1).
    @test normalize_apn(s5).lut == normalize_apn(s5, 0, 1).lut
    for (u1, u2) in [(0, 1), (0, 6), (3, 4), (7, 19), (31, 30)]
        fp = normalize_apn(s5, u1, u2)
        @test Int(fp.lut[1]) == 0
        @test Int(fp.lut[2]) == 1
        @test differential_uniformity(fp) == 2        # EA-equivalent ⇒ still APN
    end

    # Round-trip: normalize_apn leaves power functions unchanged at (0,1)
    @test normalize_apn(s5).lut == s5.lut
    @test normalize_apn(s6).lut == s6.lut

    # Sanity: S1, S2 are non-negative integers
    @test r5.s1 isa Int && r5.s1 >= 0
    @test r5.s2 isa Int && r5.s2 >= 0

    # Non-degenerate power functions are not flagged
    @test !is_swap_degenerate(s5)
    @test !is_swap_degenerate(s6)

    # Degenerate PAIR F(u₁)=F(u₂): the swap is a no-op, so Observation 7's A₁ is
    # undefined there and normalize_apn must refuse — but the function itself is
    # still usable at any other pair (README R3: no function gets discarded).
    lut = Int.(s5.lut)
    lut[2] = lut[1]                       # force F(1) = F(0)
    sdeg = SBox(lut)
    @test is_swap_degenerate(sdeg)
    @test is_swap_degenerate(sdeg, 0, 1)
    @test_throws ArgumentError normalize_apn(sdeg)
    @test_throws ArgumentError normalize_apn(sdeg, 0, 1)
    @test_throws ArgumentError normalize_apn(sdeg, 3, 3)
    u1, u2 = first_genuine_pair(sdeg)
    @test (u1, u2) != (0, 1)
    @test !is_swap_degenerate(sdeg, u1, u2)
    sdn = normalize_apn(sdeg, u1, u2)     # succeeds where the (0,1) swap cannot
    @test Int(sdn.lut[1]) == 0 && Int(sdn.lut[2]) == 1

    # ── Power-function predicate (README R6): mathematical, not TOML-metadata. ──
    @test is_power_function(s5)
    @test power_exponent(s5) == 3
    @test power_exponent(load_apn_function("n5_Kasami_x15")) == 15
    @test is_power_function(load_apn_function("n4_Gold_x3"))
    @test !is_power_function(g4)          # x^3 with two points swapped is no monomial
end
