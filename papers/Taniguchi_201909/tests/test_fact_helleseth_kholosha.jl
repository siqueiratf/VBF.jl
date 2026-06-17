@testset "fact_helleseth_kholosha_test" begin
    include(joinpath(@__DIR__, "..", "fact_helleseth_kholosha.jl"))

    # n=5 (odd): (2⁵+1)/3 = 11
    @test helleseth_kholosha_formula(5) == 11
    @test count_rootless_b(5, 1) == 11

    # n=6 (even): (2⁶-1)/3 = 21
    @test helleseth_kholosha_formula(6) == 21
    @test count_rootless_b(6, 1) == 21

    # Verify formula divides evenly
    @test helleseth_kholosha_formula(7) == 43   # (128+1)/3 = 43
end
