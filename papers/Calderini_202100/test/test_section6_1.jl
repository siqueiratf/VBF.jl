@testset "section6_1_test" begin
    include(joinpath(@__DIR__, "..", "section6_1.jl"))

    r = section6_1_report(devnull)
    @test r.valid_count > 0
    @test r.ea_classes >= 1
    @test r.new_classes >= 1   # paper claims at least one new CCZ-class
    @test r.all_ok
end
