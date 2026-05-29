@testitem "bct" begin
using VBFCatalog
using VBF
using Test

@testset "BCT row/column 0 are 2^N" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        is_permutation(s) || continue
        B = bct(s)
        n = 1 << inputbits(s)
        for a in 1:n
            @test B[a, 1] == n      # column b=0
        end
        for b in 1:n
            @test B[1, b] == n      # row a=0
        end
    end
end

@testset "BCT entries are even (N ≥ 2)" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        is_permutation(s) || continue
        @test all(iseven, bct(s))
    end
end

@testset "BCT ≥ DDT pointwise (Cid et al. 2018 Lemma 1)" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        is_permutation(s) || continue
        @test all(bct(s) .≥ ddt(s))
    end
end

@testset "BCT requires a permutation" begin
    @test_throws ArgumentError bct(SBox(UInt8[0, 0, 2, 3]))
end

# --- boomerang_uniformity catalog regression ----------------------------------

@testset "boomerang_uniformity: AES = 6 (Cid et al. EUROCRYPT 2018 Table 2)" begin
    @test boomerang_uniformity(load_literature_sbox("AES")) == 6
end

@testset "boomerang_uniformity: 4-bit catalog (locked)" begin
    # Values computed by the current Julia implementation. They are
    # locked here so any regression surfaces as a CI failure. Where a
    # value is cross-published, the source is cited inline.
    @test boomerang_uniformity(load_literature_sbox("PRESENT"))    == 16
    @test boomerang_uniformity(load_literature_sbox("GIFT"))       == 16
    @test boomerang_uniformity(load_literature_sbox("Midori_Sb0")) == 16  # involution; BU ≠ DU
    @test boomerang_uniformity(load_literature_sbox("Midori_Sb1")) == 10
    @test boomerang_uniformity(load_literature_sbox("SKINNY_4"))   == 16
    @test boomerang_uniformity(load_literature_sbox("Piccolo"))    == 16
    # Serpent S-boxes: lower bound only (each ≥ DU = 4 since BCT ≥ DDT).
    for i in 0:7
        @test boomerang_uniformity(load_literature_sbox("SERPENT_S$i")) ≥ 4
    end
end

end
