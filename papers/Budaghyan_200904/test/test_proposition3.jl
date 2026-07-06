@testset "proposition3_test" begin
    include(joinpath(@__DIR__, "..", "proposition3.jl"))

    # Case (2) n=6: graph map yields non-quadratic (deg 3) APN matching the
    # explicit polynomial, and the map round-trips (involution recovers F).
    n = 6; M = primitive_polynomial(n)
    F = apn_x3_tr_x9(n; modulus = M)
    corr = y -> gf_trace(y, n; modulus = M)
    G = graph_affine_map(F, corr)
    @test differential_uniformity(G) == 2                     # APN
    @test algebraic_degree(G) == 3                            # non-quadratic
    @test G.lut == prop3_2_explicit(n; M = M).lut             # matches explicit poly
    @test graph_affine_map(G, corr).lut == F.lut             # round-trip
end
