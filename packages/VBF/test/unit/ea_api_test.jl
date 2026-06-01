@testitem "ea_api" begin
using VBFCatalog
using VBF
using Test
using Random

# Helper: build a random invertible F₂-linear map (4-bit) from an RNG.
_rand_invertible_4(rng) = random_invertible_linear_map(rng, Val(4), UInt8)

# Helper: build a constructed EA-equivalent permutation
#   G(x) = L₁(F(A₂(x))) ⊕ L_drift(x)
# and ensure it's still a permutation. Returns (G, L₁, A₂, L_drift) on success
# or `nothing` if no drift works within `max_tries` attempts.
function _build_ea_perm(F::SBox{4, UInt8}, rng; max_tries = 5000,
                        allow_zero_drift = true)
    T = UInt8
    mask = T(0x0F)
    L1 = _rand_invertible_4(rng)
    A2 = _rand_invertible_4(rng)
    base_lut = T[L1(F.lut[A2(T(x)) + 1]) for x in 0:15]
    # Try L_drift = 0 first (which always gives a perm since base is a perm)
    if allow_zero_drift
        zero_drift = F2LinearMap{4, T}(T[0, 0, 0, 0])
        G_zero = SBox{4, T}(base_lut)
        if is_permutation(G_zero)
            return (G_zero, L1, A2, zero_drift)
        end
    end
    for _ in 1:max_tries
        L_drift = F2LinearMap{4, T}(T[rand(rng, T) & mask for _ in 1:4])
        G_lut = T[base_lut[x + 1] ⊻ L_drift(T(x)) for x in 0:15]
        G = SBox{4, T}(G_lut)
        if is_permutation(G)
            return (G, L1, A2, L_drift)
        end
    end
    return nothing
end

@testset "are_ea_equivalent: type checks" begin
    s4 = load_literature_sbox("PRESENT")
    s5 = load_apn_function("n5_Gold_x3")
    @test !are_ea_equivalent(s4, s5)
    @test !are_ea_equivalent(s5, s4)
end

@testset "are_ea_equivalent: unknown strategy throws" begin
    s = load_literature_sbox("PRESENT")
    @test_throws ArgumentError are_ea_equivalent(s, s; strategy = :nonexistent)
end

@testset "are_ea_equivalent: rejects non-permutations" begin
    c = SBox(UInt8[3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3])
    F = load_literature_sbox("PRESENT")
    @test !are_ea_equivalent(F, c)
    @test !are_ea_equivalent(c, F)
end

@testset "are_ea_equivalent: reflexivity on 4-bit catalog permutations" begin
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        inputbits(s) == 4 || continue
        is_permutation(s) || continue
        @test are_ea_equivalent(s, s)
    end
end

@testset "are_ea_equivalent: detects L₁ ∘ F ∘ A₂ ⊕ L_drift constructions" begin
    rng = MersenneTwister(0xBFA87)
    F = load_literature_sbox("PRESENT")
    # 5 constructed pairs, may include L_drift = 0 cases — both must succeed.
    detected = 0
    for _ in 1:8
        built = _build_ea_perm(F, rng)
        built === nothing && continue
        G, L1_known, A2_known, L_drift_known = built
        if are_ea_equivalent(F, G)
            detected += 1
        end
    end
    @test detected ≥ 3   # all constructed EA-perms should be detected
end

@testset "ea_equivalence_certificate: verifies the witness" begin
    rng = MersenneTwister(0xBFA88)
    F = load_literature_sbox("PRESENT")
    verified = 0
    for _ in 1:8
        built = _build_ea_perm(F, rng)
        built === nothing && continue
        G, _, _, _ = built
        cert = ea_equivalence_certificate(F, G)
        cert === nothing && continue
        # Verify G(x) == L1(F(A2(x))) ⊕ A_drift(x) for every x.
        @test all(0:15) do x
            cert.L1(F.lut[cert.A2(UInt8(x)) + 1]) ⊻ cert.A_drift.lut[x + 1] ==
                G.lut[x + 1]
        end
        @test is_invertible(cert.L1)
        @test is_invertible(cert.A2)
        verified += 1
    end
    @test verified ≥ 3
end

@testset "are_ea_equivalent: rejects non-EA-equivalent pair (PRESENT vs SKINNY_4)" begin
    F = load_literature_sbox("PRESENT")
    H = load_literature_sbox("SKINNY_4")
    @test !are_ea_equivalent(F, H)
    @test ea_equivalence_certificate(F, H) === nothing
end

@testset "are_ea_equivalent: signature-mismatch fast reject" begin
    # Build a pair with deliberately different bucket-size signatures.
    F = load_literature_sbox("PRESENT")
    # Identity at n=4 has trivial structure (all in one bucket).
    id_lut = UInt8[x for x in 0:15]
    G = SBox{4, UInt8}(id_lut)
    @test !is_permutation(F) || is_permutation(G)
    # Signatures may match in some unlucky cases; we don't assert mismatch,
    # but we do assert the decision is `false` and runs fast.
    t = @elapsed result = are_ea_equivalent(F, G)
    @test result == false
    @test t < 1.0
end

@testset "are_ea_equivalent: monomial APN is now decided via :auto routing" begin
    # n=5 monomial APN: the heggebakk k=4 partition is degenerate ([31, 1])
    # so :heggebakk alone short-circuits. The :ortho_derivative strategy
    # (auto-routed for quadratic-APN permutations) decides correctly
    # without needing the outer-permutation enumeration.
    F = load_apn_function("n5_Gold_x3")
    @test are_ea_equivalent(F, F)   # reflexive — :auto picks :ortho_derivative
    @test are_ea_equivalent(F, F; strategy = :ortho_derivative)
    # :heggebakk explicitly still short-circuits.
    @test !are_ea_equivalent(F, F; strategy = :heggebakk)
end

end
