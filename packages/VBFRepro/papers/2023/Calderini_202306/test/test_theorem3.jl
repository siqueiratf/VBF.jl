@testset "theorem3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3.jl"))

    results = theorem3_build()
    @test length(results) == 3

    for r in results
        # Lemma 1(i): no-root preserved under squaring
        @test r.lem_i
        # Lemma 1(ii): no-root <=> linear map is permutation
        @test r.lem_ii
        # Theorem 3: F1 is APN (du=2)
        @test r.apn
    end

    # Key case: m=3 (3|m), k=1 — novel case not covered by Gologlu F1
    m3 = findfirst(r -> r.m == 3 && r.k == 1, results)
    @test m3 !== nothing
    @test results[m3].apn

    # Standard case: m=4, k=1
    m4k1 = findfirst(r -> r.m == 4 && r.k == 1, results)
    @test m4k1 !== nothing
    @test results[m4k1].apn

    # Different k: m=4, k=3
    m4k3 = findfirst(r -> r.m == 4 && r.k == 3, results)
    @test m4k3 !== nothing
    @test results[m4k3].apn
end
