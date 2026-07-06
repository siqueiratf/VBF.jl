@testset "theorem5_test" begin
    include(joinpath(@__DIR__, "..", "theorem5.jl"))

    modulus = primitive_polynomial(6)
    n       = 6
    gold    = gold_apn(n, 1)
    gold_ws = absolute_walsh_spectrum(gold)

    T1   = dillon_T1(; modulus)
    T2   = dillon_T2()          # built under Conway poly; see dillon_T2 docstring
    F1   = theorem1_sbox(3, 1, [0, 0]; modulus)    # Family 1 trinomial
    F2_0 = theorem3_sbox(2, 1, 0)                  # Family 2 v=0 (binomial)
    F2_v = theorem3_sbox(2, 1, 1)                  # Family 2 v≠0 (trinomial)

    # Dillon trinomials are APN
    @test differential_uniformity(T1) == 2
    @test differential_uniformity(T2) == 2

    # Walsh spectrum equality to Gold x^3
    @test absolute_walsh_spectrum(T1)   == gold_ws
    @test absolute_walsh_spectrum(T2)   == gold_ws
    @test absolute_walsh_spectrum(F1)   == gold_ws
    @test absolute_walsh_spectrum(F2_0) == gold_ws
    @test absolute_walsh_spectrum(F2_v) == gold_ws

    # CCZ equivalence claims (n=6, all quadratic APN → CCZ=EA via ortho-derivative)
    @test are_ccz_equivalent(F1,   T1)      # Family 1 ↔ Dillon T1
    @test are_ccz_equivalent(F2_v, T2)      # Family 2 v≠0 ↔ Dillon T2
    @test are_ccz_equivalent(F2_0, gold)    # Family 2 v=0 ↔ Gold (binomial from [2])

    # NOT CCZ-equivalent to Gold (not in the power-mapping CCZ class)
    @test !are_ccz_equivalent(F1,   gold)
    @test !are_ccz_equivalent(F2_v, gold)

    # Dillon T1 and T2 are in distinct CCZ classes
    @test !are_ccz_equivalent(T1, T2)
end
