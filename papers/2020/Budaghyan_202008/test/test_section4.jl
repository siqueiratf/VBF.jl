@testset "section4_test" begin
    include(joinpath(@__DIR__, "..", "section4.jl"))

    r1 = section4_check_theoremIV1()
    @test r1.ok_zero
    @test r1.ok_id
    @test r1.ok_frob

    r2 = section4_check_corollaryIV2()
    @test r2.shifts_equal
    @test r2.shifts_unequal
end
