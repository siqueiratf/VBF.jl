module ClosureCompletionTests
using Test,VBFSearch
include(joinpath(@__DIR__,"..","tools","closure_completion.jl"))
include(joinpath(@__DIR__,"..","tools","closure_continuous.jl"))
const C=ClosureCompletion
const FP=VBFSearch
const Controller=ContinuousSeedSearch

"""Keep synthetic persistence fixtures within ordinary transport identity checks."""
fixture_lut(i)=lpad(string(i),512,'0')
"""Bind each synthetic fixture identifier to its exact LUT bytes."""
fixture_id(i)=FP.DiscoveryEvidence.lut_id(hex2bytes(fixture_lut(i)))

"""Compare every tracked counter with the original independent SQL predicate."""
function check_exact(tracker)
    s=tracker.store
    counters=FP._closure_rows(s,"SELECT * FROM temp.closure_completion_parents ORDER BY parent_id")
    for row in counters
        parent=row["parent_id"]
        @test row["unfinished_jobs"]==FP._closure_count(s,"SELECT COUNT(*) n FROM jobs WHERE parent_id=? AND kind IN ('prepare_v5','v5','switching') AND status!='done'",(parent,))
        @test row["unresolved_paths"]==FP._closure_count(s,"SELECT COUNT(*) n FROM paths p JOIN candidates c ON c.id=p.child_id WHERE p.job_id IN (SELECT id FROM jobs WHERE parent_id=? AND kind IN ('prepare_v5','v5','switching')) AND c.apn=1 AND c.degree=2 AND c.class_id IS NULL",(parent,))
    end
    if FP.SQLite.intransaction(s.db)
        @test isempty(C.ready(tracker))
    else
        @test C.ready(tracker)==Int[row["parent_id"] for row in counters if row["unfinished_jobs"]==row["unresolved_paths"]==0]
    end
    nothing
end

"""Small real schemas exercise both normalized physical and legacy view writes."""
function fixture(f;normalized=false)
    mktempdir() do directory
        db=FP.SQLite.DB();FP._closure_create_schema(db;normalized)
        lease=FP._closure_lease(directory);s=FP.ClosureStore(db,directory,lease,Dict{String,Any}(),0,UInt64(0))
        try
            FP._closure_exec(s,"PRAGMA foreign_keys=ON")
            for i in 1:8
                p=Dict{String,Any}("lut_sha256"=>fixture_id(i),"lut_hex"=>fixture_lut(i),
                    "sigma_hash"=>"fixture","apn"=>true,"algebraic_degree"=>2,"ortho_lut_hex"=>"")
                FP._closure_insert_candidate!(s,p)
                i<=3 && FP._closure_add_parent!(s,p["lut_sha256"],"fixture";origin="root")
            end
            f(s)
        finally
            FP.DiscoveryStore.close_statements!(s.statements);close(db);close(lease)
        end
    end
end

