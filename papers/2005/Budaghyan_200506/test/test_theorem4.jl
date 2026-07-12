@testset "theorem4_test" begin
    include(joinpath(@__DIR__, "..", "theorem4.jl"))

    # m=9, n=3, i=1: AB, degree n+2=5, Prop 4 EA-inequivalence
    r = theorem4_check(; m = 9, n = 3, i = 1)
    @test r.is_ab
    @test r.deg == r.expected_deg   # n+2 = 5
    @test r.prop4_ok                # deg(tr F') ∉ {0,1,deg}
    @test r.deg_tr == 4

    # m=9, n=3, i=2
    r = theorem4_check(; m = 9, n = 3, i = 2)
    @test r.is_ab
    @test r.deg == r.expected_deg
    @test r.prop4_ok
    @test r.deg_tr == 4

    # Explicit-formula audit (replaces the old unbacked "diff-unif 14" comment):
    # the derivation form (tex l.762–770) reproduces F₂∘F₁⁻¹ EXACTLY, while the
    # theorem-statement form (l.684–689) is a typo that diverges yet is still AB.
    for ii in (1, 2)
        fc = theorem4_paper_formula_check(; m = 9, n = 3, i = ii)
        @test fc.corr_matches           # derivation form == construction
        @test fc.mism_corr == 0
        @test fc.mism_stmt > 0          # statement form diverges (here: 448/512)
        @test fc.stmt_is_ab             # ... but is itself AB — not diff-unif 14
        @test fc.stmt_du == 2
    end

    # argument validation
    @test_throws ArgumentError theorem4_lut(4, 2, 1)   # m even
    @test_throws ArgumentError theorem4_lut(9, 9, 1)   # m == n
    @test_throws ArgumentError theorem4_lut(9, 4, 1)   # n ∤ m (4 ∤ 9)
    @test_throws ArgumentError theorem4_lut(9, 3, 3)   # gcd(3,9) ≠ 1
end
