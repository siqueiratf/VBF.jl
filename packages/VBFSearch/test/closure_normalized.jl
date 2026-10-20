module NormalizedClosureTests
using Test,SQLite,VBFSearch,VBF,TOML,SHA
const VS=VBFSearch
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