@testset "Completion counters backfill cohorts and follow shared exact children" begin
    for normalized in (false,true)
        fixture(;normalized) do s
            execute(sql,args=())=FP._closure_exec(s,sql,args)
            child(i)=fixture_id(i)
            job(parent,kind="switching")=Int(only(FP._closure_rows(s,"SELECT id FROM jobs WHERE parent_id=? AND kind=?",(parent,kind)))["id"])
            function path(parent,i,cursor;kind="switching",reported_parent=parent)
                execute("INSERT OR IGNORE INTO paths(parent_id,job_id,method,cursor,child_id,witness) VALUES(?,?,?,?,?,?)",(reported_parent,job(parent,kind),kind,string(cursor),child(i),"fixture"))
            end
            path(1,4,1);path(1,4,2);path(2,4,1);path(3,4,1)
            path(1,1,3);path(2,5,2)
            tracker=C.install!(s);C.track!(tracker,[1,2]);check_exact(tracker)
            @test C.snapshot(tracker)["tracked_parents"]==2
            @test C.snapshot(tracker)["unresolved_paths"]==4
            @test C.snapshot(tracker)["temp_allocated_bytes"]>0
            @test C.snapshot(tracker)["temp_store"] in (0,1,2)
            @test isempty(FP._closure_rows(s,"SELECT name FROM main.sqlite_master WHERE name LIKE 'closure_completion_%'"))
            before=FP._closure_rows(s,"SELECT * FROM temp.closure_completion_edges ORDER BY child_id,parent_id")
            C.track!(tracker,[1,2]);@test FP._closure_rows(s,"SELECT * FROM temp.closure_completion_edges ORDER BY child_id,parent_id")==before
            execute("UPDATE jobs SET status='done' WHERE parent_id IN (1,2)")
            check_exact(tracker);@test isempty(C.ready(tracker))
            execute("UPDATE candidates SET state='awaiting_equivalence' WHERE id=?",(child(4),))
            check_exact(tracker);@test isempty(C.ready(tracker))
            execute("UPDATE candidates SET class_id=1,state='equivalent' WHERE id=?",(child(4),))
            check_exact(tracker);@test C.ready(tracker)==[1]
            execute("UPDATE candidates SET class_id=1,state='equivalent' WHERE id=?",(child(5),))
            check_exact(tracker);@test C.ready(tracker)==[1,2]
            C.release!(tracker,[1]);check_exact(tracker)
            @test C.snapshot(tracker)["tracked_parents"]==1
            @test FP._closure_count(s,"SELECT COUNT(*) n FROM temp.closure_completion_edges WHERE parent_id=1")==0
            C.track!(tracker,[3]);check_exact(tracker)
            @test C.snapshot(tracker)["tracked_parents"]==2
            execute("UPDATE jobs SET status='done' WHERE parent_id=3")
            @test C.ready(tracker)==[2,3]
            execute("UPDATE candidates SET class_id=NULL,state='awaiting_equivalence' WHERE id=?",(child(4),))
            check_exact(tracker);@test isempty(C.ready(tracker))
            physical=normalized ? "closure_candidates" : "candidates"
            execute("UPDATE $physical SET apn=0 WHERE id=?",(child(4),));check_exact(tracker)
            @test C.ready(tracker)==[2,3]
            execute("UPDATE $physical SET apn=1,degree=3 WHERE id=?",(child(4),));check_exact(tracker)
            @test C.ready(tracker)==[2,3]
            execute("UPDATE $physical SET degree=2 WHERE id=?",(child(4),));check_exact(tracker)
            @test isempty(C.ready(tracker))
            path(2,4,1);check_exact(tracker)
            path(2,4,3;reported_parent=3);check_exact(tracker)
            @test C.snapshot(tracker)["unresolved_paths"]==3
            execute("DELETE FROM paths WHERE job_id=? AND cursor='3'",(job(2),));check_exact(tracker)
            execute("UPDATE paths SET child_id=? WHERE job_id=? AND cursor='1'",(child(5),job(2)));check_exact(tracker)
            @test C.ready(tracker)==[2]
            execute("UPDATE paths SET job_id=?,parent_id=3 WHERE job_id=? AND cursor='2'",(job(3),job(2)));check_exact(tracker)
            execute("UPDATE jobs SET status='failed' WHERE id=?",(job(2),));check_exact(tracker)
            @test isempty(C.ready(tracker))
            execute("UPDATE jobs SET status='paused' WHERE id=?",(job(2),));check_exact(tracker)
            execute("UPDATE jobs SET status='done' WHERE id=?",(job(2),));check_exact(tracker)
            @test C.ready(tracker)==[2]
            C.release!(tracker,[2,3]);@test C.snapshot(tracker)["tracked_parents"]==0
            @test FP._closure_count(s,"SELECT COUNT(*) n FROM temp.closure_completion_edges")==0
        end
    end
end

