@testset "theorem6_1_test" begin
    include(joinpath(@__DIR__, "..", "theorem6_1.jl"))

    io = IOBuffer()
    r = theorem6_1_report(io; m_values = (5,), necessity_control = true)
    @test r.all_ok

    row = only(r.rows)
    @test row.m == 5
    @test row.all_quadratic && row.all_apn
    @test row.cross_total > 0
    @test row.cross_separated == row.cross_total     # every cross-family pair separated
    @test isempty(row.collisions)
    @test length(row.families) >= 4

    # POSITIVE CONTROL: the invariant DOES collapse equivalent functions, so the
    # separation above is a real result and not "all mugshots happen to differ".
    @test row.positive_pairs > 0
    @test row.positive_equal == row.positive_pairs

    # NECESSITY CONTROL: at m=4 Theorem 4.8's hypotheses fail for every instance,
    # and a Zhou-Pott function really IS CCZ-equivalent to an F1 function there —
    # so the theorem's (q,m) != (2,4) exclusion is load-bearing.
    @test r.necessity.none_satisfied
    @test r.necessity.zp_f1_ccz_equivalent

    fld = BiField(5)
    Gold = gold_odd(fld, 1)
    F1 = family_f1(fld, 1)
    F2 = family_f2(fld, 1)
    @test mugshot_of(Gold) != mugshot_of(F1)
    @test mugshot_of(F1) != mugshot_of(F2)
    @test mugshot_of(Gold) != mugshot_of(F2)
    # and equal within a family across q <-> qbar
    @test mugshot_of(F1) == mugshot_of(family_f1(fld, 4))
end
