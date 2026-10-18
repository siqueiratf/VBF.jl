module FocusedParentPass
using VBFSearch,TOML,SHA
const FP=VBFSearch
include("closure_baseline.jl")
const _closure_rows=FP._closure_rows
const _closure_count=FP._closure_count

"""Finish one saved parent's own construction jobs using its archived library.

The ordinary identity/cursor gate remains in force. New representatives receive
pending construction jobs, but only the selected parent's jobs are executed.
Positive EA witnesses are replayed by the existing admission API.
"""
function run(config)
    parent=Int(config["parent_id"]);directory=abspath(config["run"]);out=abspath(config["evidence"])
    ispath(out) && error("evidence directory must be new")
    mkpath(out)
    helper=abspath(config["seed_progress_helper"])
    seed_reporter=Base.include(@__MODULE__,helper)
    seed_summary(db)=Base.invokelatest(seed_reporter,db)
    cp(@__FILE__,joinpath(out,"controller.jl"))
    cp(joinpath(@__DIR__,"closure_baseline.jl"),joinpath(out,"baseline-controller.jl"))
    cp(helper,joinpath(out,"seed-progress-helper.jl"))
    FP.DiscoveryStore.atomic_toml(joinpath(out,"config.toml"),config)
    base=TOML.parsefile(joinpath(directory,"progress.toml"))
    FP.DiscoveryStore.atomic_toml(joinpath(out,"progress-before.toml"),base)
    deadline=time()+Float64(get(config,"duration_seconds",21600.0));started=time()
    state="failed";s=nothing;tasks=Task[];processed=0;evaluated=0;last_report=0.0
    before_jobs=Any[];before_paths=0;before_seed=nothing;baseline=nothing;contexts=Dict{Int,Any}()
    stop_path=joinpath(directory,"STOP");prior_stop=isfile(stop_path) ? read(stop_path) : nothing
    external=FP._closure_stop_poller(stop_path,joinpath(out,"STOP"))
    stopped()=external() || time()>=deadline
    construction()=FP._closure_rows(s.db,"SELECT * FROM jobs WHERE parent_id=? AND kind IN ('prepare_v5','v5','switching') ORDER BY id",(parent,))
    count_status(rows,kinds,status)=count(j->j["kind"] in kinds && j["status"]==status,rows)
    paths()=FP._closure_count(s.db,"SELECT COUNT(*) n FROM paths WHERE job_id IN (SELECT id FROM jobs WHERE parent_id=? AND kind IN ('prepare_v5','v5','switching'))",(parent,))
    function publish!(;force=false,finished=false)
        !force && time()-last_report<5 && return
        now=FP._closure_now();jobs=construction();seed=seed_summary(s.db)
        report=deepcopy(base)
        report["running"]=!finished;report["state"]=finished ? state : "running"
        report["updated_utc"]=now;report["heartbeat_utc"]=now;report["heartbeat_stale"]=false;report["heartbeat_age_seconds"]=0.0
        report["seed_progress"]=seed
        for (key,sql) in (("total_parents","SELECT COUNT(*) n FROM parents"),("promoted_parents","SELECT COUNT(*) n FROM parents WHERE origin='discovered'"),
            ("exact_luts","SELECT COUNT(*) n FROM candidates"),("quadratic_apn_luts","SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2"),
            ("unresolved_equivalence","SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2 AND class_id IS NULL"),
            ("signature_buckets","SELECT COUNT(DISTINCT sigma) n FROM candidates WHERE apn=1 AND degree=2"))
            report[key]=FP._closure_count(s.db,sql)
        end
        newparents=report["total_parents"]-base["total_parents"]
        for (name,kinds) in (("v5",("prepare_v5","v5")),("switching",("switching",)))
            method=report["methods"][name]
            for status in ("pending","paused","running","done","failed","blocked")
                method["jobs_"*status]+=count_status(jobs,kinds,status)-count_status(before_jobs,kinds,status)+(status=="pending" ? newparents : 0)
            end
            oldcomplete=all(j->j["status"]=="done",filter(j->j["kind"] in kinds,before_jobs))
            complete=all(j->j["status"]=="done",filter(j->j["kind"] in kinds,jobs))
            method["parents_completed"]+=Int(complete)-Int(oldcomplete)
        end
        report["methods"]["v5"]["parents_prepared"]+=count_status(jobs,("prepare_v5",),"done")-count_status(before_jobs,("prepare_v5",),"done")
        cosets(rows)=sum(max(0,Int(j["direction"])-1) for j in rows if j["kind"]=="v5";init=0)
        report["methods"]["v5"]["cosets_checked"]+=cosets(jobs)-cosets(before_jobs)
        addedpaths=paths()-before_paths
        report["construction_paths"]+=addedpaths;report["methods"]["v5"]["candidates"]+=addedpaths
        complete=all(j->j["status"]=="done",jobs)
        report["completed_parents"]+=Int(complete)-Int(all(j->j["status"]=="done",before_jobs))
        report["active_parents"]=Int(any(j->j["status"]=="running",jobs))
        report["queued_parents"]=max(0,report["total_parents"]-report["completed_parents"]-report["active_parents"]-report["blocked_parents"])
        cluster=report["cluster"]
        cluster["enabled"]=false;cluster["workers"]=Any[]
        cluster["verified_equivalent_luts"]=FP._closure_count(s.db,"SELECT COUNT(*) n FROM candidates WHERE state='equivalent'")
        FP._closure_exec(s.db,"UPDATE sessions SET heartbeat=?,jobs=?,evaluations=? WHERE id=?",(now,processed,evaluated,s.session))
        row=only(FP._closure_rows(s.db,"SELECT id,started,finished,heartbeat,pid,host,state,jobs,evaluations FROM sessions WHERE id=?",(s.session,)))
        report["sessions"]=vcat([row],base["sessions"])
        report["parent_completion"]=Dict("parent_id"=>parent,"complete"=>complete,"processed_packets"=>processed,"elapsed_seconds"=>time()-started,"scope"=>"selected parent construction and classification only; no descendant expansion")
        FP.DiscoveryStore.atomic_toml(joinpath(directory,"progress.toml"),report)
        payload=Dict("state"=>report["state"],"running"=>!finished,"parent_id"=>parent,"complete"=>complete,
            "session_id"=>s.session,"pid"=>getpid(),"processed_packets"=>processed,"elapsed_seconds"=>time()-started,
            "seed_progress"=>seed,"unresolved_equivalence"=>report["unresolved_equivalence"],"total_parents"=>report["total_parents"],
            "exact_luts"=>report["exact_luts"],"target_jobs"=>[Dict(k=>j[k] for k in ("id","kind","status","direction","combination")) for j in jobs])
        path=joinpath(out,"progress.json");write(path*".tmp",FP.JSON3.write(payload));mv(path*".tmp",path;force=true)
        println(FP.JSON3.write(payload));flush(stdout);last_report=time()
    end
    function compute_batch(jobs;equivalence=false)
        items=Any[];empty!(tasks)
        for job in jobs
            FP._closure_exec(s.db,"UPDATE jobs SET status='running',last_session=?,error='' WHERE id=?",(s.session,job["id"]))
            packet=equivalence ? FP._closure_equivalence_packet(s,job) : FP._closure_work_packet(s,job)
            context=equivalence ? nothing : get!(FP.ClosureWorkContext,contexts,Int(job["id"]))
            push!(items,(job,packet))
            task=Threads.@spawn begin
                if equivalence
                    FP._closure_equivalence_compute(packet;seconds=30.0,nodes=100_000)
                else
                    FP._closure_compute(packet;context,seconds=max(0.0,min(300.0,deadline-time())),evaluations=256,stop_requested=stopped)
                end
            end
            push!(tasks,task)
        end
        publish!(;force=true)
        for (i,(job,packet)) in enumerate(items)
            while !istaskdone(tasks[i]);publish!();sleep(.05);end
            value=fetch(tasks[i])
            if equivalence
                FP._closure_equivalence_apply!(s,job,packet,value)
            else
                evaluated+=FP._closure_apply!(s,job,value)
            end
            processed+=1;publish!(;force=true)
        end
        empty!(tasks)
    end
    try
        println("Validating the archived checkpoint before resuming only parent ",parent);flush(stdout)
        s=FP._closure_open(directory)
        FP._closure_count(s.db,"SELECT COUNT(*) n FROM sessions WHERE finished='' ")==0 || error("source session unfinished")
        FP._closure_count(s.db,"SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2 AND class_id IS NULL")==0 || error("classify pre-existing pending candidates first")
        parentrow=only(FP._closure_rows(s.db,"SELECT origin FROM parents WHERE id=?",(parent,)))
        parentrow["origin"]=="root" || error("focused demonstration requires a published root")
        before_jobs=construction();isempty(before_jobs) && error("selected parent has no construction jobs")
        before_paths=paths();before_seed=seed_summary(s.db)
        baseline=ea_baseline!(s,out)
        FP.DiscoveryStore.atomic_toml(joinpath(out,"baseline.toml"),baseline)
        budgets=Dict("execution_scope"=>"finish only selected parent's own construction and classify outputs","parent_id"=>parent,
            "controller_sha256"=>FP.DiscoveryEvidence.filehash(@__FILE__),"baseline_controller_sha256"=>FP.DiscoveryEvidence.filehash(joinpath(@__DIR__,"closure_baseline.jl")),
            "seed_progress_helper_sha256"=>FP.DiscoveryEvidence.filehash(helper),"baseline_sha256"=>baseline["sha256"],
            "threads"=>Threads.nthreads(:default),"construction_concurrency"=>2,"ea_concurrency"=>32,
            "duration_seconds"=>deadline-started,"equivalence_seconds"=>30.0,"equivalence_nodes"=>100_000,"descendant_expansion"=>false)
        FP._closure_exec(s.db,"INSERT INTO sessions(started,heartbeat,pid,host,state,budgets) VALUES(?,?,?,?,?,?)",(FP._closure_now(),FP._closure_now(),getpid(),get(ENV,"HOSTNAME","localhost"),"running",FP._closure_text(budgets)))
        s.session=Int(only(FP._closure_rows(s.db,"SELECT last_insert_rowid() id"))["id"])
        if prior_stop!==nothing
            write(joinpath(out,"STOP-before.txt"),prior_stop)
            isfile(stop_path) && read(stop_path)==prior_stop && rm(stop_path)
        end
        while !stopped()
            ea=FP._closure_rows(s.db,"SELECT * FROM jobs WHERE parent_id=? AND kind='deduplicate' AND status IN ('pending','paused') AND last_session!=? ORDER BY id LIMIT 32",(parent,s.session))
            if !isempty(ea)
                compute_batch(ea;equivalence=true);continue
            end
            jobs=construction()
            if all(j->j["status"]=="done",jobs)
                state="paused_parent_complete";break
            end
            any(j->j["status"] in ("failed","blocked"),jobs) && error("selected parent's coverage is blocked")
            pending=filter(j->j["status"] in ("pending","paused"),jobs)
            isempty(pending) && error("no runnable selected-parent work")
            compute_batch(pending[1:min(2,length(pending))])
        end
        stopped() && (state=external() ? "paused_external" : "paused_budget")
        FP._closure_exec(s.db,"ATTACH DATABASE ? AS focused_before",(baseline["path"],))
        try
            changed=FP._closure_count(s.db,"SELECT COUNT(*) n FROM jobs j JOIN focused_before.jobs b ON j.id=b.id WHERE b.parent_id!=? AND b.kind!='deduplicate' AND (j.status!=b.status OR j.direction!=b.direction OR j.combination!=b.combination OR j.last_session!=b.last_session OR j.payload!=b.payload OR j.result!=b.result OR j.error!=b.error)",(parent,))
            changed==0 || error("another parent's construction changed")
        finally
            FP._closure_exec(s.db,"DETACH DATABASE focused_before")
        end
    catch
        state="failed";rethrow()
    finally
        for task in tasks
            try;wait(task);catch;end
        end
        if s!==nothing
            try
                if s.session>0
                    FP._closure_exec(s.db,"UPDATE jobs SET status='paused' WHERE last_session=? AND status='running'",(s.session,))
                    FP._closure_exec(s.db,"UPDATE sessions SET state=?,finished=?,heartbeat=?,jobs=?,evaluations=? WHERE id=?",(state,FP._closure_now(),FP._closure_now(),processed,evaluated,s.session))
                    publish!(;force=true,finished=true)
                end
            finally
                FP._closure_close(s)
            end
        end
    end
    result=Dict("state"=>state,"parent_id"=>parent,"processed_packets"=>processed,"evaluations"=>evaluated,
        "baseline"=>baseline,"descendants_expanded"=>false,"other_construction_cursors_unchanged"=>true)
    write(joinpath(out,"result.json"),FP.JSON3.write(result));result
end
end

if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==1 || error("usage: closure_finish_parent.jl CONFIG.toml under the archived project")
    println(FocusedParentPass.FP.JSON3.write(FocusedParentPass.run(FocusedParentPass.TOML.parsefile(only(ARGS)))))
end
