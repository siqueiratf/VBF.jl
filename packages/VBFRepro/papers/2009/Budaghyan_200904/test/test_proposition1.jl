@testset "proposition1_test" begin
    include(joinpath(@__DIR__, "..", "proposition1.jl"))

    r = proposition1_report(devnull; n = 5)
    @test r.du1 ≤ 4                     # (1) F(x)+tr(G(x)) differentially ≤4
    @test r.duAF ≤ 4                    # (2) A∘F with 2-to-1 A is exactly ≤4
    @test r.duFA_off ≤ 4               # (2) F∘A is ≤4 off ker A
    @test r.twoto1
    @test r.all_ok
end
