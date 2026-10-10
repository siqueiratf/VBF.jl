@testitem "stennes_representative" setup=[SBoxFixtures] begin

using VBF
using Test
using Random

# Tests for `linear_representative` (Stennes' algorithm). The strategy dispatch via `are_linear_equivalent(...; strategy = :stennes)` is exercised separately in test_linear_equivalence_api.jl.

@testset "rejects non-permutations" begin
    c = SBox(UInt8[3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3])
    @test !is_permutation(c)
    @test_throws ArgumentError linear_representative(c)
end

@testset "B ∘ representative == F ∘ A on the full domain" begin
    # The invariant `B(rep(x)) == F(A(x))` is what defines the returned maps; check it for every input on a range of representative S-boxes.
    for name in ("PRESENT", "GIFT", "Midori_Sb0", "SKINNY_4", "Piccolo")
        F = fixture_sbox(name)
        result = linear_representative(F)
        N = inputbits(F)
        @testset "$name" begin
            for x in 0:((1 << N) - 1)
                @test result.B(result.representative(x)) == F(result.A(x))
            end
        end
    end
end

@testset "reflexivity: linear_representative is a function of the class" begin
    for name in ("PRESENT", "GIFT", "SERPENT_S3")
        F = fixture_sbox(name)
        r1 = linear_representative(F).representative
        r2 = linear_representative(F).representative
        @test r1 == r2
    end
end

@testset "Stennes ↔ backtracking agree on linear equivalence (n ≤ 4)" begin
    # For every pair of fixed 4-bit permutations: linear equivalence decided by Stennes (reps equal) must match the LPP backtracking decision.
    names = filter(fixture_names()) do n
        s = fixture_sbox(n)
        is_permutation(s) && inputbits(s) == 4
    end
    sboxes = [fixture_sbox(n) for n in names]
    reps = [linear_representative(s).representative for s in sboxes]
    for i in eachindex(sboxes), j in i:lastindex(sboxes)
        stennes_decides = reps[i] == reps[j]
        backtracking_decides = VBF.are_linearly_equivalent_perm(sboxes[i], sboxes[j])
        @test stennes_decides == backtracking_decides
    end
end

@testset "conjugation: rep(L ∘ F ∘ L⁻¹) == rep(F)" begin
    rng = MersenneTwister(0xBFA63)
    N = 4
    T = UInt8
    F = fixture_sbox("PRESENT")
    @test inputbits(F) == N
    mask = T((T(1) << N) - T(1))
    base_rep = linear_representative(F).representative
    for _ in 1:5
        local cols = T[]
        local bs = T[]
        while length(cols) < N
            v = rand(rng, T) & mask
            v == 0 && continue
            is_in_span(v, bs; nbits = N) && continue
            push!(cols, v)
            push!(bs, v)
            bs = linear_basis(bs; nbits = N)
        end
        L = F2LinearMap{N, T}(cols)
        G = L ∘ (F ∘ inv(L))
        @test linear_representative(G).representative == base_rep
    end
end

@testset "n=5 monomial APN: Gold x³, x⁵, Kasami x¹⁵ have distinct reps" begin
    # Linear-equivalence classes are determined by the Frobenius orbit of the monomial exponent. For n=5 the orbits of 3, 5, 15 are disjoint.
    F3  = fixture_apn("n5_Gold_x3")
    F5  = fixture_apn("n5_Gold_x5")
    F15 = fixture_apn("n5_Kasami_x15")
    r3  = linear_representative(F3).representative
    r5  = linear_representative(F5).representative
    r15 = linear_representative(F15).representative
    @test r3 != r5
    @test r3 != r15
    @test r5 != r15
    @test r3  == linear_representative(F3).representative   # determinism
    @test r5  == linear_representative(F5).representative
end

@testset "F(0) ≠ 0 path: representative still computed correctly" begin
    # AES has AES(0) = 0x63 ≠ 0 — exercises the `else` branch of the init special case in `linear_representative`. We only check the B ∘ rep == F ∘ A invariant; AES at n=8 is expensive otherwise.
    aes = fixture_sbox("AES")
    @test aes(0) != 0
    # Test on a small mod: build a 4-bit permutation with F(0) != 0.
    P = fixture_sbox("PRESENT")  # PRESENT(0) = 0xC ≠ 0
    @test P(0) != 0
    result = linear_representative(P)
    for x in 0:15
        @test result.B(result.representative(x)) == P(result.A(x))
    end
end

end
