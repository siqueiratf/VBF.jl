@testset "section4_coverage_test" begin
    include(joinpath(@__DIR__, "..", "section4_coverage.jl"))

    r3 = section4_coverage_build(3, 1)
    @test r3.all_wz
    @test r3.covered === true
    @test r3.methods_agree === true   # stratified == LAT subspace search

    r5 = section4_coverage_build(5, 1)
    @test r5.all_wz
    @test r5.covered === true
    @test r5.methods_agree === true
    @test r5.n_constructed == 64      # matches Section 6.1

    # n = 7 via the Prop 3.1 stratified enumeration (generic search is
    # infeasible there): 256 = Z_a0, Z_0b, 127 X × S, 127 subfield spaces.
    r7 = section4_coverage_build(7, 1; enumerate = :stratified)
    @test r7.all_wz
    @test r7.covered === true
    @test r7.n_enumerated == 256

    # Generation-side only mode.
    r5g = section4_coverage_build(5, 1; enumerate = :none)
    @test r5g.all_wz
    @test r5g.covered === missing
end
