@testset "section5_test" begin
    include(joinpath(@__DIR__, "..", "section5.jl"))

    results = section5_check_propositionV3()
    for r in results
        @test r.ok
    end

    # Theorem V.1: scan 1-term shifts over GF(2^6), small budget
    r = section5_check_theoremV1(; n = 6, i = 1)
    @test r.violations == 0
end
