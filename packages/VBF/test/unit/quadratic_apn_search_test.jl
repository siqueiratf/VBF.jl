@testitem "quadratic_apn_search" begin
using VBF
using Test
using Random

quad_apn(F) = differential_uniformity(F) == 2 && algebraic_degree(F) == 2

@testset "finds a quadratic APN with F(0)=0" begin
    for N in (3, 4)
        sols = search_quadratic_apn(Val(N))
        @test length(sols) == 1
        F = sols[1]
        @test inputbits(F) == N
        @test F(0) == 0
        @test quad_apn(F)
        @test is_quadratic_apn(F)          # ortho-derivative is defined
    end
end

@testset "limit returns several distinct quadratic APN" begin
    sols = search_quadratic_apn(Val(4); limit=5)
    @test length(sols) == 5
    @test all(quad_apn, sols)
    @test length(unique(F.lut for F in sols)) == 5   # distinct LUTs
end

@testset "the default search is deterministic" begin
    @test search_quadratic_apn(Val(4); limit=5) == search_quadratic_apn(Val(4); limit=5)
end

@testset "a seeded rng gives a reproducible randomised order" begin
    r1 = search_quadratic_apn(Val(4); limit=3, rng=MersenneTwister(7))
    r2 = search_quadratic_apn(Val(4); limit=3, rng=MersenneTwister(7))
    @test r1 == r2
    @test length(r1) == 3 && all(quad_apn, r1)
end
end
