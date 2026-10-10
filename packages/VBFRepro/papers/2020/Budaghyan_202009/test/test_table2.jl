@testset "table2_test" begin
    include(joinpath(@__DIR__, "..", "table2.jl"))

    # ── Monomial rows: m_F, Corollary 2 bound, minimum single-shift distance ──
    # (n, exponent, m_F, bound, min single-shift distance) exactly as Table II prints.
    for (n, e, exp_m, exp_bd, exp_mss) in [
        (4, 3, 3, 2, 2),
        (5, 3, 15, 6, 8),
        (5, 5, 15, 6, 8),
        (5, 15, 9, 4, 10),
        (6, 3, 27, 10, 16),      # Edel–Pott row 1.1
    ]
        F = SBox{n}(gf_monomial_lut(n, e))
        r = table2_row(F)
        @test r.apn
        @test r.mF == exp_m
        @test r.bd == exp_bd
        @test r.mss == exp_mss
        @test r.bd == lower_bound_distance(r.mF)
    end

    # The rows are not all equal, so the assertions above discriminate: x¹⁵ at n=5 has
    # a strictly smaller m_F than x³/x⁵ (that is the paper's point — Π_F separates it).
    @test compute_m_F(SBox{5}(gf_monomial_lut(5, 15))) <
          compute_m_F(SBox{5}(gf_monomial_lut(5, 3)))

    # ── n=7 block (R6): "7.1 → 54/19" (the inverse function), "all others → 63/22".
    # The paper's text: "for n=7 we obtain the same bound for all functions listed in
    # [16] except for the inverse function". Runs in well under a second.
    inv7 = load_apn_function("n7_Inverse_x126")
    r7 = table2_row(inv7; single_shift = false)
    @test r7.mF == 54
    @test r7.bd == 19

    others = ["n7_Gold_x3", "n7_Gold_x5", "n7_Gold_x9", "n7_Kasami_x13",
              "n7_Kasami_x57", "n7_Welch_x11", "n7_Niho_x39"]
    for name in others
        r = table2_row(load_apn_function(name); single_shift = false)
        @test r.apn
        @test r.mF == 63
        @test r.bd == 22
    end
    # The inverse function really is the odd one out — so "63 for all others" has content.
    @test r7.mF != 63
    @test length(others) + 1 == count(startswith("n7_"), apn_catalog_names())

    # The whole table, through the report driver.
    @test table2_report(; io = devnull).all_ok
end
