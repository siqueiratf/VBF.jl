@testset "section7_test" begin
    include(joinpath(@__DIR__, "..", "section7.jl"))

    luts = table5_luts()
    ranks = table5_gamma_ranks()

    @test length(luts) == 14
    @test length(table5_prefix()) == 33
    @test all(length(t) == 31 for t in table5_tails())

    for (i, F) in enumerate(luts)
        # prefix ++ tail is a full 64-value LUT (Paper Issue 3).
        @test length(F.lut) == 64
        @test differential_uniformity(F) == 2
        # All 14 Γ-ranks reproduce the paper's Γ-rank row.
        @test gamma_rank(F) == ranks[i]
    end

    # Row 3 is the power-function class (the paper's `x^3` entry).
    @test are_ccz_equivalent(luts[3], gold_apn(6, 1); on_inconclusive = :missing) === true

    # Row 13 — the class the paper reports as new — is the only degree-3 row and
    # carries a Γ-rank found nowhere else in the table, so it is CCZ inequivalent
    # to the other 13 by a CCZ invariant.
    @test algebraic_degree(luts[13]) == 3
    @test all(algebraic_degree(luts[i]) == 2 for i in 1:14 if i != 13)
    @test count(==(1300), [gamma_rank(F) for F in luts]) == 1
    @test delta_rank(luts[13]) == 152
end
