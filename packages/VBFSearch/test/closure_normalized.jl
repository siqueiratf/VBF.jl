module NormalizedClosureTests
using Test,SQLite,VBFSearch,VBF,TOML,SHA
const VS=VBFSearch
struct PointerProofInteger <: Integer
    value::Ptr{Int}
end
@testset "Store statement reuse releases bindings and survives failure and rollback" begin
    db=SQLite.DB();cache=VS.DiscoveryStore.StatementCache(db;limit=2)
    execute(sql,args=())=VS.DiscoveryStore.execute!(cache,sql,args)
    query(sql,args=())=VS.DiscoveryStore.query(cache,sql,args)
    try
        VS._closure_exec(db,"CREATE TABLE fixture(id INTEGER PRIMARY KEY,value TEXT NOT NULL)")
        insert="INSERT INTO fixture VALUES(?,?)"
        execute(insert,(1,"first"));prepared=cache.statements[insert]
        @test isempty(prepared.params)
        @test_throws Exception execute(insert,(1,"duplicate"))
        @test isempty(prepared.params)
        execute("BEGIN IMMEDIATE")
        execute(insert,(2,"rolled back"))
        @test cache.statements[insert]===prepared
        execute("ROLLBACK")
        @test query("SELECT value FROM fixture ORDER BY id")==[Dict("value"=>"first")]
        execute(insert,(2,"second"))
        @test query("SELECT value FROM fixture ORDER BY id")==[Dict("value"=>"first"),Dict("value"=>"second")]
        @test length(cache.statements)==2
        @test all(isempty(statement.params) for statement in values(cache.statements))
        VS.DiscoveryStore.close_statements!(cache)
        @test isempty(cache.statements)
        @test !SQLite.isready(prepared)
    finally
        VS.DiscoveryStore.close_statements!(cache);close(db)
    end
end

@testset "Single-scan proof normalization matches the previous exact encoding" begin
    function previous_storage(proof,values)
        evidence=VS._closure_text(proof);body=evidence;slots=fill("",9);encoded=false
        if !occursin(VS._CLOSURE_TOKEN_PREFIX,evidence)
            fields=("candidate_lut_hex","target_lut_hex","candidate_sha256","target_sha256")
            encoded=all(get(proof,k,nothing)==v for (k,v) in zip(fields,values))
            if encoded
                for (key,value) in zip(("c:lut","t:lut","c:id","t:id"),values)
                    isempty(value) || (body=replace(body,value=>VS._closure_token(key)))
                end
                for (i,key) in enumerate(VS._CLOSURE_PROOF_SLOTS)
                    pattern=Regex("(?m)^"*key*" = ([^\\n]*)\n")
                    matches=collect(eachmatch(pattern,body))
                    if length(matches)==1
                        slots[i]=String(only(matches).captures[1])
                        body=replace(body,pattern=>(key*" = "*VS._closure_token("v$(i-1)")*"\n"))
                    end
                end
            end
        end
        (;body,slots,encoded)
    end
    values=(repeat("a",512),repeat("b",512),repeat("c",64),repeat("d",64))
    proof=Dict{String,Any}("candidate_lut_hex"=>values[1],"target_lut_hex"=>values[2],
        "candidate_sha256"=>values[3],"target_sha256"=>values[4],"status"=>"inconclusive_budget",
        "graph_map_columns"=>collect(1:16),"graph_map_constant"=>17,"nodes"=>125,"seconds"=>0.125,
        "timeout_seconds"=>5.0,"max_nodes"=>1000,"stop"=>"budget","evidence"=>"αβ\nfuture","rng_seed"=>940)
    nested=deepcopy(proof);nested["future"]=Dict("nodes"=>27,"evidence"=>"nested αβ","seconds"=>0.0)
    literal=deepcopy(proof);literal["future"]="literal !!vbf:v0!!"
    unbound=deepcopy(proof);unbound["candidate_sha256"]="different"
    multiline=deepcopy(proof);multiline["evidence"]="αβ\nnodes = 5\nseconds = 9\n"
    identical=deepcopy(proof);identical["target_lut_hex"]=values[1];identical["target_sha256"]=values[3]
    for (record,pair) in ((proof,values),(nested,values),(literal,values),(unbound,values),
            (multiline,values),(identical,(values[1],values[1],values[3],values[3])))
        @test VS._closure_comparison_storage(record,VS._closure_text(record),pair)==previous_storage(record,pair)
    end
