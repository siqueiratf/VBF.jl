@testset "table3_test" begin
    include(joinpath(@__DIR__, "..", "table3.jl"))

    # n=4 example
    F4 = stacked_n4()
    F4q = stacked_n4_quadpart()
    @test differential_uniformity(F4) == 2
    @test algebraic_degree(F4) == 3
    @test differential_uniformity(F4q) == 2
    @test algebraic_degree(F4q) == 2
    @test quadratic_part(F4) == F4q
    @test F4 != F4q

    # n=5 example
    F5 = stacked_n5()
    F5q = stacked_n5_quadpart()
    @test differential_uniformity(F5) == 2
    @test algebraic_degree(F5) == 3
    @test differential_uniformity(F5q) == 2
    @test algebraic_degree(F5q) == 2
    @test quadratic_part(F5) == F5q
    @test F5 != F5q

    # n=6 example
    F6 = stacked_n6()
    F6q = stacked_n6_quadpart()
    @test differential_uniformity(F6) == 2
    @test algebraic_degree(F6) == 3
    @test differential_uniformity(F6q) == 2
    @test algebraic_degree(F6q) == 2
    @test quadratic_part(F6) == F6q
    @test F6 != F6q
end
