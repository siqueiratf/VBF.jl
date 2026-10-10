@testset "section4_test" begin
    include(joinpath(@__DIR__, "..", "section4.jl"))

    # Paper-exact code matrix dimensions for Gold x³ n=5
    F5 = load_apn_function("n5_Gold_x3")
    N = 5
    n_size = 1 << N
    @test size(ccz_matrix(F5)) == (2N + 1, n_size)          # C₁ (11, 32)
    @test size(ea_matrix(F5)) == (2N + 1, 2n_size - 1)      # C₂ (11, 63)
    @test size(ae_matrix(F5)) == (2N + 1, 3n_size - 2)      # C₃ (11, 94)

    D = dillon_apn_permutation()
    @test size(ae_perm_matrix(D)) == (13, 191)                   # C₄ (2n+1, 3·2ⁿ-1)
    @test_throws ArgumentError ae_perm_matrix(kim_apn())         # permutations only

    # Theorem 5 at the weight-enumerator level
    K = kim_apn()
    Dinv = compositional_inverse(D)
    @test code_weight_enumerator(ccz_matrix(K)) == code_weight_enumerator(ccz_matrix(D))
    # Correct output-block extension is isospectral; degree supplies the proof.
    @test code_weight_enumerator(ea_matrix(K)) == code_weight_enumerator(ea_matrix(D))
    @test algebraic_degree(K) == 2 && algebraic_degree(D) == 4
    @test code_weight_enumerator(ae_matrix(D)) == code_weight_enumerator(ae_matrix(Dinv))

    # Theorem 6 with the paper's F₁: not AE to its inverse, C₃ blind to it
    F1 = calderini_f1()
    F1inv = compositional_inverse(F1)
    @test is_permutation(F1) && differential_uniformity(F1) == 2
    @test !are_affine_equivalent(F1, F1inv)
    @test code_weight_enumerator(ae_matrix(F1)) == code_weight_enumerator(ae_matrix(F1inv))

    # C₄ codes of F₁ and F₁⁻¹+b are WE-isospectral for every b (the separation
    # is certified by Theorem 6 + the complete AE decision, not by WE).
    w4 = code_weight_enumerator(ae_perm_matrix(F1))
    @test all(
        code_weight_enumerator(
            ae_perm_matrix(SBox{6}([Int(F1inv.lut[x + 1]) ⊻ b for x = 0:63])),
        ) == w4 for b = 0:63
    )

    # Forward direction positive control: D AE F₂ ⟹ ∃b with matching C₄ WE.
    F2 = calderini_f2()
    w4D = code_weight_enumerator(ae_perm_matrix(D))
    @test any(
        code_weight_enumerator(
            ae_perm_matrix(SBox{6}([Int(F2.lut[x + 1]) ⊻ b for x = 0:63])),
        ) == w4D for b = 0:63
    )
end