@testset "remark2_test" begin
    include(joinpath(@__DIR__, "..", "remark2.jl"))

    # (k=1, l=7): 28 theorem, 33 actual, uncovered = {7,35,49,77,91}
    r7 = remark2_experiment(devnull, 7, 1; max_n=100)
    @test length(r7.theorem_dims) == 28
    @test length(r7.actual_dims) == 33
    @test r7.uncovered == [7, 35, 49, 77, 91]

    # (k=1, l=5): 40 theorem, 50 actual, uncovered = 5+10k for k=0..9
    r5 = remark2_experiment(devnull, 5, 1; max_n=100)
    @test length(r5.theorem_dims) == 40
    @test length(r5.actual_dims) == 50
    @test r5.uncovered == [5 + 10i for i in 0:9]
end
