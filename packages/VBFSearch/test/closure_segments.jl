module ClosureSegmentTests
using Test,SQLite,VBFSearch,SHA
const VS=VBFSearch

function fixture(f)
    mktempdir() do directory
        db=SQLite.DB(joinpath(directory,"closure.sqlite"));VS._closure_create_schema(db)
        VS._closure_exec(db,"PRAGMA foreign_keys=ON")
        VS._closure_exec(db,"INSERT INTO candidates VALUES('fixture','00','sigma',1,2,'',1,'admitted')")
        VS._closure_exec(db,"INSERT INTO parents VALUES(1,'fixture','sigma','root','published', '',0)")
        for (job,status) in ((1,"done"),(2,"running"),(3,"done"))
            VS._closure_exec(db,"INSERT INTO jobs(id,parent_id,kind,job_key,payload,status) VALUES(?,1,'v5',?,'',?)",(job,"job:$job",status))
        end
        lease=open(joinpath(directory,"closure.lock"),"a+")
        store=VS.ClosureStore(db,directory,lease,Dict{String,Any}(),0,UInt64(0))
        try f(store) finally close(db);close(lease) end
    end
end
function rows(job,n;first=1)
    [Dict{String,Any}("job_id"=>job,"first_x"=>i,"next_x"=>i+1,"total_x"=>first+n-1,"capped"=>0,
        "evidence"=>"opaque = \"αβ $(i)\"\n"*repeat("future = [1, 5, 19]\n",30)) for i in first:first+n-1]
end
function v2rows(job,n;first=1)
    [Dict{String,Any}("job_id"=>job,"first_x"=>i,"next_x"=>i+1,"total_x"=>first+n-1,"capped"=>0,
        "evidence"=>VS._closure_coset_evidence_text(Dict{String,Any}("V5_forms"=>[1,2,3,4,5],
            "first_x"=>i,"next_x"=>i+1,"total_x"=>first+n-1,"capped"=>false,"candidate_spaces"=>i%3,
            "completion_spaces"=>0,"du_reject"=>1,"linear_system_candidates"=>i%3,"coset_representative"=>i*27,
            "coset_order"=>"increasing nonzero quotient integer with exact bent count","heuristic_pruning"=>false))) for i in first:first+n-1]
end
function block(records)
    merge(copy(first(records)),Dict("next_x"=>last(records)["next_x"],"evidence"=>VS._closure_pack_chunks(records)))
end
insert!(db,row)=VS._closure_exec(db,"INSERT INTO chunks VALUES(?,?,?,?,?,?)",Tuple(row[k] for k in (VS._CLOSURE_LEDGER_FIELDS...,"evidence")))
logical(db)=(result=Any[];VS._closure_foreach_chunk(x->push!(result,x),db);result)

