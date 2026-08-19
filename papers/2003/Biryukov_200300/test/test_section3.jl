@testset "section3_ae_algorithm" begin
    include(joinpath(@__DIR__, "..", "section3.jl"))

    g3 = load_apn_function("n5_Gold_x3")
    k15 = load_apn_function("n5_Kasami_x15")

    # AE is reflexive.
    @test are_affine_equivalent(g3, g3)

    # Different APN families are not affine equivalent.
    @test !are_affine_equivalent(g3, k15)

    # linear_representative is canonical: applying it twice gives same result.
    rep1 = linear_representative(g3).representative
    rep2 = linear_representative(g3).representative
    @test rep1 == rep2

    # A function and its linear representative are affine equivalent.
    @test are_affine_equivalent(g3, rep1)

    # affine_representative is stable for affine-equivalent functions.
    ar1 = affine_representative(g3)
    ar2 = affine_representative(rep1)
    @test ar1 == ar2

    # Full report passes.
    @test section3_report(devnull)
end
