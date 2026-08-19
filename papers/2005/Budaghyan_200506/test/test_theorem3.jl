@testset "theorem3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3.jl"))

    # F_8 computer check (exact, exhaustive, 21 pairs)
    r_f8 = theorem3_f8_check()
    @test r_f8.violations == 0
    @test r_f8.pairs_checked == 42   # i ∈ {1,2} × 7 u values × 3 w values

    # Theorem-statement F1⁻¹ formula vs. LUT inverse, all GF(2^6) elements
    for i in (1, 5)
        r_inv = theorem3_f1_inverse_formula_check(; m = 6, i = i)
        @test r_inv.ok
        @test r_inv.checked == 64
        @test r_inv.mismatch_count == 0
        @test isempty(r_inv.mismatches)
    end

    # Explicit F' expansion (tex l.588–590 / l.666–669) == construction F₂∘F₁⁻¹
    for i in (1, 5)
        r_exp = theorem3_explicit_formula_check(; m = 6, i = i)
        @test r_exp.ok
        @test r_exp.mismatch_count == 0
        @test r_exp.checked == 64
    end

    # m=6, i=1: APN, degree 4
    r = theorem3_check(; m = 6, i = 1)
    @test r.is_apn
    @test r.deg == 4

    # m=6, i=5
    r = theorem3_check(; m = 6, i = 5)
    @test r.is_apn
    @test r.deg == 4

    # Real CCZ-equivalence to Gold (paper's Conclusion) via the FIXED oracle —
    # replaces the deg==4 heuristic as the equivalence-to-Gold / inequivalence-
    # to-known-APN evidence. F' is degree-4 non-quadratic and a non-permutation,
    # exercising the recently-fixed non-permutation path.
    for i in (1, 5)
        r_ccz = theorem3_ccz_to_gold_check(; m = 6, i = i)
        @test r_ccz.is_ccz
    end

    # The novelty claim Theorem 3 actually makes is EA-inequivalence to the known
    # APN (no known APN has algebraic degree 4 for 6 | m) — NOT the CCZ-relation
    # above, which is the opposite direction. `on_inconclusive = :throw` keeps a
    # guessed `false` from manufacturing the claim; the degree separation
    # (deg F' = 4 vs deg = 2 for every known n=6 APN) is the sound witness.
    for i in (1, 5)
        r_ea = theorem3_ea_inequivalence_check(; m = 6, i = i)
        @test r_ea.deg_F == 4
        @test r_ea.n_compared >= 3          # n6_Gold_x3, n6_Kasami_x48, n6_Kim, ...
        @test r_ea.all_inequiv
        @test r_ea.degrees_separate
        @test all(!eq for (_, eq, _) in r_ea.results)
        @test all(dg != 4 for (_, _, dg) in r_ea.results)
    end

    # argument validation
    @test_throws ArgumentError theorem3_lut(5, 1)   # 6 ∤ 5
    @test_throws ArgumentError theorem3_lut(6, 2)   # gcd(2,6) ≠ 1
end
