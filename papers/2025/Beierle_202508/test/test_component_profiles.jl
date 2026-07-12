@testset "component profile moments" begin
    r = apn_component_moment_check(4)
    @test r.differential_uniformity == 2
    @test r.algebraic_degree == 2
    @test r.alpha_sum == 30
    @test r.matches

    F = gold_apn(4, 1)
    @test component_quadratic_rank(F, 1) % 2 == 0
    @test quadratic_form_rank(quadratic_component_vector(F, 1), 4) ==
          component_quadratic_rank(F, 1)
end
