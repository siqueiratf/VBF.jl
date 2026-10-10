@testset "table1_test" begin
    include(joinpath(@__DIR__, "..", "table1.jl"))

    # Test all 4 rows (sn=4, 6, 8, 8)
    for (s, n, exp_nl, exp_ds, _) in TABLE1_EXPECTED
        r = table1_compute(s, n)
        @test r.nl == exp_nl
        @test r.du == 4
        @test r.deg == r.N - 1
        ds_dict = Dict(v => c for (v, c) in sorted_pairs(r.ds))
        @test ds_dict == exp_ds
    end
    evidence=proposition5_nonlinearity_evidence()
    @test evidence[1].computed_nonlinearity == 110
    @test !evidence[1].separates_by_nonlinearity
    @test evidence[2].computed_nonlinearity == 108
    @test evidence[2].separates_by_nonlinearity
    @test TABLE1_PUBLISHED[3][3] == 108
    @test table1_compute(2,4).nl != TABLE1_PUBLISHED[3][3]
    # Control across both field representations and every nonzero F4 scalar.
    for modulus in (primitive_polynomial(8),conway_polynomial(8))
        ts=filter(!iszero,subfield_elements(8,2;modulus))
        @test length(ts)==3
        for t in ts
            F=SBox{8}(construction1_lut(2,4,t;modulus))
            @test compute_nonlinearity(F)==110
            @test Dict(sorted_pairs(differential_spectrum(F)))==Dict(0=>33111,2=>31698,4=>471)
        end
    end

    @test evidence[1].control_diff_uniformity==4
    @test evidence[1].control_nonlinearity==110
    @test evidence[1].control_differential_spectrum==Dict(0=>33153,2=>31614,4=>513)
    @test evidence[1].separates_from_control_by_differential_spectrum

end
