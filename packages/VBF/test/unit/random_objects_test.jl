@testitem "random_objects" begin
using VBFCatalog
using VBF
using Test
using Random

@testset "random_permutation_sbox: always a permutation; deterministic" begin
    rng = MersenneTwister(0x1234)
    for N in (3, 4, 5, 6)
        s = random_permutation_sbox(rng, Val(N))
        @test s isa SBox{N}
        @test is_permutation(s)
    end
    # same seed → same object
    @test random_permutation_sbox(MersenneTwister(9), Val(5)) ==
          random_permutation_sbox(MersenneTwister(9), Val(5))
end

@testset "random_function_sbox: in range; covers non-permutations" begin
    rng = MersenneTwister(0x5678)
    sboxes = [random_function_sbox(rng, Val(4)) for _ in 1:50]
    @test all(s -> all(0 ≤ v ≤ 15 for v in s.lut), sboxes)
    # a uniform random 4-bit function is almost surely not a permutation
    @test any(!is_permutation, sboxes)
end

@testset "random_invertible_linear_map: always invertible" begin
    rng = MersenneTwister(0x9abc)
    for N in (4, 5, 6, 8)
        for _ in 1:20
            L = random_invertible_linear_map(rng, Val(N))
            @test is_invertible(L)
        end
    end
    # alias points at the same generator
    @test random_linear_permutation === random_invertible_linear_map
end

@testset "random_linear_function: shape; storage type override" begin
    rng = MersenneTwister(0xdef0)
    L = random_linear_function(rng, Val(5))
    @test L isa F2LinearMap{5}
    @test length(L.cols) == 5
    # explicit T
    L16 = random_invertible_linear_map(rng, Val(10), UInt16)
    @test L16 isa F2LinearMap{10, UInt16}
    @test is_invertible(L16)
end

@testset "random_affine_permutation: invertible linear part" begin
    rng = MersenneTwister(0x0f0f)
    for _ in 1:20
        A = random_affine_permutation(rng, Val(6))
        @test A isa F2AffineMap{6}
        @test is_invertible(A.linear)
    end
    # determinism
    @test random_affine_permutation(MersenneTwister(3), Val(5)) ==
          random_affine_permutation(MersenneTwister(3), Val(5))
end

end
