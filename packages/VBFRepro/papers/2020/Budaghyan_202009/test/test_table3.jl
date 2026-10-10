@testset "table3_test" begin
    include(joinpath(@__DIR__, "..", "table3.jl"))

    # There are exactly three CCZ-classes of APN functions over F₂⁵; the paper's last
    # column names them by EA-representatives, so the labels must be resolved:
    # x⁷ is CCZ-equivalent to x⁵ and x¹¹ to x³ (checked here, not assumed).
    @test ccz_class_n5(SBox{5}(gf_monomial_lut(5, 3))) == "x^3"
    @test ccz_class_n5(SBox{5}(gf_monomial_lut(5, 5))) == "x^5"
    @test ccz_class_n5(SBox{5}(gf_monomial_lut(5, 7))) == "x^5"
    @test ccz_class_n5(SBox{5}(gf_monomial_lut(5, 11))) == "x^3"
    @test ccz_class_n5(SBox{5}(gf_monomial_lut(5, 15))) == "x^15"

    # Table III, the two computed columns: (m_F / lower bound) and the single-shift
    # distance; plus the CCZ-class of the single-shift minimiser.
    expected = [
        # e, m_F, lower bound, single-shift distance, CCZ class of the minimiser
        (3, 15, 6, 8, "x^5"),
        (5, 15, 6, 8, "x^3"),
        (7, 15, 6, 12, "x^5"),     # paper's label "x^7" — the class of x^7 is x^5
        (11, 15, 6, 12, "x^3"),    # paper's label "x^11" — the class of x^11 is x^3
        (15, 9, 4, 10, "x^15"),
    ]

    for (e, exp_m, exp_bd, exp_ss, exp_class) in expected
        r = table3_row(e)
        @test r.apn
        @test r.mF == exp_m
        @test r.bd == exp_bd
        @test r.bd == lower_bound_distance(r.mF)
        @test r.distance == exp_ss
        @test r.ccz_class == exp_class
        # The minimiser is a real APN function at exactly that distance.
        @test differential_uniformity(r.G) == 2
        @test hamming_distance(SBox{5}(gf_monomial_lut(5, e)), r.G) == exp_ss
        @test length(r.U) == exp_ss
        # Corollary 2 is a genuine lower bound on it.
        @test r.distance ≥ r.bd
    end

    # The columns are not constant, so the assertions above discriminate: three distinct
    # single-shift distances (8, 10, 12) and two distinct m_F (9, 15).
    rows = [table3_row(e) for (e, _, _, _, _) in expected]
    @test sort(unique(r.distance for r in rows)) == [8, 10, 12]
    @test sort(unique(r.mF for r in rows)) == [9, 15]

    # The paper's point: the closest APN function need not stay in F's own CCZ-class.
    # x³ ↦ class x⁵ and x⁵ ↦ class x³ (class changes), while x⁷/x¹¹/x¹⁵ stay put.
    @test rows[1].ccz_class != rows[1].own_class     # x^3  → x^5
    @test rows[2].ccz_class != rows[2].own_class     # x^5  → x^3
    @test rows[3].ccz_class == rows[3].own_class     # x^7  stays (class x^5)
    @test rows[4].ccz_class == rows[4].own_class     # x^11 stays (class x^3)
    @test rows[5].ccz_class == rows[5].own_class     # x^15 stays

    # The paper's other point: the single-shift distance can exceed the true minimum
    # distance (x^7, x^11: single-shift 12 vs the paper's actual distance 10).
    @test rows[3].distance > 10
    @test rows[4].distance > 10

    @test table3_report(; io = devnull).all_ok
end
