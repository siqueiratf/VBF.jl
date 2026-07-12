@testset "proposition6_test" begin
    include(joinpath(@__DIR__, "..", "proposition6.jl"))

    # n=3: APN butterflies exist (Theorem 1 positive case)
    r3 = proposition6_build(3, 1)
    @test !isempty(r3.apn_pairs)
    @test length(r3.apn_pairs) == 6

    # n=5: no APN butterfly (Prop 6 + Theorem 1 negative case)
    r5 = proposition6_build(5, 1)
    @test isempty(r5.apn_pairs)
    @test r5.rtc_count == 0  # refined trace condition never satisfied

    # n=3, i=2: APN butterflies also exist for the other coprime exponent
    r32 = proposition6_build(3, 2)
    @test length(r32.apn_pairs) == 6

    # n=5: all remaining i with gcd(i,5)=1
    for i in (2, 3, 4)
        r5i = proposition6_build(5, i)
        @test isempty(r5i.apn_pairs)
        @test r5i.rtc_count == 0
    end

    # theorem1_build convenience wrapper
    results = theorem1_build(1; n_values = [3, 5])
    @test length(results) == 2
    r3t = results[1]
    r5t = results[2]
    @test !isempty(r3t.apn_pairs)
    @test isempty(r5t.apn_pairs)

    # --- Theorem 1 beyond n=5, with no LUT at all (R2) ---
    # Proposition 5 makes APN-ness equivalent to the refined trace condition, a
    # 2^n-element check on α. No 2^{2n} LUT is needed, so n=15 is cheap.
    sweep = theorem1_rtc_sweep(; n_values = [3, 5, 7, 9, 11, 13, 15])
    @test all(r.rtc_count == 0 for r in sweep if r.n > 3)
    @test all(r.rtc_count == 3 for r in sweep if r.n == 3)     # the 6-bit APN case
    @test length([r for r in sweep if r.n == 7]) == 6          # i = 1..6, all coprime to 7
    @test length([r for r in sweep if r.n == 15]) == 8         # φ(15) = 8
    @test length(sweep) == 2 + 4 + 6 + 6 + 10 + 12 + 8

    # --- Proposition 6's counting argument (R3) ---
    res3 = proposition6_counting_build(3, 1)
    @test length(res3) == 6                                    # α ∈ GF(8)\{0,1}
    rtc3 = [r for r in res3 if r.rtc]
    non3 = [r for r in res3 if !r.rtc]
    @test length(rtc3) == 3                                    # positive cases exist
    @test length(non3) == 3                                    # negative cases exist

    # Eq (6) and Eq (7) are partition identities: they hold for every α.
    @test all(r.eq6 == 2^3 - 3 && r.eq6_ok for r in res3)      # Σ|preimages| = 5
    @test all(r.eq7 == 2^3 - 4 && r.eq7_ok for r in res3)      # = 4
    @test all(r.c1_preimages == 1 for r in res3)               # c=1 has exactly one preimage
    @test all(!r.zero_in_im for r in res3)                     # 0 ∉ Im(F_D)

    # On the 3 rtc α: |Im|=3, |T|=2, i₁=1, i₃=1, and Eq (8) reads 4 = 1 + 3·1.
    @test all(r.im_size == 3 for r in rtc3)
    @test all(r.imr_size == 2 for r in rtc3)
    @test all(r.t_size == 2 for r in rtc3)
    @test all(r.i1 == 1 && r.i3 == 1 for r in rtc3)
    @test all(r.i1 + 3 * r.i3 == 2^3 - 4 for r in rtc3)        # Eq (8): 4 == 1 + 3·1
    @test all(r.eq8_ok for r in rtc3)
    @test all(r.lemma_ok for r in rtc3)                        # |T| = |Im(F_D)\{0,1}|
    @test all(r.im_bound_ok for r in rtc3)                     # |Im(F_D)| ≤ 2^{n-1} = 4
    @test all(r.s1_bound_ok && r.s3_bound_ok && r.sum_bound_ok for r in rtc3)
    @test all(r.final_bound_ok for r in rtc3)                  # i₁+3i₃ = 4 ≤ 5 = 2^n-(2^{n-1}+5)/3

    # The argument is rtc-DEPENDENT, not a tautology: on the 3 non-rtc α both the
    # lemma and Eq (8) fail. (A hardcoded "always true" would fail this.)
    @test all(!r.lemma_ok for r in non3)
    @test all(!r.eq8_ok for r in non3)

    # n=3, i=2: same picture
    res32 = proposition6_counting_build(3, 2)
    @test count(r.rtc for r in res32) == 3
    @test all(r.lemma_ok && r.eq8_ok for r in res32 if r.rtc)
    @test all(!r.lemma_ok && !r.eq8_ok for r in res32 if !r.rtc)

    # n=5: no α satisfies the rtc, and the rtc-dependent steps fail for every α.
    res5c = proposition6_counting_build(5, 1)
    @test length(res5c) == 30
    @test !any(r.rtc for r in res5c)
    @test all(r.eq6_ok && r.eq7_ok for r in res5c)             # partition identities still hold
    @test !any(r.lemma_ok for r in res5c)
    @test !any(r.eq8_ok for r in res5c)

    # The closing contradiction: Eq (8) says i₁+3i₃ = 2^n-4, the bounds say
    # i₁+3i₃ ≤ 2^n-(2^{n-1}+5)/3. They collide exactly when n > 3.
    @test !prop6_contradiction(3)                              # n=3: 4 ≤ 5, no contradiction
    @test all(prop6_contradiction(n) for n in 5:2:21)

    # α ∈ {0,1} is outside the argument (D = 1/(1+α²) undefined at α=1)
    @test_throws ArgumentError prop6_counting(3, 1, 1)

    # --- Representation independence (R8) ---
    # Non-default modulus for GF(8): x³+x²+1 = 13 instead of the default x³+x+1 = 11.
    # The α values permute, but the counts do not.
    r3m = proposition6_build(3, 1; modulus = 13)
    @test length(r3m.apn_pairs) == 6
    @test r3m.rtc_count == 3
    @test Set(first.(r3m.apn_pairs)) != Set(first.(r3.apn_pairs))   # α really do permute
    res3m = proposition6_counting_build(3, 1; modulus = 13)
    @test count(r.rtc for r in res3m) == 3
    @test all(r.lemma_ok && r.eq8_ok && r.i1 == 1 && r.i3 == 1 for r in res3m if r.rtc)

    # --- Parameter guards (R5) ---
    # n even is outside the paper's hypothesis: proposition6_build(4, 1) used to
    # return a meaningless rtc_count=0 / apn_pairs=[] instead of failing.
    @test_throws AssertionError proposition6_build(4, 1)
    @test_throws AssertionError proposition6_build(9, 3)       # gcd(3,9) = 3 ≠ 1
end
