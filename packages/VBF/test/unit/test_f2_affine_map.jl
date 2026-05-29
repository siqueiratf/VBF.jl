using VBF
using Test

@testset "construction" begin
    L = identity_linear_map(4)
    A = F2AffineMap(L, 0b0101)
    @test inputbits(A) == 4
    @test storage_type(A) === UInt8
    @test A.constant == 0x05
end

@testset "evaluation" begin
    L = identity_linear_map(4)
    A = F2AffineMap(L, UInt8(0b0101))
    @test A(0b0000) == 0b0101
    @test A(0b1010) == 0b1111
    @test A(0b1111) == 0b1010
end

@testset "is_linear" begin
    L = identity_linear_map(4)
    @test is_linear(F2AffineMap(L, 0))
    @test !is_linear(F2AffineMap(L, 1))
end

@testset "validation: constant in range" begin
    L = identity_linear_map(4)
    @test_throws ArgumentError F2AffineMap{4, UInt8}(L, UInt8(0x10))  # 16 ≥ 2^4
end

@testset "equality / hash / copy" begin
    L = identity_linear_map(4)
    a = F2AffineMap(L, 1)
    b = F2AffineMap(L, 1)
    c = F2AffineMap(L, 2)
    d = F2AffineMap(zero_linear_map(4), 1)

    @test a == b
    @test a != c
    @test a != d
    @test hash(a) == hash(b)

    a2 = copy(a)
    a2.linear.cols[1] = 0x02
    @test a != a2
end

@testset "show identifies linear" begin
    L = identity_linear_map(4)
    @test occursin("(linear)", sprint(show, F2AffineMap(L, 0)))
    @test !occursin("(linear)", sprint(show, F2AffineMap(L, 1)))
end
