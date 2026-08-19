@testset "section4_self_equivalences" begin
    include(joinpath(@__DIR__, "..", "section4.jl"))

    # --- Section 4.1 / 5.1: Rijndael, constructively. ------------------------
    S = load_aes_sbox()
    A = rijndael_affine_map(S)

    # S(x) = A(x^{-1}) with A affine under the Rijndael modulus 0x11B.
    @test is_rijndael_affine_decomposition(S, A)

    pairs = rijndael_self_equivalences(S)
    @test length(pairs) == 2040                       # 8 values of i × 255 of a
    @test all(is_self_equivalence(S, p.A1, p.A2) for p in pairs)
    @test length(Set((_affine_key(p.A1), _affine_key(p.A2)) for p in pairs)) == 2040

    # Table 4 lists S and S^{-1} in one class; A ∘ S^{-1} ∘ A = S witnesses it.
    Sinv = compositional_inverse(S)
    @test all(A(Sinv.lut[A(UInt8(x))+1]) == S.lut[x+1] for x = 0:255)

    # The building blocks: Q is the squaring matrix and has order 8.
    Q = squaring_matrix()
    @test all(Q(UInt8(x)) == gf_mul(x, x, 8; modulus = RIJNDAEL_MODULUS) for x = 0:255)
    @test squaring_power(8).cols == identity_linear_map(8, UInt8).cols
    @test squaring_power(-3).cols == squaring_power(5).cols
    @test all(gf_mult_matrix(3)(UInt8(x)) == gf_mul(3, x, 8; modulus = RIJNDAEL_MODULUS)
              for x = 0:255)

    # --- Section 4.2: DES S4. ------------------------------------------------
    lut = des_s4_lut()
    @test length(lut) == 64
    @test sort(unique(lut)) == collect(0:15)          # each row is a permutation

    # B^{-1}·S4(x ⊕ 101111₂) ⊕ 0110₂ = S4(x), with A = I and B = [4,3,2,1].
    @test des_s4_relation_holds(lut, [4, 3, 2, 1], 0b101111, 0b0110)
    @test DES_S4_INPUT_CONST == 0b101111
    @test DES_S4_OUTPUT_CONST == 0b0110

    # [4,3,2,1] is the bit reversal, hence its own inverse.
    @test all(apply_bit_perm([4, 3, 2, 1], apply_bit_perm([4, 3, 2, 1], y)) == y for y = 0:15)

    # Exhaustively, the identity and the paper's triple are the only solutions.
    found = des_s4_bitperm_self_equivalences(lut)
    @test length(found) == 2
    @test ([1, 2, 3, 4], 0, 0) in found
    @test ([4, 3, 2, 1], 0b101111, 0b0110) in found

    # Eq. (9) at DES's (n, m) = (6, 4) is about 2^20.6.
    @test 20.0 < Float64(log2(eq9_complexity(6, 4))) < 21.0

    # Report passes on the fast path (no longer a vacuous `true`).
    @test section4_report(devnull; full_search = false)
end
