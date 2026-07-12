@testset "algorithm1_test" begin
    include(joinpath(@__DIR__, "..", "algorithm1.jl"))
    # n=6: exhaustive search must find exactly 1 EA-class (x³)
    classes = algorithm1_run(6; max_evaluations = 1 << 24)
    classes1 = algorithm1_run(7; max_evaluations = 1 << 24)
    classes1;
    @test length(classes) == 1
    @test differential_uniformity(classes[1]) == 2
    # Round-trip: the found function's QAM has F₂-cyclic structure
    M = quadratic_apn_matrix(classes[1])
    @test has_f2_cyclic_structure(M, 6)
end
