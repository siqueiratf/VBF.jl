@testset "theorem4_test" begin
    include(joinpath(@__DIR__, "..", "theorem4.jl"))

    # Lemma 2 (Williams [30]): exhaustive root-count trichotomy for z^3+az+b
    for m in LEMMA2_CASES
        r2 = lemma2_build(m)
        @test r2.ok
        @test r2.checked == (1 << m) * ((1 << m) - 1)
        # every pair lands in a 0/1/3-root case, never 2
        @test sum(values(r2.tallies)) == r2.checked
    end

    results = theorem4_build()
    @test length(results) == 2

    for r in results
        # Lemma 3(i): tr_m(1/alpha^2) = tr_m(1)
        @test r.lem_i
        # Lemma 3(ii): equation (5) has unique solution (alpha, 1)
        @test r.lem_ii
        # Theorem 4: F2 is APN (du=2)
        @test r.apn
    end

    # Key case: m=3 (3|m) — novel case not covered by Li et al. [28]
    m3 = findfirst(r -> r.m == 3, results)
    @test m3 !== nothing
    @test results[m3].apn

    # Standard case: m=4 (gcd(3,4)=1)
    m4 = findfirst(r -> r.m == 4, results)
    @test m4 !== nothing
    @test results[m4].apn
end
