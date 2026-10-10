# Implements independent evidence checks for Sections 3.1–3.2 and Conjecture 1.
# Paper: Baudrin, Galissant and Perrin (2025), Exploring the Set of APN Functions
# Pseudocode: check raw graph certificates, budget semantics and TOML round trips.
@testset "independent evidence and budget semantics" begin
    small = section32(dimension=4)
    @test small.degrees == Dict(2=>1, 3=>1)
    @test length(small.witnesses) == 2
    completed = only(small.rows).result
    @test completed.bounds !== nothing
    @test completed.bounds.lower <= completed.bounds.observed <= completed.bounds.upper
    # The native census consumes the shared budget first; an optional legacy
    # cross-check receives only the remaining node allowance.
    allowance = completed.automorphisms.nodes_visited +
        completed.native.orbit_result.nodes_visited + 1
    shared = section31(max_nodes=allowance)
    @test shared.exhaustive
    @test shared.legacy !== nothing && !shared.legacy.complete
    @test shared.legacy.nodes_visited == 1
    @test !shared.crosscheck_complete
    @test shared.automorphisms.nodes_visited + shared.native.orbit_result.nodes_visited +
        shared.legacy.nodes_visited <= allowance
    @test all(bgp_test_certificate, small.witnesses)
    @test bgp_test_degree(first(small.witnesses)["source_lut"]) == 2
    @test bgp_test_apn(first(small.witnesses)["source_lut"])
    cubic = only(filter(w -> algebraic_degree(SBox{4}(w["target_lut"])) == 3,
        small.witnesses))
    @test !bgp_test_certificate(cubic; relation=:ea)
    @test bgp_test_degree(cubic["target_lut"]) == 3
    @test bgp_test_apn(cubic["target_lut"])
    @test bgp_test_ortho_derivative(first(small.witnesses)["source_lut"]) ==
        Int.(ortho_derivative(gold_apn(4)).lut)
    singular = deepcopy(first(small.witnesses))
    singular["linear_columns"][2] = singular["linear_columns"][1]
    @test !bgp_test_certificate(singular)
    corrupted = deepcopy(first(small.witnesses))
    corrupted["target_lut"][2] = corrupted["target_lut"][1]
    @test !bgp_test_certificate(corrupted)

    for kwargs in ((max_nodes=0,), (max_subspaces=0,), (max_memory_bytes=0,))
        stopped = section31(; kwargs..., compare_legacy=false)
        @test !stopped.exhaustive
        @test !stopped.native.complete
        @test stopped.bounds === nothing
        @test all(bgp_test_certificate, stopped.certificates)
    end
    stopped_census = section32(dimension=4,max_nodes=0)
    @test !stopped_census.exhaustive
    @test !stopped_census.region_complete
    @test !stopped_census.exact_census
    stopped_switching = conjecture1(max_nodes=0)
    @test !stopped_switching.exhaustive
    @test !stopped_switching.conjecture_proved
    @test stopped_switching.relative_new_ccz_seeds == 0

    exploration = conjecture1(max_neighbors=2)
    @test all(bgp_test_certificate, exploration.witnesses)
    # Use unique snapshot names: these tests must not overwrite a concurrent
    # expensive census's section32.toml or a saved switching experiment.
    for (kind, witnesses, records) in (
        ("section32",small.witnesses,Dict{String,Any}[]),
        ("conjecture1",exploration.witnesses,exploration.records),
    )
        data = bgp_metadata(kind,940,(; dimension=4))
        merge!(data,Dict("witnesses"=>witnesses,"records"=>records))
        path = bgp_save("test_evidence_$(kind)_$(rand(UInt))",data;save_results=true)
        try
            restored = TOML.parsefile(path)
            @test restored["schema"] == "vbf-baudrin-202509-v2"
            @test restored["packing"] == "graph=(x<<n)|F(x), Walsh=(a<<n)|b"
            @test restored["conjecture_proved"] === false
            @test length(restored["witnesses"]) == length(witnesses)
            @test all(bgp_test_certificate, restored["witnesses"])
            @test restored["records"] == records
            @test restored["source_hashes"] == BGP_SOURCE_CAPTURE.hashes
            @test haskey(restored["source_hashes"],
                "packages/VBF/src/constructions/ea_class_orbits.jl")
            @test all(hash -> occursin(r"^[0-9a-f]{64}$",hash),
                values(restored["source_hashes"]))
            @test restored["source_hash_capture"] == "once_when_helpers_loaded"
            @test restored["paper_source"] == BGP_SOURCE_CAPTURE.paper
        finally
            rm(path)
        end
    end

    # Section 3.1 has its own output name; preserve any existing evidence when
    # checking the actual stage-by-stage serialized payload.
    stage_path = joinpath(@__DIR__, "..", "results", "section31.toml")
    previous = isfile(stage_path) ? read(stage_path) : nothing
    try
        stage = section31(save_results=true)
        saved = TOML.parsefile(stage.saved_path)
        @test saved["source_lut"] == Int.(gold_apn(4).lut)
        @test saved["dimension"] == 4
        @test saved["automorphisms_complete"] === true
        @test saved["subspaces_complete"] === true
        @test saved["actions_complete"] === true
        @test saved["representatives_complete"] === true
        @test saved["group_result_complete"] === true
        @test saved["bound_checked"] === true
        @test saved["orbit_count_bounds"] == Dict("lower"=>1,"upper"=>16,"observed"=>2)
    finally
        previous === nothing ? rm(stage_path;force=true) : write(stage_path,previous)
    end
end
