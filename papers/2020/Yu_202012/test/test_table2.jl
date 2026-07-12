@testset "table2_test" begin
    include(joinpath(@__DIR__, "..", "table2.jl"))
    result = table2_verify()
    for (desc, ok) in result.checks
        @test ok
    end
    # 14 distinct functions verified (TeX has 1 duplicate)
    @test result.n_verified == 14
end
