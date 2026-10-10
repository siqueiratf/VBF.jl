# Lightweight finite-property and independently replayed certificate regressions.
# Run: julia --project=. packages/VBFRepro/analysis/test/test_catalog_proposals.jl
using Test, TOML
include(joinpath(@__DIR__,"..","scripts","review_catalog_proposals.jl"))

@testset "F063 original proposal inventory and positive certificates" begin
    candidates=catalog_proposal_candidates()
    @test length(candidates)==32
    @test length(unique(c.name for c in candidates))==32
    @test length(unique(c.paper for c in candidates))==9
    boxes=Dict(c.name=>c.F for c in candidates)
    for c in candidates
        @test differential_uniformity(c.F)==2
        @test algebraic_degree(c.F)==2
    end
    # Pin the source's actual exceptional representative; primitive alone is insufficient.
    z=2
    invalid=ProposalZ22.zheng_lut(5,2,z,1,z;modulus=1033) .⊻
        ProposalZ22.zheng_lut(5,7,z,0,gf_pow(z,369,10;modulus=1033);modulus=1033)
    @test gf_multiplicative_order(z,10;modulus=1033)==1023
    @test differential_uniformity(SBox{10}(invalid))==4
    @test Int.(boxes["Zheng2022_Example1"].lut[1:16])==[0,77,393,409,583,907,698,811,490,617,585,407,157,671,586,21]
    @test Int.(boxes["BHK2020_C3"].lut[1:16])==[0,1,955,465,198,666,994,981,525,322,856,636,362,120,160,985]
    @test Int.(boxes["BHK2020_C7"].lut[1:16])==[0,1,170,465,450,666,522,40,451,153,420,388,933,422,160,985]
    db=load_catalog()
    try
        boxes["reprs6_1"]=load_sbox(db,"reprs6_1")
        boxes["beierleleander2022_n8:12658"]=corpus_function(db,"beierleleander2022_n8",12658)
    finally
        VBFCatalog.SQLite.close(db)
    end
    for n in (10,11)
        modulus=n==10 ? 1135 : 2053
        boxes["Budaghyan2009_x3_Trx9_n$n"]=SBox{n}([gf_pow(x,3,n;modulus) ⊻
            gf_trace(gf_pow(x,9,n;modulus),n;modulus) for x in 0:(1<<n)-1])
    end
    proofs=TOML.parsefile(joinpath(@__DIR__,"fixtures","catalog_proposal_witnesses.toml"))["witnesses"]
    @test length(proofs)==9
    for row in proofs
        F=boxes[row["candidate"]];G=boxes[row["reference"]]
        A=F2AffineMap(F2LinearMap(row["columns"]),row["constant"])
        @test replay_proposal_ea(F,G,A)
        @test sigma_key(F)==sigma_key(G)
        @test !replay_proposal_ea(F,G,F2AffineMap(A.linear,Int(A.constant)⊻1))
        forged=copy(row["columns"]);forged[1]=0
        @test !replay_proposal_ea(F,G,F2AffineMap(F2LinearMap(forged),row["constant"]))
    end
    @test proposal_pair_evidence(boxes["Yu2025_trace_n11"],boxes["Budaghyan2009_x3_Trx9_n11"];timeout_seconds=0)["status"]=="identical_lut"
    @test proposal_pair_evidence(boxes["Li2024_F1_n9"],boxes["Beierle2022_perm1"];timeout_seconds=0,max_nodes=0)["status"]=="inconclusive_budget"
    @test_throws ArgumentError review_catalog_proposals(timeout_seconds=-1,io=devnull)
    @test proposal_disposition(Dict[],Dict[],0)=="no_quadratic_references_available"
    @test proposal_disposition(Dict[],Dict[],1)=="separated_from_enumerated_quadratic_references"
    @test proposal_disposition([Dict("status"=>"inconclusive_budget","scope"=>"catalog_functions_table")],Dict[],1)=="invariant_match_equivalence_unresolved"
    @test proposal_disposition(Dict[],[Dict("status"=>"ea_equivalent_witness_replayed")],1)=="represented_by_another_proposal"
end

