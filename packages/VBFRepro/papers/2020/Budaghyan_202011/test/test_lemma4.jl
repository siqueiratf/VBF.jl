@testset "lemma4_test" begin
    include(joinpath(@__DIR__, "..", "lemma4.jl"))

    n = 10; m = 5

    # Lemma 4 (tex:433), odd k: i ∈ {m+2, m, (m+2)^-1 mod n} = {7, 5, 3}
    pairs = lemma4_i_values(n)
    @test [last(p) for p in pairs] == [m + 2, m, invmod(m + 2, n)]
    @test sort([last(p) for p in pairs]) == [3, 5, 7]

    for k in (1, 3), (_, i) in pairs
        @test system_Ei_trivial(n, i; k)
        @test differential_uniformity(build_ci_sbox(n, i, k)) == 2
    end

    # Lemma 4's list DIFFERS from Theorem 2's: it drops i = n-1 and swaps m-2 for
    # m+2. Both facts are load-bearing — see the Corollary 1 item 8 erratum.
    @test 9 ∉ [last(p) for p in pairs]          # n-1 = 9 is absent
    @test sort([last(p) for p in pairs]) != [3, 5, 7, 9]

    # The exclusion of i = n-1 is real, not an oversight: tex:446 says the odd-k
    # system DOES admit non-trivial solutions there, and the resulting C is not APN.
    for k in (1, 3)
        @test !system_Ei_trivial(n, n - 1; k)
        @test differential_uniformity(build_ci_sbox(n, n - 1, k)) == 32
    end

    # Non-vacuity: at odd k the trivial-E_i set is not all of 1..9 — exactly four
    # values are APN ({1,3,5,7}), of which Lemma 4 covers three.
    apn_odd = [i for i in 1:n-1 if differential_uniformity(build_ci_sbox(n, i, 1)) == 2]
    @test apn_odd == [1, 3, 5, 7]
    @test issubset(Set(last(p) for p in pairs), Set(apn_odd))

    # Hypothesis guard
    @test_throws ErrorException lemma4_i_values(12)  # m=6, even
end
