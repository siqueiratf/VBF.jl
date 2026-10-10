@testset "section4_test" begin
    include(joinpath(@__DIR__, "..", "section4.jl"))

    # Cyclic T for n=3: no unknowns, is APN
    M3, known3 = kalgin_T(3)
    @test all(known3)
    @test is_qam(M3)

    # Verify T[i,j] = 2^{i+j-3} formula for n=3
    @test M3[1, 2] == 1   # e_1 = 2^0
    @test M3[1, 3] == 2   # e_2 = 2^1
    @test M3[2, 3] == 4   # e_3 = 2^2
    @test M3[2, 1] == M3[1, 2]  # symmetric

    # Cyclic T for n=4: exactly 1 unknown position
    M4, known4 = kalgin_T(4)
    upos4 = unknown_positions(known4)
    @test length(upos4) == 1
    @test upos4[1] == (3, 4)  # only (3,4) has i+j=7 > n+2=6

    # Cyclic T for n=5: exactly 2 unknowns
    M5, known5 = kalgin_T(5)
    upos5 = unknown_positions(known5)
    @test length(upos5) == 2

    # Modified T for n=5 (remove e_5 subdiag at i+j=7): adds (2,5),(3,4) → 4 total
    M5m, known5m = kalgin_T(5; remove_e_n = true)
    upos5m = unknown_positions(known5m)
    @test length(upos5m) == 4

    # Modified T for n=7: 9 unknowns (6 standard + 3 from the removed subdiagonal)
    M7m, known7m = kalgin_T(7; remove_e_n = true)
    upos7m = unknown_positions(known7m)
    @test length(upos7m) == 9

    # ── R1: mugshot equality is NOT an EA-equivalence decision ───────────────
    # The counterexample that makes the old dedup wrong: Gold x^3 and x^5 over
    # GF(2^5) have the SAME apn_ea_mugshot but are EA- and CCZ-inequivalent.
    g5_3, g5_5 = gold_apn(5, 1), gold_apn(5, 2)
    @test apn_ea_mugshot(g5_3) == apn_ea_mugshot(g5_5)      # necessary…
    @test !are_ea_equivalent(g5_3, g5_5)                    # …but NOT sufficient
    @test !are_ea_equivalent_quadratic(g5_3, g5_5)
    @test isempty(ea_mappings_from_ortho_derivative(g5_3, g5_5))
    # the exact decision is reflexive on both (guards against a test that passes
    # because ea_mappings_from_ortho_derivative always returns an empty set)
    @test are_ea_equivalent_quadratic(g5_3, gold_apn(5, 1))
    @test are_ea_equivalent_quadratic(g5_5, gold_apn(5, 2))
    # and dedup_ea must therefore keep them apart
    @test length(dedup_ea([g5_3, g5_5])) == 2
    @test length(dedup_ea([g5_3, g5_3, g5_3])) == 1

    # ── R2: the cyclic T construction covers ALL CCZ-classes for n = 3, 4, 5 ─
    # Paper §4 (p. 12): "For n = 3, 4 and 5 this construction covered all
    # CCZ-classes of quadratic APN functions." Known totals: 1, 1, 2.
    raw3 = cyclic_raw_qam_solutions(3)
    @test length(raw3) == 1                      # T is fully determined at n=3
    @test length(dedup_ea(raw3)) == 1

    raw4 = cyclic_raw_qam_solutions(4)
    @test length(raw4) == 4                      # 4 of the 16 completions are QAMs
    fns4 = dedup_ea(raw4)
    @test length(fns4) == 1                      # n=4 has exactly 1 CCZ-class
    @test are_ea_equivalent_quadratic(SBox{4}(Int.(fns4[1].lut)), gold_apn(4))

    raw5 = cyclic_raw_qam_solutions(5)
    @test length(raw5) == 12                     # 12 of the 1024 completions are QAMs
    @test all(f -> differential_uniformity(f) == 2, raw5)
    # all 12 share ONE mugshot — deduping on it would report 1 class…
    @test length(unique(apn_ea_mugshot.(raw5))) == 1
    # …but they are 2 genuine CCZ-classes, and they are exactly Gold x^3 and x^5,
    # i.e. ALL of n=5. This is the number the paper claims (2/2), not 1 and not 3.
    fns5 = dedup_ea(raw5)
    @test length(fns5) == 2
    @test count(f -> are_ea_equivalent_quadratic(SBox{5}(Int.(f.lut)), g5_3), fns5) == 1
    @test count(f -> are_ea_equivalent_quadratic(SBox{5}(Int.(f.lut)), g5_5), fns5) == 1
    @test length(cyclic_apn_search(5)) == 2

    # Cyclic search n=4 through the public entry point
    @test length(cyclic_apn_search(4)) == 1
    @test all(f -> differential_uniformity(f) == 2, cyclic_apn_search(4))

    # ── The new n=7 function ────────────────────────────────────────────────
    F7 = new_apn_function_n7()
    @test F7 isa SBox{7}
    @test differential_uniformity(F7) == 2
    @test algebraic_degree(F7) == 2
    @test is_qam(quadratic_apn_matrix(F7))

    # ── R4: σ-based CCZ classification against ALL 488 known n=7 classes ─────
    # σ (the ortho-derivative signature) is a CCZ-invariant: a σ-MISMATCH is a
    # rigorous inequivalence certificate, a σ-match is only a candidate. The
    # paper's claim is that F7 is a class of its own among the n=7 quadratic APN
    # functions; the certificate is that σ(F7) differs from 487 of the 488 and
    # coincides with exactly one — which is F7's own class (EA-confirmed).
    cls = n7_sigma_classification(F7)
    @test cls.total >= 488                        # the known n=7 corpus (grows as the catalog gains named reps)
    @test length(cls.matches) == 1                # σ-uniqueness — the paper's actual claim
    @test cls.mismatches == cls.total - 1         # every other entry is an inequivalence certificate
    @test cls.ea_confirmed == cls.matches         # the σ-match is genuinely F7's class
    @test cls.sigma == sigma_hash(F7)
    # …and σ discriminates here rather than being constant across the corpus:
    @test sigma_hash(F7) != sigma_hash(gold_apn(7, 1))
    @test sigma_hash(F7) != sigma_hash(gold_apn(7, 2))
    @test !are_ea_equivalent_quadratic(F7, gold_apn(7, 1))
    # classify_ccz agrees (:sigma_match, never :known — a σ hit is not a proof)
    st, src, mid = classify_ccz(F7)
    @test st === :sigma_match
    @test mid in cls.matches
end
