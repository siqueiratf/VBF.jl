include(joinpath(@__DIR__, "..", "exhaustive_phase2.jl"))
@testset "exact center projection uses pair-major coefficients" begin
    projection_rank, indices, pc, fc, S = build_projection_basis()
    @test projection_rank == 40
    @test length(indices) == length(fc) == 40
    @test length(unique(indices)) == 40
    @test sort(indices) == collect(1:40)
end
