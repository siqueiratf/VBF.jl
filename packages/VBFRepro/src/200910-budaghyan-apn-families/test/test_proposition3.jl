@testset "proposition3_test" begin
    include(joinpath(@__DIR__, "..", "proposition3.jl"))
    r = proposition3_report(devnull)
    @test r.all_ok
    # Injectivity on E = w+GF(2³) ⊂ GF(2⁶) for the class-3 example.
    @test injective_on_superfield(:class3, 3)
end
