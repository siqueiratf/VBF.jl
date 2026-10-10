@testset "theorem4_test" begin
    include(joinpath(@__DIR__, "..", "theorem4.jl"))

    for (n, i) in [(4, 1), (4, 2), (6, 1)]
        Fu = theorem4_build(n, i; u = 1)
        half  = 1 << (n ÷ 2)
        half2 = 1 << ((n + 2) ÷ 2)
        aws = absolute_walsh_spectrum(Fu)
        @test issubset(Set(keys(aws.counts)), Set([0, half, half2]))
        @test differential_uniformity(Fu) == 4
    end
end
