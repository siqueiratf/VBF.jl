@testset "section4_self_equivalences" begin
    include(joinpath(@__DIR__, "..", "section4.jl"))

    # Fast path (full_search=false) always returns true.
    @test section4_report(devnull; full_search = false)

    # Smoke test: self_affine_equivalences on a small (n=5) permutation APN gives ≥1 result (identity).
    # Gold x^3 over GF(2^5): gcd(3,31)=1 so it IS a permutation.
    g3_n5 = load_apn_function("n5_Gold_x3")
    se = self_affine_equivalences(g3_n5)
    @test length(se) >= 1
end
