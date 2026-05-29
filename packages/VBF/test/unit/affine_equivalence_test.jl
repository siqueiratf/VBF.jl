@testitem "affine_equivalence" begin
using VBFCatalog
using VBF
using Test
using Random

@testset "are_affine_equivalent: type checks" begin
    s4 = load_literature_sbox("PRESENT")
    s5 = load_apn_function("n5_Gold_x3")
    @test !are_affine_equivalent(s4, s5)
    @test !are_affine_equivalent(s5, s4)
end

@testset "are_affine_equivalent: unknown strategy throws" begin
    s = load_literature_sbox("PRESENT")
    @test_throws ArgumentError are_affine_equivalent(s, s; strategy = :nonexistent)
end

@testset "are_affine_equivalent: rejects non-permutations" begin
    c = SBox(UInt8[3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3])
    F = load_literature_sbox("PRESENT")
    @test !are_affine_equivalent(F, c)
    @test !are_affine_equivalent(c, F)
    @test !are_affine_equivalent(c, c)
end

@testset "reflexivity on every 4-bit catalog permutation" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        inputbits(s) == 4 || continue
        is_permutation(s) || continue
        @test are_affine_equivalent(s, s)
    end
end

@testset "shifted SBoxes are affine-equivalent to the original" begin
    # Construct G(x) = F(x ⊕ a) ⊕ b for random (a, b); must be affine-
    # equivalent to F.
    rng = MersenneTwister(0xBFA71)
    for name in ("PRESENT", "GIFT", "SKINNY_4")
        F = load_literature_sbox(name)
        N = inputbits(F)
        T = storage_type(F)
        mask = T((T(1) << N) - T(1))
        for _ in 1:5
            a = T(rand(rng, 0:Int(mask)))
            b = T(rand(rng, 0:Int(mask)))
            G_lut = T[F.lut[(T(x) ⊻ a) + 1] ⊻ b for x in 0:((1 << N) - 1)]
            G = SBox{N, T}(G_lut)
            @test are_affine_equivalent(F, G)
        end
    end
end

@testset "L₁ ∘ F ∘ L₂ + b is affine-equivalent to F (full pipeline)" begin
    rng = MersenneTwister(0xBFA72)
    @testset "n=$N" for N in (3, 4)
        T = UInt8
        mask = T((T(1) << N) - T(1))
        for _ in 1:5
            # Random permutation F
            F = random_permutation_sbox(rng, Val(N), T)

            # Random invertible L₁ and L₂, random constants a, b
            L1 = random_invertible_linear_map(rng, Val(N), T)
            L2 = random_invertible_linear_map(rng, Val(N), T)
            a  = T(rand(rng, 0:Int(mask)))
            b  = T(rand(rng, 0:Int(mask)))

            # G(x) = L₁(F(L₂(x) ⊕ a)) ⊕ b
            G_lut = T[(L1(F.lut[((L2(T(x)) ⊻ a) & mask) + 1]) ⊻ b) & mask
                      for x in 0:((1 << N) - 1)]
            G = SBox{N, T}(G_lut)

            @test are_affine_equivalent(F, G)
        end
    end
end

@testset "n=5 monomial APN: pairwise NOT affine-equivalent" begin
    # x^3, x^5, x^15 are in distinct Frobenius orbits — adding affine
    # drift doesn't bridge classes.
    F3  = load_apn_function("n5_Gold_x3")
    F5  = load_apn_function("n5_Gold_x5")
    F15 = load_apn_function("n5_Kasami_x15")

    @test  are_affine_equivalent(F3, F3)
    @test  are_affine_equivalent(F5, F5)
    @test  are_affine_equivalent(F15, F15)

    @test !are_affine_equivalent(F3, F5)
    @test !are_affine_equivalent(F3, F15)
    @test !are_affine_equivalent(F5, F15)
end

@testset "affine ⊇ linear: linear-equivalent → affine-equivalent" begin
    # Every linear equivalence is also an affine equivalence.
    rng = MersenneTwister(0xBFA73)
    N, T = 4, UInt8
    mask = T(0x0F)
    F = load_literature_sbox("PRESENT")
    for _ in 1:5
        cols = T[]
        bs = T[]
        while length(cols) < N
            v = rand(rng, T) & mask
            v == 0 && continue
            is_in_span(v, bs; nbits = N) && continue
            push!(cols, v); push!(bs, v)
            bs = linear_basis(bs; nbits = N)
        end
        L = F2LinearMap{N, T}(cols)
        G = L ∘ (F ∘ inv(L))
        @test are_linear_equivalent(F, G; strategy = :stennes)
        @test are_affine_equivalent(F, G)
    end
end

@testset "affine_representative is invariant on the affine class" begin
    rng = MersenneTwister(0xBFA74)
    F = load_literature_sbox("PRESENT")
    N = inputbits(F)
    T = storage_type(F)
    mask = T((T(1) << N) - T(1))
    base = affine_representative(F)
    for _ in 1:5
        a = T(rand(rng, 0:Int(mask)))
        b = T(rand(rng, 0:Int(mask)))
        G_lut = T[F.lut[(T(x) ⊻ a) + 1] ⊻ b for x in 0:((1 << N) - 1)]
        G = SBox{N, T}(G_lut)
        @test affine_representative(G) == base
    end
end

@testset "affine_class_signature: non-empty and properly sorted" begin
    F = load_literature_sbox("PRESENT")
    sig = affine_class_signature(F)
    @test !isempty(sig)
    @test issorted(sig; by = r -> r.lut)
    @test allunique(sig)
    @test sig[1] == affine_representative(F)
end

@testset "affine_class_signature: rejects non-permutations" begin
    c = SBox(UInt8[3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3])
    @test_throws ArgumentError affine_class_signature(c)
    @test_throws ArgumentError affine_representative(c)
end

end
