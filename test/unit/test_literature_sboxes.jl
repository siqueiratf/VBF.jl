using BFA
using Test

# Expected catalog at v0.1: 1 AES + 1 AES_inv + 6 + 8 four-bit S-boxes.
const EXPECTED_NAMES = [
    "AES", "AES_inv",
    "GIFT", "Midori_Sb0", "Midori_Sb1", "PRESENT", "Piccolo",
    "SERPENT_S0", "SERPENT_S1", "SERPENT_S2", "SERPENT_S3",
    "SERPENT_S4", "SERPENT_S5", "SERPENT_S6", "SERPENT_S7",
    "SKINNY_4",
]

@testset "catalog enumeration" begin
    names = literature_sbox_names()
    @test names == EXPECTED_NAMES
    @test length(names) == 16
end

@testset "metadata schema" begin
    for name in literature_sbox_names()
        meta = literature_sbox_metadata(name)
        @test haskey(meta, "n")
        @test haskey(meta, "m")
        @test haskey(meta, "lut")
        @test haskey(meta, "bib_key")
        @test haskey(meta, "source")
        @test haskey(meta, "is_permutation")
        @test length(meta["lut"]) == 1 << meta["n"]
    end
end

@testset "load_literature_sbox: type / shape" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        meta = literature_sbox_metadata(name)
        @test s isa SBox
        @test inputbits(s) == meta["n"]
        @test length(s) == 1 << meta["n"]
    end
end

@testset "permutation property" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        if literature_sbox_metadata(name)["is_permutation"]
            n = inputbits(s)
            @test Set(s.lut) == Set(0:(1 << n) - 1)
        end
    end
end

# --- spot LUT values (fingerprints from primary specs) -----------------------

@testset "AES fingerprints (FIPS 197 Table 4)" begin
    s = load_literature_sbox("AES")
    @test storage_type(s) === UInt8
    @test s(0x00) == 0x63
    @test s(0x01) == 0x7c
    @test s(0x53) == 0xed
    @test s(0xff) == 0x16
end

@testset "AES_inv is the inverse of AES" begin
    s    = load_literature_sbox("AES")
    sinv = load_literature_sbox("AES_inv")
    for x in 0:255
        @test sinv(s(x)) == x
        @test s(sinv(x)) == x
    end
end

@testset "PRESENT (CHES'07 spec)" begin
    s = load_literature_sbox("PRESENT")
    @test s.lut == UInt8[0xc, 0x5, 0x6, 0xb, 0x9, 0x0, 0xa, 0xd,
                        0x3, 0xe, 0xf, 0x8, 0x4, 0x7, 0x1, 0x2]
    @test s(0x0) == 0xc
    @test s(0x5) == 0x0
end

@testset "GIFT (CHES'17 spec)" begin
    s = load_literature_sbox("GIFT")
    @test s(0x0) == 0x1
    @test s(0xf) == 0xe
end

@testset "Midori Sb0 == Sb0; Sb0 ≠ Sb1" begin
    a = load_literature_sbox("Midori_Sb0")
    b = load_literature_sbox("Midori_Sb1")
    @test a != b
    @test a(0x0) == 0xc
    @test b(0x0) == 0x1
end

@testset "SERPENT: all 8 distinct" begin
    serpents = [load_literature_sbox("SERPENT_S$i") for i in 0:7]
    @test length(Set(serpents)) == 8
end

# --- error paths -------------------------------------------------------------

@testset "unknown name" begin
    @test_throws ArgumentError load_literature_sbox("NoSuchSbox")
    @test_throws ArgumentError literature_sbox_metadata("NoSuchSbox")
end

# --- integration with f2/ primitives -----------------------------------------

@testset "anf roundtrip survives every literature S-box" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        @test mobius!(anf(s)) == s.lut
    end
end

@testset "Walsh of bit-0 component is bounded by 2^N (Parseval consequence)" begin
    # bit b of s(x) viewed as a Boolean function: every Walsh coefficient ≤ 2^N in absolute value.
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        n = inputbits(s)
        bit_0 = Int[(s(x) & 0x1) % Int for x in 0:(1 << n) - 1]
        w = walsh_transform(bit_0)
        @test all(c -> abs(c) ≤ (1 << n), w)
        # Parseval invariant
        @test sum(abs2, w) == (1 << n) * (1 << n)   # spec values are ±1, so sum_squared_before = 2^n
    end
end
