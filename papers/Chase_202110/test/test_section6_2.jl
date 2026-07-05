@testset "section6_2_test" begin
    include(joinpath(@__DIR__, "..", "section6_2.jl"))

    r = section6_2_build(; samples = 3, seed = 42)
    @test r.deg_f == 2
    @test r.deg_g == 5
    @test r.all_apn_perm
    # Degrees live inside the CCZ class of x^3 on F_512: {2, 4, 5} per the
    # paper. A small sample must stay inside that set.
    @test issubset(r.degrees, [2, 4, 5])
end
