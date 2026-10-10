@testset "table3_test" begin
    include(joinpath(@__DIR__, "..", "table3.jl"))

    luts = table3_luts()
    degs = table3_degrees()
    eas = table3_ea_exponents()
    cczs = table3_ccz_column()
    mod5 = primitive_polynomial(5)

    @test length(luts) == 7

    # Dropping the stray OCR cell leaves exactly 32 values per row (Paper Issue 2).
    for F in luts
        @test length(F.lut) == 32
        @test differential_uniformity(F) == 2
        # EA-canonical representatives vanish on the affine standard basis.
        @test all(F.lut[b+1] == 0 for b in [0, 1, 2, 4, 8, 16])
    end

    # The paper's degree column.
    @test [algebraic_degree(F) for F in luts] == degs

    # The paper's `EA` column (rows 3 and 4 are the BCP family, not power functions).
    for (i, d) in enumerate(eas)
        d === nothing && continue
        P = SBox{5}(gf_monomial_lut(5, d; modulus = mod5))
        @test are_ea_equivalent(luts[i], P; on_inconclusive = :missing) === true
    end

    # The paper's `CCZ` column: rows 1, 2, 5 are the three CCZ classes.
    reps = [luts[1], luts[2], luts[5]]
    rep_rows = [1, 2, 5]
    for i in 1:7
        j = findfirst(R -> are_ccz_equivalent(luts[i], R; on_inconclusive = :missing) === true,
                      reps)
        @test j !== nothing
        @test rep_rows[j] == cczs[i]
    end

    # Γ-rank separates row 5 (the x¹⁵ / Inverse class) from the other six.
    @test gamma_rank(luts[5]) == 496
    @test all(gamma_rank(luts[i]) == 330 for i in [1, 2, 3, 4, 6, 7])
end
