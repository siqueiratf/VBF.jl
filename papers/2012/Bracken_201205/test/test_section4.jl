@testset "section4_test" begin
    include(joinpath(@__DIR__, "..", "section4.jl"))

    # Lemma 4.1: Σ_{i≤d} r_i x^{2^{si}} = 0 has at most 2^d roots (BTT-11).
    l41 = lemma4_1_check(trials = 8)
    @test l41.ok
    @test length(l41.rows) == 8
    @test all(r -> r.roots ≤ r.bound, l41.rows)

    # Each instance is scanned once and reused (an n=15 Walsh scan is 4.9 s here).
    observed = Dict{Tuple{Int,Int},Vector{Int}}()
    for (k, s, expected, heavy) in SECTION4_CASES
        heavy && continue
        n, t = 3k, gcd(3k, s)
        F = bracken_binomial_sbox(k, s)
        vals = walsh_value_set(F)
        observed[(k, s)] = vals
        @test vals == expected
        if isodd(k ÷ t)
            # Lemma 4.2 is stated for F of Theorem 1.2, i.e. for k/t odd only.
            @test maximum(abs, vals) ≤ walsh_bound(n, t)
        end
    end

    # Theorem 1.1 makes a Walsh SPECTRUM-SET claim, not a bound (BTT-3): the
    # spectrum is a subset of {0, ±2^{n/2}, ±2^{(n+2)/2}}. A bound of the form
    # |F^W| ≤ 2^{(n+t)/2} would not catch a stray ±4, and the set is exactly
    # what Section 5 uses to separate F from the inverse function.
    @test observed[(2, 4)] == [-16, 0, 16]
    @test issubset(Set(observed[(2, 4)]), Set([0, 8, -8, 16, -16]))
    # …and via core absolute_walsh_spectrum, whose support is the absolute set.
    @test first.(sorted_pairs(absolute_walsh_spectrum(bracken_binomial_sbox(2, 4)))) ==
          [0, 16]

    # Scope evidence, asserted as a fact about our grid and NOT as a defect of
    # the paper: on Lemma 2.1's k/t even branch F falls outside Theorem 1.2, and
    # there the Lemma 4.2 bound genuinely fails — which is exactly why
    # section4.jl must not assert the bound on those rows.
    @test maximum(abs, observed[(2, 1)]) > walsh_bound(6, 1)      # 16 > 8
    @test maximum(abs, observed[(4, 2)]) > walsh_bound(12, 2)     # 256 > 128
    @test maximum(abs, observed[(4, 5)]) > walsh_bound(12, 1)     # 128 > 64

    # n=15 (k=5,s=1,t=1): F is AB, spectrum {0,±2^8}; the bound 2^8 is attained.
    @test observed[(5, 1)] == [-256, 0, 256]
    @test maximum(abs, observed[(5, 1)]) == 256 == walsh_bound(15, 1)

    # t = 5 at n = 15: bound 2^{(15+5)/2} = 2^10, attained.
    @test observed[(5, 10)] == [-1024, 0, 1024]
    @test maximum(abs, observed[(5, 10)]) == 1024 == walsh_bound(15, 5)

    # The streaming and full-LAT paths must agree where both are affordable.
    F12 = bracken_binomial_sbox(4, 2)
    @test walsh_value_set(F12; streaming = true) ==
          walsh_value_set(F12; streaming = false)
    @test linearity_rowwise(F12) == linearity(F12)
end
