@testset "section5a_test" begin
    include(joinpath(@__DIR__, "..", "section5a.jl"))

    r = section5a_report(io = devnull)

    # Spectra match Table IV (paper, p. 25)
    @test r.match1   # F₁ spectrum matches
    @test r.match2   # F₂ spectrum matches

    # Both distinct from all known families in Table IV
    @test r.f1_new
    @test r.f2_new

    # F₁ and F₂ have distinct orthoderivative spectra
    @test !dicts_equal(r.dict1, r.dict2)

    # Spot-check a few entries from the paper
    @test get(r.dict1, 0, 0) == 164199
    @test get(r.dict1, 22, 0) == 21
    @test get(r.dict2, 0, 0) == 172557
    @test get(r.dict2, 42, 0) == 21
end
