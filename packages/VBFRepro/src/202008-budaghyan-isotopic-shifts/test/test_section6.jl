@testset "section6_test" begin
    include(joinpath(@__DIR__, "..", "section6.jl"))

    # ── Field pinning (README R9) ────────────────────────────────────────────
    # Every ζ^k exponent quoted from the paper depends on this pair.
    fp = section6_check_field_pinning()
    @test fp.mod9 == 529                     # x⁹ + x⁴ + 1
    @test primitive_polynomial(9) == 529
    @test fp.ord2 == 511                     # ζ = 2 is primitive in GF(2⁹)
    @test fp.zeta9 == 2
    @test fp.ok_mod && fp.ok_zeta && fp.ok_smallest
    # ... and 2 is NOT primitive at n=8 (AES modulus 283, order 51) — which is
    # why ζ is searched rather than assumed.
    @test fp.ord2_n8 == 51
    @test fp.ok_n8
    @test multiplicative_order(primitive_element(8), 8) == 255

    # ── Lemma VI.6, cases (i), (ii), (iv) ────────────────────────────────────
    rl = section6_check_lemmaVI6()
    @test rl.ok_i
    @test rl.ok_ii
    @test rl.ok_iv

    # ── Theorem VI.3: the sets d, d', U, W (README R7) ───────────────────────
    st = section6_check_theoremVI3_setup()
    @test st.all_ok
    # d' > 1 must actually occur, else the W = {y·ζ^j} coset construction is
    # never exercised (at n=6, m=2: d = d' = 3, |W| = 21).
    s62 = theorem_vi3_setup(6, 2)
    @test s62.d == 3 && s62.dprime == 3
    @test length(s62.W) == 21 == s62.S
    @test gcd(s62.q - 1, s62.S ÷ s62.dprime) == 1
    s93 = theorem_vi3_setup(9, 3)
    @test s93.k == 3 && s93.q == 8 && s93.dprime == 1
    @test length(s93.W) == 73 == s93.S

    # ── Theorem VI.3: the n=9 instance ──────────────────────────────────────
    rt = section6_check_theoremVI3()
    @test rt.is_apn
    @test rt.du == 2
    @test rt.matches_table1              # equals Table I row 8, LUT-identical
    @test rt.conds.cond_i && rt.conds.cond_ii && rt.conds.cond_iii
    @test rt.others_apn                  # the other two Sec. VII-B m=3 sets

    # ── Theorem VI.3 as an iff, in both directions ──────────────────────────
    # n=6, k=2, q=8 — exhaustive over all 4096 F₈-linear L
    r63 = section6_check_theoremVI3_iff(; n = 6, m = 3, i = 1)
    @test r63.exhaustive
    @test r63.tested == 4096
    @test r63.mismatches == 0
    @test r63.nonvacuous                 # both APN and non-APN L present
    @test r63.n_apn == 764
    @test r63.n_cond == r63.n_apn

    # n=6, k=3, q=4 — exhaustive over all 262144 F₄-linear L; d' = 3 here
    r62 = section6_check_theoremVI3_iff(; n = 6, m = 2, i = 1)
    @test r62.exhaustive
    @test r62.tested == 262144
    @test r62.mismatches == 0
    @test r62.nonvacuous
    @test r62.n_apn == 2204

    # n=8, k=2, q=16 — exhaustive over all 65536 F₁₆-linear L
    r84 = section6_check_theoremVI3_iff(; n = 8, m = 4, i = 1)
    @test r84.exhaustive
    @test r84.tested == 65536
    @test r84.mismatches == 0
    @test r84.nonvacuous
    @test r84.n_apn == 1172

    # n=9, k=m=3 — the space is 2^27, so: deterministic sample + the paper's own
    # three Section VII-B parameter sets (which supply the APN positives).
    r93 = section6_check_theoremVI3_iff(;
        n = 9, m = 3, i = 1, nsample = 800,
        extra = section6_vi3_known_n9_coefficients(),
    )
    @test !r93.exhaustive
    @test r93.mismatches == 0
    @test r93.nonvacuous
    @test r93.n_apn == 3                 # exactly the three published sets
    @test r93.n_cond == 3
    @test r93.additional_controls == 3
    @test r93.generated_apn == 0
    @test !r93.generated_nonvacuous
    @test r93.generated_distinct <= 512  # LCG repeats; 800 draws are not 800 distinct cases
    @test r93.coverage == r93.distinct_tested // BigInt(2)^27
    @test r63.coverage == 1
    @test r63.generated_nonvacuous
    @test_throws ArgumentError section6_vi3_coefficient_sets(6, 4)
    @test_throws ArgumentError section6_vi3_coefficient_sets(6, 3; nsample=-1)

    # Round-trip: isotopic shift of G_1 by the zero map is the zero function,
    # and by a non-degenerate L it is not (Theorem IV.1's discriminating case).
    n = 9
    mod = primitive_polynomial(n)
    G1 = gold_apn(n, 1; modulus = mod).lut
    @test is_zero_map(isotopic_shift_lut(G1, zero_map_lut(n)))
    @test !is_zero_map(isotopic_shift_lut(G1, terms_to_lut([(1, 2)], n, mod)))
end
