include(joinpath(@__DIR__, "..", "theorem1.jl"))

@testset "Yu_201411 - Theorem 1 correspondence" begin
    for n in (4, 5)
        r = theorem1_case(n)
        @test r.gold_differential_uniformity == 2
        @test r.gold_algebraic_degree == 2
        @test r.matrix_symmetric_zero_diagonal
        @test r.matrix_is_qam
        @test r.round_trip
        @test r.homogeneous_is_qam
        @test r.homogeneous_differential_uniformity == 2
        @test r.homogeneous_algebraic_degree == 2
        @test r.overall
    end

    z = theorem1_zero_matrix_case(4)
    @test z.matrix_not_qam
    @test z.homogeneous_not_apn
    @test z.overall
end