@testset "Sealed coverage preserves TEXT/V1/V2, envelopes and logical iteration" begin
    fixture() do s
        old=rows(1,4);new=v2rows(1,4;first=5);running=only(rows(2,1));single=only(rows(3,1))
        @test String(copy(block(old)["evidence"][1:8]))=="VBFCHN01"
        @test String(copy(block(new)["evidence"][1:8]))=="VBFCHN02"
        for row in (block(old),block(new),running,single);insert!(s.db,row);end
        before=logical(s.db);physical=VS._closure_rows(s.db,"SELECT * FROM chunks ORDER BY job_id,first_x")
        envelopes=VS._closure_rows(s.db,"SELECT job_id,first_x,next_x,total_x,capped FROM chunks ORDER BY job_id,first_x")
        sealed=VS.closure_seal_segments!(s;max_rows=2)
        @test sealed["rows"]==2 && sealed["segments"]==1
        @test isfile(sealed["path"])
        @test sealed["digest"]==bytes2hex(open(SHA.sha256,sealed["path"]))
        @test logical(s.db)==before
        @test VS._closure_rows(s.db,"SELECT job_id,first_x,next_x,total_x,capped FROM chunks ORDER BY job_id,first_x")==envelopes
        @test VS._closure_count(s.db,"SELECT COUNT(*) n FROM chunks")==4
        @test VS._closure_count(s.db,"SELECT COUNT(*) n FROM paths")==0
        @test VS.closure_verify_segments(s.db,s.directory;replay=true)["rows"]==2
        @test_throws ErrorException VS._closure_unpack_chunks(only(VS._closure_rows(s.db,"SELECT * FROM chunks WHERE job_id=1 AND first_x=1")))
        @test VS._closure_rows(s.db,"SELECT evidence FROM chunks WHERE job_id=2")[1]["evidence"]==running["evidence"]
        artifacts=VS.closure_segment_artifacts(s.db,s.directory)
        @test only(keys(artifacts))==joinpath("cold",sealed["digest"]*".zst")
        @test only(values(artifacts))==sealed["path"]
        @test VS.closure_seal_segments!(s;max_rows=8)["rows"]==1
        @test VS.closure_seal_segments!(s)["rows"]==0
        @test logical(s.db)==before
        @test VS.closure_rehydrate_segments!(s;max_segments=1)["segments"]==1
        @test logical(s.db)==before
        @test VS.closure_rehydrate_segments!(s)["segments"]==1
        @test VS._closure_rows(s.db,"SELECT * FROM chunks ORDER BY job_id,first_x")==physical
        @test isempty(VS.closure_segment_artifacts(s.db,s.directory))
        @test VS.closure_verify_segments(s.db,s.directory;full=true)["rows"]==0
        @test length(readdir(joinpath(s.directory,"cold")))==2
        @test isempty(VS._closure_rows(s.db,"PRAGMA foreign_key_check"))
    end
end

@testset "Publication retry, corruption and missing artifacts fail safely" begin
    fixture() do s
        row=block(rows(1,4));insert!(s.db,row);insert!(s.db,only(rows(1,1;first=5)));before=logical(s.db)
        VS._closure_exec(s.db,"CREATE TRIGGER fail_seal BEFORE UPDATE OF evidence ON chunks WHEN NEW.first_x=5 BEGIN SELECT RAISE(ABORT,'fixture crash before commit'); END")
        @test_throws Exception VS.closure_seal_segments!(s)
        @test logical(s.db)==before
        @test VS._closure_count(s.db,"SELECT COUNT(*) n FROM closure_evidence_segments")==0
        @test length(readdir(joinpath(s.directory,"cold")))==1
        VS._closure_exec(s.db,"DROP TRIGGER fail_seal")
        sealed=VS.closure_seal_segments!(s)
        @test length(readdir(joinpath(s.directory,"cold")))==1
        @test logical(s.db)==before
        original=read(sealed["path"]);chmod(sealed["path"],0o644)
        changed=copy(original);changed[end]⊻=0x01;write(sealed["path"],changed)
        @test_throws ErrorException logical(s.db)
        @test_throws ErrorException VS.closure_verify_segments(s.db,s.directory;full=true)
        @test_throws ErrorException VS.closure_rehydrate_segments!(s)
        @test VS._closure_count(s.db,"SELECT COUNT(*) n FROM closure_segment_chunks")==2
        write(sealed["path"],original)
        moved=sealed["path"]*".unavailable";mv(sealed["path"],moved)
        @test_throws ErrorException VS.closure_verify_segments(s.db,s.directory)
        @test_throws ErrorException logical(s.db)
        symlink(moved,sealed["path"])
        @test_throws ErrorException VS.closure_segment_artifacts(s.db,s.directory)
        @test_throws ErrorException VS.closure_verify_segments(s.db,s.directory)
        @test_throws ErrorException logical(s.db)
        rm(sealed["path"])
        mv(moved,sealed["path"])
        @test logical(s.db)==before
        VS._closure_exec(s.db,"UPDATE chunks SET next_x=next_x+1")
        @test_throws ErrorException logical(s.db)
        @test_throws ErrorException VS.closure_verify_segments(s.db,s.directory;full=true)
        VS._closure_exec(s.db,"UPDATE chunks SET next_x=next_x-1")
        VS._closure_exec(s.db,"UPDATE closure_segment_chunks SET ordinal=9 WHERE first_x=1")
        @test_throws ErrorException logical(s.db)
        @test_throws ErrorException VS.closure_verify_segments(s.db,s.directory)
    end
