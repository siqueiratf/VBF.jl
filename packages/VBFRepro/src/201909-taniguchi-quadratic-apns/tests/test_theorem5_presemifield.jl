@testset "theorem5_presemifield_test" begin
    include(joinpath(@__DIR__, "..", "theorem5_presemifield.jl"))

    # The driver must hand back an a≠0 witness: Section 4 is only interesting for
    # a≠0 (Theorem 6's nuclei are conditioned on it), and the first valid triple in
    # lexicographic order is the degenerate (a=0, b=2, α=2) that the repro used to
    # settle for.
    params = theorem5_find_params()
    @test params !== nothing
    a, b, α = params
    @test a != 0
    @test theorem5_find_params(; require_nonzero_a=false) == (0, 2, 2)  # the old, bad choice

    @test theorem5_admissible(a, b, α)
    @test projective_polynomial_rootless(_T5_N, _T5_K, a, b; modulus=_T5_MOD)
    @test _norm(α) != 1

    # Lemma 2: the ∘_α multiplication has no zero-divisors
    @test lemma2_verify(α)

    # Theorem 5: full no-zero-divisor check on the a≠0 witness
    r = theorem5_verify(a, b, α)
    @test r.ok

    # σ² is the double Frobenius, *computed* — not hardcoded to the identity. On
    # GF(2⁴)/GF(2²) it happens to BE the identity, which is precisely the fact the
    # old `_σ2(x) = x` silently assumed and could not have detected losing.
    @test _T5_DEG == 2
    @test all(_σ2(x) == _σ(_σ(x)) for x = 0:15)
    @test all(_σ2(x) == x for x = 0:15)   # true here, and only because [F:K] = 2
    @test !all(_σ(x) == x for x = 0:15)   # σ itself is not the identity

    # Theorem 5 on EVERY admissible triple, not just one.
    s = theorem5_sweep()
    @test s.n_params == 1020
    @test s.n_a_nonzero == 900
    @test s.n_a_zero == 120
    @test s.n_fail == 0
    # Negative controls: the hypotheses are load-bearing, so the scan *can* fail.
    @test s.ctrl_norm      # every norm-1 α produces a zero-divisor
    @test s.ctrl_root      # every rooted (a,b) produces a zero-divisor
    @test s.ok

    # Sanity: zero*(anything) = (0,0)
    p1, p2 = presemi_mul(0, 0, 3, 5, a, b, α)
    @test p1 == 0 && p2 == 0
end
