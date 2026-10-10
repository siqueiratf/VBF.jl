@testset "corollary2_test" begin
    include(joinpath(@__DIR__, "..", "corollary2.jl"))

    n = 5
    F = gold_apn(n, 1)

    # ── Proposition 3: Π_F is a CCZ-invariant ───────────────────────────────
    # A genuine CCZ-but-not-EA pair: x³ over F₂⁵ is a permutation, so its
    # compositional inverse (x²¹) is CCZ-equivalent to it, but has algebraic degree 3
    # against x³'s 2 — EA-equivalence preserves the algebraic degree, so no EA map
    # relates them. (Testing an EA pair, as the previous version did, only tests Prop 4.)
    Finv = compositional_inverse(F)
    @test algebraic_degree(F) == 2
    @test algebraic_degree(Finv) == 3
    @test are_ccz_equivalent(F, Finv)
    @test !are_ea_equivalent(F, Finv)

    # The invariant is the FULL multiset {|Π_F^β(b)| : β, b}, not just its support.
    ΠF = pi_full_multiset(F)
    @test length(ΠF) == (1 << n) * (1 << n)
    @test pi_full_multiset(Finv) == ΠF

    # Every representative of the CCZ-class carries the same Π_F (both EA-classes).
    reps = enumerate_ccz_class(F)
    @test !isempty(reps)
    @test Set(algebraic_degree.(reps)) == Set([2, 3])       # both EA-classes present
    @test all(pi_full_multiset(r) == ΠF for r in reps)

    # Discriminating control: Kasami x¹⁵ is CCZ-INequivalent to x³ and its Π differs,
    # so `pi_full_multiset` is not a constant and the equality above has content.
    K = SBox{n}(gf_monomial_lut(n, 15))
    @test !are_ccz_equivalent(F, K)
    @test pi_full_multiset(K) != ΠF
    @test sort(collect(Set(ΠF))) == [15, 32]
    @test sort(collect(Set(pi_full_multiset(K)))) == [9, 12, 15, 18, 32]
    @test compute_m_F(F) == 15 && compute_m_F(K) == 9

    # The support alone is a strictly weaker invariant: it fails to separate x³ from x⁵
    # (CCZ-inequivalent, yet the same support AND the same multiset) — which is exactly
    # why the report must not claim more than Π_F actually gives.
    G5 = SBox{n}(gf_monomial_lut(n, 5))
    @test !are_ccz_equivalent(F, G5)
    @test pi_full_multiset(G5) == ΠF        # Π_F is invariant, not complete

    r3 = proposition3_ccz_invariance(; io = devnull, n = 5)
    @test r3.all_ok

    # ── Proposition 4: EA-invariance with non-trivial A₁, A₂, A ─────────────
    mod = primitive_polynomial(n)
    sz = 1 << n
    A1(x) = gf_pow(x, 2, n; modulus = mod)                    # Frobenius
    A1inv(y) = gf_pow(y, 1 << (n - 1), n; modulus = mod)
    A2(x) = gf_pow(x, 2, n; modulus = mod) ⊻ 7
    A(x) = gf_mul(3, x, n; modulus = mod)
    Fp = SBox{n}([A1(Int(F.lut[A2(x)+1])) ⊻ A(x) for x = 0:(sz-1)])

    @test differential_uniformity(Fp) == 2
    @test are_ea_equivalent(F, Fp)
    @test Fp.lut != F.lut
    @test all(A1inv(A1(x)) == x for x = 0:(sz-1))             # A₁ really is invertible

    cntF = [pi_counts(F, β) for β = 0:(sz-1)]
    cntFp = [pi_counts(Fp, β) for β = 0:(sz-1)]

    # |Π_{F'}^β(t)| = |Π_F^{A₂(β)}(A₁⁻¹(t + A(β)))| on every (β, t) pair.
    @test all(cntFp[β+1][t+1] == cntF[A2(β)+1][A1inv(t ⊻ A(β))+1]
              for β = 0:(sz-1), t = 0:(sz-1))

    # Both non-trivial pieces are load-bearing: dropping A(β), or dropping A₁⁻¹,
    # breaks the identity. (With A₁ = id and A = 0 — the previous test's setup —
    # these two variants coincide with the real one and nothing is tested.)
    @test count(cntFp[β+1][t+1] != cntF[A2(β)+1][A1inv(t)+1]
                for β = 0:(sz-1), t = 0:(sz-1)) > 0
    @test count(cntFp[β+1][t+1] != cntF[A2(β)+1][(t ⊻ A(β))+1]
                for β = 0:(sz-1), t = 0:(sz-1)) > 0

    # The Proposition's corollary: Π_{F'}^β = Π_F^{A₂(β)} as spectra.
    @test all(pi_multiset(Fp, β) == pi_multiset(F, A2(β)) for β = 0:(sz-1))

    r4 = proposition4_ea_invariance(; io = devnull, n = 5)
    @test r4.all_ok
    @test r4.mismatches == 0

    # ── Proposition 5 and Corollary 2 ───────────────────────────────────────
    # Quadratic ⇒ Π_F^β independent of β. Non-quadratic ⇒ it need not be (control).
    @test all(pi_multiset(F, β) == pi_multiset(F, 0) for β = 0:(sz-1))
    @test any(pi_multiset(K, β) != pi_multiset(K, 0) for β = 0:(sz-1))   # x¹⁵, deg 4

    @test proposition5_quadratic(; io = devnull, n_values = [5, 6]).all_ok
    @test corollary2_lower_bounds(; io = devnull, n_values = [3, 4, 5, 6]).all_ok

    # Corollary 2 itself: d(F, G) ≥ ⌈m_F/3⌉ + 1 — the closest APN function to x³ over
    # F₂⁵ sits at distance 8 ≥ 6 = the bound, and no APN G exists any closer by a
    # single shift (Section V is exhaustive there).
    @test lower_bound_distance(compute_m_F(F)) == 6
    @test lower_bound_distance(compute_m_F(K)) == 4
end
