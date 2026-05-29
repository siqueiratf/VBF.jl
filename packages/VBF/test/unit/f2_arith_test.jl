@testitem "f2_arith" begin
using VBFCatalog
using VBF
using Test
using Random

@testset "parity" begin
    @test parity(0) == 0
    @test parity(0b0001) == 1
    @test parity(0b0011) == 0
    @test parity(0b0111) == 1
    @test parity(0b1111) == 0
    @test parity(UInt64(typemax(UInt32))) == 0  # 32 ones
    @test parity(true) == 1
    @test parity(false) == 0
end

@testset "f2_dot" begin
    @test f2_dot(0b1100, 0b0011) == 0
    @test f2_dot(0b1100, 0b0100) == 1
    @test f2_dot(0b1111, 0b1111) == 0   # 4 ones
    @test f2_dot(0b1111, 0b1110) == 1   # 3 ones
    # bilinear: f2_dot(a, b ⊻ c) = f2_dot(a,b) ⊻ f2_dot(a,c)
    rng = MersenneTwister(0xBFA)
    for _ in 1:100
        a = rand(rng, UInt32); b = rand(rng, UInt32); c = rand(rng, UInt32)
        @test f2_dot(a, b ⊻ c) == (f2_dot(a, b) ⊻ f2_dot(a, c))
    end
end

@testset "gauss_jordan! and rank_f2" begin
    @testset "trivial cases" begin
        @test gauss_jordan!(UInt8[]) == 0
        @test gauss_jordan!(UInt8[0, 0, 0]) == 0
        @test rank_f2(UInt8[1, 2, 4, 8]) == 4
        @test rank_f2(UInt8[1, 2, 3]) == 2   # 3 = 1 ⊻ 2
    end

    @testset "redundancy removal" begin
        # 5 = 1 ⊻ 4
        rs = UInt8[1, 2, 4, 5]
        @test rank_f2(rs) == 3
    end

    @testset "nbits truncation" begin
        # bit 4 outside the window
        @test rank_f2(UInt8[0b10000, 0b00001]; nbits = 4) == 1
        @test rank_f2(UInt8[0b10000, 0b00001]; nbits = 5) == 2
    end

    @testset "in-place leaves zero rows at the end" begin
        rows = UInt8[1, 2, 4, 5, 6]  # rank 3
        r = gauss_jordan!(rows)
        @test r == 3
        @test all(==(0), rows[r + 1:end])
    end

    @testset "random matrices: rank equals full when rows independent" begin
        rng = MersenneTwister(0xC0FFEE)
        for n in (4, 8, 12)
            # generate n independent rows
            T = n ≤ 8 ? UInt8 : (n ≤ 16 ? UInt16 : UInt32)
            rows = T[T(1) << j for j in 0:n-1]
            shuffle!(rng, rows)
            @test rank_f2(rows; nbits = n) == n
        end
    end
end

@testset "linear_basis" begin
    b = linear_basis(UInt8[1, 2, 3])
    @test length(b) == 2
    # they should span the same set
    @test sort(unique(b)) ⊆ [0x01, 0x02, 0x03]
    # adding a redundant vector
    @test length(linear_basis(UInt8[1, 2, 4, 7])) == 3   # 7 = 1⊻2⊻4
end

@testset "is_in_span" begin
    basis = linear_basis(UInt8[1, 2])   # span = {0,1,2,3}
    @test is_in_span(UInt8(0), basis)
    @test is_in_span(UInt8(1), basis)
    @test is_in_span(UInt8(2), basis)
    @test is_in_span(UInt8(3), basis)
    @test !is_in_span(UInt8(4), basis)
    @test !is_in_span(UInt8(5), basis)

    # full F₂⁴ basis
    full = linear_basis(UInt8[1, 2, 4, 8])
    for x in 0:15
        @test is_in_span(UInt8(x), full)
    end
end

@testset "complete_basis" begin
    @testset "from empty" begin
        b = complete_basis(UInt8[], 4)
        @test length(b) == 4
        # spans everything
        basis = linear_basis(b)
        for x in 0:15
            @test is_in_span(UInt8(x), basis)
        end
    end

    @testset "from partial" begin
        partial = UInt8[0b0011]
        b = complete_basis(partial, 4)
        @test length(b) == 4
        @test b[1] == 0b0011
        # spans F₂⁴
        basis = linear_basis(b)
        for x in 0:15
            @test is_in_span(UInt8(x), basis)
        end
    end

    @testset "already full" begin
        b = complete_basis(UInt8[1, 2, 4, 8], 4)
        @test length(b) == 4
        @test b == UInt8[1, 2, 4, 8]
    end

    @testset "rejects dependent input" begin
        @test_throws ArgumentError complete_basis(UInt8[1, 2, 3], 4)   # 3 = 1⊻2
    end
end

end
