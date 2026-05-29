@testitem "sbox_type" begin
using VBFCatalog
using VBF
using Test

@testset "construction" begin
    @testset "explicit {N,T}" begin
        s = SBox{2, UInt8}(UInt8[0, 1, 2, 3])
        @test inputbits(s) == 2
        @test storage_type(s) === UInt8
        @test length(s) == 4
    end

    @testset "infer T from N" begin
        s = SBox{4}([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
        @test storage_type(s) === UInt8
        @test inputbits(s) == 4
    end

    @testset "infer N and T from LUT length" begin
        s = SBox(collect(0:255))
        @test inputbits(s) == 8
        @test storage_type(s) === UInt8

        s9 = SBox(collect(0:511))
        @test inputbits(s9) == 9
        @test storage_type(s9) === UInt16

        s17 = SBox(collect(0:(1 << 17) - 1))
        @test inputbits(s17) == 17
        @test storage_type(s17) === UInt32
    end

    @testset "validation" begin
        # wrong length
        @test_throws ArgumentError SBox{3, UInt8}(UInt8[0, 1, 2])
        # non-power-of-2 length
        @test_throws ArgumentError SBox([0, 1, 2])
        # out-of-range entries
        @test_throws ArgumentError SBox{2, UInt8}(UInt8[0, 1, 2, 7])  # 7 ≥ 4
        # N exceeds storage width
        @test_throws ArgumentError SBox{9, UInt8}(zeros(UInt8, 512))
        # empty
        @test_throws ArgumentError SBox(Int[])
        # N = 0
        @test_throws ArgumentError SBox{0, UInt8}(UInt8[0])
    end
end

@testset "evaluation" begin
    inv4 = SBox(UInt8[0, 1, 9, 14, 13, 11, 7, 6, 15, 2, 12, 5, 10, 4, 3, 8])  # GIFT-like

    @testset "callable" begin
        @test inv4(0) == 0x00
        @test inv4(2) == 0x09
        @test inv4(15) == 0x08
    end

    @testset "getindex" begin
        @test inv4[0] == 0x00
        @test inv4[2] == 0x09
        @test inv4[15] == 0x08
    end

    @testset "indexing matches lut" begin
        for x in 0:15
            @test inv4(x) == inv4.lut[x + 1]
        end
    end
end

@testset "equality and hash" begin
    a = SBox(UInt8[0, 1, 2, 3])
    b = SBox(UInt8[0, 1, 2, 3])
    c = SBox(UInt8[3, 2, 1, 0])
    d = SBox(UInt8[0, 1, 2, 3, 4, 5, 6, 7])  # different N

    @test a == b
    @test a != c
    @test a != d  # different SBox{N}: returns false, no throw

    @test hash(a) == hash(b)
    @test hash(a) != hash(c)

    s = Set{SBox}()
    push!(s, a); push!(s, b); push!(s, c)
    @test length(s) == 2  # a and b dedup
end

@testset "copy is deep enough" begin
    s = SBox(UInt8[0, 1, 2, 3])
    s2 = copy(s)
    @test s == s2
    s2.lut[1] = 0x02
    @test s != s2
    @test s.lut[1] == 0x00  # original untouched
end

@testset "show" begin
    s = SBox(UInt8[0, 1, 2, 3])
    @test sprint(show, s) == "SBox{2, UInt8} (4-element LUT)"
    out = sprint(show, MIME"text/plain"(), s)
    @test occursin("SBox{2, UInt8}", out)
    @test occursin("0x00", out)
end

end
