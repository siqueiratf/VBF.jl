using VBF
using Test

@testset "enumerate_bucket_maps: signature mismatch → empty" begin
    F = load_literature_sbox("PRESENT")
    G_lut = UInt8[(i + 1) % 16 for i in 0:15]   # affine, partition will look different
    G = SBox{4, UInt8}(G_lut)
    pF = ea_partition(F, 4)
    pG = ea_partition(G, 4)
    if pF.bucket_sizes != pG.bucket_sizes
        @test isempty(enumerate_bucket_maps(pF, pG))
    end
end

@testset "enumerate_bucket_maps: identity is enumerated" begin
    F = load_literature_sbox("PRESENT")
    p = ea_partition(F, 4)
    maps = enumerate_bucket_maps(p, p)
    @test !isempty(maps)
    # Identity σ (each bucket maps to itself) must be present.
    nb = nbuckets(p)
    @test [1:nb;] in maps
end

@testset "enumerate_bucket_maps: distinct sizes → unique map" begin
    # Monomial APN n=5: signature [31, 1] — every bucket has a unique
    # size, so only one bucket map exists.
    F = load_apn_function("n5_Gold_x3")
    p = ea_partition(F)
    @test length(enumerate_bucket_maps(p, p)) == 1
end

@testset "outer_permutations: identity is found (full GL when partition is trivial)" begin
    # For monomial APN with signature [31, 1], the only constraint is L(0) = 0;
    # so every linear permutation is found. Verify the count matches |GL(5, F₂)|.
    F = load_apn_function("n5_Gold_x3")
    p = ea_partition(F)
    maps = enumerate_bucket_maps(p, p)
    @test length(maps) == 1
    sigma = maps[1]
    Ls = outer_permutations(p, p, sigma, UInt8)
    # |GL(5, F₂)| = (2⁵-1)(2⁵-2)(2⁵-4)(2⁵-8)(2⁵-16) = 9,999,360
    @test length(Ls) == 9_999_360
end

@testset "outer_permutations_all: an EA-equivalent G yields ≥ 1 outer L" begin
    F = load_literature_sbox("PRESENT")
    # Construct G = L₁ ∘ F ∘ L₂(· ⊕ a) ⊕ b where L₁, L₂ are fixed and known
    N, T = 4, UInt8
    L1 = F2LinearMap{N, T}(T[0x2, 0x4, 0x8, 0x1])    # cyclic shift
    L2 = F2LinearMap{N, T}(T[0x1, 0x2, 0x4, 0x8])    # identity
    a = T(0x5)
    b = T(0x3)
    mask = T(0x0F)
    G_lut = T[(L1(F.lut[((L2(T(x)) ⊻ a) & mask) + 1]) ⊻ b) & mask for x in 0:15]
    G = SBox{N, T}(G_lut)
    res = outer_permutations_all(F, G)
    @test !isempty(res.sigmas)
    @test sum(length, res.Ls_per_sigma; init = 0) > 0
end

@testset "outer_permutations: every returned L is invertible and bucket-compatible" begin
    F = load_apn_function("n5_Gold_x3")
    p = ea_partition(F)
    sigma = enumerate_bucket_maps(p, p)[1]
    Ls = outer_permutations(p, p, sigma, UInt8)
    # Spot-check the first few (the full set is 10M)
    n = 32
    for L in Ls[1:min(end, 50)]
        # Invertibility: every value in 0..n-1 appears exactly once
        @test sort(L) == collect(UInt8, 0:(n - 1))
        # Linearity: L(x ⊕ y) == L(x) ⊕ L(y)
        for _ in 1:5
            x = rand(0:(n - 1))
            y = rand(0:(n - 1))
            @test L[(x ⊻ y) + 1] == L[x + 1] ⊻ L[y + 1]
        end
        # Bucket compatibility: bucket size of x in F = bucket size of L(x) in F
        for x in 0:(n - 1)
            f_b = p.position_of_value[x + 1]
            g_b = p.position_of_value[L[x + 1] + 1]
            @test p.bucket_sizes[f_b] == p.bucket_sizes[g_b]
        end
    end
end
