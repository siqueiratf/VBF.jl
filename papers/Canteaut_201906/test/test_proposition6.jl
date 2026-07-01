@testset "proposition6_test" begin
    include(joinpath(@__DIR__, "..", "proposition6.jl"))

    # n=3: APN butterflies exist (Theorem 1 positive case)
    r3 = proposition6_build(3, 1)
    @test !isempty(r3.apn_pairs)
    @test length(r3.apn_pairs) == 6

    # n=5: no APN butterfly (Prop 6 + Theorem 1 negative case)
    r5 = proposition6_build(5, 1)
    @test isempty(r5.apn_pairs)
    @test r5.rtc_count == 0  # refined trace condition never satisfied

    # theorem1_build convenience wrapper
    results = theorem1_build(1; n_values = [3, 5])
    @test length(results) == 2
    r3t = results[1]
    r5t = results[2]
    @test !isempty(r3t.apn_pairs)
    @test isempty(r5t.apn_pairs)
end
