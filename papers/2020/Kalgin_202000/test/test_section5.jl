@testset "section5_test" begin
    include(joinpath(@__DIR__, "..", "section5.jl"))

    row1 = first_row_n7()
    @test row1 == [0, 1, 2, 4, 8, 16, 32]

    cases = second_row_cases_n7()
    @test length(cases) == 5

    # Each case: M[2,1] must equal M[1,2] = 1 (symmetry)
    for (row2, _) in cases
        @test row2[1] == row1[2]   # M[2,1] == M[1,2] == 1
        @test row2[2] == 0         # diagonal is zero
    end

    # Count arithmetic: 3+2+0+220+263 = 488
    total = sum(count for (_, count) in cases)
    @test total == 488

    # Individual counts
    counts = [c for (_, c) in cases]
    @test counts == [3, 2, 0, 220, 263]

    # Compatibility check passes for all cases
    for (row2, _) in cases
        @test first_two_rows_compatible(row1, row2)
    end

    # Gold n=7 is a quadratic APN (exists within the 488 classes)
    g7 = gold_apn(7)
    @test differential_uniformity(g7) == 2
    @test algebraic_degree(g7) == 2
end
