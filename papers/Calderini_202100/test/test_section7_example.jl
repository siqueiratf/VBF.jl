@testset "section7_example_test" begin
    include(joinpath(@__DIR__, "..", "section7_example.jl"))

    r = section7_example_report(devnull)
    @test r.all_ok
    @test r.deg_F == 2
    @test r.deg_Fp > 2
end
