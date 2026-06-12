@testset "theorem2_test" begin
    include(joinpath(@__DIR__, "..", "theorem2.jl"))
    result = theorem2_examples()
    for (desc, ok) in result.checks
        @test ok
    end
end
