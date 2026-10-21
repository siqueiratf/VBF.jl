using Test,VBF,VBFSearch,SQLite,TOML
const V5ApplyVS=VBFSearch

@testset "Native construction encodings are immutable and exact across transport" begin
    p=V5ApplyVS.properties(gold_apn(8).lut)
    witness=Dict{String,Any}("V5_forms"=>collect(1:5),"eligible_coset_index"=>17,
        "coset_representative"=>43,"need"=>2,"output_forms"=>collect(1:8),"target_b6"=>52)
    for (T,original) in ((V5ApplyVS._ClosurePreparedCandidate,p),(V5ApplyVS._ClosurePreparedWitness,witness))
        expected=deepcopy(original);prepared=V5ApplyVS._closure_prepare_construction(T,original)
        @test prepared isa T
        @test prepared==expected && copy(prepared)==expected
        @test prepared==prepared
        @test prepared==T(expected)
        @test V5ApplyVS._closure_text(prepared)==V5ApplyVS._closure_text(expected)
        immutable_graph(value)=value isa String || (isimmutable(value) && all(
            immutable_graph(getfield(value,index)) for index in 1:fieldcount(typeof(value))))
        @test immutable_graph(prepared)
        if prepared isa V5ApplyVS._ClosurePreparedCandidate
            original["ddt_histogram"][1]["count"]=-1
            prepared["ddt_histogram"][1]["count"]=-2
            @test V5ApplyVS._closure_candidate_storage(prepared)==V5ApplyVS._closure_candidate_storage(expected)
        else
            original["output_forms"][1]=-1;prepared["output_forms"][1]=-2
        end
        @test prepared==expected
        @test_throws MethodError setindex!(prepared,"changed","opaque")
        @test_throws MethodError T((getfield(prepared,index) for index in 1:fieldcount(T))...)
        wire=V5ApplyVS.JSON3.read(V5ApplyVS.JSON3.write(prepared),Dict{String,Any})
        @test wire==expected && !(wire isa V5ApplyVS._ClosurePreparedConstructionMap)
        future=copy(expected);future["future"]=Ref(1)
        @test V5ApplyVS._closure_prepare_construction(T,future)===future
        nonreflexive=copy(expected);nonreflexive["future_nan"]=NaN
        native_nan=T(nonreflexive)
        @test (native_nan==native_nan)==(nonreflexive==nonreflexive)==false
    end
    for id in (repeat("a",64),repeat("0123456789abcdef",4),repeat("0",64),"future",repeat("A",64),
            "quoted \" ID", "new\nline", "NUL\0ID", SubString(repeat("a",64)))
        @test V5ApplyVS._closure_deduplication_payload(id)==V5ApplyVS._closure_text(Dict("candidate_id"=>id))
    end
end

