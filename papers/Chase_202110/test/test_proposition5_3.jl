@testset "proposition5_3_test" begin
    include(joinpath(@__DIR__, "..", "proposition5_3.jl"))

    r = proposition5_3_build(3, 1; samples = 100, seed = 7)
    @test r.n_cond > 0
    @test r.all_ok

    r9 = proposition5_3_build(9, 1; samples = 20, seed = 7)
    @test r9.n_cond > 0
    @test r9.all_ok
end
