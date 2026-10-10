@testset "algorithm1_test" begin
    include(joinpath(@__DIR__, "..", "algorithm1.jl"))

    # quadratic_apn_search on n=4: must find at least one solution in bounded time.
    solutions = quadratic_apn_search(4; max_solutions = 1, seed = 42, timeout_seconds = 60.0)
    @test !isempty(solutions)

    f = first(solutions)
    @test differential_uniformity(f) == 2  # APN
    @test algebraic_degree(f) == 2         # quadratic
    @test f.lut[1] == 0                    # F(0) = 0 is always fixed

    # All solutions returned must satisfy both constraints.
    sols3 = quadratic_apn_search(4; max_solutions = 3, seed = 7, timeout_seconds = 60.0)
    for s in sols3
        @test differential_uniformity(s) == 2
        @test algebraic_degree(s) == 2
        @test s.lut[1] == 0
    end
end
