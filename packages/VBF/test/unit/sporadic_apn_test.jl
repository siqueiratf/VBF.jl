@testitem "sporadic_apn" begin
using VBF
using Test

@testset "Dillon n=6 APN permutation (Browning–Dillon–McQuistan–Wolfe 2010)" begin
    F = dillon_apn_permutation()
    @test inputbits(F) == 6
    @test is_permutation(F)                      # the only known even-dim APN permutation
    @test differential_uniformity(F) == 2        # APN
    @test algebraic_degree(F) == 4               # degree 4 (CCZ-equivalent to a quadratic)
end

@testset "is_ccz_equivalent_to_permutation (Canteaut–Perrin thickness criterion)" begin
    # the Dillon permutation IS a permutation → trivially CCZ-equiv to one
    @test is_ccz_equivalent_to_permutation(dillon_apn_permutation())
    # Gold x³ is a permutation in odd dimension
    @test is_ccz_equivalent_to_permutation(gold_apn(5, 1))
    # ... but NOT CCZ-equivalent to a permutation in even dimension
    @test !is_ccz_equivalent_to_permutation(gold_apn(4, 1))   # no n=4 APN permutation
    @test !is_ccz_equivalent_to_permutation(gold_apn(6, 1))   # x³ is not the Dillon class
end
end
