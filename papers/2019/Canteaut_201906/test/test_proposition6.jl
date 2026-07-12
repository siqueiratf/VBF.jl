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

    # n=3, i=2: APN butterflies also exist for the other coprime exponent
    r32 = proposition6_build(3, 2)
    @test length(r32.apn_pairs) == 6

    # n=5: all remaining i with gcd(i,5)=1
    for i in (2, 3, 4)
        r5i = proposition6_build(5, i)
        @test isempty(r5i.apn_pairs)
        @test r5i.rtc_count == 0
    end

    # theorem1_build convenience wrapper
    results = theorem1_build(1; n_values = [3, 5])
    @test length(results) == 2
    r3t = results[1]
    r5t = results[2]
    @test !isempty(r3t.apn_pairs)
    @test isempty(r5t.apn_pairs)
end
