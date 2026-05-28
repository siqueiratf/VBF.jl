using BFA
using Test
using Random

_rand_invertible_linear(rng, ::Val{N}, ::Type{T}) where {N, T} =
    random_invertible_linear_map(rng, Val(N), T)

@testset "identity / zero affine maps" begin
    id = identity_affine_map(5, UInt8)
    @test is_linear(id)
    @test all(id(x) == x for x in 0:31)
    z = zero_affine_map(5, UInt8)
    @test all(z(x) == 0 for x in 0:31)
end

@testset "affine inverse is a two-sided inverse" begin
    rng = MersenneTwister(0xA1)
    for _ in 1:20
        L = _rand_invertible_linear(rng, Val(6), UInt8)
        c = rand(rng, UInt8) & UInt8(0x3F)
        A = F2AffineMap{6, UInt8}(L, c)
        Ainv = inv(A)
        @test all(Ainv(A(UInt8(x))) == UInt8(x) for x in 0:63)
        @test all(A(Ainv(UInt8(x))) == UInt8(x) for x in 0:63)
    end
end

@testset "compose matches pointwise composition" begin
    rng = MersenneTwister(0xB2)
    for _ in 1:20
        A = F2AffineMap{6, UInt8}(_rand_invertible_linear(rng, Val(6), UInt8),
                                  rand(rng, UInt8) & UInt8(0x3F))
        B = F2AffineMap{6, UInt8}(_rand_invertible_linear(rng, Val(6), UInt8),
                                  rand(rng, UInt8) & UInt8(0x3F))
        AB = compose(A, B)
        @test all(AB(UInt8(x)) == A(B(UInt8(x))) for x in 0:63)
        @test (A ∘ B) == AB
    end
end

@testset "transpose: involution on linear maps, errors on affine" begin
    rng = MersenneTwister(0xC3)
    L = _rand_invertible_linear(rng, Val(6), UInt8)
    Alin = F2AffineMap{6, UInt8}(L, UInt8(0))
    @test transpose(transpose(Alin)) == Alin
    Aaff = F2AffineMap{6, UInt8}(L, UInt8(0b000001))
    @test_throws ArgumentError transpose(Aaff)
end

@testset "complete_basis_reversed" begin
    # Input occupies the last positions; result is a full-rank basis.
    part = UInt8[0b000111, 0b011000]
    br = complete_basis_reversed(part, 6)
    @test length(br) == 6
    @test rank_f2(br; nbits = 6) == 6
    @test br[end - 1:end] == part
    # Empty input completes to a full standard basis.
    @test rank_f2(complete_basis_reversed(UInt8[], 5); nbits = 5) == 5
    # Dependent input is rejected.
    @test_throws ArgumentError complete_basis_reversed(UInt8[0b001, 0b010, 0b011], 4)
end

@testset "generating_affine_map family" begin
    basis = UInt8[0b000111, 0b011000]
    g = generating_affine_map(basis, 6)
    @test is_invertible(g.linear)
    @test g(UInt8(1)) == basis[1] && g(UInt8(2)) == basis[2]

    gr = generating_affine_map_r(basis, 6)
    @test is_invertible(gr.linear)
    # basis lands on the highest-index columns
    @test gr(UInt8(1) << 4) == basis[1] && gr(UInt8(1) << 5) == basis[2]
end

@testset "affine_map_from_masks / from_range_and_image" begin
    masks = UInt8[0b000011, 0b001100]
    fm = affine_map_from_masks(masks, 6)
    @test fm(UInt8(1)) == masks[1] && fm(UInt8(2)) == masks[2]
    @test fm(UInt8(4)) == 0   # beyond the supplied masks → 0

    inputs = UInt8[0b000011, 0b001100]
    outputs = UInt8[0b110000, 0b000110]
    rai = affine_map_from_range_and_image(inputs, outputs, 6)
    @test rai(inputs[1]) == outputs[1]
    @test rai(inputs[2]) == outputs[2]
end

@testset "block_diagonal_affine_map: low block then high block" begin
    # B acts on low bits, A on high bits.
    A = F2AffineMap{2, UInt8}(F2LinearMap{2, UInt8}(UInt8[0b10, 0b01]), UInt8(0))  # swap 2 bits
    B = identity_affine_map(3, UInt8)
    blk = block_diagonal_affine_map(A, B)
    @test inputbits(blk) == 5
    # low 3 bits identity, high 2 bits swapped
    for x in 0:31
        lo = x & 0b111
        hi = (x >> 3) & 0b11
        hi_swapped = ((hi & 1) << 1) | ((hi >> 1) & 1)
        @test blk(UInt8(x)) == UInt8(lo | (hi_swapped << 3))
    end
end

@testset "swap_affine_map is an involution swapping branches" begin
    sw = swap_affine_map(2, 4, 4)   # n+m = 8
    @test inputbits(sw) == 8
    @test all(sw(sw(UInt16(x))) == UInt16(x) for x in 0:255)
end
