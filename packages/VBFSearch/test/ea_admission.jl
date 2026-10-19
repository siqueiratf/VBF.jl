module EAAdmissionTests
using Test,VBF,VBFSearch
const FP=VBFSearch
const DE=FP.DiscoveryEvidence

"""Only elapsed solver time is nondeterministic for these fixed, ample budgets."""
stable(proof)=Dict(k=>v for (k,v) in proof if k!="seconds")

function packet(f,g;targets=true,saved=false)
    p=FP.properties(f);q=FP.properties(g)
    rows=targets ? [Dict{String,Any}("parent_id"=>1,"candidate_id"=>q["lut_sha256"],
        "lut_hex"=>q["lut_hex"],"saved_exhaustive"=>saved)] : Dict{String,Any}[]
    result=Dict{String,Any}("schema"=>FP.CLOSURE_EQUIVALENCE_SCHEMA,"job_id"=>42,"job_key"=>"ea-admission-fixture",
        "candidate_id"=>p["lut_sha256"],"lut_hex"=>p["lut_hex"],"sigma"=>p["sigma_hash"],"targets"=>rows)
    result["packet_sha256"]=FP._closure_packet_digest(result);result
end

@testset "EA comparison reuses fresh properties with exact LUT binding" begin
    f=gold_apn(8).lut;g=f .⊻ UInt8(17)
    pf=FP.properties(f);pg=FP.properties(g);original=deepcopy(pf)
    reused=DE._compare_verified_properties(f,g,pf,pg;relation=:ea,timeout_seconds=5,max_nodes=100_000)
    public=FP.compare(f,g;relation=:ea,timeout_seconds=5,max_nodes=100_000)
    @test stable(reused)==stable(public)
    @test reused["status"]=="equivalent_with_verified_witness"
    @test FP.verify_comparison(reused)
    @test pf==original
    @test reused["solver_implementation_sha256"]==FP.equivalence_solver_fingerprint()
    @test_throws ErrorException DE._compare_verified_properties(g,f,pf,pg;relation=:ea)
    altered=deepcopy(pf);altered["lut_sha256"]=pg["lut_sha256"]
    @test_throws ErrorException DE._compare_verified_properties(f,g,altered,pg;relation=:ea)
    @test_throws MethodError FP.compare(f,g;properties=(pf,pg))
    unknown=DE._compare_verified_properties(f,g,pf,pg;relation=:ea,timeout_seconds=5,max_nodes=0)
    @test unknown["status"]=="inconclusive_budget"
    @test unknown["equivalent"]=="unresolved"
    @test !FP.verify_comparison(unknown)
    bad=zeros(UInt8,256);pb=FP.properties(bad)
    negative=DE._compare_verified_properties(f,bad,pf,pb;relation=:ea,timeout_seconds=5,max_nodes=100_000)
    @test negative["status"]=="inequivalent_by_exhaustive_solver"
    @test negative["equivalent"]===false
    @test negative["solver_implementation_sha256"]==FP.equivalence_solver_fingerprint()
end

@testset "EA admission preserves empty, saved-negative and budget outcomes" begin
    f=gold_apn(8).lut;g=f .⊻ UInt8(17);p=packet(g,f)
    resolved=FP._closure_equivalence_compute(p;seconds=5,nodes=100_000)
    @test resolved["complete"]
    @test length(resolved["comparisons"])==1
    @test FP.verify_comparison(only(resolved["comparisons"])["proof"])
    @test resolved["properties"]==FP.properties(g)
    zero_nodes=FP._closure_equivalence_compute(p;seconds=5,nodes=0)
    @test !zero_nodes["complete"] && isempty(zero_nodes["comparisons"])
    zero_time=FP._closure_equivalence_compute(p;seconds=0,nodes=100_000)
    @test !zero_time["complete"] && isempty(zero_time["comparisons"])
    empty=FP._closure_equivalence_compute(packet(g,f;targets=false);seconds=0,nodes=0)
    @test empty["complete"] && isempty(empty["comparisons"])
    saved=FP._closure_equivalence_compute(packet(g,f;saved=true);seconds=0,nodes=0)
    @test saved["complete"] && isempty(saved["comparisons"])
    invalid=deepcopy(p);invalid["targets"][1]["lut_hex"]=bytes2hex(g)
    invalid["packet_sha256"]=FP._closure_packet_digest(invalid)
    @test_throws ErrorException FP._closure_equivalence_compute(invalid;seconds=5,nodes=100_000)
    invalid=deepcopy(p);invalid["sigma"]="wrong"
    invalid["packet_sha256"]=FP._closure_packet_digest(invalid)
    @test_throws ErrorException FP._closure_equivalence_compute(invalid;seconds=5,nodes=100_000)
    invalid=deepcopy(p);invalid["lut_hex"]=bytes2hex(f)
    invalid["packet_sha256"]=FP._closure_packet_digest(invalid)
    @test_throws ErrorException FP._closure_equivalence_compute(invalid;seconds=5,nodes=100_000)
    invalid=deepcopy(p);invalid["job_id"]+=1
    @test_throws ErrorException FP._closure_equivalence_compute(invalid;seconds=5,nodes=100_000)
