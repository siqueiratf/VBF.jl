@testitem "ccz_thickness" setup=[SBoxFixtures] begin

using VBF
using Test

@testset "thickness: small closed-form examples" begin
    N = 4
    # Subspace {(a, 0)} packed as [128, 64, 32, 16]: projection onto low 4 bits is all zeros → rank 0 → thickness 0.
    @test thickness(UInt32[128, 64, 32, 16], N) == 0
    # Subspace {(0, b)} packed as [8, 4, 2, 1]: projection IS the basis itself, rank 4 → thickness 4.
    @test thickness(UInt32[8, 4, 2, 1], N) == 4
    # Mixed subspace: basis [129, 64, 32, 16] = {(8, 1), (4, 0), (2, 0), (1, 0)}. Projection onto low 4 bits: {1, 0, 0, 0} → rank 1.
    @test thickness(UInt32[129, 64, 32, 16], N) == 1
end

@testset "thickness_spectrum: shape + sorting" begin
    F = fixture_sbox("PRESENT")
    spec = thickness_spectrum(F)
    @test !isempty(spec)
    @test issorted(spec; rev = true)
    @test all(t -> 0 ≤ t ≤ inputbits(F), spec)
end

@testset "thickness_spectrum: NOT a CCZ-invariant (documented)" begin
    # F and inv(F) are CCZ-equivalent (via the swap map on F₂²ⁿ), but individual subspace thicknesses don't commute with the swap action — so the spectra typically differ. GIFT is a concrete witness.
    spec_F = thickness_spectrum(fixture_sbox("GIFT"))
    spec_inv = thickness_spectrum(inv(fixture_sbox("GIFT")))
    @test spec_F != spec_inv
end

@testset "thickness_spectrum: |Z(F)| and DDT multiset ARE CCZ-invariant" begin
    # The actual CCZ-invariants used by are_ccz_equivalent's fast reject.
    for name in ("PRESENT", "GIFT", "SKINNY_4", "Midori_Sb0")
        F = fixture_sbox(name)
        is_permutation(F) || continue
        @test walsh_zeroes_size(F) == walsh_zeroes_size(inv(F))
        @test sort(vec(ddt(F))) == sort(vec(ddt(inv(F))))
    end
end

@testset "thickness_spectrum: distinguishes GIFT from PRESENT" begin
    # GIFT and PRESENT have the same |Z(F)| = 123 but different numbers of 4-dim subspaces (64 vs 112). Their thickness spectra must therefore differ.
    spec_present = thickness_spectrum(fixture_sbox("PRESENT"))
    spec_gift = thickness_spectrum(fixture_sbox("GIFT"))
    @test spec_present != spec_gift
    # Sanity: lengths match the 4-dim subspace counts.
    @test length(spec_present) == 112
    @test length(spec_gift) == 64
end

@testset "thickness_spectrum: PRESENT histogram" begin
    # Concrete histogram pinned as a high-signal regression check.
    spec = thickness_spectrum(fixture_sbox("PRESENT"))
    counts = Dict{Int, Int}()
    for t in spec
        counts[t] = get(counts, t, 0) + 1
    end
    @test counts[0] == 1
    @test counts[1] == 9
    @test counts[2] == 32
    @test counts[3] == 54
    @test counts[4] == 16
end

@testset "enumerate_ccz_class: produces valid SBoxes" begin
    # Not every rep is a permutation — only thickness-N subspaces yield permutations; lower-thickness reps are arbitrary functions in F's CCZ-class.
    F = fixture_sbox("PRESENT")
    reps = enumerate_ccz_class(F)
    @test !isempty(reps)
    for rep in reps[1:min(end, 5)]
        @test rep isa SBox{inputbits(F), storage_type(F)}
        # DDT multiset is a CCZ-invariant; every rep must share F's.
        @test sort(vec(ddt(rep))) == sort(vec(ddt(F)))
    end
end

@testset "enumerate_ccz_class: at least one permutation rep exists" begin
    F = fixture_sbox("PRESENT")
    reps = enumerate_ccz_class(F)
    @test any(is_permutation, reps)
end

@testset "enumerate_ccz_class: deduplicated count matches subspaces" begin
    # The total number of reps equals the number of admissible CCZ-mappings, which equals the count of N-dim subspaces of Z(F) (every basis L we build is invertible since complete_basis produces a full basis).
    F = fixture_sbox("PRESENT")
    Z = walsh_zeroes(F)
    bases = extract_linear_subspaces(Z, 4; max_bits = 8)
    reps = enumerate_ccz_class(F)
    @test length(reps) == length(bases)
end

@testset "are_ccz_equivalent: type checks" begin
    s4 = fixture_sbox("PRESENT")
    s5 = fixture_apn("n5_Gold_x3")
    @test !are_ccz_equivalent(s4, s5)
    @test !are_ccz_equivalent(s5, s4)
end

@testset "are_ccz_equivalent: unknown strategy throws" begin
    s = fixture_sbox("PRESENT")
    @test_throws ArgumentError are_ccz_equivalent(s, s; strategy = :nonexistent)
end

@testset "are_ccz_equivalent: rejects non-permutations" begin
    c = SBox(UInt8[3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3])
    F = fixture_sbox("PRESENT")
    @test !are_ccz_equivalent(F, c)
    @test !are_ccz_equivalent(c, F)
end

@testset "are_ccz_equivalent: F ~_CCZ F" begin
    # Reflexivity on n=4 permutations.
    F = fixture_sbox("PRESENT")
    @test are_ccz_equivalent(F, F)
end

@testset "are_ccz_equivalent: F ~_CCZ inv(F)" begin
    # Every permutation is CCZ-equivalent to its functional inverse.
    F = fixture_sbox("PRESENT")
    @test are_ccz_equivalent(F, inv(F))
end

@testset "are_ccz_equivalent: GIFT vs PRESENT are NOT CCZ-equivalent" begin
    # Caught by the DDT/|Z| necessary-condition fast path.
    F = fixture_sbox("PRESENT")
    G = fixture_sbox("GIFT")
    @test !are_ccz_equivalent(F, G)
end

end
