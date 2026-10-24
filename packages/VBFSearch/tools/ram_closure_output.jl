"""Publish validated RAM state to SQLite only after mathematical workers join.

Logical RAM job IDs are preserved, so original coverage blocks and switching
witness bindings require no rewriting. Export streams one compressed frame at a
time and never materializes the full candidate or evidence corpus again.
"""
module RAMClosureOutput
using VBFSearch,TOML,Dates
using ..RAMClosureSearch
const FP=VBFSearch
const R=RAMClosureSearch
const S=R.RAMClosureStore

"""Archive the exact audited sources, inputs and RAM controllers for publication."""
function archive!(state,directory)
    identity=state.identity
    FP.DiscoveryStore.atomic_toml(joinpath(directory,"identity.toml"),identity)
    for (relative,digest) in identity["implementation"]
        source=joinpath(FP.DiscoveryInputs.ROOT,relative)
        target=joinpath(directory,"replay","workspace",relative)
        mkpath(dirname(target));cp(source,target)
        FP.DiscoveryEvidence.filehash(target)==digest || error("source changed before RAM publication")
    end
    for (i,(source,digest)) in enumerate(sort!(collect(identity["inputs"]);by=first))
        target=joinpath(directory,"replay","inputs",string(i)*"-"*basename(source))
        mkpath(dirname(target));cp(source,target)
        FP.DiscoveryEvidence.filehash(target)==digest || error("input changed before RAM publication")
    end
    controllers=Dict{String,String}()
    for name in ("ram_closure_store.jl","ram_closure_search.jl","ram_closure_output.jl",
            "closure_refill.jl","closure_operations.jl")
        source=joinpath(@__DIR__,name)
        relative=joinpath("packages","VBFSearch","tools",name)
        target=joinpath(directory,"replay","workspace",relative)
        mkpath(dirname(target));cp(source,target)
        controllers[relative]=FP.DiscoveryEvidence.filehash(target)
    end
    started=get(state.config,"ram_controller_sources",nothing)
    started===nothing && error("RAM controller startup source pins are missing")
    controllers==started || error("RAM controllers changed during computation")
    FP.DiscoveryStore.atomic_toml(joinpath(directory,"ram-controllers.toml"),controllers)
    controllers
end

"""Recreate compact verified properties without inventing unretained invariants."""
function compact_properties(row)
    p=Dict{String,Any}("lut_sha256"=>row.id,"lut_hex"=>row.lut_hex,"apn"=>row.apn,
        "quadratic"=>row.degree==2,"algebraic_degree"=>row.degree,
        "verification"=>"RAM native worker validation; original construction evidence and source retained")
    row.sigma===nothing || (p["sigma_hash"]=row.sigma)
    p
end

"""Keep actual failure diagnostics in the ordinary normalized candidate view.

Quadratic APNs already have their compact canonical row. Other observations
also need the producer's actual uniformity and any retained failure certificate.
Only serialization fields change; identity and admission columns stay fixed.
"""
function diagnostics!(store,p)
    p["apn"] && p["quadratic"] && return nothing
    FP._closure_check_result_properties(p)
    rows=FP._closure_rows(store,"SELECT lut_hex,apn,degree FROM candidates WHERE id=?",(p["lut_sha256"],))
    length(rows)==1 || error("diagnostic candidate is missing")
    row=only(rows)
    row["lut_hex"]==p["lut_hex"] && Bool(row["apn"])==p["apn"] && row["degree"]==p["algebraic_degree"] ||
        error("candidate diagnostic identity differs")
    storage=FP._closure_candidate_storage(p)
    template=FP._closure_template!(store,storage.body)
    FP._closure_exec(store,"UPDATE closure_candidates SET template_id=?,ortho=?,encoding=? WHERE id=?",
        (template,hex2bytes(storage.ortho),Int(storage.encoded),p["lut_sha256"]))
    nothing
end

"""Persist already checked observation evidence, preserving its logical job binding."""
function path!(store,parent,job,kind,record)
    p=record["properties"];child=p["lut_sha256"]
    diagnostics!(store,p)
    FP._closure_exec(store,FP._CLOSURE_PATH_INSERT_SQL,
        (parent,job,kind,String(record["cursor"]),child,FP._closure_text(record["witness"])))
    if p["apn"] && p["quadratic"]
        # Preadmitted roots need no classification job. Every other observed
        # quadratic candidate has one canonical job, irrespective of multiplicity.
        root=FP._closure_count(store,"SELECT EXISTS(SELECT 1 FROM parents WHERE candidate_id=? AND origin='root') n",(child,))
        if root==0
            FP._closure_add_job!(store,parent,"deduplicate","deduplicate:$child",Dict("candidate_id"=>child))
        end
    end
