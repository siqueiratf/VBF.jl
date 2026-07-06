@testset "theorem2_test" begin
    include(joinpath(@__DIR__, "..", "theorem2.jl"))

    # s=1, n=3 (N=3)
    r = theorem2_verify(1, 3)
    @test r.perm == true
    @test r.du == 4

    # s=1, n=5 (N=5)
    r = theorem2_verify(1, 5)
    @test r.perm == true
    @test r.du == 4

    # s=1, n=7 (N=7)
    r = theorem2_verify(1, 7)
    @test r.perm == true
    @test r.du == 4

    # s=3, n=3 (N=9)
    r = theorem2_verify(3, 3)
    @test r.perm == true
    @test r.du == 4
end
