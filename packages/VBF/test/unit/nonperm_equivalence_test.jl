@testitem "nonperm_equivalence" begin
using VBF
using Random
using Test

# Phase 22: equivalence testing for non-permutation functions. Almost every APN
# function is 3-to-1 (not a permutation); previously `are_ea_equivalent` /
# `are_ccz_equivalent` silently returned false for them (a permutation gate),
# and `are_linear_equivalent` could not handle the non-permutation
# ortho-derivatives. `are_linearly_equivalent_general` fixes the foundation.

# Taniguchi's three n=8 CCZ-classes (computed once) — pairwise EA-inequivalent.
reps = [r.sbox for r in taniguchi_apn_representatives(4)]

@testset "are_linearly_equivalent_general on non-permutations" begin
    F = SBox{6}(gf_monomial_lut(6, 3))          # 3-to-1 quadratic APN
    od = ortho_derivative(F)
    @test !is_permutation(od)
    @test are_linearly_equivalent_general(od, od)            # self
    L = random_invertible_linear_map(MersenneTwister(7), Val(6))
    odL = SBox{6}([od.lut[L(x) + 1] for x in 0:63])
    @test are_linearly_equivalent_general(od, odL)           # linear image
    # ortho-derivatives of distinct classes are inequivalent (fast: spectra differ)
    @test !are_linearly_equivalent_general(ortho_derivative(reps[1]),
                                           ortho_derivative(reps[2]))
end

@testset "are_ea_equivalent / are_ccz_equivalent work on non-permutation APN" begin
    F = SBox{6}(gf_monomial_lut(6, 3))
    @test !is_permutation(F)
    @test are_ea_equivalent(F, F)               # was silently false before Phase 22
    @test are_ccz_equivalent(F, F)              # delegates to EA (CCZ = EA on quad APN)
    L1 = random_invertible_linear_map(MersenneTwister(1), Val(6))
    L2 = random_invertible_linear_map(MersenneTwister(2), Val(6))
    G = SBox{6}([L1(F.lut[L2(x) + 1]) for x in 0:63])
    @test are_ea_equivalent(F, G)               # linearly (hence EA) equivalent
end

@testset "permutation EA still works (regression)" begin
    P = SBox{5}(gf_monomial_lut(5, 3))          # x³ is an APN permutation on n=5
    @test is_permutation(P)
    @test are_ea_equivalent(P, P)
end

@testset "Taniguchi's three n=8 classes are pairwise EA-inequivalent (exact test)" begin
    @test length(reps) == 3
    @test all(are_ea_equivalent(F, F) for F in reps)
    for i in 1:3, j in (i + 1):3
        @test !are_ea_equivalent(reps[i], reps[j])
    end
end
end
