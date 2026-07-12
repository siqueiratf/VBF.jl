@testset "remark3_test" begin
    include(joinpath(@__DIR__, "..", "remark3.jl"))

    # n=4: Walsh spectrum {0, ±4, ±8} for i=1,2
    for i in [1, 2]
        N = 5
        F = gold_apn(N, i)
        fu_lut, _ = build_fu(F.lut, 1, N)
        Fu = SBox{4}(fu_lut)
        aws = absolute_walsh_spectrum(Fu)
        @test issubset(Set(keys(aws.counts)), Set([0, 4, 8]))
    end

    # n=4: i=1 and i=2 are CCZ-equivalent
    F1 = gold_apn(5, 1); fu1, _ = build_fu(F1.lut, 1, 5); Fu1 = SBox{4}(fu1)
    F2 = gold_apn(5, 2); fu2, _ = build_fu(F2.lut, 1, 5); Fu2 = SBox{4}(fu2)
    @test are_ccz_equivalent(Fu1, Fu2)

    # RDF sets n=8 i=1 (Theorem 5 and Theorem 6 inverses)
    Fu5_inv = compositional_inverse(theorem5_build(8, 1; u = 1))
    Fp6_inv = compositional_inverse(theorem6_build(9, 1))
    @test rdf_set(Fu5_inv) == Set([13,14,15,16,17,18,19,20,23])
    @test rdf_set(Fp6_inv) == Set([11,12,13,14,15,16,17,18,19,21,22,23,28])
end
