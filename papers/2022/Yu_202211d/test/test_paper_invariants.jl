using Test
using Random

@testset "Ortho-derivative fingerprint is EA-invariant" begin
    F = gold_apn(5, 1)
    rng = MersenneTwister(123)
    A = random_linear_permutation(rng, Val(5))
    B = random_linear_permutation(rng, Val(5))
    G = compose(A, compose(F, B))                  # EA-equivalent to F
    @test apn_ea_mugshot(G) == apn_ea_mugshot(F)
    @test ortho_derivative_fingerprint(G) == ortho_derivative_fingerprint(F)
    @test sigma_invariant(G) == sigma_invariant(F)
    @test ortho_derivative_fingerprint(SBox{5}(zeros(Int, 32))) === nothing
end

@testset "Ortho-derivative separates the 13 quadratic APN classes on F_2^6" begin
    cls = search_solutions(search_qam_full(6; limit = 13, max_evaluations = 1 << 24))
    @test length(cls) == 13
    @test distinct_ccz_lower_bound(cls) == 13
end

@testset "Sigma_4 invariant and design ranks" begin
    F = gold_apn(5, 1)
    @test total_mass(sigma_multiplicities(F)) == 1 << 5
    dr = design_ranks(F)
    @test dr.available
    @test dr.gamma > 0 && dr.delta > 0
    # Γ/Δ-ranks are guarded above n = 7
    @test design_ranks(gold_apn(8, 1)).available == false
end

@testset "Extended Walsh classifier" begin
    @test paper_walsh_class(gold_apn(5, 1)) == :na    # only defined for n = 8
    @test paper_walsh_class(gold_apn(8, 1)) in (:W1, :W2, :W3, :other)
end
