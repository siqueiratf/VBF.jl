@testset "section3_test" begin
    include(joinpath(@__DIR__, "..", "section3.jl"))
    # Literal Table 2 coefficients: distinguish power indices from values.
    cases = Dict(r.family => r.sbox for r in table2_n12_instances())
    @test cases["8"] == SBox{12}(terms_to_lut([(1328,768),(2,33),(1,257),(3747,544)],12,4179))
    @test cases["8W"] == SBox{12}(terms_to_lut([(1328,768),(2,33),(1,257)],12,4179))
    @test cases["7"] == SBox{12}(terms_to_lut([(1328,768),(2,33),(3747,544)],12,4179))

    modulus6 = primitive_polynomial(6)

    # ── n=6 Δ-rank distinguishes Family 1 from Families 7/8W/8 ─────────────
    # Paper Section 3: "n=6 distinguishes Family 1 from the others."
    cases6 = table2_n6_instances()
    dr = Dict(c.family => delta_rank(c.sbox) for c in cases6)

    @test dr["1"] != dr["7"]    # Family 1 CCZ-inequivalent to others at n=6
    @test dr["7"] == dr["8W"]   # Families 7 and 8W CCZ-equivalent to same function at n=6
    @test dr["7"] == dr["8"]    # Family 8 also CCZ-equivalent to same function at n=6

    # Paper: Family 1 at n=6 is CCZ-equivalent to Gold x^3
    gold6_dr = delta_rank(gold_apn(6, 1))
    @test dr["1"] == gold6_dr

    # ── n=12 Table 2 — APN only (Δ-rank out-of-scope) ──────────────────────
    cases12 = table2_n12_instances()
    for c in cases12
        @test differential_uniformity(c.sbox) == 2
    end

    # ── Table 3 loaded values encode paper's CCZ-inequivalence claims ───────
    @test TABLE3_PAPER_DELTA_RANKS_N12["Family 7"]  == TABLE3_PAPER_DELTA_RANKS_N12["Family 8W"]
    @test TABLE3_PAPER_DELTA_RANKS_N12["Family 7"]  == TABLE3_PAPER_DELTA_RANKS_N12["Family 8"]
    @test TABLE3_PAPER_DELTA_RANKS_N12["Family 1"]  != TABLE3_PAPER_DELTA_RANKS_N12["Family 7"]
    @test TABLE3_PAPER_DELTA_RANKS_N12["Gold x^3"]  != TABLE3_PAPER_DELTA_RANKS_N12["Family 7"]
    @test TABLE3_PAPER_DELTA_RANKS_N12["Gold x^33"] == TABLE3_PAPER_DELTA_RANKS_N12["Gold x^3"]
end
