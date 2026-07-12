@testset "table4_test" begin
    include(joinpath(@__DIR__, "..", "table4.jl"))
    result = table4_verify()
    for (desc, ok) in result.checks
        @test ok
    end
end
