@testset "theorem6_test" begin
    include(joinpath(@__DIR__, "..", "theorem6.jl"))

    modulus = primitive_polynomial(6)
    n       = 6
    gold    = gold_apn(n, 1)
    gold_ws = absolute_walsh_spectrum(gold)

    T1   = dillon_T1(; modulus)
    T2   = dillon_T2()          # built under Conway poly; see dillon_T2 docstring
    F1   = theorem1_sbox(3, 1, [nothing, nothing]; modulus)   # Family 1 trinomial
    F2_0 = theorem3_sbox(2, 1, nothing)                       # Family 2 v=0 (binomial)
    F2_v = theorem3_sbox(2, 1, 21)                            # Family 2 v≠0 (trinomial)

    # Dillon's T2 *is* the Kim function — VBF already exports it, so `dillon_T2`
    # returns the core construction instead of re-deriving the polynomial (Br-7).
    @test T2 == kim_apn()
    @test Int.(T2.lut) == [gf_pow(x, 3, n; modulus = conway_polynomial(6)) ⊻
                           gf_mul(2, gf_pow(x, 24, n; modulus = conway_polynomial(6)), n;
                                  modulus = conway_polynomial(6)) ⊻
                           gf_pow(x, 10, n; modulus = conway_polynomial(6))
                           for x in 0:63]

    # Dillon trinomials are APN
    @test differential_uniformity(T1) == 2
    @test differential_uniformity(T2) == 2

    # Walsh spectrum equality to Gold x^3
    @test absolute_walsh_spectrum(T1)   == gold_ws
    @test absolute_walsh_spectrum(T2)   == gold_ws
    @test absolute_walsh_spectrum(F1)   == gold_ws
    @test absolute_walsh_spectrum(F2_0) == gold_ws
    @test absolute_walsh_spectrum(F2_v) == gold_ws

    # CCZ equivalence claims (n=6, all quadratic APN → CCZ=EA via ortho-derivative)
    @test are_ccz_equivalent(F1,   T1)      # Family 1 ↔ Dillon T1
    @test are_ccz_equivalent(F2_v, T2)      # Family 2 v≠0 ↔ Dillon T2
    @test are_ccz_equivalent(F2_0, gold)    # Family 2 v=0 ↔ Gold (binomial from [2])

    # NOT CCZ-equivalent to Gold (not in the power-mapping CCZ class)
    @test !are_ccz_equivalent(F1,   gold)
    @test !are_ccz_equivalent(F2_v, gold)

    # Dillon T1 and T2 are in distinct CCZ classes
    @test !are_ccz_equivalent(T1, T2)

    # ── Theorem 6 itself (Br-6) ────────────────────────────────────────────────
    all_six = [F1, F2_0, F2_v, T1, T2, gold]

    # Ĥ_f is the (2n+1) × 2ⁿ matrix with columns (1, x, f(x))ᵀ, and Ĉ_f = Null(Ĥ_f)
    # has dimension 2ⁿ − (2n+1) = 51 (the rows are independent for APN f).
    for F in all_six
        @test size(paper_code_matrix(F)) == (13, 64)
        @test code_dimension(F) == (13, 51)
    end

    # The paper's Section 5 remark: the weight distribution of the code is the
    # Walsh spectrum. Rebuilt from `lat` alone and compared with the enumerator.
    for F in all_six
        @test weight_distribution_matches_walsh(F)
    end

    # Forward direction of Theorem 6, constructively: X = [[1,0],[γ,M]] built from
    # the CCZ certificate sends Ĥ_f to a column permutation of Ĥ_g.
    for (F, G) in [(F1, T1), (F2_v, T2), (F2_0, gold)]
        cert = theorem6_forward_certificate(F, G)
        @test cert !== nothing
        X, _ = cert
        @test size(X) == (13, 13)
        @test X[1, 1] == 1 && all(X[1, 2:end] .== 0)
        @test theorem6_forward_holds(F, G)
    end

    # Necessary condition: CCZ-equivalent ⇒ equal code weight enumerators.
    @test code_weight_distribution(F1)   == code_weight_distribution(T1)
    @test code_weight_distribution(F2_v) == code_weight_distribution(T2)
    @test code_weight_distribution(F2_0) == code_weight_distribution(gold)

    # ...and it is only *necessary*. Every function here has the Gold x^3 weight
    # distribution — as the paper reports — so the enumerator cannot separate the
    # CCZ-inequivalent T1 and T2. Deciding the converse needs binary code
    # permutation-equivalence, which VBF does not implement.
    wd_gold = code_weight_distribution(gold)
    @test all(code_weight_distribution(F) == wd_gold for F in all_six)
    @test code_weight_distribution(T1) == code_weight_distribution(T2)
    @test !are_ccz_equivalent(T1, T2)
end
