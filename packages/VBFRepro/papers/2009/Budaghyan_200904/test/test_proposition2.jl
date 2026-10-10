@testset "proposition2_test" begin
    include(joinpath(@__DIR__, "..", "proposition2.jl"))

    r = proposition2_report(devnull; m = 3)      # n=6
    @test r.ea                                   # F, G EA-equivalent
    @test r.witness                              # explicit L(F)=G witness
    @test r.all_ok
end
