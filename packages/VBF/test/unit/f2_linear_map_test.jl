@testitem "f2_linear_map" begin
using VBFCatalog
using VBF
using Test

@testset "construction" begin
    L = F2LinearMap{4, UInt8}(UInt8[1, 2, 4, 8])
    @test inputbits(L) == 4
    @test storage_type(L) === UInt8

    @test F2LinearMap{4}([1, 2, 4, 8]).cols == [0x01, 0x02, 0x04, 0x08]
    @test F2LinearMap([1, 2, 4, 8]).cols == [0x01, 0x02, 0x04, 0x08]
end

@testset "validation" begin
    @test_throws ArgumentError F2LinearMap{4, UInt8}(UInt8[1, 2, 4])           # length
    @test_throws ArgumentError F2LinearMap{4, UInt8}(UInt8[1, 2, 4, 16])       # out of range
    @test_throws ArgumentError F2LinearMap{9, UInt8}(zeros(UInt8, 9))          # N > 8 for UInt8
    @test_throws ArgumentError F2LinearMap(Int[])                              # empty
end

@testset "identity_linear_map" begin
    id4 = identity_linear_map(4)
    @test id4.cols == [0x01, 0x02, 0x04, 0x08]
    @test storage_type(id4) === UInt8

    id9 = identity_linear_map(9)
    @test storage_type(id9) === UInt16
    @test id9.cols[1] == 0x0001
    @test id9.cols[9] == 0x0100

    # identity acts as identity
    for x in 0:15
        @test id4(x) == x
    end
end

@testset "zero_linear_map" begin
    Z = zero_linear_map(4)
    @test all(==(0), Z.cols)
    for x in 0:15
        @test Z(x) == 0
    end
end

@testset "evaluation on a non-identity map" begin
    # L: bit 0 ↦ 0b0011, bit 1 ↦ 0b0110, bit 2 ↦ 0b1100, bit 3 ↦ 0b1001
    L = F2LinearMap(UInt8[0b0011, 0b0110, 0b1100, 0b1001])
    @test L(0)          == 0
    @test L(0b0001)     == 0b0011
    @test L(0b0010)     == 0b0110
    @test L(0b0011)     == 0b0011 ⊻ 0b0110   # F₂-linearity
    @test L(0b1111)     == 0b0011 ⊻ 0b0110 ⊻ 0b1100 ⊻ 0b1001  # == 0

    # linearity: L(a ⊻ b) == L(a) ⊻ L(b) for all a,b
    for a in 0:15, b in 0:15
        @test L(a ⊻ b) == L(a) ⊻ L(b)
    end
end

@testset "equality / hash / copy" begin
    a = F2LinearMap(UInt8[1, 2, 4, 8])
    b = F2LinearMap(UInt8[1, 2, 4, 8])
    c = F2LinearMap(UInt8[1, 2, 4, 9])
    d = identity_linear_map(8)

    @test a == b
    @test a != c
    @test a != d
    @test hash(a) == hash(b)

    a2 = copy(a)
    a2.cols[1] = 0x02
    @test a != a2
    @test a.cols[1] == 0x01
end

@testset "show identifies identity" begin
    L = identity_linear_map(4)
    @test occursin("(identity)", sprint(show, L))
    @test !occursin("(identity)", sprint(show, F2LinearMap(UInt8[1, 2, 4, 9])))
end

end
