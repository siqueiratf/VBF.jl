module EAAdmissionTests
using Test,VBF,VBFSearch
const FP=VBFSearch
const DE=FP.DiscoveryEvidence

@testset "Queued candidate IDs preserve ordinary TOML semantics" begin
    id=repeat("0123456789abcdef",4)
    canonical=FP._closure_deduplication_payload(id)
    payloads=(canonical,SubString("!"*canonical,2),
        "candidate_id='"*id*"'", "candidate_id=\""*id*"\" # comment\n",
        "candidate_id = \""*uppercase(id)*"\"\n", "candidate_id = \""*id*"\"\nextra = 1\n",
        "candidate_id = \"escaped\\nvalue\"\n", "candidate_id = \"λ\"\n",
        "candidate_id = 12\n", "candidate_id = true\n")
    for payload in payloads
        @test FP._closure_equivalence_candidate_id(payload)==FP.TOML.parse(payload)["candidate_id"]
    end
    @test FP._closure_equivalence_candidate_id(canonical) isa String
    @test_throws KeyError FP._closure_equivalence_candidate_id("another_id = 1\n")
    for payload in ("candidate_id = \"unterminated", "candidate_id = \""*id*"\"\ncandidate_id = 1\n")
        @test_throws FP.TOML.ParserError FP._closure_equivalence_candidate_id(payload)
    end
end

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
    context=FP.ClosureWorkContext();session=FP._equivalence_solver_session()
    stable_admission(proof)=Dict(k=>v for (k,v) in proof if k ∉ ("seconds","timeout_seconds"))
    for _ in 1:2
        reused=FP._closure_equivalence_compute(p;seconds=5,nodes=100_000,context,solver_session=session)
        @test stable_admission(only(reused["comparisons"])["proof"])==stable_admission(only(resolved["comparisons"])["proof"])
    end
    @test context.property_cache.hits>=2
    bad=deepcopy(p);bad["sigma"]="wrong";bad["packet_sha256"]=FP._closure_packet_digest(bad)
    @test_throws ErrorException FP._closure_equivalence_compute(bad;seconds=5,nodes=100_000,context,solver_session=session)
    @test fetch(@async begin
        acquired=trylock(context.guard)
        acquired && unlock(context.guard)
        acquired
    end)
    lock(context.guard) do
        @test_throws TaskFailedException fetch(@async FP._closure_equivalence_compute(p;seconds=5,nodes=100_000,context,solver_session=session))
    end
end

@testset "Native EA packets bind immutable contents and preserve mutable transport checks" begin
    f=gold_apn(8).lut;g=f .⊻ UInt8(17)
    original=packet(g,f);expected=deepcopy(original)
    native=FP._ClosureEquivalencePacket(original)
    @test native isa AbstractDict && copy(native)==expected
    @test FP._closure_packet_digest(native)==FP._closure_packet_digest(expected)==expected["packet_sha256"]
    original["targets"][1]["lut_hex"]="changed caller target"
    native["targets"][1]["candidate_id"]="changed getter target"
    iterated=Dict(native);iterated["targets"][1]["candidate_id"]="changed iteration target"
    @test copy(native)==expected
    @test FP._closure_packet_digest(native)==expected["packet_sha256"]
    immutable_graph(value)=value isa String || (isimmutable(value) && all(
        immutable_graph(getfield(value,index)) for index in 1:fieldcount(typeof(value))))
    @test all(immutable_graph(getfield(native,key)) for key in propertynames(native))
    @test_throws Exception (native["job_id"]=999)
    @test_throws MethodError FP._ClosureEquivalencePacket(native.fields,native.digest)
    without_digest=deepcopy(expected);delete!(without_digest,"packet_sha256")
    @test copy(FP._ClosureEquivalencePacket(without_digest))==expected
    wrong=deepcopy(expected);wrong["packet_sha256"]=repeat("0",64)
    @test_throws ErrorException FP._ClosureEquivalencePacket(wrong)
    wrong=deepcopy(expected);wrong["schema"]="unsupported"
    @test_throws ErrorException FP._ClosureEquivalencePacket(wrong)
    wire=FP.JSON3.read(FP.JSON3.write(native),Dict{String,Any})
    @test wire isa Dict && !(wire isa FP._ClosureEquivalencePacket)
    @test wire==expected && Set(keys(wire))==Set(keys(expected))
    @test FP._closure_packet_digest(wire)==native.digest
    copied=copy(native);copied["job_id"]+=1
    @test FP._closure_packet_digest(copied)!=native.digest
    @test_throws ErrorException FP._closure_equivalence_compute(copied;seconds=5,nodes=100_000)
    wire["targets"][1]["lut_hex"]=bytes2hex(g)
    @test_throws ErrorException FP._closure_equivalence_compute(wire;seconds=5,nodes=100_000)
    wire["packet_sha256"]=FP._closure_packet_digest(wire)
    @test_throws ErrorException FP._closure_equivalence_compute(wire;seconds=5,nodes=100_000)
    stable_result(result)=(result["complete"],result["properties"],
        [(comparison["target_parent"],Dict(k=>v for (k,v) in comparison["proof"] if k ∉ ("seconds","timeout_seconds"))) for comparison in result["comparisons"]])
    for descriptor in (expected,packet(g,f;targets=false),packet(g,f;saved=true)),
            (seconds,nodes) in ((0.0,0),(5.0,0),(0.0,100_000),(5.0,100_000))
        immutable=FP._ClosureEquivalencePacket(descriptor)
        mutable_result=FP._closure_equivalence_compute(descriptor;seconds,nodes)
        native_result=FP._closure_equivalence_compute(immutable;seconds,nodes)
        @test stable_result(native_result)==stable_result(mutable_result)
    end
