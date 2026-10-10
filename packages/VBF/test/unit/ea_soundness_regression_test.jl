@testitem "ea_soundness_regression" setup=[SBoxFixtures] begin

using VBF
using Test

# Regression tests for the five silent-wrongness bugs found while reproducing
# Calderini 2020 (packages/VBFRepro/papers/2020/Calderini_202009):
#   1. ea_matrix packed its y-columns at the wrong row offset (not Edel-Pott C₂).
#   2. apn_ea_mugshot's non-quadratic branch used the basis-dependent
#      per-coordinate degree_spectrum (not an EA-invariant).
#   3. are_ea_equivalent returned silent false negatives on capped Heggebakk
#      searches — including affine-equivalent (hence EA-equivalent) pairs.
#   4. automorphisms_from_ortho_derivative silently returned an empty list for
#      every even-n quadratic APN (permutation-only linear_equivalences).
#   5. canonical_3to1_representative(π_kim) returns nothing — documented as
#      mathematically correct (non-Desarguesian fibre spread), with
#      linear_equivalences_general as the working alternative.

# A deterministic affine-equivalent companion of the Dillon permutation:
# G = B ∘ D ∘ A ⊕ b with fixed invertible linear A, B and constant b. B is
# chosen so that Bᵀ selects three of D's seven degree-3 component masks
# (4, 16, 10) as coordinates of G — making G's per-coordinate degree
# histogram {3³, 4³} differ from D's {3², 4⁴}, which is exactly the
# basis-dependence that broke the old mugshot.
function _dillon_ae_pair()
    D = dillon_apn_permutation()
    A = F2LinearMap{6,UInt8}(UInt8[0x03, 0x02, 0x14, 0x0b, 0x30, 0x21])
    Bt = F2LinearMap{6,UInt8}(UInt8[0x04, 0x10, 0x0a, 0x01, 0x02, 0x20])
    @assert is_invertible(A) && is_invertible(Bt)
    B = transpose(Bt)
    b = UInt8(0x15)
    G = SBox{6,UInt8}(UInt8[B(D.lut[A(UInt8(x))+1]) ⊻ b for x = 0:63])
    return D, G
end

@testset "bug 1: ea_matrix is the true Edel-Pott C₂" begin
    D, G = _dillon_ae_pair()
    # Structural: the 2ⁿ-1 y-columns carry bits only in the F(x)-block rows
    # (n+2..2n+1). The old packing put them in rows 1..n+1 — this fails there.
    em = ea_matrix(D)
    n_size = 64
    @test size(em) == (13, 127)
    @test !any(em[1:7, (n_size+1):end])          # constant + x rows all zero
    @test any(em[8:13, (n_size+1):end])          # y bits live in the F-block
    # Semantic: affine-equivalent (⊂ EA-equivalent) pair ⇒ permutation-
    # equivalent C₂ codes ⇒ equal weight enumerators. Differed under the bug.
    @test code_weight_enumerator(ea_matrix(D)) == code_weight_enumerator(ea_matrix(G))

    # Promoted companions: paper-exact dimensions and behaviour.
    @test size(ae_matrix(D)) == (13, 190)
    @test size(ae_perm_matrix(D)) == (13, 191)
    @test_throws ArgumentError ae_perm_matrix(kim_apn())
    # ae codes of an AE pair (constant absorbed by the shift block on C₄ only
    # up to b; C₃ is directly equivalent for AE pairs):
    @test code_weight_enumerator(ae_matrix(D)) == code_weight_enumerator(ae_matrix(G))
end

@testset "bug 2: non-quadratic mugshot is EA-invariant" begin
    D, G = _dillon_ae_pair()
    @test algebraic_degree(D) == 4               # non-quadratic branch
    mD = apn_ea_mugshot(D)
    mG = apn_ea_mugshot(G)
    @test mD.kind == :non_quadratic
    # AE-equivalent (hence EA-equivalent) pair must share the mugshot.
    # The pair is constructed so the per-coordinate histograms differ
    # ({3²,4⁴} vs {3³,4³}) — the old degree_spectrum-based mugshot fails here.
    @test degree_spectrum(D) != degree_spectrum(G)
    @test mD == mG
    # The replaced quantity is genuinely well-defined and invariant:
    @test component_degree_spectrum(D) == component_degree_spectrum(G)
    @test sorted_pairs(component_degree_spectrum(D)) == [3 => 7, 4 => 56]
end

@testset "bug 3: no silent false negatives in are_ea_equivalent" begin
    D, G = _dillon_ae_pair()
    # Degree-4 n=6 permutations, partition signature [56, 7, 1]: the Heggebakk
    # search is capped here, and the old code returned `false` for this
    # affine-equivalent (⊂ EA-equivalent) pair. Now: sound `true` via the
    # affine witness in the fallback chain.
    @test are_ea_equivalent(D, G)
    # Sound negatives are preserved:
    K = kim_apn()
    @test !are_ea_equivalent(K, D)               # degrees 2 ≠ 4 (EA-invariant)
    # Degree ≤ 1 semantics: one EA-class of affine functions.
    c3 = SBox{4,UInt8}(fill(UInt8(3), 16))
    c5 = SBox{4,UInt8}(fill(UInt8(5), 16))
    idn = SBox{4,UInt8}(UInt8.(0:15))
    @test are_ea_equivalent(c3, c5)
    @test are_ea_equivalent(c3, idn)
    @test !are_ea_equivalent(fixture_sbox("PRESENT"), c3)
end

@testset "bug 4: even-n quadratic APN graph automorphisms + orbit census" begin
    K = kim_apn()
    π = ortho_derivative(K)
    @test !is_permutation(π)                     # the case the old code dropped
    eqs = linear_equivalences_general(π, π)
    @test length(eqs) == 14
    @test all(
        all(e.L1(π.lut[e.L2(UInt8(x))+1]) == π.lut[x+1] for x = 0:63) for e in eqs
    )
    auts = automorphisms_from_ortho_derivative(K)
    @test length(auts) == 896                    # was 0 before the fix
    # EA-class census of the Kim CCZ-class (Calderini 2020, Table 1 row 5 /
    # Section 5.1): 222 Walsh-zero 6-spaces, exactly 13 EA-classes.
    r = ea_class_orbits(K)
    @test r.nspaces == 222
    @test r.nauts == 896
    @test length(r.orbits) == 13
    @test sum(length, r.orbits) == 222
end

@testset "bug 5: canonical 3-to-1 representative — documented boundary" begin
    K = kim_apn()
    π = ortho_derivative(K)
    @test is_3_to_1(π)
    # π_kim's fibre spread is non-Desarguesian: no canonical representative
    # exists (verified by exhaustive search; see the docstring). `nothing` is
    # the mathematically correct answer, NOT a missing-capability bug.
    @test canonical_3to1_representative(π) === nothing
    # Positive control: x³ over the Conway GF(2⁶) has a Desarguesian fibre
    # spread and gets a canonical representative C = T ∘ L.
    T0 = SBox{6}(gf_monomial_lut(6, 3; modulus = conway_polynomial(6)))
    r = canonical_3to1_representative(T0)
    @test r !== nothing
    C, L = r
    @test all(C.lut[x+1] == T0.lut[Int(L(UInt8(x)))+1] for x = 0:63)
end

end