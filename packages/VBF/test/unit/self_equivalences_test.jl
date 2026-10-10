@testitem "self_equivalences" setup=[SBoxFixtures] begin

using VBF
using Test
using Random

@testset "linear_equivalences: empty for non-permutations" begin
    c = SBox(UInt8[3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3])
    F = fixture_sbox("PRESENT")
    @test isempty(linear_equivalences(F, c))
    @test isempty(linear_equivalences(c, F))
end

@testset "self_linear_equivalences: contains identity, all verify" begin
    for name in ("PRESENT", "GIFT", "SKINNY_4")
        F = fixture_sbox(name)
        N = inputbits(F)
        T = storage_type(F)
        sl = self_linear_equivalences(F)
        @test !isempty(sl)
        id = identity_linear_map(N)
        @test any(eq -> eq.L1 == id && eq.L2 == id, sl)
        for eq in sl
            @test all(0:((1 << N) - 1)) do x
                eq.L1(F.lut[eq.L2(T(x)) + 1]) == F.lut[x + 1]
            end
            @test is_invertible(eq.L1)
            @test is_invertible(eq.L2)
        end
    end
end

@testset "linear_equivalences: agrees with are_linear_equivalent" begin
    rng = MersenneTwister(0xBFA_B2)
    F = fixture_sbox("PRESENT")
    N, T = 4, UInt8
    mask = T(0x0F)
    # Conjugate: should be linearly equivalent, so non-empty.
    for _ in 1:3
        gen = let
            local cols = T[]; local bs = T[]
            while length(cols) < N
                v = rand(rng, T) & mask
                v == 0 && continue
                is_in_span(v, bs; nbits = N) && continue
                push!(cols, v); push!(bs, v); bs = linear_basis(bs; nbits = N)
            end
            F2LinearMap{N, T}(cols)
        end
        G = gen ∘ (F ∘ inv(gen))
        le = linear_equivalences(F, G)
        @test !isempty(le) == are_linear_equivalent(F, G; strategy = :lpp_backtracking)
        # Every returned pair must witness G = L1 ∘ F ∘ L2.
        for eq in le
            @test all(0:15) do x
                eq.L1(F.lut[eq.L2(T(x)) + 1]) == G.lut[x + 1]
            end
        end
    end
end

@testset "self_linear_equivalences: monomial APN has a non-trivial group" begin
    # Gold APN x^3 over GF(2^5) has a large linear self-equivalence group (the multiplicative + Frobenius structure). Must be more than just the identity.
    F = fixture_apn("n5_Gold_x3")
    sl = self_linear_equivalences(F)
    @test length(sl) > 1
    N, T = 5, UInt8
    for eq in sl
        @test all(0:31) do x
            eq.L1(F.lut[eq.L2(T(x)) + 1]) == F.lut[x + 1]
        end
    end
end

@testset "self_affine_equivalences: superset of linear, all verify" begin
    F = fixture_sbox("PRESENT")
    N, T = 4, UInt8
    sa = self_affine_equivalences(F)
    @test !isempty(sa)
    # Every affine self-equivalence verifies F = A1 ∘ F ∘ A2.
    for eq in sa
        @test all(0:15) do x
            eq.A1(F.lut[eq.A2(T(x)) + 1]) == F.lut[x + 1]
        end
    end
    # The linear self-equivalences embed as affine ones (c_in = c_out = 0), so the affine count is at least the linear count.
    @test length(sa) ≥ length(self_linear_equivalences(F))
end

@testset "self_affine_equivalences: rejects non-permutations" begin
    c = SBox(UInt8[3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3])
    @test_throws ArgumentError self_affine_equivalences(c)
end

end
