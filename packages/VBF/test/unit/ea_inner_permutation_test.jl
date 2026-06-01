@testitem "ea_inner_permutation" begin
using VBFCatalog
using VBF
using Test
using Random

@testset "inner_permutation: reflexive case (F, F) → identity A₂, zero drift" begin
    for name in ("PRESENT", "GIFT", "SKINNY_4")
        F = load_literature_sbox(name)
        N = inputbits(F)
        T = storage_type(F)
        res = inner_permutation(F, F)
        @test res !== nothing
        @test res.A2 == T[T(x) for x in 0:((1 << N) - 1)]
        @test all(d -> d == zero(T), res.A_drift)
    end
end

@testset "inner_permutation: F vs F ∘ A₂_known ⊕ linear_drift" begin
    rng = MersenneTwister(0xBFA84)
    N, T = 4, UInt8
    mask = T(0x0F)
    F = load_literature_sbox("PRESENT")
    for _ in 1:5
        # Random invertible linear A₂
        A2_cols, A2 = let
            local cols = T[]
            local bs = T[]
            while length(cols) < N
                v = rand(rng, T) & mask
                v == 0 && continue
                is_in_span(v, bs; nbits = N) && continue
                push!(cols, v); push!(bs, v)
                bs = linear_basis(bs; nbits = N)
            end
            (cols, F2LinearMap{N, T}(cols))
        end
        # Random linear drift L_drift (NOT necessarily invertible)
        L_drift_cols = T[rand(rng, T) & mask for _ in 1:N]
        L_drift = F2LinearMap{N, T}(L_drift_cols)
        # G(x) = F(A2(x)) ⊕ L_drift(x). Linear drift: L_drift(0) = 0.
        G_lut = T[F.lut[A2(T(x)) + 1] ⊻ L_drift(T(x)) for x in 0:15]
        G = SBox{N, T}(G_lut)
        res = inner_permutation(F, G)
        @test res !== nothing
        # The certificate: F ∘ res.A2 ⊕ G == res.A_drift, and res.A_drift is affine.
        if res !== nothing
            derived_drift = T[F.lut[res.A2[x + 1] + 1] ⊻ G.lut[x + 1] for x in 0:15]
            @test derived_drift == res.A_drift
            # Verify drift is affine: f(0) ⊕ f(a) ⊕ f(b) ⊕ f(a⊕b) = 0 for all a, b
            for a in 1:15, b in (a + 1):15
                ab = a ⊻ b
                ab > b || continue
                @test (res.A_drift[1] ⊻ res.A_drift[a + 1] ⊻
                       res.A_drift[b + 1] ⊻ res.A_drift[ab + 1]) == 0
            end
        end
    end
end

@testset "inner_permutation: rejects EA-inequivalent pair" begin
    # PRESENT and SKINNY_4 have different cryptographic profiles (different DDT/LAT) and are not EA-equivalent.
    F = load_literature_sbox("PRESENT")
    H = load_literature_sbox("SKINNY_4")
    res = inner_permutation(F, H)
    @test res === nothing
end

@testset "inner_permutation: A₂ output is always F₂-linear bijection" begin
    # Whatever A₂ the search returns must be invertible.
    rng = MersenneTwister(0xBFA85)
    F = load_literature_sbox("PRESENT")
    N, T = 4, UInt8
    mask = T(0x0F)
    for _ in 1:3
        A2_inner = let
            local cols = T[]; local bs = T[]
            while length(cols) < N
                v = rand(rng, T) & mask
                v == 0 && continue
                is_in_span(v, bs; nbits = N) && continue
                push!(cols, v); push!(bs, v)
                bs = linear_basis(bs; nbits = N)
            end
            F2LinearMap{N, T}(cols)
        end
        L_drift = F2LinearMap{N, T}(T[rand(rng, T) & mask for _ in 1:N])
        G_lut = T[F.lut[A2_inner(T(x)) + 1] ⊻ L_drift(T(x)) for x in 0:15]
        G = SBox{N, T}(G_lut)
        res = inner_permutation(F, G)
        if res !== nothing
            # Check A₂ is bijective (every output appears once)
            @test sort(res.A2) == collect(T, 0:15)
            # Check A₂ is linear: A₂(x ⊕ y) == A₂(x) ⊕ A₂(y) for sampled x, y
            for x in 0:7, y in 0:7
                @test res.A2[(x ⊻ y) + 1] == res.A2[x + 1] ⊻ res.A2[y + 1]
            end
        end
    end
end

end
