@testset "table1_test" begin
    include(joinpath(@__DIR__, "..", "table1.jl"))
    result = table1_verify()
    for (desc, ok) in result.checks
        @test ok
    end
end