end

@testset "Template lookup retains exact collision checks without copying the body" begin
    db=SQLite.DB();VS._closure_create_schema(db;normalized=true)
    try
        body="literal αβ\0with embedded NUL"
        id=VS._closure_template!(db,body)
        @test VS._closure_template!(db,body)==id
        other="another exact body"
        VS._closure_exec(db,"INSERT INTO closure_templates(digest,body) VALUES(?,?)",(SHA.sha256(other),"different"))
        @test_throws ErrorException VS._closure_template!(db,other)
        @test only(VS._closure_rows(db,"SELECT body FROM closure_templates WHERE digest=?",(SHA.sha256(other),)))["body"]=="different"
    finally
        close(db)
    end
end

@testset "Worker-prepared proofs are immutable, exact and transparent over JSON" begin
    values=(repeat("a",512),repeat("b",512),repeat("c",64),repeat("d",64))
    original=Dict{String,Any}("candidate_lut_hex"=>values[1],"target_lut_hex"=>values[2],
        "candidate_sha256"=>values[3],"target_sha256"=>values[4],"status"=>"inconclusive_budget",
        "graph_map_columns"=>collect(1:16),"graph_map_constant"=>17,"seconds"=>0.125,
        "future"=>Dict("nested"=>Any[Dict("unicode"=>"αβ"),big(2)^100,Int[]]))
    expected=deepcopy(original);prepared=VS._closure_prepare_comparison_proof(original,values)
    @test prepared isa VS._ClosurePreparedProof
    @test copy(prepared)==expected
    @test VS._closure_text(prepared)==VS._closure_text(expected)
    original["graph_map_columns"][1]=99
    original["future"]["nested"][1]["unicode"]="changed"
    prepared["graph_map_columns"][1]=88
    prepared["future"]["nested"][1]["unicode"]="changed again"
    copied=copy(prepared);copied["future"]["nested"][1]["unicode"]="copy changed"
    iterated=Dict(prepared);iterated["future"]["nested"][1]["unicode"]="iteration changed"
    immutable_graph(value)=value isa String || (isimmutable(value) && all(
        immutable_graph(getfield(value,index)) for index in 1:fieldcount(typeof(value))))
    @test all(immutable_graph(getfield(prepared,key)) for key in propertynames(prepared))
    @test copy(prepared)==expected
    @test VS._closure_text(prepared)==VS._closure_text(expected)
    @test_throws Exception (prepared["status"]="changed")
    @test_throws MethodError VS._ClosurePreparedProof(prepared.fields,prepared.evidence,
        prepared.body,prepared.slots,prepared.encoded,prepared.pair)
    wire=VS.JSON3.read(VS.JSON3.write(prepared),Dict{String,Any})
    @test wire isa Dict && !(wire isa VS._ClosurePreparedProof)
    @test Set(keys(wire))==Set(keys(expected))
    @test !haskey(wire,"body") && !haskey(wire,"slots")
    plain=VS._closure_comparison_storage(expected,VS._closure_text(expected),values)
    cached=VS._closure_comparison_storage(prepared,VS._closure_text(prepared),values)
    @test plain.body==cached.body && plain.slots==collect(cached.slots) && plain.encoded==cached.encoded
    other=(values[1],values[2],values[3],"different")
    fallback=VS._closure_comparison_storage(prepared,VS._closure_text(prepared),other)
    @test !fallback.encoded && fallback.body==VS._closure_text(expected)
    future=copy(expected);future["opaque"]=(1,2)
    @test VS._closure_prepare_comparison_proof(future,values)===future
    future["opaque"]=PointerProofInteger(Ptr{Int}(0))
    @test VS._closure_prepare_comparison_proof(future,values)===future
end

