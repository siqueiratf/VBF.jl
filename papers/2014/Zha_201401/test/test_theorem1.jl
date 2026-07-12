@testset "theorem1_test" begin
    include(joinpath(@__DIR__, "..", "theorem1.jl"))

    # s=2, n=2 (N=4) — smallest case
    r = theorem1_verify(2, 2)
    @test r.perm == true
    @test r.du == 4

    # s=2, n=3 (N=6)
    r = theorem1_verify(2, 3)
    @test r.perm == true
    @test r.du == 4
end
