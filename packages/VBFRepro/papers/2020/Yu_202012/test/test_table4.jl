@testset "table4_test" begin
    include(joinpath(@__DIR__, "..", "table4.jl"))
    result = table4_verify()
    @test result.literature_novelty == :unresolved
    for (desc, ok) in result.checks
        @test ok
    end
    @test result.gold_coverage["complete"]
    @test result.gold_coverage["expected_indices"]==[1,2,4,5,7,8]
    @test length(result.reference_functions)==result.n_quadratic_catalog+result.n_nonquadratic_catalog
    @test length(result.catalog_sha256)==64
    for candidate in result.candidate_evidence
        @test !candidate["power_exclusion"]["literature_novelty_verified"]
        @test length(candidate["target_checks"])==length(result.reference_functions)
        candidate["label"] in ("s₁","s₂") || continue
        @test candidate["power_exclusion"]["all_apn_power_functions_excluded"]
        @test candidate["finite_catalog_separation_proved"]
        @test all(startswith(r["status"],"ccz_inequivalent_") for r in candidate["target_checks"])
        @test length(candidate["power_exclusion"]["gold_checks"])==6
    end
    @test first(result.candidate_evidence)["power_exclusion"]["status"]=="gold_invariant_match_unresolved"
    @test result.finite_catalog_separation_proved
    # A later catalog may contain an equal invariant. Report text must not turn
    # a failed comparison into a separation guarantee.
    collided=deepcopy(result.candidate_evidence)
    targets=first(filter(c->c["label"]=="s₁",collided))["target_checks"]
    first(filter(r->r["reference_degree"]==2,targets))["status"]="invariant_match_equivalence_unresolved"
    note=table4_scope_note(collided,result.n_quadratic_catalog,result.n_nonquadratic_catalog,true)
    @test occursin("Separation of s₁/s₂ from every current curated quadratic n9 reference remains unresolved",note)
    @test !occursin("s₁/s₂ are separated by exact signatures",note)
    missing=table4_verify(gold_indices_to_check=[1])
    @test occursin("Gold coverage or power exclusion is incomplete",missing.note)
    @test !missing.finite_catalog_separation_proved
    for candidate in missing.candidate_evidence
        candidate["label"] in ("s₁","s₂") || continue
        @test !candidate["power_exclusion"]["all_apn_power_functions_excluded"]
        @test !candidate["finite_catalog_separation_proved"]
        @test any(r["status"]=="inconclusive_power_coverage" for r in candidate["target_checks"])
    end
end