@testset "Duplicate candidates retain every path without serializing properties again" begin
    for normalized in (false,true)
        db=SQLite.DB();VS._closure_create_schema(db;normalized)
        lease=open(tempname(),"w");s=VS.ClosureStore(db,"",lease,Dict{String,Any}(),1,UInt64(0))
        try
            VS._closure_exec(s,"PRAGMA foreign_keys=ON")
            p=VS.properties(gold_apn(8).lut)
            VS._closure_insert_candidate!(s,p)
            parent=VS._closure_add_parent!(s,p["lut_sha256"],p["sigma_hash"])
            job=only(VS._closure_rows(s,"SELECT id,parent_id,kind FROM jobs WHERE kind='switching'"))
            original=only(VS._closure_rows(s,"SELECT properties FROM candidates"))["properties"]
            templates=normalized ? VS._closure_count(s,"SELECT COUNT(*) n FROM closure_templates") : 0
            duplicate=copy(p);duplicate["would_fail_TOML_serialization"]=Ref(1)
            @test VS._closure_record_candidate!(s,job,duplicate,"1:1",Dict("direction"=>1))==p["lut_sha256"]
            @test VS._closure_record_candidate!(s,job,duplicate,"1:2",Dict("direction"=>1))==p["lut_sha256"]
            @test VS._closure_count(s,"SELECT COUNT(*) n FROM paths")==2
            @test VS._closure_count(s,"SELECT COUNT(*) n FROM candidates")==1
            @test only(VS._closure_rows(s,"SELECT properties FROM candidates"))["properties"]==original
            normalized && @test VS._closure_count(s,"SELECT COUNT(*) n FROM closure_templates")==templates
            collision=copy(p);collision["lut_hex"]=repeat("00",256)
            @test_throws ErrorException VS._closure_insert_candidate!(s,collision)
            VS._closure_exec(s,"BEGIN IMMEDIATE")
            VS._closure_record_candidate!(s,job,duplicate,"1:3",Dict("direction"=>1))
            VS._closure_exec(s,"ROLLBACK")
            @test VS._closure_count(s,"SELECT COUNT(*) n FROM paths")==2
            @test only(VS._closure_rows(s,"SELECT class_id FROM candidates"))["class_id"]==parent
        finally
            VS.DiscoveryStore.close_statements!(s.statements);close(db);close(lease)
        end
    end
end

