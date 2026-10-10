include(joinpath(@__DIR__, "..", "prior_art.jl"))
@testset "Example 4.2 prior-art EA witness" begin
    r = prior_art_witness()
    @test r.verified
    @test prior_art_witness(; recover = true, timeout_seconds = 10).verified === true
    @test differential_uniformity(SBox(r.candidate)) == 2
    @test differential_uniformity(SBox(r.reference)) == 2
    bad = copy(r.columns); bad[1] = bad[2]
    @test !GraphWitnesses.verify_ea_witness(r.candidate, r.reference, bad, r.constant)
end

@testset "Edel--Pott Table9 entry1.3 source and corpus witnesses" begin
    ep = edel_pott_prior_art_witness()
    @test ep.verified === true
    @test ep.member == 5
    @test ep.corpus == ep.alternate
    @test differential_uniformity(SBox(ep.primary)) == 2
    @test algebraic_degree(SBox(ep.primary)) == 2
    @test GraphWitnesses.verify_ea_witness(ep.candidate, ep.primary,
        ep.to_primary.columns, ep.to_primary.constant)
    @test GraphWitnesses.verify_ea_witness(ep.primary, ep.corpus,
        ep.to_corpus.columns, ep.to_corpus.constant)
    @test edel_pott_prior_art_witness(; recover = true).verified === true
    bad = copy(ep.to_primary.columns); bad[1] = bad[2]
    @test !GraphWitnesses.verify_ea_witness(ep.candidate, ep.primary, bad, ep.to_primary.constant)
    @test ismissing(edel_pott_prior_art_witness(; recover = true, timeout_seconds = 0).verified)
end