end

"""Write one final standard search database; no worker receives this store."""
function write_database(result,config;on_progress=_->nothing)
    state=result.state;directory=abspath(config["run"])
    mkpath(directory);path=joinpath(directory,"closure.sqlite")
    ispath(path) && error("RAM publication refuses an existing database")
    controllers=archive!(state,directory)
    lease=FP._closure_lease(directory);db=FP.SQLite.DB(path)
    store=FP.ClosureStore(db,directory,lease,state.identity,1,UInt64(0))
    started=time();counts=Dict("candidates"=>0,"parents"=>0,"frames"=>0,"paths"=>0)
    try
        FP._closure_exec(store,"PRAGMA journal_mode=WAL")
        FP._closure_exec(store,"PRAGMA synchronous=FULL")
        FP._closure_exec(store,"PRAGMA foreign_keys=ON")
        FP._closure_create_schema(db;normalized=true)
        FP._closure_exec(store,"CREATE TABLE ram_unapplied_frames(job_id INTEGER,kind TEXT,raw_bytes INTEGER,sha256 TEXT,evidence BLOB)")
        FP._closure_transaction(store) do
            for (key,value) in (("identity",FP._closure_text(state.identity)),("created_utc",FP._closure_now()),
                    ("dispatch_sequence","0"),("origin_turn","root"),("method_turn","v5"),
                    ("ledger_encoding","VBFCHN02"),("ram_controller_sources",FP._closure_text(controllers)))
                FP._closure_exec(store,"INSERT INTO metadata VALUES(?,?)",(key,value))
            end
            FP._closure_exec(store,"INSERT INTO metadata VALUES('property_record_format','ram-compact-properties-v1')")
            FP._closure_exec(store,"INSERT INTO sessions(id,started,finished,heartbeat,pid,host,state,budgets) VALUES(1,?,?,?,?,?,?,?)",
                (Dates.format(Dates.unix2datetime(state.started),dateformat"yyyy-mm-ddTHH:MM:SS.sss")*"Z",FP._closure_now(),FP._closure_now(),getpid(),Base.gethostname(),
                    String(result.report["state"]),FP._closure_text(config)))
            for row in S.candidate_rows(result.store)
                FP._closure_insert_candidate!(store,compact_properties(row);state=row.state)
                counts["candidates"]+=1
                counts["candidates"]%100_000==0 && on_progress(copy(counts))
            end
            for row in S.class_rows(result.store)
                FP._closure_exec(store,"INSERT INTO parents(id,candidate_id,sigma,origin,source,admitted_utc) VALUES(?,?,?,?,?,?)",
                    (row.id,row.candidate_id,row.sigma,row.origin,row.source,row.admitted_utc))
                counts["parents"]+=1
            end
            for row in S.candidate_rows(result.store)
                row.class_id==0 || FP._closure_candidate_state!(store,row.id,row.state;class_id=row.class_id)
            end
            for row in R.job_rows(state)
                direction=row.kind=="v5" && row.status!="done" ? 1 : row.direction
                status=row.status=="pending" && direction>1 ? "paused" : row.status
                FP._closure_exec(store,"INSERT INTO jobs(id,parent_id,kind,job_key,payload,status,direction,combination,last_session) VALUES(?,?,?,?,?,?,?,?,1)",
                    (row.id,row.parent_id,row.kind,row.job_key,FP._closure_text(row.payload),status,direction,row.combination))
            end
            for entry in R.evidence_frames(state)
                if !entry.applied
                    f=entry.frame
                    FP._closure_exec(store,"INSERT INTO ram_unapplied_frames VALUES(?,?,?,?,?)",(f.job_id,String(f.kind),f.raw_bytes,f.sha256,f.bytes))
                    continue
                end
                decoded=R.decode_frame(entry.frame);packet=decoded.packet;work=decoded.work
                job=Int(packet["job_id"]);parent=Int(packet["parent_id"]);kind=String(packet["kind"])
                if kind=="v5"
                    for record in work["records"]
                        path!(store,parent,job,kind,record);counts["paths"]+=1
                    end
                    ledger=work["ledger"]
                    if ledger!==nothing
                        ledger.job_id==job || error("RAM ledger job binding differs")
                        FP._closure_exec(store,"INSERT INTO chunks VALUES(?,?,?,?,?,?)",
                            (job,ledger.first_x,ledger.next_x,ledger.total_x,ledger.capped,ledger.evidence))
                    end
                elseif kind=="switching"
                    for event in work["events"]
                        if event["event"]=="kernel"
                            FP._closure_exec(store,"INSERT OR IGNORE INTO kernels VALUES(?,?,?,?)",
                                (job,event["direction"],event["dimension"],FP._closure_text(event["evidence"])))
                        elseif event["event"]=="candidate_complete"
                            path!(store,parent,job,kind,event);counts["paths"]+=1
                            FP._closure_exec(store,"INSERT INTO evaluations VALUES(?,?,?,?,?)",
                                (job,event["direction"],event["combination"],event["properties"]["lut_sha256"],Int(event["properties"]["apn"])))
                        end
                    end
                end
                if get(work,"proof",nothing)!==nothing
                    FP._closure_exec(store,"UPDATE jobs SET result=? WHERE id=?",(FP._closure_text(work["proof"]),job))
                end
                counts["frames"]+=1
                counts["frames"]%10_000==0 && on_progress(copy(counts))
            end
            # Unexpanded representatives have implicit jobs in RAM. Materialize
            # those descriptors only in this final distributable snapshot.
            for row in S.class_rows(result.store)
                FP._closure_add_job!(store,row.id,"prepare_v5","$(row.id):prepare_v5",Dict{String,Any}())
                FP._closure_add_job!(store,row.id,"switching","$(row.id):switching",Dict{String,Any}())
            end
            for row in S.comparison_rows(result.store)
                FP._closure_insert_comparison!(store,row.candidate_id,row.target_parent,row.proof)
            end
            FP._closure_exec(store,"""UPDATE jobs SET status='done',result=(
                SELECT CASE WHEN c.state='admitted'
                    THEN printf('promoted_parent = %d\ndescendant_profile_filter = "none"\n',c.class_id)
                    ELSE printf('verified_equivalent_parent = %d\n',c.class_id) END
                FROM candidates c WHERE c.id=substr(jobs.job_key,13))
                WHERE kind='deduplicate' AND substr(job_key,13) IN (SELECT id FROM candidates WHERE class_id IS NOT NULL)""")
            FP._closure_exec(store,"UPDATE jobs SET status='paused',result=? WHERE kind='deduplicate' AND substr(job_key,13) IN (SELECT id FROM candidates WHERE class_id IS NULL)",
                (FP._closure_text(Dict("unresolved_equivalence"=>true)),))
            for row in R.job_rows(state)
                row.kind=="switching" && row.status=="done" || continue
                count=FP._closure_count(store,"SELECT COUNT(*) n FROM evaluations WHERE job_id=?",(row.id,))
                proof=Dict("evaluations"=>count,"next_direction"=>256,"next_combination"=>"1","stop"=>"none","scope"=>"complete RAM logical job")
                FP._closure_exec(store,"UPDATE jobs SET result=? WHERE id=?",(FP._closure_text(proof),row.id))
            end
            FP._closure_exec(store,"INSERT INTO metadata VALUES('initialization_complete','true')")
            FP._closure_exec(store,"INSERT INTO metadata VALUES('ram_execution',?)",(String(FP.JSON3.write(result.report)),))
        end
        isempty(FP._closure_rows(store,"PRAGMA foreign_key_check")) || error("RAM export foreign key mismatch")
        only(FP._closure_rows(store,"PRAGMA quick_check"))["quick_check"]=="ok" || error("RAM export SQLite integrity mismatch")
        FP.DiscoveryStore.atomic_toml(joinpath(directory,"progress.toml"),Dict("state"=>result.report["state"],"ram_execution"=>true))
    finally
        FP._closure_close(store)
    end
    receipt=Dict("seconds"=>time()-started,"bytes"=>filesize(path),"counts"=>counts)
    result.report["final_export"]=receipt
    receipt
end
end
