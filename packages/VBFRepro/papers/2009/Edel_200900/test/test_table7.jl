@testset "Edel-Pott Table 7 entry 14.3" begin
    include(joinpath(@__DIR__, "..", "table7.jl"))
    r = table7_report(; io=devnull)
    @test r.differential_uniformity == 2
    @test r.degree == 2
    @test r.gamma_rank == 4046
    @test r.delta_rank == 212
end