@testset "Completion state obeys admission savepoints and failed coordinator commits" begin
    for normalized in (false,true)
        fixture(;normalized) do s
            execute(sql,args=())=FP._closure_exec(s,sql,args)
            child=fixture_id(4)
            job=Int(only(FP._closure_rows(s,"SELECT id FROM jobs WHERE parent_id=1 AND kind='switching'"))["id"])
            tracker=C.install!(s);C.track!(tracker,[1]);check_exact(tracker)
            before=FP._closure_rows(s,"SELECT * FROM temp.closure_completion_parents")
            execute("BEGIN IMMEDIATE");execute("SAVEPOINT packet")
            execute("INSERT INTO paths(parent_id,job_id,method,cursor,child_id,witness) VALUES(1,?,'switching','1',?,'fixture')",(job,child))
            execute("UPDATE jobs SET status='done' WHERE parent_id=1")
            execute("UPDATE candidates SET class_id=1,state='equivalent' WHERE id=?",(child,))
            check_exact(tracker);@test isempty(C.ready(tracker))
            execute("ROLLBACK TO packet");execute("RELEASE packet")
            @test FP._closure_rows(s,"SELECT * FROM temp.closure_completion_parents")==before
            @test FP._closure_count(s,"SELECT COUNT(*) n FROM temp.closure_completion_edges")==0
            check_exact(tracker)
            C.track!(tracker,[2,3]);check_exact(tracker)
            execute("ROLLBACK")
            @test C.snapshot(tracker)["tracked_parents"]==1
            check_exact(tracker)
            execute("BEGIN IMMEDIATE")
            execute("INSERT INTO paths(parent_id,job_id,method,cursor,child_id,witness) VALUES(1,?,'switching','1',?,'fixture')",(job,child))
            execute("UPDATE jobs SET status='done' WHERE parent_id=1")
            execute("SAVEPOINT failing_packet")
            execute("UPDATE candidates SET class_id=1,state='equivalent' WHERE id=?",(child,))
            execute("ROLLBACK TO failing_packet");execute("RELEASE failing_packet");execute("COMMIT")
            check_exact(tracker);@test isempty(C.ready(tracker))
            execute("UPDATE candidates SET class_id=1,state='equivalent' WHERE id=?",(child,))
            check_exact(tracker);@test C.ready(tracker)==[1]
            execute("BEGIN IMMEDIATE");C.release!(tracker,[1]);execute("ROLLBACK")
            check_exact(tracker);@test C.ready(tracker)==[1]
            C.track!(tracker,[2])
            execute("UPDATE jobs SET parent_id=2,kind='v5',status='paused' WHERE id=?",(job,));check_exact(tracker)
            execute("UPDATE jobs SET kind='deduplicate',status='done' WHERE id=?",(job,));check_exact(tracker)
            execute("DELETE FROM paths WHERE job_id=?",(job,));execute("DELETE FROM jobs WHERE id=?",(job,));check_exact(tracker)
            execute("INSERT INTO jobs(parent_id,kind,job_key,payload,status) VALUES(1,'v5','new-space','fixture','paused')")
            check_exact(tracker);@test !(1 in C.ready(tracker))
            @test C.snapshot(tracker)["backfill_calls"]>=3
            @test C.snapshot(tracker)["check_calls"]>0
        end
    end
end

@testset "Fallback admission selection preserves construction timing baselines" begin
    root=Dict("id"=>7,"origin"=>"root","source"=>"timing-fixture")
    jobs=[Dict{String,Any}("parent_id"=>7,"kind"=>"v5","direction"=>33,"status"=>"paused"),
        Dict{String,Any}("parent_id"=>7,"kind"=>"prepare_v5","direction"=>1,"status"=>"done"),
        Dict{String,Any}("parent_id"=>7,"kind"=>"switching","direction"=>256,"status"=>"done")]
    timings=Dict{Int,Dict{String,Any}}()
    original=Controller.seed_timing!(timings,root,jobs)
    original["first_dispatch_epoch"]=100.0;original["construction_task_seconds"]=2.5
    saved=deepcopy(original)
    @test Controller.seed_timing!(timings,root,Any[];preserve_existing=true)===original
    @test timings[7]==saved
    @test timings[7]["previous_cosets"]==32 && timings[7]["first_dispatch_epoch"]==100.0
    other=merge(root,Dict("id"=>8))
    @test Controller.seed_timing!(timings,other,Any[];preserve_existing=true)["parent_id"]==8
    @test timings[8]["previous_cosets"]==0
    jobs[1]["direction"]=65
    replaced=Controller.seed_timing!(timings,root,jobs)
    @test replaced!==original && replaced["previous_cosets"]==64
    @test !haskey(replaced,"first_dispatch_epoch")
end

