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
    # Columns that reproduce the paper exactly.
    @test spn_layer_bound(6, 3) == 8
    @test spn_layer_bound(8, 4) == 20
    @test spn_layer_bound(10, 5) == 39

    # All eight columns: exact BigInt eval lands within 3% (and never above) the paper.
    for (n, m, k, lp) in TABLE1
        got = spn_layer_bound(n, m)
        @test table1_within_tolerance(lp, got)
    end

    # Report passes (n=3 already verified above; keep the report on the fast path).
    @test section7_report(devnull; full_search = false)
end
