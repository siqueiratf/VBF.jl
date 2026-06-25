@testset "section5_3_test" begin
    include(joinpath(@__DIR__, "..", "section5_3.jl"))

    db = load_catalog()

    # Gold x^3 is APN for n=10
    r3 = find_function(db; canonical_name = "n10_Gold_x3")
    F3 = load_sbox(db, r3.id)
    @test differential_uniformity(F3) == 2

    # Gold x^9 is APN for n=10
    r9 = find_function(db; canonical_name = "n10_Gold_x9")
    F9 = load_sbox(db, r9.id)
    @test differential_uniformity(F9) == 2

    # Third class is APN
    G = third_ccz_class_n10()
    @test differential_uniformity(G) == 2

    # All three have distinct ODDS → pairwise CCZ-inequivalent
    ds3 = differential_spectrum(ortho_derivative(F3))
    ds9 = differential_spectrum(ortho_derivative(F9))
    dsG = differential_spectrum(ortho_derivative(G))
    @test ds3.counts != ds9.counts
    @test ds3.counts != dsG.counts
    @test ds9.counts != dsG.counts
end
