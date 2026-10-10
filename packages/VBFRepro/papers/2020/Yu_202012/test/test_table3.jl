@testset "table3_test" begin
    include(joinpath(@__DIR__, "..", "table3.jl"))
    result = table3_verify()
    for (desc, ok) in result.checks
        @test ok
    end
end
