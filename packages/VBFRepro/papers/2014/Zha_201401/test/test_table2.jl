@testset "table2_test" begin
    include(joinpath(@__DIR__, "..", "table2.jl"))

    # Row 1: Example 1 over F_{2^4}
    r1 = table2_row1()
    @test r1.nl == 4
    @test r1.du == 4
    @test r1.deg == 3
    ds1 = Dict(v => c for (v, c) in sorted_pairs(r1.ds))
    @test ds1 == Dict(0=>135, 2=>90, 4=>15)

    # Row 2: Theorem 4 over F_{2^6}, t₂=0
    # Paper spectrum {0^2127,2^1794,4^111} is a likely typo (matches Construction 1)
    r2 = table2_row2()
    @test r2.nl == 22
    @test r2.du == 4
    @test r2.deg == 5
    ds2 = Dict(v => c for (v, c) in sorted_pairs(r2.ds))
    @test ds2 == Dict(0=>2151, 2=>1746, 4=>135)

    # Row 3: Theorem 4 over F_{2^6}, t₂≠0
    r3 = table2_row3()
    @test r3.nl == 22
    @test r3.du == 4
    @test r3.deg == 5
    ds3 = Dict(v => c for (v, c) in sorted_pairs(r3.ds))
    @test ds3 == Dict(0=>2103, 2=>1842, 4=>87)
end
