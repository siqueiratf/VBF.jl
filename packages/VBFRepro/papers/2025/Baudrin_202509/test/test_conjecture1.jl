# Implements bounded Conjecture 1 exploration test cases.
# Paper: Baudrin, Galissant and Perrin (2025), "Exploring the Set of APN Functions", BFA 2025
# Section: 3.2 — Conjecture 1
#
# Pseudocode:
#   1. Check explicit limits, undecided comparisons and saved witness round trips.
# VBF API used: switching_neighbors, ccz_equivalent_function
@testset "conjecture1_test" begin
    include(joinpath(@__DIR__, "..", "conjecture1.jl"))
    skipped = conjecture1(limit=0)
    @test skipped.expanded == 0
    @test !skipped.exhaustive
    @test !skipped.conjecture_proved
    @test skipped.stop_reason === :roots
    capped = conjecture1(max_evaluations=0)
    @test capped.evaluations == 0
    @test capped.expanded == 0
    @test !capped.exhaustive
    @test capped.stop_reason === :evaluations
    result = conjecture1(max_neighbors=2)
    @test result.expanded == 1
    @test result.evaluations == 2
    @test length(result.records) == 2
    @test !result.exhaustive
    @test !result.conjecture_proved
    @test result.relative_new_ccz_seeds == 0
    for record in result.records
        @test differential_uniformity(SBox{4}(record["candidate_lut"])) == 2
        source = SBox{4}(record["parent_lut"])
        target = SBox{4}(record["candidate_lut"])
        direction = record["switching_direction"]
        support = Set(record["switching_support"])
        @test all(x -> target.lut[x+1] == (source.lut[x+1] ⊻ (x in support ? direction : 0)),0:15)
    end
    for witness in result.witnesses
        source = SBox{4}(witness["source_lut"])
        target = SBox{4}(witness["target_lut"])
        map = F2AffineMap{8,UInt32}(witness["linear_columns"],witness["constant"])
        @test bgp_verify_graph_map(source,target,map;relation=Symbol(witness["relation"]))
    end
    undecided = conjecture1(max_neighbors=1,max_comparisons=1)
    @test undecided.relative_new_ccz_seeds == 0
    @test !isempty(undecided.inconclusive)
    @test any(record -> record["status"] == "undecided_ea",undecided.inconclusive)
    @test !undecided.exhaustive
    state = (;comparisons=Ref(0),max_comparisons=10,
        remaining_time=()->10.0,remaining_nodes=Ref(0),
        max_memory_bytes=512 * 1024^2,rng=Xoshiro(940))
    match = bgp_match(gold_apn(4),[gold_apn(4)],:ccz,state)
    @test match.status === :undecided
    @test match.certificate === nothing
    @test only(match.checks)["outcome"] == "budget_hit"
end
