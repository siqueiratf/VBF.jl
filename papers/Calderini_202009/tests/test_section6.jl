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
end