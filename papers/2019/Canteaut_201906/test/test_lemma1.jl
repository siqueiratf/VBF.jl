@testset "lemma1_test" begin
    include(joinpath(@__DIR__, "..", "lemma1.jl"))

    r3 = lemma1_build(3, 1)
    @test r3.all_zero
    @test r3.n_counterex == 0
    # α=1 has β₂=0 (not iterated), so all 7 betas valid; other 6 α skip one β₂ each
    @test r3.n_pairs == 7 + 6 * 6  # = 43
    # the Lemma 1 *statement* formula, its middle form and the simplified form agree
    @test r3.forms_agree
    @test r3.n_form_mismatch == 0

    r5 = lemma1_build(5, 1)
    @test r5.all_zero
    @test r5.forms_agree
    # α=1 has β₂=0, so 31 betas valid; other 30 α skip one β₂ each
    @test r5.n_pairs == 31 + 30 * 30  # = 931

    # i=2 spot check (gcd(2,5)=1)
    r5i2 = lemma1_build(5, 2)
    @test r5i2.all_zero
    @test r5i2.forms_agree

    # The three forms of B_{α,β} on a concrete pair (α=3, β=5 at n=3, i=1):
    # statement formula == λ^{q-1}(λ+Q)/Q^q == p^q + p^{q-1}, and B ≠ 0 there,
    # so the agreement is not the trivial 0 == 0.
    B_stmt, B_mid, B_simp = lemma1_B(3, 1, 3, 5)
    @test B_stmt == B_mid == B_simp
    @test B_stmt != 0
    @test gf_trace(gf_pow(B_stmt, tau_exp(3, 1), 3), 3) == 0

    # α=1 (λ_α = 0) is the degenerate B = 0 case
    @test lemma1_B(3, 1, 1, 5) == (0, 0, 0)

    # β = β₂ makes Q_α(β) = 0 and B undefined — the lemma excludes it
    _, b2 = beta_pair(3, 1, 3)
    @test_throws ArgumentError lemma1_B(3, 1, 3, b2)

    # Representation independence (R8): non-default modulus for GF(8), x³+x²+1
    r13 = lemma1_build(3, 1; modulus = 13)
    @test r13.all_zero
    @test r13.forms_agree
    @test r13.n_pairs == 43
end
