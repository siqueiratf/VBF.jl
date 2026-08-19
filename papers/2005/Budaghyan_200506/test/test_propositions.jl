@testset "propositions_test" begin
    include(joinpath(@__DIR__, "..", "propositions.jl"))

    # ── Example 1 ────────────────────────────────────────────────────────────
    # The counterexample to the naive converse of Prop 3: both components of
    # 𝓛 = (L₁, L₂) depend on both variables, yet F' is EA-equivalent to (x³)⁻¹.
    for (m, n, s, d3) in ((5, 2, 0, 21), (7, 3, 1, 85))
        e = example1_check(; m = m)
        @test e.n == n && e.s == s
        @test e.d3 == d3                    # 1/3 on F_{2^m}
        @test e.L_is_perm
        @test e.L_one == 1                  # L(1) = 1: the derivation depends on it
        @test e.Linv_ok                     # L⁻¹(x) = x + x² + tr(x)
        @test e.F1_is_perm
        @test e.F1_alt_ok                   # F₁(x) = L((x+1)³) + 1
        @test e.F1inv_ok                    # F₁⁻¹(x) = [L⁻¹(x+1)]^{1/3} + 1
        @test e.script_L_is_perm            # 𝓛 permutes F_{2^m}²
        @test e.both_depend_on_both         # ... with L₁ AND L₂ on both variables
        @test e.closed_ok                   # F' matches the paper's closed form
        @test e.ea_witness_ok               # which IS an EA-witness for x^{1/3}
        @test e.deg_Fp == e.deg_cuberoot    # EA preserves algebraic degree
        @test e.checked == 1 << m
    end

    @test_throws ArgumentError example1_L_lut(6)    # needs m = 2n+1 odd
    @test_throws ArgumentError example1_L_lut(3)    # needs m > 3

    # ── Proposition 3 ────────────────────────────────────────────────────────
    for i in (1, 2)
        p = prop3_check(; m = 5, i = i)
        @test p.caseA_is_function           # L₁(x,y) = L(x): 𝓛(G_F) is a graph
        @test p.caseA_ok                    # ... and F' = M₂∘F∘L⁻¹ + M₁∘L⁻¹ ~EA F
        @test p.caseB_is_function           # L₁(x,y) = L(y)
        @test p.caseB_ok                    # ... and F' ~EA F⁻¹
        @test p.caseC_L1_both               # Theorem 1's L₁ uses both variables
        @test p.caseC_matches_theorem1      # its graph image IS Theorem 1's F'
        @test p.caseC_prop4_witnesses > 0
        @test p.caseC_ea_inequivalent       # ⇒ no one-variable L₁ can produce it
    end
    @test_throws ArgumentError prop3_check(; m = 6, i = 1)   # needs m odd

    # ── Proposition 5 ────────────────────────────────────────────────────────
    # Exhaustive at m=4: all 2^16 linear L with L'=id, then all 2^16 linear L'
    # with L=id. 16 of those are permutations, so the "⟸" half is not vacuous.
    p5 = prop5_exhaustive_check(; m = 4, i = 1)
    @test p5.tested == 2 * (1 << 16)
    @test p5.agree == p5.tested
    @test p5.permutations == 16
    @test p5.ok

    for (m, i) in ((6, 1), (8, 3), (5, 1), (7, 1))
        r = prop5_check(; m = m, i = i, trials = 40)
        @test r.ok
        @test r.agree == r.tested
        @test isempty(r.disagreements)
        @test r.permutations > 0            # permutation branch exercised
    end

    @test_throws ArgumentError prop5_exhaustive_check(; m = 5)   # 2^(m²) blows up

    # Theorem 3's F₁ is a Prop-5-shaped permutation: L(y) = tr_{m/3}(y²+y⁴),
    # L'(x) = x. Both sides of the criterion must say "permutation".
    let m = 6, i = 1, modulus = primitive_polynomial(6)
        L = _theorem3_L_lut(m; modulus = modulus)
        Lp = collect(0:(1<<m)-1)
        F = prop5_function_lut(m, i, L, Lp; modulus = modulus)
        @test is_permutation(SBox{m}(F))
        @test prop5_criterion(m, i, L, Lp; modulus = modulus)
    end

    # ── Proposition 6 ────────────────────────────────────────────────────────
    p6 = prop6_exhaustive_check(; m = 4, i = 1)
    @test p6.tested == 1 << 16
    @test p6.agree == p6.tested
    @test p6.permutations == 16
    @test p6.ok

    for (m, i) in ((6, 1), (6, 5), (8, 3))
        r = prop6_check(; m = m, i = i, trials = 15)
        @test r.adj_ok                      # tr(v·L(x)) = tr(L*(v)·x)
        @test r.ok
        @test r.agree == r.tested
        @test isempty(r.disagreements)
        @test r.permutations > 0
    end

    @test_throws ArgumentError prop6_check(; m = 5)              # Prop 6 needs m even
    @test_throws ArgumentError prop6_criterion(5, 1, collect(0:31))

    # the adjoint is an involution and satisfies its defining identity
    let m = 4, modulus = primitive_polynomial(4)
        L = linear_map_lut(random_invertible_linear_map(Xoshiro(7), Val(4)))
        A = adjoint_lut(L, m; modulus = modulus)
        @test adjoint_lut(A, m; modulus = modulus) == L
        @test all(
            gf_trace(gf_mul(v, L[x+1], m; modulus = modulus), m; modulus = modulus) ==
            gf_trace(gf_mul(A[v+1], x, m; modulus = modulus), m; modulus = modulus)
            for v in 0:15, x in 0:15
        )
    end
end
