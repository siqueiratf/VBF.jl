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
