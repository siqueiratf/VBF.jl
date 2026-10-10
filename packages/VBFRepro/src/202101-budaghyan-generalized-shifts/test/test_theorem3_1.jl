@testset "theorem3_1_test" begin
    include(joinpath(@__DIR__, "..", "theorem3_1.jl"))

    # Table 1 (n=8): spot-check rows 1, 2, 12
    n8 = table1_build()
    @test n8[1].apn   # row 1: equiv no. 9 in [19]
    @test n8[2].apn   # row 2: equiv 1.2
    @test n8[12].apn  # row 12: equiv 1.3

    # Table 3 (n=9): spot-check rows 1 (eq to [6]), 12 (eq to 8.1), 17 (i=4)
    n9 = table3_build()
    @test n9[1].apn    # row 1: eq. to APN in [6]
    @test n9[12].apn   # row 12: eq. to 8.1
    @test n9[17].apn   # row 17: i=4, new

    # All entries APN
    @test all(e.apn for e in n8)
    @test all(e.apn for e in n9)
end
