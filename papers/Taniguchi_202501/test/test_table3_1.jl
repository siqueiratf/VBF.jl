@testset "table3_1_test" begin
    include(joinpath(@__DIR__, "..", "table3_1.jl"))

    funcs = build_table3_1_functions()

    # All 13 must be APN and quadratic
    for f in funcs
        @test differential_uniformity(f.sbox) == 2
        @test algebraic_degree(f.sbox) == 2
    end

    # 13 distinct EA-classes
    mugshots = [apn_ea_mugshot(f.sbox) for f in funcs]
    @test length(unique(mugshots)) == 13

    # G1 (L=0) is Gold x^3
    gold = SBox([gf_pow(x, 3, 6; modulus=PAPER_MODULUS_6) for x in 0:63])
    @test funcs[1].sbox.lut == gold.lut
end
