"""Bounded real-packet coordinator profile; writes only a disposable tiny fixture."""
module CoordinatorApplyProfile
using VBF,VBFSearch,JSON3,SHA,Dates,Profile,Statistics,SQLite
include("closure_worker_integration_audit.jl")
const VS=VBFSearch
const Q=VBF.QuadraticExtensions
sha(path)=bytes2hex(open(SHA.sha256,path))

function snapshot(s)
    Dict(table=>VS._closure_rows(s.db,"SELECT * FROM $table ORDER BY rowid") for table in
        ("candidates","parents","jobs","paths","chunks","evaluations","kernels","comparisons"))
end

function measure(f)
    t=@timed f()
    Dict("seconds"=>t.time,"allocated_bytes"=>t.bytes,"gc_seconds"=>t.gctime)
end

function reset!(s,job,root)
    VS._closure_transaction(s) do
        VS._closure_exec(s.db,"DELETE FROM paths WHERE job_id=?",(job["id"],))
        VS._closure_exec(s.db,"DELETE FROM chunks WHERE job_id=?",(job["id"],))
        VS._closure_exec(s.db,"DELETE FROM jobs WHERE kind='deduplicate'")
        VS._closure_exec(s.db,"DELETE FROM candidates WHERE id!=?",(root,))
        VS._closure_exec(s.db,"UPDATE jobs SET direction=1,status='pending',result='',error='' WHERE id=?",(job["id"],))
    end
end

function run(holdout_path,parents_path,out;repeats=8,max_seconds=115.0)
    started=time();mkpath(out)
    inputs=Dict(p=>sha(p) for p in (holdout_path,parents_path))
    sources=Dict(name=>joinpath(dirname(pathof(VS)),name) for name in
        ("closure_algorithms.jl","closure_ledger.jl","closure_coset_proofs.jl","closure_store.jl"))
    before=Dict(k=>sha(v) for (k,v) in sources)
    holdout=JSON3.read(read(holdout_path,String));holdout["complete"] || error("incomplete holdout")
    records=[first(holdout["records"])]
    parents=Dict(Int(p["parent_id"])=>p for p in JSON3.read(read(parents_path,String))["parents"])
    s,jobs=ClosureWorkerIntegrationAudit.fixture(joinpath(out,"isolated-fixture"),records,parents)
    try
        job=only(jobs);packet=VS._closure_work_packet(s,job)
        table=Q.PackedPolarRankTable(Q.geometry(8));context=VS.ClosureWorkContext(;rank_table=table)
        result=VS._closure_compute(packet;context,seconds=60,evaluations=256)
        result["work"]["done"] || error("full real packet did not exhaust")
        base=snapshot(s);root=packet["parent"]["lut_sha256"]
        # Compile actual validation and candidate insertion inside a rolled-back transaction.
        VS._closure_exec(s.db,"BEGIN IMMEDIATE")
        VS._closure_apply!(s,job,result)
        committed=snapshot(s)
        VS._closure_exec(s.db,"ROLLBACK")
        isequal(snapshot(s),base) || error("warmup rollback changed fixture")
        println(JSON3.write(Dict("event"=>"warmup_complete","cosets"=>length(result["work"]["chunks"]),
            "candidate_records"=>length(result["work"]["records"]),"elapsed_seconds"=>time()-started)));flush(stdout)

        rows=Any[]
        for rep in 1:repeats
            time()-started<max_seconds || error("bounded apply profile timed out")
            begin_t=measure(()->VS._closure_exec(s.db,"BEGIN IMMEDIATE"))
            body_t=measure(()->VS._closure_apply!(s,job,result))
            commit_t=measure(()->VS._closure_exec(s.db,"COMMIT"))
            isequal(snapshot(s),committed) || error("durable apply persisted different rows")
            reset!(s,job,root);isequal(snapshot(s),base) || error("fixture reset differs")
            full_t=measure(()->VS._closure_apply!(s,job,result))
            isequal(snapshot(s),committed) || error("full apply persisted different rows")
            push!(rows,Dict("repeat"=>rep,"begin"=>begin_t,"validation_and_sql_body"=>body_t,
                "durable_commit"=>commit_t,"full_atomic_apply"=>full_t))
            reset!(s,job,root);isequal(snapshot(s),base) || error("fixture reset differs")
        end

        Profile.clear();Profile.init(;delay=0.0005)
        Profile.@profile for _ in 1:12
            VS._closure_exec(s.db,"BEGIN IMMEDIATE")
            VS._closure_apply!(s,job,result)
            VS._closure_exec(s.db,"ROLLBACK")
        end
        open(joinpath(out,"profile-tree.txt"),"w") do io
            Profile.print(io;format=:tree,mincount=2,C=false)
        end
        open(joinpath(out,"profile-flat.txt"),"w") do io
            Profile.print(io;format=:flat,sortedby=:count,mincount=2,C=false)
        end
        isequal(snapshot(s),base) || error("profiling rollback changed fixture")

        # This rejects after candidate/path insertion, ledger insertion and cursor UPDATE.
        bad=copy(result);badwork=copy(result["work"]);badwork["done"]=false;bad["work"]=badwork
        rejected=false
        try VS._closure_apply!(s,job,bad) catch e
            occursin("extension completion flag mismatch",sprint(showerror,e)) || rethrow()
            rejected=true
        end
        rejected && isequal(snapshot(s),base) || error("late failure was not atomic")
        report=Dict("schema"=>"coordinator-apply-profile-v1","created_utc"=>string(now(UTC))*"Z",
            "threads"=>Threads.nthreads(),"source_hashes"=>before,
            "sources_unchanged"=>before==Dict(k=>sha(v) for (k,v) in sources),"inputs"=>inputs,
            "parent_id"=>Int(first(records)["parent_id"]),"processed_cosets"=>result["work"]["processed_cosets"],
            "candidate_records"=>length(result["work"]["records"]),"ledger_bytes"=>sizeof(result["work"]["ledger"].evidence),
            "record_timings"=>rows,"median_atomic_seconds"=>median(r["full_atomic_apply"]["seconds"] for r in rows),
            "median_body_seconds"=>median(r["validation_and_sql_body"]["seconds"] for r in rows),
            "median_commit_seconds"=>median(r["durable_commit"]["seconds"] for r in rows),
            "late_failure_atomicity"=>true,"all_persisted_rows_exact"=>true,"elapsed_seconds"=>time()-started,
            "scope"=>"One real complete V5 packet; fresh disposable WAL/FULL fixture; no campaign read/write or EA execution; tiny-index timings do not extrapolate to full campaign.")
        write(joinpath(out,"report.json"),JSON3.write(report));println(JSON3.write(report));flush(stdout)
        report
    finally
        VS._closure_close(s)
    end
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==3 || error("usage: coordinator_apply_profile HOLDOUT PARENTS NEW_OUT")
    run(ARGS...)
end
end
