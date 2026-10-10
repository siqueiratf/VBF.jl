@testitem "design_ranks" begin
using VBF
using Random
using Test

@testset "Γ/Δ-rank: values, the Δ-rank bound, and CCZ-invariance (n=5)" begin
    n = 5
    F = SBox{n}(gf_monomial_lut(n, 3))           # Gold x³ on F₂⁵
    @test gamma_rank(F) == 330                   # regression pin
    @test delta_rank(F) == 42
    @test delta_rank(F) ≤ 1 << (n + 1)           # Edel–Pott bound Δ-rank ≤ 2^{n+1}
    # an EA-image must have identical ranks (CCZ-invariance)
    L1 = random_invertible_linear_map(MersenneTwister(1), Val(n))
    L2 = random_invertible_linear_map(MersenneTwister(2), Val(n))
    G = SBox{n}([L1(F.lut[L2(x) + 1]) for x in 0:(1 << n) - 1])
    @test gamma_rank(G) == gamma_rank(F)
    @test delta_rank(G) == delta_rank(F)
end

@testset "n=4 invariance and the n ≥ 8 guard" begin
    F = SBox{4}(gf_monomial_lut(4, 3))
    g4 = gamma_rank(F); d4 = delta_rank(F)
    @test d4 ≤ 1 << 5
    L = random_invertible_linear_map(MersenneTwister(3), Val(4))
    FL = SBox{4}([F.lut[L(x) + 1] for x in 0:15])
    @test gamma_rank(FL) == g4
    @test delta_rank(FL) == d4
    # n = 8 needs a 2^16 × 2^16 matrix — guarded as impractical
    @test_throws ArgumentError gamma_rank(SBox{8}(gf_monomial_lut(8, 3)))
    @test_throws ArgumentError delta_rank(SBox{8}(gf_monomial_lut(8, 3)))
end
@testset "explicit storage/time budgets fail without publishing a partial rank" begin
    F8=gold_apn(8)
    @test_throws ArgumentError gamma_rank(F8;allow_large=true)
    @test_throws DesignRankBudgetHit gamma_rank(F8;allow_large=true,max_memory_bytes=1,timeout_seconds=600)
    @test_throws DesignRankBudgetHit gamma_rank(F8;allow_large=true,max_memory_bytes=2*1024^3,timeout_seconds=0)
    @test_throws DesignRankBudgetHit delta_rank(F8;allow_large=true,max_memory_bytes=2*1024^3,timeout_seconds=0)
    @test_throws DesignRankBudgetHit gamma_rank(gold_apn(4);max_memory_bytes=0)
    @test_throws ArgumentError gamma_rank(gold_apn(4);timeout_seconds=-1)
    @test_throws ArgumentError gamma_rank(gold_apn(9);allow_large=true,max_memory_bytes=64*1024^3,timeout_seconds=600)
    # Optional real n8 verification is deliberately absent from ordinary CI.
    if get(ENV,"VBF_TEST_DESIGN_RANK8","0")=="1"
        @test gamma_rank(F8;allow_large=true,max_memory_bytes=2*1024^3,timeout_seconds=600)==11818
    end
end
end
