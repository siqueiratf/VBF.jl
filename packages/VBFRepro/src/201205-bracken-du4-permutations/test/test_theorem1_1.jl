@testset "theorem1_1_test" begin
    include(joinpath(@__DIR__, "..", "theorem1_1.jl"))

    # BTT-1: Theorem 1.1's headline is no longer declared out of scope. Its
    # smallest GENUINE (non-degenerate) instance is n = 30, (k,s) = (10,2), and
    # both halves are reachable — the differential one exactly, the permutation
    # one under an explicit budget.

    # Core PRIMITIVE_POLYNOMIALS stops at n = 16, so n = 30 needs a local entry;
    # α = 2 must be primitive under it, which Theorem 1.1 requires.
    @test paper_modulus(30) == 1073741907            # x^30+x^6+x^4+x+1
    @test paper_modulus(15) == primitive_polynomial(15)
    @test alpha_is_primitive(30)
    # 2^30 − 1 = 3²·7·11·31·151·331
    @test 9 * 7 * 11 * 31 * 151 * 331 == (1 << 30) - 1

    F = theorem1_1_instance()
    @test F.n == 30 && F.t == 2 && isodd(F.k ÷ F.t)
    @test iseven(F.k) && isodd(F.k ÷ 2) && mod(F.k, 3) != 0   # Theorem 1.1 hypotheses
    @test gcd(3 * F.k, F.s) == 2 && mod(F.k + F.s, 3) == 0
    @test !is_degenerate(F)                          # a TRUE binomial, unlike n=6
    @test (F.e1, F.e2) == (5, (1 << 20) + (1 << 12))

    # Differential half. F is quadratic, so B_a is linear and every DDT entry of
    # row a is 0 or 2^{dim ker B_a}. dim ker B_a = t = 2 therefore certifies
    # Δ_F = 4 and differential spectrum {0,4} on every sampled row — exactly
    # Theorem 1.1 / Lemma 3.1, with no DDT and no 2^30-entry LUT.
    r = derivative_kernel_dims(F; samples = 500)
    @test r.dims == [2]
    @test r.samples == 500
    @test !r.exhaustive                              # sampled, not proved, and said so

    # The same criterion agrees with the exact answer where an exact answer is
    # affordable: at n = 15 the kernel dimension equals log2 of the measured
    # differential uniformity, for every a.
    for (k, s, du) in ((5, 1, 2), (4, 8, 16), (2, 4, 4))
        Fs = bracken_binomial(k, s)
        rs = derivative_kernel_dims(Fs; full_search = true)
        @test rs.exhaustive
        @test rs.dims == [Int(log2(du))]
        @test 1 << rs.dims[1] == differential_uniformity(bracken_binomial_sbox(k, s))
    end

    # Permutation half: budgeted per the AGENTS.md rule on expensive searches.
    # The default path scans a prefix; full_search = true would scan all 2^30
    # (~55 min extrapolated on this machine) and is NOT run here.
    p = streaming_permutation_check(F; limit = 1 << 16)
    @test p.injective
    @test p.scanned == 1 << 16
    @test !p.full_domain                             # partial, and reported as such
    @test !p.conclusive
    @test p.collision == -1

    # The budgeted scan is honest on small inputs too: at n = 12, (4,2) is a
    # non-permutation and the scan must find the collision and say so.
    F12 = bracken_binomial(4, 2)
    p12 = streaming_permutation_check(F12; full_search = true)
    @test !p12.injective && p12.conclusive && p12.collision > 0
    F6 = bracken_binomial(2, 4)
    p6 = streaming_permutation_check(F6; full_search = true)
    @test p6.injective && p6.full_domain && p6.conclusive && p6.scanned == 64
end