@testset "F040/F063 complete Gold theorem evidence fails closed" begin
    domains=Dict(6=>[1,5],8=>[1,3,5,7],9=>[1,2,4,5,7,8],
        10=>[1,3,7,9],11=>collect(1:10),12=>[1,5,7,11])
    for (n,expected) in domains
        @test gold_indices(n)==expected
    end
    F=kim_apn();coverage=build_gold_coverage(6)
    evidence=gold_power_evidence(F,coverage)
    @test evidence["all_apn_power_functions_excluded"]
    @test evidence["gold_reference_integrity_verified"]
    @test evidence["status"]=="ccz_inequivalent_to_every_apn_power_function"
    @test !evidence["literature_novelty_verified"]
    @test gold_power_evidence(gold_apn(6,1),coverage)["status"]=="gold_invariant_match_unresolved"
    missing=build_gold_coverage(6;indices=[1])
    @test !gold_power_evidence(F,missing)["all_apn_power_functions_excluded"]
    @test gold_power_evidence(F,merge(missing,(;complete=true)))["status"]=="incomplete_gold_coverage"
    @test !build_gold_coverage(6;max_evaluations=0).complete
    @test !build_gold_coverage(6;timeout_seconds=0).complete
    @test_throws ArgumentError build_gold_coverage(6;indices=[1,1])
    @test_throws ArgumentError build_gold_coverage(6;indices=[2])
    @test_throws ArgumentError build_gold_coverage(6;max_evaluations=-1)
    @test gold_power_evidence(dillon_apn_permutation(),coverage)["status"]=="theorem_hypotheses_not_met"
    @test gold_power_evidence(SBox{6}(collect(0:63)),coverage)["status"]=="theorem_hypotheses_not_met"
    @test gold_power_evidence(SBox{2}([0,1,2,3]),coverage)["status"]=="theorem_hypotheses_not_met"
    @test gold_power_evidence(gold_apn(5,1),coverage)["status"]=="coverage_dimension_mismatch"
    for corruption in (:lut,:sigma,:exponent,:hash)
        broken=deepcopy(coverage);record=broken.records[1]
        if corruption==:lut
            record.F.lut[1] ⊻= 1
        elseif corruption==:sigma
            broken.records[1]=merge(record,(;sigma=((),())))
        elseif corruption==:exponent
            broken.records[1]=merge(record,(;exponent=record.exponent+1))
        else
            broken.records[1]=merge(record,(;sha256_uint16_le="forged"))
        end
        invalid=gold_power_evidence(F,broken)
        @test invalid["status"]=="invalid_gold_reference_evidence"
        @test !invalid["all_apn_power_functions_excluded"]
        @test !invalid["gold_coverage_complete"]
    end
    # A self-consistent hash of a changed LUT still must match the Gold formula.
    changed=deepcopy(coverage);record=changed.records[1]
    record.F.lut .⊻= 1
    changed.records[1]=merge(record,(;sha256_uint16_le=power_lut_sha(record.F),sigma=sigma_key(record.F)))
    @test gold_power_evidence(F,changed)["status"]=="invalid_gold_reference_evidence"
    n12=build_gold_coverage(12)
    @test n12.complete
    @test [r.k for r in n12.records]==[1,5,7,11]
    @test all(r->r.du==2 && r.degree==2,n12.records)

    controls=known_power_controls(6)
    @test power_target_identity(gold_apn(6,1),controls)["status"]=="literal_known_power_map"
    @test power_target_identity(dillon_apn_permutation(),controls)["status"]=="not_identified_as_power"
    literal=gold_apn(6,1)
    for corruption in (:lut,:hash,:exponent,:modulus)
        record=deepcopy(first(controls))
        broken=if corruption==:lut
            record.F.lut[1] ⊻= 1;record
        elseif corruption==:hash
            merge(record,(;sha256_uint16_le="forged"))
        elseif corruption==:exponent
            merge(record,(;exponent=5))
        else
            merge(record,(;modulus=record.modulus⊻1))
        end
        @test power_target_identity(literal,[broken])["status"]=="not_identified_as_power"
    end
    forged=merge(first(controls),(;F=dillon_apn_permutation(),sha256_uint16_le=power_lut_sha(dillon_apn_permutation())))
    @test power_target_identity(dillon_apn_permutation(),[forged])["status"]=="not_identified_as_power"
    @test power_exclusion_applies(F,evidence)
    @test !power_exclusion_applies(literal,evidence)
    @test !power_exclusion_applies(F,merge(evidence,Dict("n"=>8)))
    @test !power_exclusion_applies(F,merge(evidence,Dict("gold_reference_integrity_verified"=>false)))
    # Higher degree alone cannot separate this known CCZ pair. With no general
    # solver budget its equal Walsh invariant must yield an unresolved outcome.
    D=dillon_apn_permutation()
    @test sorted_pairs(absolute_walsh_spectrum(F))==sorted_pairs(absolute_walsh_spectrum(D))
    reference=(;name="Dillon6",F=D,degree=4,scope="control",sigma=nothing)
    outcome=finite_target_evidence(F,reference,evidence,controls,sigma_key(F),Dict[];
        timeout_seconds=0,max_nodes=0)
    @test outcome["status"]=="inconclusive_budget"
    @test finite_target_evidence(F,reference,evidence,[forged],sigma_key(F),Dict[];
        timeout_seconds=0,max_nodes=0)["status"]=="inconclusive_budget"
    @test finite_catalog_disposition([outcome])=="comparison_incomplete"
    @test finite_catalog_disposition(Dict[])=="no_catalog_references_available"
    @test finite_catalog_disposition([Dict("status"=>"identical_lut")])=="represented_in_current_catalog"
    @test archived_n8_proposal_evidence(gold_apn(8,1),joinpath(@__DIR__,"absent-reference"))["status"]=="unavailable"
end
