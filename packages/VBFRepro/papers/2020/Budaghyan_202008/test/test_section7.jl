@testset "section7_test" begin
    include(joinpath(@__DIR__, "..", "section7.jl"))

    # ── Section VII-B: the paper's central claim (README R2) ────────────────
    # The new n=9 APN is CCZ-inequivalent to every known APN over GF(2⁹):
    # all 7 known Table I rows, plus every quadratic n=9 catalog entry.
    r = section7_check_n9_inequivalence()
    @test r.nonvacuous                       # 7 known rows and ≥5 catalog quadratics
    @test r.known_checked == 7
    @test r.known_distinct == 7
    @test r.all_known_inequiv
    @test length(r.catalog_quadratic) == 5   # 3 Gold + Budaghyan2009 eq7 + eq8
    @test r.cat_distinct == 5
    @test r.all_cat_inequiv
    @test r.all_inequiv
    @test length(r.catalog_power) == 4       # Kasami x13/x241, Welch/Niho, Inverse

    # ── Section VII-A: x⁹ + Tr(x³) over GF(2⁸) ──────────────────────────────
    rn8 = section7_check_n8_reference()
    @test rn8.is_apn
    @test rn8.du == 2

    # ── n=6: 1-term shifts of G_1 reach the Gold class and nothing else ─────
    # (Lemma VI.6(i) — NOT Section VII-D; see README R6.)
    r6 = section7_check_n6_1term_shift_classes()
    @test r6.gold_reachable
    @test r6.only_gold
    @test r6.nclasses == 1
end
