@testset "theorem4_test" begin
    include(joinpath(@__DIR__, "..", "theorem4.jl"))

    # s=2, n=3 (N=6)
    r = theorem4_verify(2, 3)
    @test r.perm == true
    @test r.du == 4
end
