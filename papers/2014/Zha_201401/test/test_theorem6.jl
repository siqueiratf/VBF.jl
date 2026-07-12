@testset "theorem6_test" begin
    include(joinpath(@__DIR__, "..", "theorem6.jl"))

    # s=2, n=2 (N=4)
    r = theorem6_verify(2, 2)
    @test r.perm == true
    @test r.du <= 6

    # s=2, n=3 (N=6)
    r = theorem6_verify(2, 3)
    @test r.perm == true
    @test r.du <= 6
end