@testset "Normalized SQL evidence retains exact text, constraints and transactions" begin
    db=SQLite.DB();VS._closure_create_schema(db;normalized=true)
    lease=open(tempname(),"w");s=VS.ClosureStore(db,"",lease,Dict{String,Any}(),1,UInt64(0))
    try
        VS._closure_exec(db,"PRAGMA foreign_keys=ON")
        F=gold_apn(8);p=VS.properties(F.lut)
        VS._closure_insert_candidate!(s,p)
        @test only(VS._closure_rows(db,"SELECT * FROM candidates"))["properties"]==VS._closure_text(p)
        @test only(VS._closure_rows(db,"SELECT lut_hex FROM candidates"))["lut_hex"]==p["lut_hex"]
        VS._closure_exec(db,"INSERT INTO parents VALUES(1,?,?, 'root','fixture','now',0)",(p["lut_sha256"],p["sigma_hash"]))
        proof=VS.compare(F.lut,F.lut;relation=:ea)
        VS._closure_insert_comparison!(s,p["lut_sha256"],1,proof)
        restored=only(VS._closure_rows(db,"SELECT evidence FROM comparisons"))["evidence"]
        @test restored==VS._closure_text(proof)
        @test VS.verify_comparison(TOML.parse(restored))
        @test VS._closure_count(db,"SELECT COUNT(*) n FROM closure_comparisons WHERE encoding=1")==1
        VS._closure_exec(db,"UPDATE candidates SET class_id=1,state='equivalent'")
        @test only(VS._closure_rows(db,"SELECT class_id,state FROM candidates"))==Dict("class_id"=>1,"state"=>"equivalent")
        @test_throws Exception VS._closure_exec(db,"UPDATE candidates SET properties='changed'")
        @test_throws Exception VS._closure_exec(db,"DELETE FROM candidates")
        @test isempty(VS._closure_rows(db,"PRAGMA foreign_key_check"))
        VS._closure_insert_candidate!(s,p)
        @test VS._closure_count(db,"SELECT COUNT(*) n FROM candidates")==1
        # The legacy SQL interface must neither duplicate a binary LUT nor need an extension.
        VS._closure_exec(db,"INSERT OR IGNORE INTO candidates VALUES(?,?,?,?,?,?,?,?)",("other",p["lut_hex"],p["sigma_hash"],1,2,"opaque",missing,"observed"))
        @test VS._closure_count(db,"SELECT COUNT(*) n FROM candidates")==1
        p2=deepcopy(p);p2["lut_hex"]=bytes2hex(UInt8.(F.lut .⊻ 1));p2["lut_sha256"]=VS.lut_id(F.lut .⊻ 1)
        p2["extra"]=Dict("unicode"=>"αβ\n!!vbf:c:lut!! is literal")
        VS._closure_exec(db,"BEGIN IMMEDIATE");VS._closure_insert_candidate!(s,p2)
        @test only(VS._closure_rows(db,"SELECT properties FROM candidates WHERE id=?",(p2["lut_sha256"],)))["properties"]==VS._closure_text(p2)
        VS._closure_exec(db,"ROLLBACK")
        @test VS._closure_count(db,"SELECT COUNT(*) n FROM candidates")==1
        # Opaque legacy inserts survive exactly, including future schemas and non-hex fixtures.
        VS._closure_exec(db,"INSERT INTO candidates VALUES('legacy','fixture','sigma',1,2,'literal !!vbf:c:id!!',NULL,'observed')")
        @test only(VS._closure_rows(db,"SELECT properties FROM candidates WHERE id='legacy'"))["properties"]=="literal !!vbf:c:id!!"
        proof["future"]="literal !!vbf:t:lut!! αβ"
        VS._closure_insert_comparison!(s,p["lut_sha256"],1,proof)
        @test last(VS._closure_rows(db,"SELECT evidence FROM comparisons ORDER BY id"))["evidence"]==VS._closure_text(proof)
        VS._closure_exec(db,"INSERT INTO comparisons(candidate_id,target_parent,status,evidence,session_id) VALUES(?,1,'opaque','future αβ',1)",(p["lut_sha256"],))
        @test last(VS._closure_rows(db,"SELECT evidence FROM comparisons ORDER BY id"))["evidence"]=="future αβ"
        pair=(p["lut_hex"],p["lut_hex"],p["lut_sha256"],p["lut_sha256"])
        plain=copy(proof);delete!(plain,"future")
        for original in (plain,proof)
            native=VS._closure_prepare_comparison_proof(original,pair)
            wire=VS.JSON3.read(VS.JSON3.write(native),Dict{String,Any})
            @test native isa VS._ClosurePreparedProof && !(wire isa VS._ClosurePreparedProof)
            for record in (native,wire)
                VS._closure_insert_comparison!(s,p["lut_sha256"],1,record;bound_pair=pair)
                @test last(VS._closure_rows(db,"SELECT evidence FROM comparisons ORDER BY id"))["evidence"]==VS._closure_text(original)
            end
            encoded=VS._closure_rows(db,"SELECT template_id,encoding,v0,v1,v2,v3,v4,v5,v6,v7,v8 FROM closure_comparisons ORDER BY id DESC LIMIT 2")
            @test first(encoded)==last(encoded)
            @test VS.verify_comparison(wire)
        end
    finally
        close(db);close(lease)
    end
end
function proof_rows(n)
    [Dict{String,Any}("job_id"=>17,"first_x"=>i,"next_x"=>i+1,"total_x"=>n,"capped"=>Int(i==n),
        "evidence"=>VS._closure_coset_evidence_text(Dict{String,Any}("V5_forms"=>[1,2,3,4,5],
        "candidate_spaces"=>i%3,"completion_spaces"=>0,"du_reject"=>1,"linear_system_candidates"=>i%3,
        "coset_representative"=>iseven(i) ? i : n-i,"capped"=>i==n,"first_x"=>i,"next_x"=>i+1,
        "total_x"=>n,"coset_order"=>"increasing nonzero quotient integer with exact bent count","heuristic_pruning"=>false))) for i in 1:n]
