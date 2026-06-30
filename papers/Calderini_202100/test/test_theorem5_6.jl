@testset "theorem5_6_test" begin
    include(joinpath(@__DIR__, "..", "theorem5_6.jl"))

    r = theorem5_6_report(devnull; m = 4)
    @test r.ok_f3
    @test r.ok_f2
    @test r.ok_cor57_f2
    @test r.ok_f1
    @test r.ok_p58
    @test r.all_ok
end
