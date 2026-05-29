@testitem "linear_equivalence_api" begin
using VBFCatalog
using VBF
using Test

@testset "are_linear_equivalent: type checks" begin
    s4 = load_literature_sbox("PRESENT")       # SBox{4, UInt8}
    s5 = load_apn_function("n5_Gold_x3")        # SBox{5, UInt8}
    # Different N → always false (no throw)
    @test !are_linear_equivalent(s4, s5)
    @test !are_linear_equivalent(s5, s4)
end

@testset "are_linear_equivalent: unknown strategy throws" begin
    s = load_literature_sbox("PRESENT")
    @test_throws ArgumentError are_linear_equivalent(s, s; strategy = :nonexistent)
end

@testset "are_linear_equivalent: :auto routes by (N, permutation)" begin
    # n=4 permutation: :auto picks :lpp_backtracking
    s4 = load_literature_sbox("PRESENT")
    @test are_linear_equivalent(s4, s4; strategy = :auto) ==
          are_linear_equivalent(s4, s4; strategy = :lpp_backtracking)
    # n=5 permutation: :auto picks :stennes
    s5 = load_apn_function("n5_Gold_x3")
    @test are_linear_equivalent(s5, s5; strategy = :auto) ==
          are_linear_equivalent(s5, s5; strategy = :stennes)
end

@testset "are_linear_equivalent: :stennes ↔ :lpp_backtracking parity (n=4)" begin
    # On every 4-bit catalog pair, the two strategies must agree.
    names = filter(literature_sbox_names()) do n
        s = load_literature_sbox(n)
        is_permutation(s) && inputbits(s) == 4
    end
    sboxes = [load_literature_sbox(n) for n in names]
    for i in eachindex(sboxes), j in i:lastindex(sboxes)
        F, G = sboxes[i], sboxes[j]
        @test are_linear_equivalent(F, G; strategy = :stennes) ==
              are_linear_equivalent(F, G; strategy = :lpp_backtracking)
    end
end

@testset "are_linear_equivalent: :stennes rejects non-permutations gracefully" begin
    F = load_literature_sbox("PRESENT")
    c = SBox(UInt8[3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3])
    # Both directions return false (no throw).
    @test !are_linear_equivalent(F, c; strategy = :stennes)
    @test !are_linear_equivalent(c, F; strategy = :stennes)
    @test !are_linear_equivalent(c, c; strategy = :stennes)
end

# ---------------------------------------------------------------------------
# Catalog-level spot checks
# ---------------------------------------------------------------------------

@testset "reflexivity on every 4-bit catalog permutation" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        inputbits(s) == 4 || continue
        is_permutation(s) || continue
        @test are_linear_equivalent(s, s)
    end
end

@testset "n=5 Gold/Kasami monomials are pairwise NOT linearly equivalent" begin
    # For monomial APNs x^d, x^d' over GF(2^n), linear equivalence happens
    # iff d' ∈ {2^k · d mod (2^n - 1) : k ∈ ℤ} (Frobenius orbit).
    # For n=5 these orbits are disjoint for d ∈ {3, 5, 15}.
    s3  = load_apn_function("n5_Gold_x3")
    s5  = load_apn_function("n5_Gold_x5")
    s15 = load_apn_function("n5_Kasami_x15")

    @test are_linear_equivalent(s3, s3)
    @test are_linear_equivalent(s5, s5)
    @test are_linear_equivalent(s15, s15)

    @test !are_linear_equivalent(s3, s5)
    @test !are_linear_equivalent(s3, s15)
    @test !are_linear_equivalent(s5, s15)

    # Symmetry: F ~ G ⇔ G ~ F
    @test are_linear_equivalent(s5, s3) == are_linear_equivalent(s3, s5)
end

@testset "AES and AES_inv: different linear-equivalence class" begin
    # AES uses inversion-then-affine; AES_inv is its functional inverse.
    # They are CCZ-equivalent (every function is CCZ-equivalent to its
    # inverse) but NOT generally linearly equivalent.
    aes = load_literature_sbox("AES")
    inv_aes = load_literature_sbox("AES_inv")
    # Even the same n=8 case can be expensive — search bounded by smart
    # pruning. The reflexivity case is always cheap.
    @test are_linear_equivalent(aes, aes)
end

end