end

@testset "Legacy clone/migration helpers cannot omit indispensable cold evidence" begin
    fixture() do s
        insert!(s.db,block(rows(1,4)));VS.closure_seal_segments!(s)
        write(joinpath(s.directory,"STOP"),"stopped fixture\n")
        for (kind,call) in (
            ("upgrade",out->VS.closure_upgrade(s.directory;output=out)),
            ("compact",out->VS.closure_compact(s.directory;output=out,helper="unused")),
            ("reduce",out->VS.closure_reduce(s.directory;output=out,helper="unused")))
            out=s.directory*"-"*kind
            caught=try call(out);nothing catch error;error end
            @test caught isa ErrorException
            @test occursin("closure_rehydrate_segments!",sprint(showerror,caught))
            @test !ispath(out)
            @test !ispath(out*".reducing")
        end
        @test VS.closure_rehydrate_segments!(s)["rows"]==1
        @test VS._closure_reject_segmented_clone(s.db)===nothing
    end
end

if haskey(ENV,"VBF_CLOSURE_COMPACT_HELPER") && haskey(ENV,"VBF_CLOSURE_REDUCE_HELPER")
@testset "Native helpers reject external segments before creating output" begin
    fixture() do s
        insert!(s.db,only(rows(1,1)))
        VS._closure_exec(s.db,"UPDATE jobs SET status='paused'")
        VS._closure_exec(s.db,"UPDATE jobs SET status='done',direction=2 WHERE id=1")
        write(joinpath(s.directory,"STOP"),"stopped fixture\n")
        VS.closure_seal_segments!(s)
        for kind in ("compact","reduce")
            out=joinpath(s.directory,kind*".sqlite")
            command=kind=="compact" ? Cmd([ENV["VBF_CLOSURE_COMPACT_HELPER"],joinpath(s.directory,"closure.sqlite"),out]) :
                Cmd([ENV["VBF_CLOSURE_REDUCE_HELPER"],joinpath(s.directory,"closure.sqlite"),out,joinpath(pkgdir(VS),"src","closure_normalized.sql"),"1","0",string(16*1024^2)])
            log=joinpath(s.directory,kind*".stderr")
            @test !success(pipeline(ignorestatus(command);stdout=devnull,stderr=log))
            @test occursin("closure_rehydrate_segments!",read(log,String))
            @test !isfile(out)
        end
        VS.closure_rehydrate_segments!(s)
        # Empty archival registries must not make a legacy schema appear normalized.
        for kind in ("compact","reduce")
            out=joinpath(s.directory,kind*".sqlite")
            command=kind=="compact" ? Cmd([ENV["VBF_CLOSURE_COMPACT_HELPER"],joinpath(s.directory,"closure.sqlite"),out]) :
                Cmd([ENV["VBF_CLOSURE_REDUCE_HELPER"],joinpath(s.directory,"closure.sqlite"),out,joinpath(pkgdir(VS),"src","closure_normalized.sql"),"1","0",string(16*1024^2)])
            @test success(pipeline(command;stdout=devnull))
            db=SQLite.DB(out)
            try @test logical(db)==logical(s.db) finally close(db) end
        end
    end
end
end