end

@testset "EA packets reuse only latest negatives from the current solver" begin
    db=FP.SQLite.DB();store=(db=db,)
    try
        FP._closure_create_schema(db)
        f=gold_apn(8).lut
        candidate=FP.properties(f .⊻ UInt8(17))
        targets=[FP.properties(f),FP.properties(f .⊻ UInt8(18))]
        FP._closure_insert_candidate!(store,candidate)
        for p in targets
            FP._closure_insert_candidate!(store,p)
            FP._closure_add_parent!(store,p["lut_sha256"],p["sigma_hash"])
        end
        job=Dict{String,Any}("id"=>42,"job_key"=>"negative-cache-fixture",
            "payload"=>FP._closure_text(Dict("candidate_id"=>candidate["lut_sha256"])))
        flags()=[t["saved_exhaustive"] for t in FP._closure_equivalence_packet(store,job)["targets"]]
        record(status,evidence;target=1)=FP._closure_exec(db,
            "INSERT INTO comparisons(candidate_id,target_parent,status,evidence,session_id) VALUES(?,?,?,?,?)",
            (candidate["lut_sha256"],target,status,evidence,0))
        negative="inequivalent_by_exhaustive_solver"
        digest=FP.equivalence_solver_fingerprint()
        # Synthetic rows exercise reuse policy only; none is applied as an
        # admission or claimed as a genuine mathematical negative certificate.
        proof=Dict("status"=>negative,"solver_implementation_sha256"=>digest)
        @test flags()==[false,false]
        record(negative,FP._closure_text(proof))
        @test flags()==[true,false]
        stale=copy(proof);stale["solver_implementation_sha256"]=repeat("0",64)
        record(negative,FP._closure_text(stale))
        @test flags()==[false,false]
        record(negative,FP._closure_text(Dict("status"=>negative)))
        @test flags()==[false,false]
        record(negative,"[unclosed")
        @test flags()==[false,false]
        wrong_type=Dict{String,Any}("status"=>negative,"solver_implementation_sha256"=>17)
        record(negative,FP._closure_text(wrong_type))
        @test flags()==[false,false]
        record(negative,FP._closure_text(Dict("solver_implementation_sha256"=>digest)))
        @test flags()==[false,false]
        changed=copy(proof);changed["status"]="inconclusive_budget"
        record(negative,FP._closure_text(changed))
        @test flags()==[false,false]
        record(negative,FP._closure_text(proof))
        @test flags()==[true,false]
        record("inconclusive_budget",FP._closure_text(proof))
        @test flags()==[false,false]
        record("equivalent_with_verified_witness",FP._closure_text(proof))
        @test flags()==[false,false]
        record(negative,FP._closure_text(proof))
        record(negative,FP._closure_text(proof);target=2)
        rows_before=FP._closure_rows(db,"SELECT * FROM comparisons ORDER BY id")
        @test flags()==[true,true]
        @test FP._closure_rows(db,"SELECT * FROM comparisons ORDER BY id")==rows_before
        other=FP.properties(gold_apn(8,3).lut)
        @test other["sigma_hash"]!=candidate["sigma_hash"]
        FP._closure_insert_candidate!(store,other)
        empty=copy(job);empty["payload"]=FP._closure_text(Dict("candidate_id"=>other["lut_sha256"]))
        @test isempty(FP._closure_equivalence_packet(store,empty)["targets"])
    finally
        close(db)
    end
end
end
