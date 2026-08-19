@testset "section7_decomposition_and_class_counts" begin
    include(joinpath(@__DIR__, "..", "section7.jl"))

    # --- Appendix C / Table 5: exact linear/affine equivalence-class counts. ---
    # Enumerated exhaustively for n = 1, 2, 3 and matched against the paper.
    @test equivalence_class_counts(1) == (2, 1)
    @test equivalence_class_counts(2) == (2, 1)
    @test equivalence_class_counts(3) == (10, 4)   # exhaustive over all 8! permutations

    # Transcribed values (n = 4, 5 are infeasible to enumerate here) are present.
    @test TABLE5[4] == (big"52246", big"302")
    @test TABLE5[5] == (big"2631645209645100680144", big"2569966041123963092")

    # --- Section 7 / Table 1: SPN-layer lower bound from the counting argument. ---
    # With the paper's 1/k! factor in the per-round count, all eight
    # fully-specified columns reproduce the printed value exactly.
    @test spn_layer_bound(6, 3) == 8
    @test spn_layer_bound(8, 4) == 20
    @test spn_layer_bound(9, 3) == 43
    @test spn_layer_bound(10, 5) == 39
    @test spn_layer_bound(12, 3) == 276
    @test spn_layer_bound(12, 4) == 246
    @test spn_layer_bound(12, 6) == 75
    @test spn_layer_bound(16, 4) == 3196

    for (n, m, k, lp) in TABLE1
        @test spn_layer_bound(n, m) == lp
    end

    # Appendix C footnote: exact class counts only for m ≤ 4, the
    # 2^m!/|AGL(m,2)|² approximation beyond.  m = 5 differs from the exact
    # Table 5 entry but leaves the (n,m) = (10,5) column at l = 39.
    @test affine_class_count(3) == big"4"
    @test affine_class_count(4) == big"302"
    @test affine_class_count(5) != TABLE5[5][2]
    @test affine_class_count(5) == div(factorial(BigInt(2)^5), agl_order(5)^2)

    # Report passes (n=3 already verified above; keep the report on the fast path).
    @test section7_report(devnull; full_search = false)
end
