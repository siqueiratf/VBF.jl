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

@testset "Kim function — the quadratic source of the Dillon permutation" begin
    K = kim_apn()
    @test inputbits(K) == 6
    @test differential_uniformity(K) == 2        # APN (only under this GF(2⁶) field)
    @test algebraic_degree(K) == 2               # quadratic (unlike the degree-4 permutation)
    @test !is_permutation(K)                      # 3-to-1, like every quadratic APN here
end

@testset "is_ccz_equivalent_to_permutation (complementary Walsh-zero pair)" begin
    # the Kim function is the canonical positive case: a non-permutation quadratic
    # APN that IS CCZ-equivalent to a permutation (the Dillon one)
    @test is_ccz_equivalent_to_permutation(kim_apn())
    @test is_ccz_equivalent_to_permutation(dillon_apn_permutation())
    @test is_ccz_equivalent_to_permutation(gold_apn(5, 1))   # x³ is a permutation on n=5
    # ... but not in even dimension
    @test !is_ccz_equivalent_to_permutation(gold_apn(4, 1))  # no n=4 APN permutation
    @test !is_ccz_equivalent_to_permutation(gold_apn(6, 1))  # x³ is not the Dillon class
end
end