@testset "Native V5 validation owns immutable records and exact packet scope" begin
    p=V5ApplyVS.properties(gold_apn(8).lut)
    for (field,value) in (("lut_sha256",repeat("0",64)),("quadratic",false),("apn",false),
            ("algebraic_degree",3),("differential_uniformity",4),("lut_hex",repeat("00",255)))
        bad=copy(p);bad[field]=value
        @test_throws Exception V5ApplyVS._ClosurePreparedCandidate(bad)
    end
    packet=Dict{String,Any}("schema"=>V5ApplyVS.CLOSURE_WORK_SCHEMA,"kind"=>"v5",
        "payload"=>Dict("forms"=>collect(1:5),"need"=>0),"target_b6"=>52)
    packet["packet_sha256"]=V5ApplyVS._closure_packet_digest(packet)
    scope=V5ApplyVS._ClosureV5ValidationScope(packet)
    witness=Dict{String,Any}("V5_forms"=>collect(1:5),"eligible_coset_index"=>1,
        "coset_representative"=>17,"need"=>0,"output_forms"=>collect(1:8),"target_b6"=>52)
    record=Dict{String,Any}("properties"=>V5ApplyVS._ClosurePreparedCandidate(p),"cursor"=>"1",
        "witness"=>V5ApplyVS._ClosurePreparedWitness(witness))
    proof=V5ApplyVS._ClosureCosetProof((1,2,3,4,5),1,2,3,1,7,0,11,17,false)
    raw=V5ApplyVS._ClosureCosetChunk(proof,[record])
    prepared=V5ApplyVS._closure_prepare_v5_chunk(raw,scope)
    @test prepared isa V5ApplyVS._ClosurePreparedV5Chunk
    @test prepared==raw
    wire=V5ApplyVS.JSON3.read(V5ApplyVS.JSON3.write(prepared),Dict{String,Any})
    @test wire==raw && !(wire isa V5ApplyVS._ClosurePreparedV5Chunk)
    immutable_graph(value)=value isa String || (isimmutable(value) && all(
        immutable_graph(getfield(value,index)) for index in 1:fieldcount(typeof(value))))
    @test immutable_graph(prepared)
    record["cursor"]="999";packet["payload"]["forms"][1]=999
    @test only(prepared.records).cursor=="1"
    @test prepared.scope.forms==(1,2,3,4,5)
    @test_throws MethodError push!(prepared.records,record)
    @test_throws MethodError setindex!(only(prepared.records),"999","cursor")
    @test_throws MethodError V5ApplyVS._ClosurePreparedV5Chunk(proof,prepared.records,scope)
    @test_throws MethodError V5ApplyVS._ClosureV5ValidationScope(scope.packet_sha256,scope.forms,scope.need,scope.target_b6)
    record["cursor"]="1";packet["payload"]["forms"][1]=1
    native_flat=Any[];wire_flat=Any[]
    native_summary=V5ApplyVS._closure_apply_v5_cosets!(nothing,nothing,packet,copy(proof),[prepared],1,native_flat)
    wire_summary=V5ApplyVS._closure_apply_v5_cosets!(nothing,nothing,packet,copy(proof),[wire],1,wire_flat)
    @test native_summary==wire_summary
    @test native_flat==wire_flat
    proof_fields=((1,2,3,4,5),1,2,3,1,7,0,11,17,false)
    for (index,value) in ((1,(2,3,4,5,6)),(2,0),(3,3),(4,0),(5,2),(6,-1),(7,2),(8,-1),(9,0),(9,1<<28))
        arguments=Any[proof_fields...];arguments[index]=value
        badproof=V5ApplyVS._ClosureCosetProof(arguments...)
        @test_throws ErrorException V5ApplyVS._ClosurePreparedV5Chunk(V5ApplyVS._ClosureCosetChunk(badproof,[record]),scope)
        badwire=deepcopy(wire);badwire["proof"]=copy(badproof);badwire["native_validated"]=true
        @test_throws ErrorException V5ApplyVS._closure_apply_v5_cosets!(nothing,nothing,packet,copy(proof),[badwire],1,Any[])
    end
    for (apn,degree,uniformity) in ((false,2,4),(true,3,2))
        invalid=copy(p);invalid["apn"]=apn;invalid["algebraic_degree"]=degree
        invalid["quadratic"]=degree==2;invalid["differential_uniformity"]=uniformity
        invalid_record=copy(record);invalid_record["properties"]=V5ApplyVS._ClosurePreparedCandidate(invalid)
        @test_throws ErrorException V5ApplyVS._ClosurePreparedV5Chunk(V5ApplyVS._ClosureCosetChunk(proof,[invalid_record]),scope)
    end
    bad_cursor=copy(record);bad_cursor["cursor"]="2"
    @test_throws ErrorException V5ApplyVS._ClosurePreparedV5Chunk(V5ApplyVS._ClosureCosetChunk(proof,[bad_cursor]),scope)
    for (field,value) in (("eligible_coset_index",2),("coset_representative",18),("V5_forms",[2,3,4,5,6]),
            ("need",1),("target_b6",53),("output_forms",[1,2]))
        bad=deepcopy(witness);bad[field]=value
        badrecord=copy(record);badrecord["witness"]=V5ApplyVS._ClosurePreparedWitness(bad)
        @test_throws ErrorException V5ApplyVS._ClosurePreparedV5Chunk(V5ApplyVS._ClosureCosetChunk(proof,[badrecord]),scope)
        corrupted=deepcopy(wire);corrupted["records"][1]["witness"][field]=value
        @test_throws ErrorException V5ApplyVS._closure_apply_v5_cosets!(nothing,nothing,packet,copy(proof),[corrupted],1,Any[])
    end
    other=copy(packet);other["future_scope"]="changed";other["packet_sha256"]=V5ApplyVS._closure_packet_digest(other)
    mismatch=V5ApplyVS._ClosurePreparedV5Chunk(raw,V5ApplyVS._ClosureV5ValidationScope(other))
    @test_throws ErrorException V5ApplyVS._closure_apply_v5_cosets!(nothing,nothing,packet,copy(proof),[mismatch],1,Any[])
    broken=copy(packet);broken["packet_sha256"]=repeat("0",64)
    @test_throws ErrorException V5ApplyVS._ClosureV5ValidationScope(broken)
    plainrecord=Dict{String,Any}("properties"=>p,"cursor"=>"1","witness"=>witness)
    fallback=V5ApplyVS._ClosureCosetChunk(proof,[plainrecord])
    @test V5ApplyVS._closure_prepare_v5_chunk(fallback,scope)===fallback
