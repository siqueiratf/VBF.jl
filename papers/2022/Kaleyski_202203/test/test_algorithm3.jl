@testset "algorithm3_test" begin
    include(joinpath(@__DIR__, "..", "algorithm3.jl"))

    # Algorithm 3: inner permutation search.
    # Given F and currentG = F(A2(·)), recover A2.

    n = 5
    F = gold_x3(n)
    sz = 1 << n

    # A2 = swap bits 0 and 1 (specific bijective linear map)
    function swap_bits01(x)
        b0 = (x >> 0) & 1
        b1 = (x >> 1) & 1
        rest = x & ~3
        rest | (b1 << 0) | (b0 << 1)
    end
    A2_lut = UInt8[swap_bits01(x) for x = 0:(sz - 1)]
    @test length(unique(A2_lut)) == sz   # bijection

    # currentG = F ∘ A2
    currentG = SBox{n,UInt8}(UInt8[F.lut[A2_lut[x + 1] + 1] for x = 0:(sz - 1)])

    result = inner_permutation(F, currentG)
    @test result !== nothing
    @test result.A2 == A2_lut
    @test all(d == 0x00 for d in result.A_drift)

    # Certificate validity: F(A2(x)) ⊕ drift(x) == currentG(x) for all x
    @test all(
        xor(F.lut[result.A2[x + 1] + 1], result.A_drift[x + 1]) ==
        currentG.lut[x + 1] for x = 0:(sz - 1)
    )

    # If F and H are NOT related by a linear map, inner_permutation returns nothing.
    # Use a function with totally different structure.
    H_lut = UInt8[xor(x, 1) for x = 0:(sz - 1)]   # affine, not APN
    H = SBox{n,UInt8}(H_lut)
    @test inner_permutation(F, H) === nothing
end
