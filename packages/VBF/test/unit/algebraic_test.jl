@testitem "algebraic" setup=[SBoxFixtures] begin

using VBF
using Test

@testset "algebraic_degree: identity SBox" begin
    id = SBox(UInt8[0, 1, 2, 3])   # F(x) = x → each coordinate is x_b → degree 1
    @test algebraic_degree(id) == 1
end

@testset "algebraic_degree: constant SBox" begin
    c = SBox(UInt8[2, 2, 2, 2])   # F(x) = 2 → only constant monomial → degree 0
    @test algebraic_degree(c) == 0
end

@testset "algebraic_degree: F(x) = x_0 x_1 in bit 0 → degree 2" begin
    # truth table for f_0(x_1 x_0) = x_0 x_1, other bits 0: TT = [0, 0, 0, 1]
    s = SBox(UInt8[0, 0, 0, 1])
    @test algebraic_degree(s) == 2
end

# --- fixed-vector regression ------------------------------------------------------

@testset "algebraic_degree fixed-vector regression" begin
    # AES (inversion in GF(2^8)): every coordinate is degree-7 (Daemen-Rijmen).
    @test algebraic_degree(fixture_sbox("AES"))     == 7
    @test algebraic_degree(fixture_sbox("AES_inv")) == 7

    # All "good" 4-bit S-boxes are degree-3 by design (no degree-1 or 2 would be enough to resist higher-order attacks; degree-3 is the standard choice).
    @test algebraic_degree(fixture_sbox("PRESENT"))    == 3
    @test algebraic_degree(fixture_sbox("GIFT"))       == 3
    @test algebraic_degree(fixture_sbox("Midori_Sb0")) == 3
    @test algebraic_degree(fixture_sbox("Midori_Sb1")) == 3
    @test algebraic_degree(fixture_sbox("SKINNY_4"))   == 3
    @test algebraic_degree(fixture_sbox("Piccolo"))    == 3
    for i in 0:7
        @test algebraic_degree(fixture_sbox("SERPENT_S$i")) == 3
    end
end

# --- degree_spectrum ---------------------------------------------------------

@testset "degree_spectrum: identity" begin
    id = SBox(UInt8[0, 1, 2, 3])
    # 2 output coordinates, each degree 1
    @test degree_spectrum(id) == Spectrum([1, 1])
end

@testset "degree_spectrum: AES is uniformly degree-7" begin
    s = fixture_sbox("AES")
    sp = degree_spectrum(s)
    @test sorted_pairs(sp) == [7 => 8]
end

@testset "degree_spectrum: PRESENT (per-bit degrees, locked)" begin
    s = fixture_sbox("PRESENT")
    sp = degree_spectrum(s)
    @test total_mass(sp) == 4         # 4 output bits
    @test maximum(first.(sorted_pairs(sp))) == 3
end

end
