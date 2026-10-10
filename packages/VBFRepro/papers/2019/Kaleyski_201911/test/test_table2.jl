@testset "table2_test" begin
    include(joinpath(@__DIR__, "..", "helpers.jl"))
    include(joinpath(@__DIR__, "..", "table2.jl"))

    # Formula (34) spot-checks against known values from Table 2 in the paper
    # n=5 (odd): 2*(2^4 - 1) = 30
    @test formula34(5) == 30
    # n=6 (even, 6/2=3 odd): 2*(2^5 + 2^3 - 1) = 2*39 = 78
    @test formula34(6) == 78
    # n=7 (odd): 2*(2^6 - 1) = 126
    @test formula34(7) == 126
    # n=8 (even, 8/2=4 even): 2*(2^7 - 2^4 - 1) = 2*111 = 222
    @test formula34(8) == 222
    # n=1 (odd): 2*(1 - 1) = 0
    @test formula34(1) == 0
    # n=2 (even, 2/2=1 odd): 2*(2 + 2 - 1) = 6
    @test formula34(2) == 6

    # DDT matches formula for small n
    r = table2_report(; n_max_ddt = 7, n_max_formula = 8, io = devnull)
    @test r.all_match
    # Spot-check a specific row
    row5 = only(filter(r -> r.n == 5, r.rows))
    @test row5.s1_formula == 30
    @test !ismissing(row5.s1_ddt) && row5.s1_ddt == 30
end
