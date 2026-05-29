@testitem "qam" begin
using VBF
using Test

mono(n, e) = SBox{n}(gf_monomial_lut(n, e))

@testset "derivative matrix is symmetric with zero diagonal" begin
    for (n, e) in ((5, 3), (6, 5), (8, 3))
        M = quadratic_apn_matrix(mono(n, e))
        @test size(M) == (n, n)
        @test M == permutedims(M)
        @test all(M[i, i] == 0 for i in 1:n)
    end
end

@testset "is_qam decides APN-ness of quadratic functions" begin
    @test is_qam(mono(5, 3))             # Gold x³, APN
    @test is_qam(mono(7, 3))
    @test !is_qam(mono(6, 5))            # x⁵ = Gold k=2, not APN for even n
    @test !is_qam(mono(8, 5))
    @test is_qam(mono(5, 5))             # x⁵ APN for n=5 (gcd(2,5)=1)
end

@testset "is_qam matches differential_uniformity over Gold exponents" begin
    for n in 4:8, k in 1:n - 1
        e = (1 << k) + 1                 # x^(2ᵏ+1), quadratic
        e >= (1 << n) && continue
        F = mono(n, e)
        @test is_qam(F) == (differential_uniformity(F) == 2)
    end
end

@testset "is_qam on a matrix equals is_qam on the function" begin
    F = mono(6, 3)
    @test is_qam(quadratic_apn_matrix(F)) == is_qam(F)
end
end
