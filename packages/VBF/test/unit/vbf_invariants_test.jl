@testitem "vbf_invariants" begin
using VBF
using VBFCatalog
using Test
using Random

# Helpers: a Gold x³ function over GF(2ⁿ) (non-permutation, quadratic, APN for
# odd n; n4 is the classic non-bijective APN), and a random linear-equivalent.
gold(n) = SBox{n}(gf_monomial_lut(n, 3))
lin_equiv(rng, F::SBox{N}) where {N} =
    random_invertible_linear_map(rng, Val(N)) ∘ F ∘ random_invertible_linear_map(rng, Val(N))

@testset "subspaces in a set: closed forms on a full k-space" begin
    # the full 3-dimensional space {0,…,7}: 7 nonzero elts, [3 choose 2]₂ = 7
    # two-dimensional subspaces, and one 3-dimensional subspace (itself).
    S = collect(0:7)
    @test length(smallest_basis(S)) == 3
    @test length(find_2d_subspaces(S, 3)) == 7
    @test subspace_count_signature(S, 3) == [7, 7, 1, 0]
    # a 2-dimensional space {0,1,2,3}: one 2-space, no 3-space.
    @test subspace_count_signature([0, 1, 2, 3], 2) == [3, 1, 0]
    # a set with no 2-dimensional subspace at all
    @test subspace_count_signature([0, 1, 2], 3) == [2, 0, 0]
end

@testset "walsh_power_moment: Parseval (k=2) closed form" begin
    for F in (gold(4), gold(5), SBox(UInt8[0, 1, 2, 3]))
        n = inputbits(F)
        @test walsh_power_moment(F, 2) == 1 << (3n)        # Σ W² = 2^{3n}
    end
end

@testset "bent/nonbent components partition (AES); odd n has none" begin
    aes = load_literature_sbox("AES")               # n=8: bent_components is fast (just the LAT)
    @test bent_components(aes) isa Vector{Int}
    @test length(bent_components(aes)) + length(nonbent_components(aes)) == 256
    @test 0 in nonbent_components(aes)              # the zero component is never bent
    @test isempty(bent_components(gold(5)))         # odd n: no bent components
end

@testset "nonbent_signature is a linear-equivalence invariant" begin
    # done at n=4 — `nonbent_signature` enumerates subspaces of the nonbent set,
    # which is only cheap when that set is small (it explodes near-full at n=8).
    rng = MersenneTwister(0xB0BA)
    F = gold(4)
    sig = nonbent_signature(F)
    for _ in 1:3
        @test nonbent_signature(lin_equiv(rng, F)) == sig
    end
end

@testset "image_set / image_subspaces are linear-equivalence invariants" begin
    rng = MersenneTwister(0xC0FFEE)
    F = gold(4)                                            # non-permutation
    @test length(image_set(F)) < 16                        # proper image
    sig = image_subspaces(F)
    for _ in 1:3
        @test image_subspaces(lin_equiv(rng, F)) == sig
    end
    # a permutation has the whole space as image
    perm = random_permutation_sbox(rng, Val(4))
    @test image_set(perm) == collect(0:15)
end

@testset "pi_multiset: returns a Spectrum, collection over β is lin-eq invariant" begin
    rng = MersenneTwister(0x1234)
    F = gold(4)
    @test pi_multiset(F, 0) isa Spectrum
    canon(G) = sort([sorted_pairs(pi_multiset(G, β)) for β in 0:15])
    base = canon(F)
    for _ in 1:2
        @test canon(lin_equiv(rng, F)) == base
    end
end
end
