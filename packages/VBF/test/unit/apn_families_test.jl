@testitem "apn_families" begin
using VBF
using Test

@testset "each known monomial family is APN at its dimension" begin
    @test differential_uniformity(gold_apn(5, 1)) == 2        # x³
    @test differential_uniformity(gold_apn(7, 2)) == 2        # x⁵ on n=7
    @test differential_uniformity(kasami_apn(5, 2)) == 2      # x¹³ on n=5
    @test differential_uniformity(welch_apn(5)) == 2          # x⁷
    @test differential_uniformity(niho_apn(5)) == 2           # t even branch
    @test differential_uniformity(niho_apn(7)) == 2           # t odd branch
    @test differential_uniformity(inverse_apn(5)) == 2        # x³⁰
    @test differential_uniformity(dobbertin_apn(5)) == 2      # x²⁹, n = 5k
    # Gold is the only quadratic family; the rest have higher degree
    @test algebraic_degree(gold_apn(5, 1)) == 2
    @test algebraic_degree(kasami_apn(5, 2)) > 2
end

@testset "parameter guards" begin
    @test_throws ArgumentError gold_apn(4, 2)      # gcd(2,4) ≠ 1
    @test_throws ArgumentError kasami_apn(6, 2)    # gcd(2,6) ≠ 1
    @test_throws ArgumentError welch_apn(6)        # even
    @test_throws ArgumentError niho_apn(6)
    @test_throws ArgumentError inverse_apn(6)
    @test_throws ArgumentError dobbertin_apn(6)    # 5 ∤ 6
end

@testset "known_apn_monomials lists the applicable families, all APN" begin
    fams = known_apn_monomials(5)
    names = Set(first.(fams))
    @test :gold in names
    @test :welch in names
    @test :niho in names
    @test :inverse in names
    @test :dobbertin in names                      # 5 ∣ 5
    @test all(differential_uniformity(F) == 2 for (_, F) in fams)
    @test all(inputbits(F) == 5 for (_, F) in fams)
end
end
