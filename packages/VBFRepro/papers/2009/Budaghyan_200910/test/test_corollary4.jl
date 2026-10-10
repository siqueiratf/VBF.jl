@testset "corollary4_test" begin
    include(joinpath(@__DIR__, "..", "corollary4.jl"))
    # Default (no full_search): APN + ortho-derivative CCZ checks only.
    r = corollary4_report(devnull; full_search = false)
    @test r.all_ok
    @test r.pairwise          # (6),(7),(8) pairwise CCZ-distinct at n=9
    @test r.vs_gold           # (7),(8) CCZ-distinct from Gold family at n=9
    @test r.vs_known_full === missing   # heavy path gated off by default

    # eqs (7),(8) APN quadratic at n=9.
    @test differential_uniformity(as_sbox(apn_eq7(9, 1), 9)) == 2
    @test differential_uniformity(as_sbox(apn_eq8(9, 1), 9)) == 2
end
