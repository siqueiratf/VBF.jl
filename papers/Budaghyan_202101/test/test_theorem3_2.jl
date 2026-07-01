@testset "theorem3_2_test" begin
    include(joinpath(@__DIR__, "..", "theorem3_2.jl"))

    cases = theorem3_2_cases()
    @test length(cases) >= 7
    for c in cases
        @test c.apn_G   # G_{i,L} is APN
        @test c.ea_ok   # G_{i,L} is EA-equiv to target power APN
    end
end
