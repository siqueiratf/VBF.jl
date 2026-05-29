@testitem "trims" begin
using VBF
using Test
using Random

mono(n, e) = SBox{n}(gf_monomial_lut(n, e))

@testset "trim count and shape" begin
    for n in (4, 5)
        F = mono(n, 3)
        t = trims(F)
        @test length(t) == 2 * (2^n - 1)^2
        @test all(inputbits(s) == n - 1 for s in t)
    end
end

@testset "apn_trims are APN" begin
    F = mono(5, 3)                       # Gold x³ over GF(2⁵)
    at = apn_trims(F)
    @test !isempty(at)
    @test all(differential_uniformity(s) == 2 for s in at)
    @test all(inputbits(s) == 4 for s in at)
end

@testset "trim spectrum is a linear-equivalence invariant" begin
    rng = MersenneTwister(2024)
    n = 5
    F = mono(n, 3)
    L1 = random_invertible_linear_map(rng, Val(n))
    L2 = random_invertible_linear_map(rng, Val(n))
    G = SBox{n}([L1(F(L2(x))) for x in 0:(1 << n) - 1])
    sF = trim_spectrum(F)
    sG = trim_spectrum(G)
    @test sF == sG
    @test sum(values(sF)) == length(apn_trims(F))   # total over the multiset
    @test !isempty(sF)
end
end
