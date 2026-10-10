@testset "table2_complexities" begin
    include(joinpath(@__DIR__, "..", "table2.jl"))

    @test length(TABLE2_DIMS) == 11
    for row in (TABLE2_LE, TABLE2_AE, TABLE2_AE_D1, TABLE2_AE_D2, TABLE2_AE_D3)
        @test length(row) == length(TABLE2_DIMS)
    end

    # Every one of the 5 × 11 printed exponents is reproduced exactly.
    for (label, f, printed) in table2_rows()
        @test [table2_exponent(f(n)) for n in TABLE2_DIMS] == printed
    end

    # Spot checks against the closed forms, independent of the row table.
    @test table2_exponent(le_log2(8)) == 8 + 6          # 64 · 2^8 = 2^14
    @test table2_exponent(ae_log2(8)) == 16 + 6         # 64 · 2^16 = 2^22
    @test table2_exponent(ae_nonbijective_log2(8, 1)) == 18
    @test table2_exponent(ae_nonbijective_log2(8, 2)) == 23
    @test table2_exponent(ae_nonbijective_log2(8, 3)) == 29

    # Report passes.
    @test table2_report(devnull)
end
