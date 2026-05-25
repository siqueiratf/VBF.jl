using BFA
using Test

@testset "identity SBox: LAT" begin
    # F(x) = x ⇒ b · F(x) = b · x ⇒ LAT[a, b] = 2^n if a == b, else 0.
    id = SBox(UInt8[0, 1, 2, 3])
    L = lat(id)
    n = 4
    for a in 0:n - 1, b in 0:n - 1
        @test L[a + 1, b + 1] == (a == b ? n : 0)
    end
end

@testset "LAT[0, 0] == 2^N for every S-box" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        L = lat(s)
        n = 1 << inputbits(s)
        @test L[1, 1] == n
    end
end

@testset "LAT[a, 0] == 0 for a ≠ 0 (constant balanced 0 output)" begin
    # column 0 corresponds to b=0 → Boolean function f(x) = 0 → spectrum [2^N, 0, …, 0]
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        L = lat(s)
        n = 1 << inputbits(s)
        for a in 2:n
            @test L[a, 1] == 0
        end
    end
end

@testset "LAT[0, b] == 0 for b ≠ 0 on every permutation" begin
    # Every output coordinate of a permutation is balanced ⇒ Walsh at a=0 is 0.
    for name in literature_sbox_names()
        meta = literature_sbox_metadata(name)
        meta["is_permutation"] || continue
        s = load_literature_sbox(name)
        L = lat(s)
        n = 1 << inputbits(s)
        for b in 2:n
            @test L[1, b] == 0
        end
    end
end

@testset "all LAT entries are even (N ≥ 2)" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        L = lat(s)
        @test all(iseven, L)
    end
end

@testset "Parseval per column: ∑_a LAT[a, b]^2 == 2^(2N)" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        L = lat(s)
        n = size(L, 1)
        target = n * n
        for b in 1:n
            @test sum(view(L, :, b) .^ 2) == target
        end
    end
end

# --- known linearity values from primary sources ----------------------------

@testset "linearity catalog regression" begin
    # AES (Daemen-Rijmen): nonlinearity 112, linearity = 2^7 - 2·112 = 32.
    @test linearity(load_literature_sbox("AES"))     == 32
    @test linearity(load_literature_sbox("AES_inv")) == 32

    # 4-bit ciphers: all designed for linearity 8 except GIFT and Piccolo
    # (which trade off vs. circuit area).
    @test linearity(load_literature_sbox("PRESENT"))    == 8
    @test linearity(load_literature_sbox("GIFT"))       == 8
    @test linearity(load_literature_sbox("Midori_Sb0")) == 8
    @test linearity(load_literature_sbox("Midori_Sb1")) == 8
    @test linearity(load_literature_sbox("SKINNY_4"))   == 8
    @test linearity(load_literature_sbox("Piccolo"))    == 8

    # Serpent: all 8 are designed with linearity 8.
    for i in 0:7
        @test linearity(load_literature_sbox("SERPENT_S$i")) == 8
    end
end

# --- absolute_walsh_spectrum ------------------------------------------------

@testset "absolute_walsh_spectrum: shape" begin
    s = load_literature_sbox("AES")
    sp = absolute_walsh_spectrum(s)
    # excludes (0,0) entry only
    @test total_mass(sp) == 256 * 256 - 1
    @test maximum(first.(sorted_pairs(sp))) == 32   # = linearity(AES)
end

@testset "absolute_walsh_spectrum: AES alphabet" begin
    # For N ≥ 2 every LAT entry is a multiple of 4. AES's |LAT| alphabet
    # is {0, 4, 8, 12, 16, 20, 24, 28, 32}.
    s = load_literature_sbox("AES")
    sp = absolute_walsh_spectrum(s)
    @test Set(first.(sorted_pairs(sp))) == Set([0, 4, 8, 12, 16, 20, 24, 28, 32])
end
