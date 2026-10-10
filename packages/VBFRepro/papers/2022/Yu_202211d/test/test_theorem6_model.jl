using Test

@testset "Theorem 6: properness of the H_8 leading block" begin
    @test is_proper(h8_base(), 6)
    # the zero matrix is not proper for m ≥ 2
    @test !is_proper(zeros(Int, 8, 8), 6)
end

@testset "Theorem 6: new model agrees with is_qam on the seed" begin
    H = h8_base()
    @test new_model_is_qam(H) == is_qam(H) == true
end

@testset "Theorem 6: new model ≡ is_qam under properness hypothesis" begin
    for (n, s) in ((5, 500), (6, 200))
        m = new_model_matches_is_qam(; n = n, samples = s)
        @test m.checked == s
        @test m.agree == m.checked      # exact equivalence
    end
end

@testset "Theorem 6: redundancy avoidance for (x_13, x_7)" begin
    r = redundancy_comparison()
    @test r.same_pairs                  # eq.(5) and eq.(6) select the same pairs
    @test r.span_builds_new == 1        # V computed once
    @test r.span_builds_old > r.span_builds_new   # Algorithm 1 rebuilds per x_13
end
