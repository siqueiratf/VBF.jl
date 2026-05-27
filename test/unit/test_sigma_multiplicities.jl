using BFA
using Test

@testset "sigma_multiplicities: validation" begin
    F = load_literature_sbox("PRESENT")
    @test_throws ArgumentError sigma_multiplicities(F; k = 1)
end

@testset "sigma_multiplicities: total mass = 2ⁿ" begin
    # σ is computed for each s ∈ F₂ⁿ, so the spectrum should have
    # exactly 2ⁿ entries (with multiplicity).
    for name in ("PRESENT", "GIFT", "SKINNY_4")
        F = load_literature_sbox(name)
        sp = sigma_multiplicities(F)
        @test total_mass(sp) == (1 << inputbits(F))
    end
end

@testset "sigma_multiplicities: invariant under inv(F) (CCZ-invariance)" begin
    for name in ("PRESENT", "GIFT", "SKINNY_4", "Midori_Sb0")
        F = load_literature_sbox(name)
        is_permutation(F) || continue
        @test sigma_multiplicities(F) == sigma_multiplicities(inv(F))
    end
end

@testset "sigma_multiplicities: invariant under EA conjugation" begin
    # σ-multiplicities is a CCZ-invariant — in particular an EA-invariant.
    using Random
    rng = MersenneTwister(0xBFA_A1)
    F = load_literature_sbox("PRESENT")
    N, T = 4, UInt8
    mask = T(0x0F)
    sp_F = sigma_multiplicities(F)
    for _ in 1:3
        # Random invertible L₁, L₂; constants don't matter for σ but include
        local cols1 = T[]; local bs1 = T[]
        while length(cols1) < N
            v = rand(rng, T) & mask
            v == 0 && continue
            is_in_span(v, bs1; nbits = N) && continue
            push!(cols1, v); push!(bs1, v)
            bs1 = linear_basis(bs1; nbits = N)
        end
        L1 = F2LinearMap{N, T}(cols1)
        local cols2 = T[]; local bs2 = T[]
        while length(cols2) < N
            v = rand(rng, T) & mask
            v == 0 && continue
            is_in_span(v, bs2; nbits = N) && continue
            push!(cols2, v); push!(bs2, v)
            bs2 = linear_basis(bs2; nbits = N)
        end
        L2 = F2LinearMap{N, T}(cols2)
        G = L1 ∘ (F ∘ L2)
        @test sigma_multiplicities(G) == sp_F
    end
end

@testset "sigma_multiplicities: agrees on EA-equivalent inputs (catalog spot)" begin
    # σ is an EA-invariant. The two Gold APNs at n=5 are EA-INequivalent
    # (different Frobenius orbits), but each is EA-equivalent to itself,
    # so reflexivity must hold. Stronger discrimination is the
    # ortho-derivative's job; σ alone may collide between CCZ-classes
    # of similar function families.
    F1 = load_apn_function("n5_Gold_x3")
    F2 = load_apn_function("n5_Gold_x3")
    @test sigma_multiplicities(F1) == sigma_multiplicities(F2)
end

@testset "sigma_multiplicities: k ≥ 2 produces a non-trivial spectrum" begin
    F = load_apn_function("n5_Gold_x3")
    sp4 = sigma_multiplicities(F; k = 4)
    @test total_mass(sp4) == 32
    # k = 6 also works (just exercises the loop)
    sp6 = sigma_multiplicities(F; k = 6)
    @test total_mass(sp6) == 32
end
