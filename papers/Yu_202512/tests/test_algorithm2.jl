@testset "algorithm2_test" begin
    include(joinpath(@__DIR__, "..", "algorithm3.jl"))

    # fn_set(5): 5 is prime → only proper subfield is GF(2^1)* = {1}
    # elements not in any proper subfield: 31-1=30, orbits of size 5: 30/5=6
    @test length(fn_set(5; modulus = conway_polynomial(5))) == 6

    # fn_set(6): proper subfields GF(2^2)* (3) and GF(2^3)* (7), overlap GF(2^1)*={1}
    # excluded: 3+7-1=9; remaining 63-9=54; orbits of size 6: 54/6=9
    @test length(fn_set(6; modulus = conway_polynomial(6))) == 9

    # Algorithm 2: n=5 finds at least 1 APN matrix (Gold x^3 class)
    @test generate_apn_f2(5; limit = 5, max_evaluations = 1 << 22) >= 1

    # Algorithm 3 (partial search, all non-self-paired vars in Fₙ):
    # n=6 → exactly 4 APN matrices (Table 2 paper count)
    @test partial_search_apn_f2(6; limit = 10, max_evaluations = 1 << 24) == 4
end
