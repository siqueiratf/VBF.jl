@testset "proposition2_test" begin
    include(joinpath(@__DIR__, "..", "proposition2.jl"))
    r = proposition2_report(devnull)
    @test r.all_ok
end
