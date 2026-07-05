@testset "theorem5_4_test" begin
    include(joinpath(@__DIR__, "..", "theorem5_4.jl"))

    # reduced sample count for test speed; seed fixed for reproducibility
    r = theorem5_4_report(devnull; ms = [3, 4], samples = 50)
    @test r.all_ok
    @test r.stats[3].mism == 0
    @test r.stats[4].mism == 0
    @test r.stats[3].apn_n > 0    # structured Taniguchi instance is APN
    @test r.stats[4].apn_n > 0
end