@testset "Cold roots relocate with artifact export and bounded sealing" begin
    fixture() do s
        first=only(rows(1,1));second=only(rows(1,1;first=2))
        insert!(s.db,first);insert!(s.db,second);before=logical(s.db)
        @test_throws ArgumentError VS.closure_seal_segments!(s;max_rows=0)
        @test_throws ErrorException VS.closure_seal_segments!(s;max_bytes=64)
        @test VS._closure_count(s.db,"SELECT COUNT(*) n FROM closure_segment_chunks")==0
        budget=12+49+sizeof(first["evidence"])
        sealed=VS.closure_seal_segments!(s;max_bytes=budget)
        @test sealed["rows"]==1
        @test logical(s.db)==before
        @test_throws ErrorException VS.closure_seal_segments!(s;cold_directory=joinpath(s.directory,"different"))
        VS._closure_exec(s.db,"BEGIN IMMEDIATE")
        @test_throws ErrorException VS.closure_seal_segments!(s)
        @test_throws ErrorException VS.closure_rehydrate_segments!(s)
        VS._closure_exec(s.db,"ROLLBACK")
        other=joinpath(s.directory,"relocated");mkpath(joinpath(other,"cold"))
        for (name,path) in VS.closure_segment_artifacts(s.db,s.directory);cp(path,joinpath(other,name));end
        target=joinpath(other,"closure.sqlite");SQLite.backup(s.db,target)
        db=SQLite.DB(target)
        try
            @test VS.closure_verify_segments(db,other;full=true)["rows"]==1
            @test logical(db)==before
        finally close(db) end
    end
end

@testset "A sealed checkpoint reopens with unchanged cursors, paths and EA classes" begin
    for normalized in (false,true)
        mktempdir() do directory
            p=VS.properties(VS.VBF.gold_apn(8).lut)
            root=joinpath(directory,"roots.tsv");write(root,p["lut_hex"]*"\n")
            digest=VS.DiscoveryEvidence.filehash(root)
            identity=Dict{String,Any}("schema"=>VS.CLOSURE_SCHEMA,"campaign"=>root,"campaign_sha256"=>digest,
                "roots_sha256"=>digest,"initial_roots"=>1,"qualified_roots"=>1,"qualification_complete"=>true,
                "inputs"=>Dict(root=>digest),"implementation"=>VS.implementation_fingerprint(),"julia"=>string(VERSION),
                "scientific"=>Dict("n"=>8,"m"=>8,"target_b6"=>52,"max_kernel"=>23))
            run=joinpath(directory,"run")
            VS._closure_initialize(run,identity,[(lut_sha256=p["lut_sha256"],lut_hex=p["lut_hex"],sigma_hash=p["sigma_hash"],catalog_id="published:fixture")];normalized)
            s=VS._closure_open(run)
            before=nothing;paths=nothing;classes=nothing;envelopes=nothing
            try
                VS._closure_exec(s.db,"INSERT INTO jobs(id,parent_id,kind,job_key,payload,status,direction) VALUES(3,1,'v5','3:v5','','done',5)")
                insert!(s.db,block(v2rows(3,4)))
                VS._closure_exec(s.db,"INSERT INTO paths(parent_id,job_id,method,cursor,child_id,witness) VALUES(1,3,'v5','1',?,'opaque exact construction witness')",(p["lut_sha256"],))
                before=logical(s.db);paths=VS._closure_rows(s.db,"SELECT * FROM paths")
                classes=VS._closure_rows(s.db,"SELECT id,class_id,state FROM candidates")
                envelopes=VS._closure_rows(s.db,"SELECT job_id,first_x,next_x,total_x,capped FROM chunks")
                @test VS._closure_validate_cursors(s)===nothing
                @test VS.closure_seal_segments!(s)["rows"]==1
                @test VS._closure_validate_cursors(s)===nothing
            finally VS._closure_close(s) end
            reopened=VS._closure_open(run)
            try
                @test logical(reopened.db)==before
                @test VS._closure_rows(reopened.db,"SELECT * FROM paths")==paths
                @test VS._closure_rows(reopened.db,"SELECT id,class_id,state FROM candidates")==classes
                @test VS._closure_rows(reopened.db,"SELECT job_id,first_x,next_x,total_x,capped FROM chunks")==envelopes
                @test VS.closure_verify_segments(reopened.db,run;full=true)["rows"]==1
                @test VS.closure_rehydrate_segments!(reopened)["rows"]==1
                @test logical(reopened.db)==before
            finally VS._closure_close(reopened) end
        end
    end
end
end
