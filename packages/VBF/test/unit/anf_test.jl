@testitem "anf" begin

using VBF
using Test
using Random

@testset "mobius! on trivial inputs" begin
    # length 1 — no-op
    v = UInt8[0x05]
    mobius!(v)
    @test v == UInt8[0x05]

    # length 2 — single butterfly
    v = UInt8[0x01, 0x03]
    mobius!(v)
    @test v == UInt8[0x01, 0x02]   # second entry XOR-ed with first

    # length 4 — F(00)=0, F(01)=1, F(10)=0, F(11)=1 is the function "bit 0". ANF: F(x) = x_0; coefficients [const, x_0, x_1, x_0 x_1] = [0, 1, 0, 0].
    v = UInt8[0, 1, 0, 1]
    mobius!(v)
    @test v == UInt8[0, 1, 0, 0]

    # And the involution recovers the truth table.
    mobius!(v)
    @test v == UInt8[0, 1, 0, 1]
end

@testset "mobius! is involutive over F₂" begin
    rng = MersenneTwister(0xBFA)
    @testset "n=$n" for n in 1:8
        len = 1 << n
        v = rand(rng, UInt8, len)
        v_orig = copy(v)
        mobius!(v)
        @test v != v_orig || iszero(v_orig)   # transform actually changes something
        mobius!(v)
        @test v == v_orig
    end
end

@testset "mobius! across widths" begin
    rng = MersenneTwister(0xC0FFEE)
    @testset "$T n=$n" for T in (UInt8, UInt16, UInt32, UInt64), n in (3, 6)
        len = 1 << n
        v = rand(rng, T, len) .& T((T(1) << n) - 1)   # mask to N bits
        v_orig = copy(v)
        mobius!(v)
        mobius!(v)
        @test v == v_orig
    end
end

@testset "mobius!: validation" begin
    @test_throws ArgumentError mobius!(UInt8[])
    @test_throws ArgumentError mobius!(UInt8[1, 2, 3])   # not power of 2
end

@testset "allocating mobius preserves input" begin
    v = UInt8[1, 2, 3, 4]
    out = mobius(v)
    @test v == UInt8[1, 2, 3, 4]
    @test out != v
end

@testset "anf(s::SBox)" begin
    # identity SBox: F(x) = x; ANF should be the indicator monomial x_b for bit b — i.e., anf[m+1] has bit b set iff m = 2^b.
    id = SBox(UInt8[0, 1, 2, 3])  # N=2
    a = anf(id)
    @test length(a) == 4
    @test a[1] == 0x00          # no constant term
    @test a[2] == 0x01          # x_0 → bit 0
    @test a[3] == 0x02          # x_1 → bit 1
    @test a[4] == 0x00          # x_0 x_1 absent

    # ANF is involutive: re-applying Möbius recovers the LUT
    @test mobius!(copy(a)) == id.lut
end

@testset "anf reflects algebraic degree of small functions" begin
    # F(x_1, x_0) = x_0 x_1 in bit 0 only truth table: F(00)=0, F(01)=0, F(10)=0, F(11)=1
    s = SBox(UInt8[0, 0, 0, 1])
    a = anf(s)
    @test a[1] == 0  # no constant
    @test a[2] == 0  # no x_0
    @test a[3] == 0  # no x_1
    @test a[4] == 1  # x_0 x_1 appears in bit 0
end

@testset "anf roundtrip on random SBoxes" begin
    rng = MersenneTwister(0xDEADBEEF)
    for N in (3, 4, 5, 6, 8)
        mask = UInt8((1 << N) - 1)
        N > 8 && (mask = UInt16((1 << N) - 1))
        T = N ≤ 8 ? UInt8 : UInt16
        for _ in 1:5
            lut = T.(rand(rng, 0:(1 << N) - 1, 1 << N))
            s = SBox{N, T}(lut)
            a = anf(s)
            @test mobius!(copy(a)) == s.lut
        end
    end
end

end
