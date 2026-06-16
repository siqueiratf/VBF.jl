@testset "remark4_test" begin
    include(joinpath(@__DIR__, "..", "remark4.jl"))

    r = remark4_check(; sample_size = 500, seed = 42)
    @test r.violations == 0
    @test r.tested == 500

    # different seed still finds no violations
    r2 = remark4_check(; sample_size = 200, seed = 137)
    @test r2.violations == 0
end
