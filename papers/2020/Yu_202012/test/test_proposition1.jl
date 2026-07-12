@testset "proposition1_test" begin
    include(joinpath(@__DIR__, "..", "proposition1.jl"))
    result = proposition1_examples()
    for (desc, ok) in result.checks
        @test ok
    end
end