@testset "Batched V5 shared children and TEMP completion counters roll back together" begin
    for normalized in (false,true), native in (false,true)
        fixture(;normalized) do s
            execute(sql,args=())=FP._closure_exec(s,sql,args)
            child(i)=fixture_id(i)
            function properties(i)
                Dict{String,Any}("lut_sha256"=>child(i),"lut_hex"=>fixture_lut(i),
                    "sigma_hash"=>"fixture","apn"=>true,"quadratic"=>true,
                    "differential_uniformity"=>2,"algebraic_degree"=>2,"ortho_lut_hex"=>"")
            end
            function records(n;offset=0,third=false)
                [begin
                    p=properties(third && i==1 ? 10 : isodd(i) ? 4 : 9)
                    w=Dict{String,Any}("output"=>i,"forms"=>[1,2,3],"reject"=>false)
                    Dict{String,Any}("properties"=>native ? FP._ClosurePreparedCandidate(p) : p,
                        "cursor"=>string(offset+i),"witness"=>native ? FP._ClosurePreparedWitness(w) : w)
                end for i in 1:n]
            end
            for parent in (1,2)
                execute("INSERT INTO jobs(parent_id,kind,job_key,payload) VALUES(?,'v5',?,'fixture')",(parent,"$parent:v5:fixture"))
            end
            jobs=[only(FP._closure_rows(s,"SELECT * FROM jobs WHERE parent_id=? AND kind='v5'",(parent,))) for parent in (1,2)]
            tracker=C.install!(s);C.track!(tracker,[1,2])
            FP._closure_transaction(s) do
                FP._closure_record_v5_candidates!(s,jobs[1],records(80))
                FP._closure_record_v5_candidates!(s,jobs[2],records(17))
                execute("UPDATE jobs SET status='done' WHERE parent_id IN (1,2) AND kind IN ('prepare_v5','v5','switching')")
            end
            check_exact(tracker)
            @test C.snapshot(tracker)["unresolved_paths"]==97
            @test FP._closure_count(s,"SELECT COUNT(*) n FROM jobs WHERE kind='deduplicate'")==2
            @test all(row["parent_id"]==1 for row in FP._closure_rows(s,"SELECT parent_id FROM jobs WHERE kind='deduplicate'"))
            execute("UPDATE candidates SET class_id=1,state='equivalent' WHERE id=?",(child(4),))
            check_exact(tracker)
            @test C.snapshot(tracker)["unresolved_paths"]==48
            execute("UPDATE jobs SET status='paused' WHERE id=?",(jobs[1]["id"],))
            tables=normalized ? ("candidates","jobs","paths","closure_candidates","closure_templates") : ("candidates","jobs","paths")
            science()=Dict(table=>FP._closure_rows(s,"SELECT * FROM $table ORDER BY 1") for table in tables)
            counters()=Dict(table=>FP._closure_rows(s,"SELECT * FROM temp.$table ORDER BY 1,2") for table in ("closure_completion_parents","closure_completion_edges"))
            before_science=science();before_counters=counters()
            broken=records(70;offset=1000,third=true)
            witness=Dict{String,Any}("reject"=>true)
            broken[end]["witness"]=native ? FP._ClosurePreparedWitness(witness) : witness
            execute("CREATE TEMP TRIGGER reject_late_v5_path BEFORE INSERT ON paths WHEN NEW.cursor='1070' AND NEW.witness LIKE '%reject = true%' BEGIN SELECT RAISE(ABORT,'fixture late V5 failure'); END")
            failure=try
                Controller.closure_coordinator_step!(s.db;execute_control=execute) do
                    Controller.closure_apply_savepoint!(s.db;execute_control=execute) do
                        FP._closure_record_v5_candidates!(s,jobs[1],broken)
                    end
                end
                nothing
            catch error
                error
            end
            @test failure isa Exception
            @test occursin("fixture late V5 failure",sprint(showerror,failure))
            @test isequal(science(),before_science)
            @test isequal(counters(),before_counters)
            @test !FP.SQLite.intransaction(s.db)
            @test isempty(FP._closure_rows(s,"PRAGMA foreign_key_check"))
            check_exact(tracker)
            execute("DROP TRIGGER reject_late_v5_path")
            Controller.closure_coordinator_step!(s.db;execute_control=execute) do
                Controller.closure_apply_savepoint!(s.db;execute_control=execute) do
                    FP._closure_record_v5_candidates!(s,jobs[1],broken)
                    execute("UPDATE jobs SET status='done' WHERE id=?",(jobs[1]["id"],))
                end
            end
            check_exact(tracker)
            @test FP._closure_count(s,"SELECT COUNT(*) n FROM paths")==167
            @test FP._closure_count(s,"SELECT COUNT(*) n FROM jobs WHERE kind='deduplicate'")==3
            execute("UPDATE candidates SET class_id=1,state='equivalent' WHERE id IN (?,?)",(child(9),child(10)))
            check_exact(tracker);@test C.ready(tracker)==[1,2]
        end
    end
end
end