end

@testset "Batched V5 paths retain serial SQL state and transaction rollback" begin
    for normalized in (false,true)
        stores=Any[]
        try
            for _ in 1:2
                db=SQLite.DB();V5ApplyVS._closure_create_schema(db;normalized)
                lease=open(tempname(),"w")
                s=V5ApplyVS.ClosureStore(db,"",lease,Dict{String,Any}(),1,UInt64(0));push!(stores,s)
                V5ApplyVS._closure_exec(s,"PRAGMA foreign_keys=ON")
                p=V5ApplyVS.properties(gold_apn(8).lut)
                V5ApplyVS._closure_insert_candidate!(s,p)
                parent=V5ApplyVS._closure_add_parent!(s,p["lut_sha256"],p["sigma_hash"])
                V5ApplyVS._closure_exec(s,"INSERT INTO jobs(parent_id,kind,job_key,payload) VALUES(?,'v5','fixture:v5','')",(parent,))
            end
            properties=[V5ApplyVS.properties(gold_apn(8).lut .⊻ UInt8(i)) for i in 0:2]
            records=[Dict{String,Any}("properties"=>V5ApplyVS._ClosurePreparedCandidate(properties[1+i%3]),
                "cursor"=>string(i),"witness"=>V5ApplyVS._ClosurePreparedWitness(Dict("output"=>i,"forms"=>[1,2,3]))) for i in 1:79]
            push!(records,first(records))
            jobs=[only(V5ApplyVS._closure_rows(s,"SELECT * FROM jobs WHERE kind='v5'")) for s in stores]
            V5ApplyVS._closure_transaction(stores[1]) do
                for record in records
                    V5ApplyVS._closure_record_candidate!(stores[1],jobs[1],record["properties"],record["cursor"],record["witness"])
                end
            end
            V5ApplyVS._closure_transaction(stores[2]) do
                V5ApplyVS._closure_record_v5_candidates!(stores[2],jobs[2],records)
            end
            state(s)=Dict(table=>V5ApplyVS._closure_rows(s,"SELECT * FROM $table ORDER BY 1")
                for table in ("candidates","jobs","paths"))
            @test isequal(state(stores[1]),state(stores[2]))
            @test V5ApplyVS._closure_count(stores[2],"SELECT COUNT(*) n FROM paths")==79
            @test V5ApplyVS._closure_count(stores[2],"SELECT COUNT(*) n FROM jobs WHERE kind='deduplicate'")==2
            @test isempty(V5ApplyVS._closure_rows(stores[2],"PRAGMA foreign_key_check"))
            # A fresh batch can fail after multiple path inserts; every insert,
            # candidate admission update and template insertion must roll back.
            before=state(stores[2])
            V5ApplyVS._closure_exec(stores[2],"CREATE TEMP TRIGGER reject_v5_path BEFORE INSERT ON paths WHEN NEW.witness LIKE '%reject = true%' BEGIN SELECT RAISE(ABORT,'fixture path failure'); END")
            broken=V5ApplyVS.JSON3.read(V5ApplyVS.JSON3.write(records),Vector{Dict{String,Any}})
            for (i,r) in enumerate(broken);r["cursor"]=string(1000+i);end
            broken[end]["witness"]=Dict("reject"=>true)
            @test_throws Exception V5ApplyVS._closure_transaction(stores[2]) do
                V5ApplyVS._closure_record_v5_candidates!(stores[2],jobs[2],broken)
            end
            @test isequal(state(stores[2]),before)
            V5ApplyVS._closure_exec(stores[2],"DROP TRIGGER reject_v5_path")
            V5ApplyVS._closure_transaction(stores[2]) do
                V5ApplyVS._closure_record_v5_candidates!(stores[2],jobs[2],records)
            end
            @test isequal(state(stores[2]),before)
        finally
            for s in stores
                V5ApplyVS.DiscoveryStore.close_statements!(s.statements);close(s.db);close(s.lease)
            end
        end
    end
end