end

@testset "Native, mutable and JSON EA admission preserve stored science and reject tampering" begin
    f=gold_apn(8).lut;p=FP.properties(f);candidate=FP.properties(f .⊻ UInt8(17))
    for normalized in (false,true)
        stores=Any[];leases=String[]
        try
            for _ in 1:3
                db=FP.SQLite.DB();FP._closure_create_schema(db;normalized)
                lease_path=tempname();lease=open(lease_path,"w");push!(leases,lease_path)
                store=FP.ClosureStore(db,"",lease,Dict{String,Any}(),1,UInt64(0));push!(stores,store)
                FP._closure_insert_candidate!(store,p)
                parent=FP._closure_add_parent!(store,p["lut_sha256"],p["sigma_hash"])
                FP._closure_insert_candidate!(store,candidate)
                FP._closure_add_job!(store,parent,"deduplicate","deduplicate:"*candidate["lut_sha256"],Dict("candidate_id"=>candidate["lut_sha256"]))
            end
            job=only(FP._closure_rows(first(stores),"SELECT * FROM jobs WHERE kind='deduplicate'"))
            mutable_packet=FP._closure_equivalence_packet(first(stores),job)
            native_packet=FP._closure_equivalence_packet(stores[2],job;native=true)
            @test mutable_packet isa Dict && native_packet isa FP._ClosureEquivalencePacket
            @test mutable_packet==copy(native_packet)
            @test_throws ArgumentError FP._closure_equivalence_packet(first(stores),job;native="true")
            value=FP._closure_equivalence_compute(mutable_packet;seconds=5,nodes=100_000)
            @test FP.verify_comparison(only(value["comparisons"])["proof"])
            wire_packet=FP.JSON3.read(FP.JSON3.write(native_packet),Dict{String,Any})
            wire_value=FP.JSON3.read(FP.JSON3.write(value),Dict{String,Any})
            snapshots=Any[]
            science(store)=(FP._closure_rows(store,"SELECT id,class_id,state FROM candidates ORDER BY id"),
                FP._closure_rows(store,"SELECT job_key,status,result FROM jobs WHERE kind='deduplicate'"),
                FP._closure_rows(store,"SELECT candidate_id,target_parent,status,evidence FROM comparisons ORDER BY id"))
            before=science(first(stores))
            changed=copy(native_packet);changed["targets"][1]["parent_id"]+=100
            @test_throws ErrorException FP._closure_equivalence_apply!(first(stores),job,changed,value)
            @test isequal(science(first(stores)),before)
            forged=deepcopy(wire_packet);forged["targets"][1]["parent_id"]+=100
            forged["packet_sha256"]=FP._closure_packet_digest(forged)
            forged_value=FP._closure_equivalence_compute(forged;seconds=5,nodes=100_000)
            @test_throws Exception FP._closure_equivalence_apply!(first(stores),job,FP._ClosureEquivalencePacket(forged),forged_value)
            @test isequal(science(first(stores)),before)
            for (store,descriptor,result) in zip(stores,(mutable_packet,native_packet,wire_packet),(value,value,wire_value))
                @test FP._closure_equivalence_apply!(store,job,descriptor,result)==:done
                push!(snapshots,science(store))
            end
            @test isequal(snapshots[1],snapshots[2]) && isequal(snapshots[1],snapshots[3])
        finally
            for store in stores
                FP.DiscoveryStore.close_statements!(store.statements);close(store.db);close(store.lease)
            end
            foreach(path->rm(path;force=true),leases)
        end
    end
end

@testset "EA packets reuse only latest negatives from the current solver" begin
    for normalized in (false,true)
    db=FP.SQLite.DB();store=(db=db,)
    try
        FP._closure_create_schema(db;normalized)
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
end
