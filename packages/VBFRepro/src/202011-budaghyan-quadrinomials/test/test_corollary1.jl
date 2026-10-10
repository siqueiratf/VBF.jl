@testset "corollary1_test" begin
    include(joinpath(@__DIR__, "..", "corollary1.jl"))

    n = 10
    items = corollary1_items(n)
    @test length(items) == 8
    @test [it.item for it in items] == collect(1:8)

    # ── Items 1-7: the paper's claim holds (APN over GF(2^10)) ────────────────
    for it in items
        it.erratum && continue
        @test corollary1_du(it; n) == 2
    end

    # Item 1 IS the binomial B(x) = x^3 + β·x^36 of Edel–Kyureghyan–Pott, i.e. the
    # (a,b,c) = (β,0,0) corner of the family. build_ci_sbox must be able to express
    # it — the whole point of generalising the (a,b,c) coefficients.
    β, β² = beta_in_gfn(10)
    B = build_ci_sbox(10, 3, 2; b = 0, c = 0)
    @test differential_uniformity(B) == 2
    @test algebraic_degree(B) == 2
    # Rebuilt independently of build_ci_sbox, straight from the paper's Table III
    # row "B(x) = x^3 + α^341 x^36":
    mod10 = primitive_polynomial(10)
    B_ref = SBox{10}(terms_to_lut([(1, 3), (gf_pow(2, 341, 10; modulus = mod10), 36)], 10, mod10))
    @test B == B_ref
    @test β == gf_pow(2, 341, 10; modulus = mod10)   # β = α^341 under 0x409

    # ── Item 8: PAPER ERRATUM ────────────────────────────────────────────────
    # The paper claims (a,b,c)=(β,β²,1), i = n-1, k odd is APN. It is not.
    item8 = items[8]
    @test item8.erratum
    @test (item8.i, item8.k) == (n - 1, 1)
    @test corollary1_du(item8; n) == 32          # du = 32, wildly non-APN
    # Independent of k's particular odd value:
    @test differential_uniformity(build_ci_sbox(10, 9, 1; a = β, b = β², c = 1)) == 32
    @test differential_uniformity(build_ci_sbox(10, 9, 3; a = β, b = β², c = 1)) == 32
    # The even-k sibling (item 5, same i = n-1) IS APN — so the error is exactly
    # the odd-k carry-over, matching Lemma 4's omission of n-1.
    @test corollary1_du(items[5]; n) == 2
    @test items[5].i == n - 1 && iseven(items[5].k)

    # ── Non-vacuity of the erratum check ─────────────────────────────────────
    # Not every (i, k odd) is non-APN, so "du != 2" is not trivially satisfied:
    # items 6 and 7 (odd k) are APN.
    @test all(corollary1_du(items[j]; n) == 2 for j in (6, 7))
    @test all(isodd(items[j].k) for j in (6, 7, 8))

    # At n = 14 (m=7) the item-8 erratum reproduces: still not APN.
    β14, β²14 = beta_in_gfn(14)
    @test differential_uniformity(build_ci_sbox(14, 13, 1; a = β14, b = β²14, c = 1)) != 2
    # ...while items 2/3/4 (even k) remain APN at n=14.
    items14 = corollary1_items(14)
    @test all(it -> it.item != 1, items14)   # item 1 is an n=10-only statement
    for it in items14
        it.erratum && continue
        iseven(it.k) || continue
        @test corollary1_du(it; n = 14) == 2
    end
end