end
@testset "V2 ledger preserves signed representative deltas and rejects malformed streams" begin
    rows=proof_rows(32);blob=VS._closure_pack_chunks(rows)
    @test String(copy(blob[1:8]))=="VBFCHN02"
    envelope=merge(copy(first(rows)),Dict("next_x"=>33,"capped"=>1,"evidence"=>blob))
    @test VS._closure_unpack_chunks(envelope)==rows
    # A V1 block remains readable and decodes to precisely the same logical records.
    io=IOBuffer();write(io,htol(UInt32(length(rows))))
    for r in rows
        for k in VS._CLOSURE_LEDGER_FIELDS;write(io,htol(UInt64(r[k])));end
        write(io,htol(UInt32(sizeof(r["evidence"]))));write(io,r["evidence"])
    end
    raw=take!(io);old=VS._closure_encode_chunk_bytes(raw;normalized=nothing)
    @test VS._closure_unpack_chunks(merge(envelope,Dict("evidence"=>old)))==rows
    for bytes in (UInt8[0x80],fill(UInt8(0xff),10),UInt8[0x80,0x00])
        @test_throws Exception VS._closure_getvar(IOBuffer(bytes))
    end
    payload=VS._closure_v2_from_raw(raw)
    @test VS._closure_v2_raw(payload,length(raw))==raw
    @test_throws Exception VS._closure_v2_raw(vcat(payload,0x00),length(raw))
    bad=copy(payload);bad[49:52].=0xff
    @test_throws Exception VS._closure_v2_raw(bad,length(raw))
    @test_throws Exception VS._closure_v2_raw(payload,length(raw)-1)
    unknown=deepcopy(rows);unknown[end]["evidence"]*="future = true\n"
    @test String(copy(VS._closure_pack_chunks(unknown)[1:8]))=="VBFCHN01"
end
if haskey(ENV,"VBF_CLOSURE_REDUCE_HELPER")
@testset "Native reduction resumes after SQLITE_FULL and preserves mixed encodings" begin
    mktempdir() do dir
        source=joinpath(dir,"source");mkpath(source);write(joinpath(source,"STOP"),"stop\n")
        path=joinpath(source,"closure.sqlite");db=SQLite.DB(path);VS._closure_create_schema(db)
        text=repeat("opaque future evidence αβ\n",80000)
        VS._closure_exec(db,"INSERT INTO candidates VALUES('fixture','00',NULL,1,2,?,NULL,'observed')",(text,))
        rows=proof_rows(32);io=IOBuffer();write(io,htol(UInt32(length(rows))))
        for row in rows
            for k in VS._CLOSURE_LEDGER_FIELDS;write(io,htol(UInt64(row[k])));end
            write(io,htol(UInt32(sizeof(row["evidence"]))));write(io,row["evidence"])
        end
        raw=take!(io)
        for (job,blob) in ((17,VS._closure_encode_chunk_bytes(raw;normalized=nothing)),(18,VS._closure_pack_chunks([merge(r,Dict("job_id"=>18)) for r in rows])))
            VS._closure_exec(db,"INSERT INTO chunks VALUES(?,1,33,32,1,?)",(job,blob))
        end
        VS._closure_exec(db,"INSERT INTO chunks VALUES(19,1,1,0,0,'future = \"αβ\"\n')")
        close(db);before=VS.DiscoveryEvidence.filehash(path)
        target=joinpath(dir,"reduced.sqlite");helper=ENV["VBF_CLOSURE_REDUCE_HELPER"]
        schema=joinpath(pkgdir(VS),"src","closure_normalized.sql")
        small=Cmd([helper,path,target,schema,"2","0",string(1024^2)])
        @test !success(pipeline(ignorestatus(small);stdout=devnull,stderr=devnull))
        command=Cmd([helper,path,target,schema,"2","0",string(16*1024^2)])
        # A different helper cannot resume a partially converted checkpoint,
        # even when its predecessor is explicitly supplied.
        partial=SQLite.DB(target)
        actual=only(VS._closure_rows(partial,"SELECT value FROM closure_reduction_state WHERE key='helper_sha256'"))["value"]
        predecessor=repeat("a",64)
        VS._closure_exec(partial,"UPDATE closure_reduction_state SET value=? WHERE key='helper_sha256'",(predecessor,));close(partial)
        permit=Cmd(vcat(command.exec,[predecessor]))
        @test !success(pipeline(ignorestatus(command);stdout=devnull,stderr=devnull))
        @test !success(pipeline(ignorestatus(permit);stdout=devnull,stderr=devnull))
        partial=SQLite.DB(target);VS._closure_exec(partial,"UPDATE closure_reduction_state SET value=? WHERE key='helper_sha256'",(actual,));close(partial)
        @test success(pipeline(command;stdout=devnull))
        @test before==VS.DiscoveryEvidence.filehash(path)
        reduced=SQLite.DB(target)
        try
            @test only(VS._closure_rows(reduced,"SELECT properties FROM candidates"))["properties"]==text
            expected=Set(["candidates_counters","candidates_lut","candidates_lut_text","candidates_sigma","candidates_state","comparisons_pair"])
            @test issubset(expected,Set(r["name"] for r in VS._closure_rows(reduced,"SELECT name FROM sqlite_master WHERE type='index' AND sql IS NOT NULL")))
            for job in (17,18)
                block=only(VS._closure_rows(reduced,"SELECT * FROM chunks WHERE job_id=?",(job,)))
                @test String(copy(block["evidence"][1:8]))=="VBFCHN02"
                @test VS._closure_unpack_chunks(block)==[merge(r,Dict("job_id"=>job)) for r in rows]
            end
            @test only(VS._closure_rows(reduced,"SELECT evidence FROM chunks WHERE job_id=19"))["evidence"]=="future = \"αβ\"\n"
            @test only(VS._closure_rows(reduced,"SELECT value FROM closure_reduction_state WHERE key='chunks:logical_rows'"))["value"]=="65"
        finally
            close(reduced)
        end
        # Once all data proofs exist, an explicit predecessor permits rerunning
        # final database checks with a replacement helper and records that lineage.
        ready=SQLite.DB(target);VS._closure_exec(ready,"UPDATE closure_reduction_state SET value=? WHERE key='helper_sha256'",(predecessor,));close(ready)
        @test success(pipeline(permit;stdout=devnull))
        ready=SQLite.DB(target)
        @test only(VS._closure_rows(ready,"SELECT value FROM closure_reduction_state WHERE key=?",("helper_history:"*predecessor,)))["value"]=="all data verified; resumed final database checks with "*actual
        close(ready)
        @test success(pipeline(command;stdout=devnull))
    end
