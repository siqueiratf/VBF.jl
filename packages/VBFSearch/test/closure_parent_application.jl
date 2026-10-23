using Test,VBF,VBFSearch,SQLite
const ParentApplyVS=VBFSearch

@testset "Parent admission binds its own rowid and both construction jobs" begin
    for normalized in (false,true)
        db=SQLite.DB();ParentApplyVS._closure_create_schema(db;normalized)
        lease=open(tempname(),"w")
        s=ParentApplyVS.ClosureStore(db,"",lease,Dict{String,Any}(),1,UInt64(0))
        try
            ParentApplyVS._closure_exec(s,"PRAGMA foreign_keys=ON")
            ParentApplyVS._closure_exec(s,"CREATE TABLE parent_insert_audit(id INTEGER PRIMARY KEY)")
            ParentApplyVS._closure_exec(s,"CREATE TEMP TRIGGER audit_parent_insert AFTER INSERT ON parents BEGIN INSERT INTO parent_insert_audit VALUES(NEW.id+1000); END")
            p=ParentApplyVS.properties(gold_apn(8).lut)
            ParentApplyVS._closure_insert_candidate!(s,p)
            parent=ParentApplyVS._closure_transaction(s) do
                ParentApplyVS._closure_add_parent!(s,p["lut_sha256"],p["sigma_hash"])
            end
            @test parent==1
            row=only(ParentApplyVS._closure_rows(s,"SELECT class_id,state FROM candidates"))
            @test row["class_id"]==parent && row["state"]=="admitted"
            jobs=ParentApplyVS._closure_rows(s,"SELECT parent_id,kind,job_key,payload FROM jobs ORDER BY id")
            @test [row["parent_id"] for row in jobs]==[parent,parent]
            @test [row["kind"] for row in jobs]==["prepare_v5","switching"]
            @test [row["job_key"] for row in jobs]==["1:prepare_v5","1:switching"]
            @test all(row["payload"]==ParentApplyVS._closure_text(Dict{String,Any}()) for row in jobs)
            @test isempty(ParentApplyVS._closure_rows(s,"PRAGMA foreign_key_check"))
            child=ParentApplyVS.properties(gold_apn(8).lut .⊻ UInt8(1))
            ParentApplyVS._closure_insert_candidate!(s,child)
            ParentApplyVS._closure_exec(s,"CREATE TEMP TRIGGER reject_parent_switching BEFORE INSERT ON jobs WHEN NEW.parent_id=2 AND NEW.kind='switching' BEGIN SELECT RAISE(ABORT,'fixture parent job failure'); END")
            @test_throws Exception ParentApplyVS._closure_transaction(s) do
                ParentApplyVS._closure_add_parent!(s,child["lut_sha256"],child["sigma_hash"])
            end
            @test ParentApplyVS._closure_count(s,"SELECT COUNT(*) n FROM parents")==1
            @test ParentApplyVS._closure_count(s,"SELECT COUNT(*) n FROM jobs")==2
            @test ParentApplyVS._closure_count(s,"SELECT COUNT(*) n FROM parent_insert_audit")==1
            pending=only(ParentApplyVS._closure_rows(s,"SELECT class_id,state FROM candidates WHERE id=?",(child["lut_sha256"],)))
            @test ismissing(pending["class_id"]) && pending["state"]=="observed"
            ParentApplyVS._closure_exec(s,"DROP TRIGGER reject_parent_switching")
            next_parent=ParentApplyVS._closure_transaction(s) do
                ParentApplyVS._closure_add_parent!(s,child["lut_sha256"],child["sigma_hash"])
            end
            @test next_parent==2
            @test ParentApplyVS._closure_count(s,"SELECT COUNT(*) n FROM jobs WHERE parent_id=2")==2
            @test isempty(ParentApplyVS._closure_rows(s,"PRAGMA foreign_key_check"))
        finally
            ParentApplyVS.DiscoveryStore.close_statements!(s.statements);close(db);close(lease)
        end
    end
end
