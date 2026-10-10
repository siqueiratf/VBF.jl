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
        # At n=3 the statement exponent 2^i+1 and the derivation exponent
        # 2^i/(2^i+1) COINCIDE mod 2^n−1, so the divergence here is caused by the
        # dropped "+ tr_{m/n}(x)" ALONE — the second typo is not observable.
        @test !fc.exponents_differ
        @test fc.statement_exp == fc.derivation_exp
        @test fc.mism_stmt == fc.tr_nonzero    # 512 − 2^{9-3} = 448
        @test fc.mism_stmt == 448
    end

    # bracket exponents, straight from the arithmetic (see the table in
    # theorem4.jl's header): n=3 collapses, n=5 separates.
    @test theorem4_bracket_exponents(3, 1) == (statement_exp = 3, derivation_exp = 3, differ = false)
    @test theorem4_bracket_exponents(3, 2) == (statement_exp = 5, derivation_exp = 5, differ = false)
    @test theorem4_bracket_exponents(5, 1) == (statement_exp = 3, derivation_exp = 11, differ = true)
    @test theorem4_bracket_exponents(5, 2) == (statement_exp = 5, derivation_exp = 7, differ = true)

    # n = 5 is where the "wrong last exponent" half of the verdict becomes
    # observable. There the statement form is no longer AB and no longer APN,
    # which is exactly the evidence the n=3 parameters cannot produce.
    fc = theorem4_paper_formula_check(; m = 15, n = 5, i = 1)
    @test fc.corr_matches
    @test fc.mism_corr == 0
    @test fc.exponents_differ
    @test fc.statement_exp == 3 && fc.derivation_exp == 11
    @test fc.mism_stmt == 32734
    @test fc.mism_stmt > fc.tr_nonzero        # more than the dropped linear term explains
    @test !fc.stmt_is_ab
    @test fc.stmt_lin == 896                  # ≠ 2^{(15+1)/2} = 256
    @test fc.stmt_du == 16                    # not APN either

    fc = theorem4_paper_formula_check(; m = 15, n = 5, i = 2, stmt_stats = false)
    @test fc.corr_matches
    @test fc.exponents_differ
    @test fc.statement_exp == 5 && fc.derivation_exp == 7
    @test fc.mism_stmt > fc.tr_nonzero

    # Divisor corollary (tex l.772): "the number of functions CCZ-equivalent to a
    # Gold AB function and EA-inequivalent to it is not smaller than the number
    # of divisors of m". Needs ≥ 2 admissible n for ONE m, impossible at m=9.
    dv = theorem4_divisors_check(; m = 15, i = 1, ns = (3, 5))
    @test dv.all_ab                            # both Theorem 4 members are AB
    @test dv.degrees_ok                        # degrees n+2 ∈ {5,7}, plus 3 for n=1
    @test dv.degrees == [5, 7, 3]
    @test dv.n_members == 3                    # n ∈ {3,5} from Thm 4, n=1 from Thm 1
    @test dv.pairwise_ea_inequivalent          # distinct degrees ≥ 2 ⇒ EA-inequivalent
    @test dv.n_divisors == 4                   # divisors of 15: 1,3,5,15

    # Prop 4 scanned over every c ∈ F*_{2^9}, not just c = 1
    r = theorem4_check(; m = 9, n = 3, i = 1)
    @test r.prop4_scan_c
    @test r.n_witnesses > 0

    # argument validation
    @test_throws ArgumentError theorem4_lut(4, 2, 1)   # m even
    @test_throws ArgumentError theorem4_lut(9, 9, 1)   # m == n
    @test_throws ArgumentError theorem4_lut(9, 4, 1)   # n ∤ m (4 ∤ 9)
    @test_throws ArgumentError theorem4_lut(9, 3, 3)   # gcd(3,9) ≠ 1
end
