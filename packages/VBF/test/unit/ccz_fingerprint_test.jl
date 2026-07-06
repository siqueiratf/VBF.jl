@testitem "ccz_fingerprint" begin
    using VBF
    using VBFCatalog
    using Test

    # Kim (quadratic, degree 2) and the Dillon permutation (degree 4) are
    # CCZ-equivalent. A sound CCZ-invariant fingerprint must give them the SAME
    # hash despite the different algebraic degree.
    K = kim_apn()
    D = dillon_apn_permutation()
    @test are_ccz_equivalent(K, D)
    @test algebraic_degree(K) == 2
    @test algebraic_degree(D) == 4
    @test ccz_fingerprint_hash(K) == ccz_fingerprint_hash(D)      # soundness

    # Regression guarding the soundness ledger: the invariants deliberately
    # EXCLUDED from the key differ on this CCZ-equivalent pair, so including any
    # of them would make the fingerprint unsound (false "novel" verdicts).
    @test algebraic_degree(K) != algebraic_degree(D)
    @test sorted_pairs(sigma_multiplicities(K)) != sorted_pairs(sigma_multiplicities(D))

    # Discrimination: distinct CCZ classes get distinct fingerprints (here via
    # Γ-rank at n = 6). Gold x^3 is not CCZ-equivalent to Kim.
    @test !are_ccz_equivalent(gold_apn(6, 1), K)
    @test ccz_fingerprint_hash(gold_apn(6, 1)) != ccz_fingerprint_hash(K)

    # Determinism.
    @test ccz_fingerprint_hash(kim_apn()) == ccz_fingerprint_hash(K)

    # Tiering: n ≤ 7 carries Γ/Δ-rank (tier 1); n ≥ 8 omits them (tier 2) and
    # must not touch the design-rank guard. The (N, tier) prefix keeps keys from
    # different dimensions/tiers incomparable.
    @test ccz_fingerprint_key(K)[1:2] == (6, 1)
    kt = ccz_fingerprint_key(inverse_apn(9))         # non-quadratic APN, n = 9
    @test kt[1:2] == (9, 2)
    @test length(kt) == 4                            # (N, tier, diff-spec, abs-Walsh)
end
