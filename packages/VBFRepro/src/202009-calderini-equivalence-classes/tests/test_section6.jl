@testset "section6_test" begin
    include(joinpath(@__DIR__, "..", "section6.jl"))

    # Theorem 7 for n=5,6,7: x^{-1} has exactly 2 Walsh-zero n-dim subspaces
    for n in (5, 6, 7)
        r = theorem7_verify(n; io = devnull)
        @test r.is_perm
        @test r.is_involution
        @test r.n_subsp == 2
    end
    # n=8 (du = 4, the paper's extension) — a few seconds
    r8 = theorem7_verify(8; io = devnull)
    @test r8.is_perm
    @test r8.is_involution
    @test r8.du == 4
    @test r8.n_subsp == 2

    stopped = theorem7_verify(7; max_nodes=0, io=devnull)
    @test !stopped.complete
    @test stopped.n_subsp === nothing
    @test stopped.outcome isa BudgetHit

    # Theorem 8 for n=5: Kasami x^15
    t8 = theorem8_verify_n5(; io = devnull)
    @test t8.n_subsp <= 2
    @test t8.in_same_coset

    # Remark 5 (n=7): x^13 → 2 classes; x^63 → 1 class
    @test !coset_class_count(13, 7).same
    @test coset_class_count(13, 7).inv_exp == 88
    @test coset_class_count(63, 7).same
    @test 126 in cyclotomic_coset(63, 127)     # x^63 ≃ x^{-1}

    # DISCREPANCY with Remark 5 for x^57: the paper's cyclotomic claim fails
    # (57⁻¹ = 78 ∉ coset(57)) and x^57 is NOT affine-equivalent to its inverse
    # (complete decision; x^63/x^125 control passes inside remark5_verify).
    r57 = coset_class_count(57, 7)
    @test r57.inv_exp == 78
    @test !r57.same
    @test remark5_verify(; io = devnull, check_x57_ae = true)

    # Remark 6 (n=8): x^127 ≃ x^{-1} (coset part; the x^57 simplex count runs
    # in the report — several minutes over |Z| = 16575)
    @test 254 in cyclotomic_coset(127, 255)
    @test remark6_verify(; io = devnull, check_x57 = false)

    # Remark 7 (n=9)
    for d in (13, 19, 241)
        @test !coset_class_count(d, 9).same
    end
    @test 510 in cyclotomic_coset(255, 511)
    @test remark7_verify(; io = devnull)

    # Theorem 8 census (n=5..9): every APN power CCZ-class, Gold-tagged, with
    # the EA-class count of the non-Gold ones (coset-arithmetic half).
    @test is_gold_exponent(3, 7) && is_gold_exponent(9, 7) && is_gold_exponent(17, 9)
    @test !is_gold_exponent(13, 7) && !is_gold_exponent(63, 7)
    @test theorem8_gold_inverse_check(; io = devnull)   # "non-Gold" = no Gold in the CCZ-class

    # n=6: Gold x^3 is the only APN power class ⇒ Theorem 8 is vacuous there.
    c6 = apn_power_ccz_classes(6)
    @test length(c6) == 1 && c6[1].rep == 3 && c6[1].gold

    # Non-Gold classes per dimension, keyed by cyclotomic-coset minimum:
    #   n=5: x^15 (≃ x^{-1});  n=7: x^13→11, x^57→23, x^63;
    #   n=8: x^57→39 (not a permutation);  n=9: x^13, x^19, x^241→47, x^255.
    ng(n) = Dict(c.rep => c.predicted_ea_classes for c in apn_power_ccz_classes(n) if !c.gold)
    @test ng(5) == Dict(15 => 1)
    @test ng(7) == Dict(11 => 2, 23 => 2, 63 => 1)   # 23 = coset(57): paper says 1 (P1)
    @test ng(8) == Dict(39 => 1)
    @test ng(9) == Dict(13 => 2, 19 => 2, 47 => 2, 255 => 1)
    for n = 5:9
        r = theorem8_census(n; io = devnull)
        @test !r.exact_class_count_established
        @test r.ok                                   # matches Remarks 5-7 / Tables 2-4
    end
end