end
@testset "Native reducer and Julia codec agree and stopped checkpoint remains runnable" begin
    helper=ENV["VBF_CLOSURE_REDUCE_HELPER"]
    mktempdir() do dir
        root=joinpath(dir,"root.tsv");write(root,"published fixture\n");h=VS.DiscoveryEvidence.filehash(root)
        identity=Dict{String,Any}("schema"=>VS.CLOSURE_SCHEMA,"campaign"=>root,"campaign_sha256"=>h,
            "roots_sha256"=>h,"initial_roots"=>1,"qualified_roots"=>1,"qualification_complete"=>true,
            "inputs"=>Dict(root=>h),"implementation"=>VS.implementation_fingerprint(),"julia"=>string(VERSION),
            "scientific"=>Dict("n"=>8,"m"=>8,"target_b6"=>52,"max_kernel"=>23))
        p=VS.properties(gold_apn(8).lut);source=joinpath(dir,"source")
        VS._closure_initialize(source,identity,[(lut_sha256=p["lut_sha256"],lut_hex=p["lut_hex"],sigma_hash=p["sigma_hash"],catalog_id="published:fixture")])
        write(joinpath(source,"STOP"),"stopped\n");before=VS.DiscoveryEvidence.filehash(joinpath(source,"closure.sqlite"))
        output=joinpath(dir,"reduced")
        result=VS.closure_reduce(source;output,helper,threads=2,reserve_bytes=0,max_bytes=1024^3)
        @test result["exact_luts"]==1
        @test isfile(joinpath(output,"STOP"))
        @test before==VS.DiscoveryEvidence.filehash(joinpath(source,"closure.sqlite"))
        reduced=VS._closure_open(output)
        try
            @test VS._closure_normalized(reduced.db)
            @test VS._closure_count(reduced.db,"SELECT COUNT(*) n FROM parents")==1
            rows=proof_rows(32);blob=VS._closure_pack_chunks(rows)
            # Check subsequent Julia writes and reads without dispatching search work.
            VS._closure_exec(reduced.db,"INSERT INTO chunks VALUES(?,?,?,?,?,?)",(17,1,33,32,1,blob))
            @test VS._closure_unpack_chunks(only(VS._closure_rows(reduced.db,"SELECT * FROM chunks")))==rows
        finally
            VS._closure_close(reduced)
        end
        @test_throws ErrorException VS.closure_reduce(source;output,helper,reserve_bytes=0)
    end
end
end
end
