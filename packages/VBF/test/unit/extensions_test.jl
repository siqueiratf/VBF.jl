@testitem "extensions" begin
using VBF
using Test
using Random

quad_apn(F) = differential_uniformity(F) == 2 && algebraic_degree(F) == 2

@testset "deterministic search enumerates exactly the c=0 extensions" begin
    G3 = SBox{3}(gf_monomial_lut(3, 3))          # 3-bit Gold x³
    allext = extend_quadratic_apn(G3; limit=typemax(Int))
    @test length(allext) == 448                  # matches independent brute force
    @test all(inputbits(F) == 4 for F in allext)
    @test all(quad_apn, allext)
end

@testset "limit and determinism" begin
    G3 = SBox{3}(gf_monomial_lut(3, 3))
    a = extend_quadratic_apn(G3; limit=3)
    @test length(a) == 3 && all(quad_apn, a)
    @test a == extend_quadratic_apn(G3; limit=3)
end

@testset "trim/extend round trip" begin
    G3 = SBox{3}(gf_monomial_lut(3, 3))
    F = extend_quadratic_apn(G3; limit=1)[1]
    gmug = apn_ea_mugshot(G3)
    @test any(apn_ea_mugshot(t) == gmug for t in apn_trims(F))   # G is a trim of F
end

@testset "randomised top coordinate is reproducible and valid (n=5)" begin
    G4 = SBox{4}(gf_monomial_lut(4, 3))          # 4-bit Gold x³
    # A random top coordinate need not admit an extension: emptiness is valid.
    # Test a fixed finite batch, rather than assuming one particular RNG seed hits.
    hits = 0
    for seed in 0:15
        r1 = extend_quadratic_apn(G4; limit=1, rng=MersenneTwister(seed))
        r2 = extend_quadratic_apn(G4; limit=1, rng=MersenneTwister(seed))
        @test r1 == r2
        @test length(r1) <= 1
        for F in r1
            hits += 1
            @test inputbits(F) == 5 && quad_apn(F)
            @test any(apn_ea_mugshot(t) == apn_ea_mugshot(G4) for t in apn_trims(F))
        end
    end
    @test hits > 0   # the batch exercises successful extension verification too
end
end
