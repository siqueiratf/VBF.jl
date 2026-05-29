using VBF
using Test

@testset "identity SBox has trivial DDT" begin
    # F(x) = x: F(x⊕a) ⊕ F(x) = a, so DDT[a, b] = 2^n if a == b, else 0.
    id = SBox(UInt8[0, 1, 2, 3])
    d = ddt(id)
    n = 4
    for a in 0:n - 1, b in 0:n - 1
        @test d[a + 1, b + 1] == (a == b ? n : 0)
    end
end

@testset "row 0 of DDT" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        d = ddt(s)
        n = 1 << inputbits(s)
        @test d[1, 1] == n            # a=b=0 always 2^n
        for b in 2:n
            @test d[1, b] == 0        # a=0, b≠0 always 0
        end
    end
end

@testset "row sums == 2^N for every row" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        d = ddt(s)
        n = 1 << inputbits(s)
        for a in 1:n
            @test sum(view(d, a, :)) == n
        end
    end
end

@testset "all entries even (since N ≥ 2)" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        @test inputbits(s) ≥ 2
        d = ddt(s)
        @test all(iseven, d)
    end
end

# --- known differential uniformity values from primary sources ---------------

@testset "differential_uniformity catalog regression" begin
    # AES: famously 4-uniform (inversion in GF(2^8)).
    @test differential_uniformity(load_literature_sbox("AES"))     == 4
    @test differential_uniformity(load_literature_sbox("AES_inv")) == 4

    # 4-bit ciphers, all from their respective spec papers:
    @test differential_uniformity(load_literature_sbox("PRESENT"))    == 4
    @test differential_uniformity(load_literature_sbox("GIFT"))       == 6
    @test differential_uniformity(load_literature_sbox("Midori_Sb0")) == 4
    @test differential_uniformity(load_literature_sbox("Midori_Sb1")) == 4
    @test differential_uniformity(load_literature_sbox("SKINNY_4"))   == 4
    @test differential_uniformity(load_literature_sbox("Piccolo"))    == 4

    # Serpent: all 8 S-boxes are 4-uniform by design.
    for i in 0:7
        @test differential_uniformity(load_literature_sbox("SERPENT_S$i")) == 4
    end
end

# --- differential_spectrum ---------------------------------------------------

@testset "differential_spectrum: shape" begin
    s = load_literature_sbox("PRESENT")
    sp = differential_spectrum(s)
    n = 1 << inputbits(s)
    # excludes row a=0 → 15 rows × 16 cols = 240 entries
    @test total_mass(sp) == (n - 1) * n
    # max entry is the differential uniformity (4 for PRESENT)
    @test maximum(first.(sorted_pairs(sp))) == 4
end

@testset "differential_spectrum: AES values" begin
    # AES DDT is known: non-zero entries are 0, 2, 4. Row-by-row,
    # exactly 1 entry of 4 + 126 entries of 2 + 129 entries of 0
    # (per row excluding row 0 of a 4-uniform AES-style S-box).
    s = load_literature_sbox("AES")
    sp = differential_spectrum(s)
    pairs = sorted_pairs(sp)
    # The DDT entries of AES contain only {0, 2, 4}
    @test Set(first.(pairs)) ⊆ Set([0, 2, 4])
    @test haskey(sp, 0) && haskey(sp, 2) && haskey(sp, 4)
end
