@testset "section2_test" begin
    include(joinpath(@__DIR__, "..", "section2.jl"))

    # Lemma 2.1: F is a permutation iff k/t is odd, t = gcd(3k, s).
    # The complete feasible grid n = 3k ≤ 15 (12 instances) is exercised, so
    # both branches and every degenerate/genuine shape are covered (BTT-10).
    @test length(SECTION2_CASES) == 12
    for (k, s, expect, degen) in SECTION2_CASES
        t = gcd(3k, s)
        @test isodd(k ÷ t) == expect            # Lemma 2.1 as a prediction
        F = bracken_binomial_sbox(k, s)
        @test is_permutation(F) == expect       # …and as a computation
        @test is_degenerate(bracken_binomial(k, s)) == degen
        @test algebraic_degree(F) == 2          # BTT-11: F is quadratic
    end

    # BTT-11: α = 2 is primitive at every size the paper uses. Orders are
    # 7, 63, 4095, 32767 for n = 3, 6, 12, 15.
    for n in (3, 6, 12, 15)
        @test alpha_is_primitive(n)
    end

    # BTT-6: the constructor now rejects invalid parameters instead of silently
    # returning a LUT. Mirrors what core bcp_apn does.
    @test_throws ArgumentError bracken_binomial_lut(3, 3)    # 3 | k
    @test_throws ArgumentError bracken_binomial_lut(6, 3)    # 3 | k
    @test_throws ArgumentError bracken_binomial_lut(2, 2)    # 3 ∤ (k+s)
    @test_throws ArgumentError bracken_binomial_lut(5, 2)    # 3 ∤ (k+s)
    @test_throws ArgumentError bracken_binomial_lut(0, 3)    # k ≥ 1
    @test_throws ArgumentError bracken_binomial_lut(2, 0)    # s ≥ 1
    # k/t even is Lemma 2.1's non-permutation branch: allowed by default,
    # rejected when the full Theorem 1.2 hypothesis set is demanded.
    @test bracken_binomial(4, 2) isa BrackenBinomial
    @test_throws ArgumentError bracken_binomial(4, 2; allow_nonpermutation = false)
    @test_throws ArgumentError bracken_binomial(2, 1; allow_nonpermutation = false)
    @test bracken_binomial(5, 1; allow_nonpermutation = false) isa BrackenBinomial
    # A non-primitive modulus is rejected: x^6+x^5+x^4+x^2+1 is irreducible but
    # not primitive over GF(2), so α = 2 has order 21, not 63.
    @test !alpha_is_primitive(6; modulus = 0b1110101)
    @test_throws ArgumentError bracken_binomial(2, 4; modulus = 0b1110101)

    # BTT-8: for t = 1 the paper's F is exactly α · core bcp_apn(k, s) — the
    # "obtained by changing certain conditions from [8]" sentence, made explicit.
    for (k, s) in ((5, 1), (5, 4), (4, 5), (2, 1))
        n = 3k
        @test bracken_binomial_lut(k, s) == [gf_mul(2, y, n) for y in bcp_apn(k, s).lut]
    end
    # …and bracken_binomial_lut earns its keep on the t > 1 cases core rejects.
    @test_throws ArgumentError bcp_apn(4, 8)     # t = 4
    @test_throws ArgumentError bcp_apn(5, 10)    # t = 5
    @test bracken_binomial_lut(4, 8) isa Vector{Int}
    @test bracken_binomial_lut(5, 10) isa Vector{Int}
end
