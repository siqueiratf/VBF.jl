@testset "example1_test" begin
    include(joinpath(@__DIR__, "..", "example1.jl"))

    results = example1_verify()
    @test !isempty(results)
    for r in results
        @test r.perm == true
        @test r.du == 4
    end
end
