@testset "section6_test" begin
    include(joinpath(@__DIR__, "..", "section6.jl"))

    # Table 4, n=1: exact count
    @test count_apn_n1() == 4

    # Table 4, n=2: exact count
    @test count_apn_n2() == 192

    # n=3 full leaf enumeration is ~2 min — omitted from the fast test suite.
    # `count_apn_backtrack(3)` in algorithm1.jl computes it in < 1 s and is
    # asserted in test_algorithm1.jl.
    @test APN_COUNT_N3 == "688128"

    # Regression against Table 4 (tex lines 393-395). n=5 previously carried a
    # transcription bug: 23 digits (…146800) instead of the paper's 24-digit
    # …1468800 — a dropped '8', off by ~10x. Assert the exact digit strings.
    @test APN_COUNT_N4 == "18940805775360"
    @test APN_COUNT_N5 == "110823678910407691468800"
    @test length(APN_COUNT_N5) == 24

    # ... and derive them, rather than only transcribing: eq. (10) for |G| plus
    # the orbit-stabiliser formula over Section 6's stabiliser orders.
    @test g_order(4) == big"6818690079129600"
    @test g_order(5) == big"3435534046222638435532800"
    @test stabiliser_orders(4) == [5760, 384]
    @test stabiliser_orders(5) == [4960, 4960, 160, 160, 155, 155, 155]
    @test string(apn_count_from_orbits(4)) == APN_COUNT_N4
    @test string(apn_count_from_orbits(5)) == APN_COUNT_N5
    @test_throws ArgumentError stabiliser_orders(6)

    # |G| = |Gᵅ|·|Gᵝ|·|Gᵞ| with |GL(n,2)| the middle factor (OEIS A002884).
    @test g_order(1) == big(2) * 1 * 1 * big(2)^2
    @test length(stabiliser_orders(4)) == 2   # 2 EA classes for n=4 (Table 2)
    @test length(stabiliser_orders(5)) == 7   # 7 EA classes for n=5 (Table 3)

    # The truncation warning promised by the docstring is actually emitted.
    @test_logs (:warn,) match_mode = :any count_apn_n3(limit = 8)
end
