@testset "theorem7_test" begin
    include(joinpath(@__DIR__, "..", "theorem7.jl"))

    # Fast n=6 path only (Corollary 8 n=7 ranks are opt-in / heavy).
    r = theorem7_report(devnull; full_search = false)
    @test r.bound6 == 128
    @test r.all_quad_ok                          # every quadratic rep has Δ ≤ 128
    @test isempty(r.cor8)                        # n=7 not run by default

    # The non-crooked witness: 2.11 Δ-rank exceeds 2^(n+1).
    rep211 = only(x.sbox for x in edelpott_table5() if x.name == "2.11")
    @test delta_rank(rep211) == 152
    @test delta_rank(rep211) > r.bound6
end
