# Implements bounded Section 3.2 test cases.
# Paper: Baudrin, Galissant and Perrin (2025), "Exploring the Set of APN Functions", BFA 2025
# Section: 3.2 — Implementation and Results
#
# Pseudocode:
#   1. Check fourteen catalog roots and a completed small census fixture.
# VBF API used: differential_uniformity, algebraic_degree
@testset "section32_test" begin
    include(joinpath(@__DIR__, "..", "section32.jl"))
    inputs = section32_inputs()
    @test length(inputs) == 14
    @test count(row -> algebraic_degree(row.function_value) == 2,inputs) == 13
    @test all(row -> differential_uniformity(row.function_value) == 2,inputs)
    result = section32(dimension=4)
    @test result.region_complete
    @test !result.exhaustive
    @test result.crosschecks
    @test result.status === :exact_sample
    @test result.degrees == Dict(2=>1,3=>1)
    @test result.root_distinctness.complete
    @test result.root_distinctness.distinct
    skipped = section32(dimension=4,limit=0)
    @test isempty(skipped.rows)
    @test !skipped.exhaustive
    @test skipped.stop_reason === :inputs
    @test_throws ArgumentError section32(full_search=true)
    @test_throws ArgumentError section32(dimension=7,full_search=true)
end
