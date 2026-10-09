# Implements Section 3.1 test cases.
# Paper: Baudrin, Galissant and Perrin (2025), "Exploring the Set of APN Functions", BFA 2025
# Section: 3.1 — An Exact Representation of a CCZ-Equivalence Class
#
# Pseudocode:
#   1. Check subgroup semantics, a known count and graph-map round trips.
# VBF API used: ea_class_orbits, ccz_equivalent_function
@testset "section31_test" begin
    include(joinpath(@__DIR__, "..", "section31.jl"))
    F = gold_apn(4)
    result = section31(;F)
    @test result.exhaustive
    @test result.legacy_agrees === true
    @test result.crosscheck_complete
    @test length(result.native.representatives) == 2
    @test count(G -> algebraic_degree(G) == 2,result.native.representatives) == 1
    @test all(G -> differential_uniformity(G) == 2,result.native.representatives)
    @test all(A -> bgp_verify_graph_map(F,F,A;relation=:ea),result.automorphisms.generators)
    for (G,A) in zip(result.native.representatives,result.native.mappings)
        @test bgp_verify_graph_map(F,G,A)
        inverse = inv(A.linear)
        @test bgp_verify_graph_map(G,F,F2AffineMap(inverse,inverse(A.constant)))
    end
    stopped = section31(;F,max_nodes=0,compare_legacy=false)
    @test !stopped.exhaustive
    @test isempty(stopped.native.representatives)
    @test_throws ArgumentError section31(limit=-1)
    identity_function = SBox{4}(collect(0:15))
    singular = F2AffineMap{8,UInt32}(UInt32[zeros(UInt32,4);
        [(UInt32(1)<<j) | (UInt32(1)<<(j+4)) for j in 0:3]],0)
    @test !bgp_verify_graph_map(identity_function,identity_function,singular)

    witness = first(result.certificates)
    data = bgp_metadata("test_section31",940,(;limit=1))
    data["witnesses"] = [witness]
    name = "test_section31_snapshot_$(rand(UInt))"
    @test bgp_save(name,data) === nothing
    path = bgp_save(name,data;save_results=true)
    try
        restored = TOML.parsefile(path)
        record = only(restored["witnesses"])
        source = SBox{4}(record["source_lut"])
        target = SBox{4}(record["target_lut"])
        map = F2AffineMap{8,UInt32}(record["linear_columns"],record["constant"])
        @test bgp_verify_graph_map(source,target,map)
        @test restored["conjecture_proved"] === false
    finally
        rm(path)
    end
end
