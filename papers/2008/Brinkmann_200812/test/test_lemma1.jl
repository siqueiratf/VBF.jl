@testset "lemma1_test" begin
    include(joinpath(@__DIR__, "..", "lemma1.jl"))

    F1, F2 = table2_luts()

    @test check_lemma1(F1)
    @test check_lemma1(F2)

    # Lemma 1 check agrees with DDT criterion for both Table 2 functions
    @test check_lemma1(F1) == (differential_uniformity(F1) == 2)
    @test check_lemma1(F2) == (differential_uniformity(F2) == 2)

    # Non-APN function: f(x) = x mod 3 over F₂⁴ is not APN
    non_apn = SBox{4}([x % 3 for x in 0:15])
    @test !check_lemma1(non_apn)
    @test !check_lemma1(non_apn) == (differential_uniformity(non_apn) != 2)
end
