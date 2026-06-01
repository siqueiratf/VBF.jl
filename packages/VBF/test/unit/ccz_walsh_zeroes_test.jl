@testitem "ccz_walsh_zeroes" begin
using VBFCatalog
using VBF
using Test

@testset "walsh_zeroes: basic shape and ordering" begin
    F = load_literature_sbox("PRESENT")
    Z = walsh_zeroes(F)
    @test eltype(Z) == UInt32
    @test issorted(Z)
    @test allunique(Z)
    # Every entry lies in [0, 2^(2N))
    @test all(z -> z < UInt32(1) << 8, Z)
end

@testset "walsh_zeroes: contains the trivial (a, 0) column" begin
    # LAT(a, 0) = 0 for every a ≠ 0 (b = 0 is the zero linear form on output).
    F = load_literature_sbox("PRESENT")
    N = inputbits(F)
    Z = walsh_zeroes(F)
    for a in 1:((1 << N) - 1)
        packed = (UInt32(a) << N) | UInt32(0)
        @test packed in Z
    end
    # The trivial entry (0, 0) has LAT == 2ⁿ ≠ 0 and is NOT in Z.
    @test !(UInt32(0) in Z)
end

@testset "walsh_zeroes: parity with LAT" begin
    F = load_literature_sbox("GIFT")
    N = inputbits(F)
    L = lat(F)
    Z = walsh_zeroes(F)
    n_size = 1 << N
    # Z exactly captures positions where LAT == 0.
    for a in 0:(n_size - 1), b in 0:(n_size - 1)
        packed = (UInt32(a) << N) | UInt32(b)
        expected_in_Z = (L[a + 1, b + 1] == 0)
        @test (packed in Z) == expected_in_Z
    end
end

@testset "walsh_zeroes: same size on inv(F) (CCZ-invariance)" begin
    # CCZ-equivalence preserves |Z(F)|. Functional inverse is always CCZ-equivalent to F, so |Z(F)| == |Z(F⁻¹)|.
    for name in ("PRESENT", "GIFT", "SKINNY_4", "Midori_Sb0")
        F = load_literature_sbox(name)
        @test is_permutation(F)
        @test walsh_zeroes_size(F) == walsh_zeroes_size(inv(F))
    end
end

@testset "walsh_zeroes_size: matches direct count from LAT" begin
    F = load_literature_sbox("PRESENT")
    L = lat(F)
    direct = count(==(0), L)
    @test walsh_zeroes_size(F) == direct
end

@testset "walsh_zeroes: packing convention (a << N) | b" begin
    F = load_literature_sbox("PRESENT")
    N = inputbits(F)
    L = lat(F)
    Z = walsh_zeroes(F)
    mask = (UInt32(1) << N) - UInt32(1)
    # Spot-check: each Z entry's unpacked (a, b) gives LAT == 0.
    for z in Z[1:min(end, 20)]
        a = z >> N
        b = z & mask
        @test L[a + 1, b + 1] == 0
    end
end

end
