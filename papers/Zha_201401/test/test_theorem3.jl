@testset "theorem3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3.jl"))

    # s=1, n=2 (N=2): n/2=1 odd → Δ_f = 4
    r = theorem3_verify(1, 2)
    @test r.perm == true
    @test r.du == r.expected

    # s=1, n=4 (N=4): n/2=2 even → Δ_f = 6
    r = theorem3_verify(1, 4)
    @test r.perm == true
    @test r.du == r.expected

    # s=1, n=6 (N=6): n/2=3 odd → Δ_f = 4
    r = theorem3_verify(1, 6)
    @test r.perm == true
    @test r.du == r.expected

    # s=3, n=2 (N=6): s=3, n/2=1 odd → Δ_f = 4
    r = theorem3_verify(3, 2)
    @test r.perm == true
    @test r.du == r.expected

    # s=1, n=8 (N=8): n/2=4 even → Δ_f = 6
    r = theorem3_verify(1, 8)
    @test r.perm == true
    @test r.du == r.expected
end
