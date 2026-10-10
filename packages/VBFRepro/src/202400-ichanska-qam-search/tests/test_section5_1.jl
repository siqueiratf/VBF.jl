@testset "section5_1_test" begin
    include(joinpath(@__DIR__, "..", "section5_1.jl"))

    F = new_function_n8_m2()

    # APN
    @test differential_uniformity(F) == 2

    # ODDS matches Table 11, index 10
    ds = odds(F)
    exp = expected_odds_new()
    @test all(ds.counts[k] == v for (k, v) in exp)
    @test length(ds.counts) == length(exp)

    # Nonlinearity = 112 (Table 5)
    ws = absolute_walsh_spectrum(F)
    max_w = maximum(keys(ws.counts))
    @test (1 << 7) - max_w ÷ 2 == 112

    # CCZ-inequivalent to Gold x^3 over F₂⁸
    db = load_catalog()
    r = find_function(db; canonical_name = "n8_Gold_x3")
    gold3 = load_sbox(db, r.id)
    @test odds(F).counts != odds(gold3).counts
    close(db)
    # The positive witness is verified point-by-point, independently of search.
    prior=section5_1_prior_art()
    @test prior.witness_verified
    @test verify_ea_witness(Int.(F.lut),prior.target_lut,prior.columns,prior.constant)
    @test !verify_ea_witness(Int.(F.lut),Int.(gold3.lut),prior.columns,prior.constant)
    @test !verify_ea_witness(Int.(F.lut),prior.target_lut,prior.columns,prior.constant⊻1)
    @test odds(F).counts != odds(gold_apn(8,3;modulus=conway_polynomial(8))).counts
    db=load_catalog()
    try
        if prior.source_available
            @test Int.(corpus_function(db,"wengtangong2013_n8",9).lut) == prior.target_lut
            @test odds(F).counts != odds(corpus_function(db,"wengtangong2013_n8",1)).counts
        end
    finally
        close(db)
    end

end
