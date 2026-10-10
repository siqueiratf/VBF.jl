@testitem "ccz_transitivity" begin
using VBF
using Test

# Regression for a CCZ-oracle false-negative that broke transitivity.
#
# Over GF(2⁴) there is exactly ONE CCZ-class of APN functions: every APN
# function on n=4 is CCZ-equivalent to the Gold power map x³. Hence every
# n=4 APN representative below must be pairwise CCZ-equivalent, and
# `are_ccz_equivalent` must respect transitivity across them.
#
# The bug: the "neither quadratic APN, not both permutations" branch of
# `are_ccz_equivalent` returned `false` unconditionally (it was gated behind
# `is_permutation(F) && is_permutation(G)`). Both F2 and f5 are degree-3,
# non-permutation APN, so the oracle answered `are_ccz_equivalent(F2, f5) ==
# false` while every other pair among {F1, F2, x³, f5} answered `true` — a
# transitivity violation, since all four share the single n=4 CCZ-class.

# n=4 APN representatives (see packages/VBFRepro/papers/2008/Brinkmann_200812/helpers.jl):
x3 = SBox{4}(gf_monomial_lut(4, 3))                                 # Gold x³, deg 2
F1 = SBox{4}(UInt8[0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 6, 3, 8, 14, 10, 13])  # Table 2, deg 2
F2 = SBox{4}(UInt8[0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 6, 3, 8, 14, 11, 12])  # Table 2, deg 3
# f5 = formula5_n4(1): Budaghyan-Carlet-Pott (2006) eq. (5), non-power, deg 3.
f5 = SBox{4}(UInt8[0, 1, 15, 8, 10, 12, 1, 1, 15, 10, 12, 15, 10, 8, 12, 8])

reps = [("x3", x3), ("F1", F1), ("F2", F2), ("f5", f5)]

@testset "all n=4 reps are APN" begin
    for (name, F) in reps
        @test differential_uniformity(F) == 2
    end
    # The two exposing reps are exactly the hard case: degree-3, non-permutation.
    @test algebraic_degree(F2) == 3 && !is_permutation(F2)
    @test algebraic_degree(f5) == 3 && !is_permutation(f5)
end

@testset "all n=4 APN reps are pairwise CCZ-equivalent (single class)" begin
    for (na, A) in reps, (nb, B) in reps
        @test are_ccz_equivalent(A, B)              # every pair, both directions
    end
end

@testset "minimal reproducer: F2 ~_CCZ f5 (both degree-3 non-permutation)" begin
    @test are_ccz_equivalent(F2, f5)
    @test are_ccz_equivalent(f5, F2)                # symmetric
end

@testset "transitivity holds across the class" begin
    # F2 ~ x³ and x³ ~ f5  ⟹  F2 ~ f5.
    @test are_ccz_equivalent(F2, x3)
    @test are_ccz_equivalent(x3, f5)
    @test are_ccz_equivalent(F2, f5)
end
end
