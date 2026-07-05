@testset "theorem7_1_test" begin
    include(joinpath(@__DIR__, "..", "theorem7_1.jl"))

    r = theorem7_1_report(devnull; m = 3)
    @test r.all_ok
    @test r.apn_sweep > 0
    @test r.ok_subset
    @test r.ok_equal
end
