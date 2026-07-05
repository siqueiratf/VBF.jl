@testset "section6_1_test" begin
    include(joinpath(@__DIR__, "..", "section6_1.jl"))

    r = section6_1_build(; drift_samples = 2)
    @test r.n_enumerated == 64
    @test r.n_perm_half == 32
    @test r.n_xs_half == 32
    @test r.disjoint
    @test r.covered
    @test r.n_thick_full == 32
    @test r.orbit43_size == 31
    @test r.orbitxs_size == 31
    @test r.orbits_cover && r.fixed_trivial
    @test r.twists_constant
    @test r.drift_ok
    @test r.lower_bound_3
    @test r.merge_quad && r.merge_inv && r.merge_43
    @test r.n_ea_classes == 3
    # x^3 has degree 2; the other two classes are cubic (x^{1/3} = x^{21}
    # has a weight-3 exponent; the third class is a non-permutation class).
    @test r.class_degrees == [2, 3, 3]
    @test r.xs_nonpermutation
end
