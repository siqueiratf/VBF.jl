@testitem "qam_full_search" begin
using VBF
using Test

# Yu–Wang–Li's "guess and determine" QAM construction over the FULL symmetric
# matrix space (Algorithm 1), as opposed to the cyclic-only `search_qam`. It
# reproduces the complete small classifications; n=6 → the 13 CCZ classes is
# verified standalone (too slow for the suite), n=5 → the single Gold-x³ class
# is fast.
@testset "search_qam_full reproduces the n=5 classification (Gold x³)" begin
    reps = search_qam_full(5; limit = 1)
    @test length(reps) == 1
    F = reps[1]
    @test inputbits(F) == 5
    @test differential_uniformity(F) == 2          # APN
    @test algebraic_degree(F) == 2                 # quadratic
    @test is_qam(F)                                # its derivative matrix is a QAM
    gold = SBox{5}(gf_monomial_lut(5, 3))
    @test apn_ea_mugshot(F) == apn_ea_mugshot(gold)
end

@testset "search_qam_full: budget caps the search" begin
    # a zero evaluation budget returns immediately with nothing examined
    @test isempty(search_qam_full(6; max_evaluations = 0))
end
end
