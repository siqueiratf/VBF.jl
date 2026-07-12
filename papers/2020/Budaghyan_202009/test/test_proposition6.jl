@testset "proposition6_test" begin
    include(joinpath(@__DIR__, "..", "proposition6.jl"))

    # Table I: m_F formula values
    table1 = Dict(3 => 3, 4 => 3, 5 => 15, 6 => 27, 7 => 63, 8 => 111)
    for (n, exp_m) in table1
        @test m_F_formula_gold(n) == exp_m
    end

    # Lower bound from Table I
    table1_bounds = Dict(3 => 2, 4 => 2, 5 => 6, 6 => 10, 7 => 22, 8 => 38)
    for (n, exp_bd) in table1_bounds
        @test lower_bound_distance(m_F_formula_gold(n)) == exp_bd
    end

    # Corollary 2 is ⌈m_F/3⌉ + 1, and the ceiling matters. Every m_F the paper ever
    # prints happens to be divisible by 3 (3, 9, 15, 27, 54, 63, 111, 255, 495), so
    # the table data alone cannot tell ⌈m/3⌉ from ⌊m/3⌋ — pin the rounding directly.
    @test lower_bound_distance(15) == 6      # 15/3 exact
    @test lower_bound_distance(16) == 7      # ⌈16/3⌉+1 = 7  (⌊16/3⌋+1 would be 6)
    @test lower_bound_distance(17) == 7      # ⌈17/3⌉+1 = 7  (⌊17/3⌋+1 would be 6)
    @test lower_bound_distance(18) == 7
    @test lower_bound_distance(0) == 1
    @test all(lower_bound_distance(m) == cld(m, 3) + 1 for m = 0:200)

    # pi_counts must agree with core's pi_multiset (it is the pointwise version of it)
    for N in (4, 5), β in (0, 1, 3)
        F = gold_apn(N, 1)
        sp = Spectrum()
        for c in pi_counts(F, β)
            add!(sp, c, 1)
        end
        @test sorted_pairs(sp) == sorted_pairs(pi_multiset(F, β))
    end

    # eq. (9) — corrected — matches |Π_F^β(b)| on EVERY (β, b) pair, n = 3..6.
    # This covers all six branches: n odd, and both cube/not-cube branches for
    # n/2 odd (n=6) and n/2 even (n=4).
    for N = 3:6
        r = proposition6_check_formula(N)
        @test r.mismatches == 0
        # P2: the formula AS PUBLISHED (2ⁿ − 1 for b = β³) is wrong, and wrong exactly
        # on that branch — one (β, b) pair per β. If someone "fixed" our corrected
        # branch back to the paper's, the assertion above would fail.
        @test r.published_mismatches == (1 << N)
    end

    # The b = β³ branch is 2ⁿ, not 2ⁿ − 1: every direction a (including a = 0) hits β³.
    for N in (4, 5), β in (0, 1, 5)
        β3 = gf_pow(β, 3, N; modulus = primitive_polynomial(N))
        @test pi_formula_gold(N, β, β3) == 1 << N
        @test pi_counts(gold_apn(N, 1), β)[β3+1] == 1 << N
        @test pi_formula_gold_as_published(N, β, β3) == (1 << N) - 1   # the paper's value
    end

    # Prop 5: for quadratic Gold n=5, m_F is same via formula and compute_m_F
    @test m_F_formula_gold(5) == compute_m_F(gold_apn(5, 1))
    @test m_F_formula_gold(6) == compute_m_F(gold_apn(6, 1))

    # ── Section IV-E: tightness of the bound for n ≤ 4, and paper issue P1 ───
    w = tightness_witnesses(; io = devnull)
    @test w.all_ok

    # n=2 and n=4: the paper's witnesses are correct — APN, at distance = bound.
    F2 = gold_apn(2, 1)
    G2 = apply_modifications(F2, [0], [2])                  # u₁=0, v₁=α
    @test differential_uniformity(G2) == 2
    @test hamming_distance(F2, G2) == 1 == lower_bound_distance(m_F_formula_gold(2))

    F4 = gold_apn(4, 1)
    G4 = apply_modifications(F4, [0, 1], [1, 1])            # u₁=0,u₂=1,v₁=v₂=1
    @test differential_uniformity(G4) == 2
    @test hamming_distance(F4, G4) == 2 == lower_bound_distance(m_F_formula_gold(4))

    # n=3 (P1): the paper's witness v₁=1, v₂=α is NOT APN for ANY primitive α of GF(8)
    # (every element ≠ 0, 1 is primitive there), so the published witness is simply wrong.
    F3 = gold_apn(3, 1)
    for α = 2:7
        @test is_primitive_element(α, 3)
        @test differential_uniformity(apply_modifications(F3, [0, 1], [1, α])) != 2
    end

    # The bound IS tight at n=3 — with the corrected witnesses v₁ = v₂ ∈ {α, α², α⁴}.
    mod3 = primitive_polynomial(3)
    conj = sort([gf_pow(2, e, 3; modulus = mod3) for e in (1, 2, 4)])
    @test conj == [2, 4, 6]
    apn_pairs = sort([(v1, v2) for v1 = 0:7 for v2 = 0:7
                      if !(v1 == 0 && v2 == 0) &&
                         differential_uniformity(apply_modifications(F3, [0, 1], [v1, v2])) == 2])
    @test apn_pairs == [(2, 2), (4, 4), (6, 6)]             # exhaustive: nothing else works
    for v in conj
        G3 = apply_modifications(F3, [0, 1], [v, v])
        @test differential_uniformity(G3) == 2
        @test hamming_distance(F3, G3) == 2 == lower_bound_distance(m_F_formula_gold(3))
    end
end
