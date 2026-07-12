@testset "section3_test" begin
    include(joinpath(@__DIR__, "..", "section3.jl"))

    # ZW(λ) and S_F for Gold x³ n=4
    F = power_sbox(4, 3)
    S = sf_set(F)
    @test 0 ∈ S
    @test length(S) > 1
    for λ in S
        λ == 0 && continue
        @test !isempty(zw_set(F, λ))
    end

    # Observation 1 as an equivalence, on a Procedure-2 admissible pair …
    pr = procedure2_admissible_pair(F)
    @test pr !== nothing
    @test !all(iszero, pr.A2_cols)                       # genuinely A₂ ≠ 0
    @test admissible_check(F, pr.A1_cols, pr.A2_cols)
    @test observation1_criterion(F, pr.A1_cols, pr.A2_cols)

    # … on the trivial admissible pair (A₁ invertible, A₂ = 0) …
    T4 = storage_type(F)
    A1c = random_invertible_cols(4, T4)
    A2c = zeros(T4, 4)
    @test admissible_check(F, A1c, A2c)
    @test observation1_criterion(F, A1c, A2c)

    # … and on random pairs (both sides must agree).
    for _ = 1:20
        rA1 = T4.(rand(0:15, 4))
        rA2 = T4.(rand(0:15, 4))
        @test admissible_check(F, rA1, rA2) == observation1_criterion(F, rA1, rA2)
    end

    # Corollary 1: exact simplex-code counts
    @test corollary1_upper_bound(power_sbox(4, 3); io = devnull) == 16
    @test corollary1_upper_bound(load_apn_function("n5_Gold_x3"); io = devnull) == 64
    @test corollary1_upper_bound(load_apn_function("n5_Kasami_x15"); io = devnull) == 2

    # Proposition 1: computed (not hardcoded) — L∘L₁ gives affine-equivalent output
    @test proposition1_check(load_apn_function("n5_Gold_x3"); io = devnull)

    # Procedure 2 for every k (not just k=1): every admissible L₁ in the
    # Observation-3/4 normal form. Gold x³ n=4 has S_F with no 2-dim subspace,
    # so only k ∈ {0, 1} occur; x¹⁵ n=5 is a permutation, so 0 ∈ ZW(u) for all
    # u and the k = n case (A₁ = 0, A₂ = id, F₁ = F) appears.
    ps = procedure2_pairs(F)
    @test length(ps) == 121
    @test sort(unique(p.k for p in ps)) == [0, 1]
    @test all(is_permutation(procedure2_f1(F, p.A1_cols, p.A2_cols)) for p in ps)  # Observation 1
    @test all(observation1_criterion(F, p.A1_cols, p.A2_cols) for p in ps)
    K15 = power_sbox(5, 15)
    ps15 = procedure2_pairs(K15)
    @test sort(unique(p.k for p in ps15)) == [0, 5]
    @test all(is_permutation(procedure2_f1(K15, p.A1_cols, p.A2_cols)) for p in ps15)

    # The code 𝒞_{F₁} of Propositions 2/3: equal codes ⟺ F₁' = L ∘ F₁
    F1a = procedure2_f1(F, ps[2].A1_cols, ps[2].A2_cols)
    Lr = F2LinearMap{4,T4}(random_invertible_cols(4, T4))
    F1b = SBox{4,T4}(T4[Lr(F1a.lut[x+1]) for x = 0:15])
    @test permutation_code(F1a) == permutation_code(F1b)
    @test left_linear_factor(F1a, F1b) !== nothing
    @test permutation_code(F1a) != permutation_code(procedure2_f1(F, ps[1].A1_cols, ps[1].A2_cols))

    # Propositions 2 and 3 on Gold x³ n=4 (hypotheses + conclusions)
    p23 = propositions_2_3_check(F; io = devnull)
    @test p23.all_perm && p23.nl_ok                 # 𝒩ℒ(F) ≠ 0 (Remark 3)
    @test p23.no_lin && p23.span_ok                 # Proposition 2's hypotheses
    @test p23.factor_ok                             # equal codes ⟹ L₁' = L∘L₁
    @test p23.ea_ok                                 # ⟹ EA-equivalent graph functions
    @test p23.prop2 && p23.prop3
    @test p23.n_codes == 16                         # = the Corollary-1 simplex bound

    # The paper's pipeline: Procedure 2 (all k) → Proposition-3 filter → EA-classes.
    # Cross-validated against the independent orbit method for the quadratic case.
    r4 = procedure2_ea_classes(F; io = devnull)
    @test r4.n_pairs == 121
    @test r4.n_codes == 16                          # = corollary1_upper_bound(Gold n=4)
    @test r4.n_ea == 2 == length(ea_class_orbits(F).orbits)
    # x¹⁵ n=5: the 2 simplex codes are those of F and F⁻¹, and they collapse to a
    # single EA-class (x¹⁵ ≃linear x⁻¹, an involution — Theorems 7/8). The orbit
    # method does not apply here (F is not quadratic).
    r15 = procedure2_ea_classes(K15; io = devnull)
    @test r15.n_codes == 2 == corollary1_upper_bound(K15; io = devnull)
    @test r15.n_ea == 1
end