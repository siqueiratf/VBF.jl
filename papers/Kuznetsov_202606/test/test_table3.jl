@testset "table3_test" begin
    include(joinpath(@__DIR__, "..", "table3.jl"))

    r = table3_run()

    @test r.all_correct

    for row in r.rows
        @test row.va == row.expected
    end
end
