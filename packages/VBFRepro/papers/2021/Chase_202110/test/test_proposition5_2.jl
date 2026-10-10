@testset "proposition5_2_test" begin
    include(joinpath(@__DIR__, "..", "proposition5_2.jl"))

    r = proposition5_2_build(3, 1; samples = 100, seed = 7)
    @test r.n_cond > 0
    @test r.all_ok

    r9 = proposition5_2_build(9, 1; samples = 20, seed = 7)
    @test r9.n_cond > 0
    @test r9.all_ok
end
