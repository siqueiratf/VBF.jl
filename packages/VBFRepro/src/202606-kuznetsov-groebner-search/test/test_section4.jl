@testset "section4_test" begin
    include(joinpath(@__DIR__, "..", "section4.jl"))

    r = section4_run(; seed = 42)

    @test r.A5_is_I
    @test r.A1_not_I
    @test r.A2_not_I
    @test r.A3_not_I
    @test r.A4_not_I

    @test r.n_free  == 40
    @test r.n_pivot == 184

    @test r.geometry.rank_intra == 24
    @test r.geometry.rank_center == 168
    @test r.geometry.fiber_dimension == 0
    @test r.geometry.projection_dimension == 40
    @test r.geometry.slice_count == big(2)^40
    @test (r.geometry.free_center, r.geometry.free_intra) == (32, 8)
    c1 = falses(224); c2 = copy(c1)
    c2[slice_center_indices()[100]] = true
    @test slice_identifier(c1) != slice_identifier(c2)
    c2 .= c1; c2[first(slice_intra_indices())] = true
    @test slice_identifier(c1) == slice_identifier(c2)
    @test r.va_zero
    @test r.va_rand
end
