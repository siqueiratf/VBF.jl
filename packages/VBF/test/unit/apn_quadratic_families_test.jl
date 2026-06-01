@testitem "apn_quadratic_families" begin
using VBF
using Test

@testset "BCP binomial (n = 3k) is quadratic and APN" begin
    # n = 3k with k = 2 (smallest valid: gcd(k,3)=1), n = 6. s coprime to 3k = 6 ⇒ s ∈ {1, 5}; both give a valid i = s·k mod 3.
    for s in (1, 5)
        F = bcp_apn(2, s)
        @test inputbits(F) == 6
        @test differential_uniformity(F) == 2     # APN
        @test algebraic_degree(F) == 2            # quadratic
    end
end

@testset "BCL binomial (n = 4k) is quadratic and APN" begin
    # n = 4k with k = 1 (smallest valid: gcd(k,2)=1, k odd), n = 4. s coprime to 2k = 2 and s ≤ 4k−1 = 3 ⇒ s ∈ {1, 3}.
    for s in (1, 3)
        F = bcl_apn(1, s)
        @test inputbits(F) == 4
        @test differential_uniformity(F) == 2     # APN
        @test algebraic_degree(F) == 2            # quadratic
    end
end

@testset "parameter guards" begin
    # BCP: gcd(k, 3) ≠ 1
    @test_throws ArgumentError bcp_apn(3, 1)
    # BCP: gcd(s, 3k) ≠ 1  (s = 2 shares factor 2 with 3k = 6)
    @test_throws ArgumentError bcp_apn(2, 2)
    # BCL: gcd(k, 2) ≠ 1  (k must be odd)
    @test_throws ArgumentError bcl_apn(2, 1)
    # BCL: gcd(s, 2k) ≠ 1  (s even with k = 1)
    @test_throws ArgumentError bcl_apn(1, 2)
    # BCL: s ≤ 4k − 1 violated
    @test_throws ArgumentError bcl_apn(1, 5)
end
end
