@testitem "partial_isomorphism" begin
    using VBF, Test, Random

    A = VBF._PartialF2Isomorphism(4)
    @test VBF._partial_insert!(A, UInt32(3), UInt32(5))
    @test VBF._partial_insert!(A, UInt32(6), UInt32(9))
    @test VBF._partial_image(A, UInt32(5)) == UInt32(12)
    @test VBF._partial_image(A, UInt32(1)) === nothing
    @test !VBF._partial_insert!(A, UInt32(5), UInt32(11))
    @test !VBF._partial_insert!(A, UInt32(1), UInt32(12))
    @test A.rank == 2
    L = VBF._partial_complete(A)
    @test is_invertible(L)
    @test L(3) == 5 && L(6) == 9
    B = copy(A)
    @test VBF._partial_insert!(B, UInt32(1), UInt32(1))
    @test A.rank == 2 && B.rank == 3

    rng = Xoshiro(940)
    for n in 1:12
        L = random_invertible_linear_map(rng, Val(n), UInt32)
        A = VBF._PartialF2Isomorphism(n)
        for x in rand(rng, UInt32(0):UInt32((1 << n)-1), 30)
            @test VBF._partial_insert!(A, x, L(x))
        end
        M = VBF._partial_complete(A)
        @test is_invertible(M)
        for x in UInt32(0):UInt32((1 << n)-1)
            y = VBF._partial_image(A, x)
            y === nothing || @test M(x) == y == L(x)
        end
    end

    for T in (Int32, Int64, BigInt)
        v = T[3, -2, 5, 7, -1, 0, 4, 8]
        original = copy(v)
        @test walsh_hadamard!(v) === v
        @test v == T[sum(original[x+1] * (isodd(count_ones(x & a)) ? -1 : 1)
                          for x in 0:7) for a in 0:7]
        walsh_hadamard!(v)
        @test v == 8 .* original
    end
end
