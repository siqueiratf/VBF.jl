@testitem "ea_partition" begin
using VBFCatalog
using VBF
using Test
using Random

@testset "ea_multiplicities: validation" begin
    F = load_literature_sbox("PRESENT")
    @test_throws ArgumentError ea_multiplicities(F, 3)   # odd k
    @test_throws ArgumentError ea_multiplicities(F, 2)   # k < 4 (also even)
    @test_throws ArgumentError ea_multiplicities(F, 5)   # odd
end

@testset "ea_multiplicities: total count invariant" begin
    # The k=4 recursion enumerates (y₁, y₂, y₃) ∈ (F₂ⁿ)^3 — exactly 2^(3n) tuples — and each contributes 1 to exactly one bucket. So sum(multiplicities) must equal 2^(3n).
    for name in ("PRESENT", "GIFT", "Midori_Sb0", "SKINNY_4")
        F = load_literature_sbox(name)
        n = inputbits(F)
        m = ea_multiplicities(F, 4)
        @test sum(m) == (1 << (3n))
        @test length(m) == (1 << n)
    end
end

@testset "ea_multiplicities: zero-value contribution" begin
    F = load_literature_sbox("PRESENT")
    m = ea_multiplicities(F, 4)
    @test any(>(0), m)
end

@testset "ea_partition: structure consistency" begin
    F = load_literature_sbox("PRESENT")
    p = ea_partition(F, 4)
    n = inputbits(F)
    @test inputbits(p) == n
    @test p.k == 4
    @test nbuckets(p) ≥ 1
    @test sum(p.bucket_sizes) == (1 << n)
    @test length(p.position_of_value) == (1 << n)
    # buckets and position_of_value agree
    for (i, b) in enumerate(p.buckets)
        for v in b
            @test p.position_of_value[v + 1] == i
        end
        @test length(b) == p.bucket_sizes[i]
    end
    # multiplicities within each bucket all equal bucket_multiplicities[i]
    m = ea_multiplicities(F, 4)
    for (i, b) in enumerate(p.buckets)
        for v in b
            @test m[v + 1] == p.bucket_multiplicities[i]
        end
    end
end

@testset "ea_partition: EA-invariance of bucket-size signature" begin
    # Build G = L₁ ∘ F ∘ L₂(· ⊕ a) ⊕ drift, with drift an arbitrary affine function. Signature must match F's.
    rng = MersenneTwister(0xBFA82)
    @testset "n=$N" for N in (4, 5)
        T = UInt8
        mask = T((T(1) << N) - T(1))
        F = if N == 4
            load_literature_sbox("PRESENT")
        else
            load_apn_function("n5_Gold_x3")
        end
        sig_F = ea_partition_signature(F, 4)
        for _ in 1:3
            # Random invertible L₁, L₂
            L1, L2 = let
                local cols1 = T[]; local bs1 = T[]
                while length(cols1) < N
                    v = rand(rng, T) & mask
                    v == 0 && continue
                    is_in_span(v, bs1; nbits = N) && continue
                    push!(cols1, v); push!(bs1, v)
                    bs1 = linear_basis(bs1; nbits = N)
                end
                local cols2 = T[]; local bs2 = T[]
                while length(cols2) < N
                    v = rand(rng, T) & mask
                    v == 0 && continue
                    is_in_span(v, bs2; nbits = N) && continue
                    push!(cols2, v); push!(bs2, v)
                    bs2 = linear_basis(bs2; nbits = N)
                end
                (F2LinearMap{N, T}(cols1), F2LinearMap{N, T}(cols2))
            end
            a = T(rand(rng, 0:Int(mask)))
            b = T(rand(rng, 0:Int(mask)))
            drift_lin = let
                local cols = T[]
                for _ in 1:N
                    push!(cols, T(rand(rng, 0:Int(mask))))
                end
                F2LinearMap{N, T}(cols)
            end
            drift_c = T(rand(rng, 0:Int(mask)))
            # G(x) = L₁(F(L₂(x) ⊕ a)) ⊕ drift_lin(x) ⊕ drift_c ⊕ b
            G_lut = T[(L1(F.lut[((L2(T(x)) ⊻ a) & mask) + 1])
                       ⊻ drift_lin(T(x)) ⊻ drift_c ⊻ b) & mask
                      for x in 0:((1 << N) - 1)]
            G = SBox{N, T}(G_lut)
            @test ea_partition_signature(G, 4) == sig_F
        end
    end
end

@testset "ea_partition: deterministic" begin
    F = load_apn_function("n5_Gold_x3")
    p1 = ea_partition(F)
    p2 = ea_partition(F)
    @test p1.bucket_sizes == p2.bucket_sizes
    @test p1.bucket_multiplicities == p2.bucket_multiplicities
end

@testset "ea_partition_signature: sorted descending" begin
    F = load_literature_sbox("PRESENT")
    sig = ea_partition_signature(F, 4)
    @test issorted(sig; rev = true)
    @test sum(sig) == (1 << inputbits(F))
end

end
