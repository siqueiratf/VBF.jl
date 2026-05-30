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
end
