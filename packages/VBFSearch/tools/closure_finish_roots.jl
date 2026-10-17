"""Measure a bounded published-root expansion with the checkpoint's archived math.

The checkpoint is opened once with its ordinary identity and coverage checks.
Construction jobs from the selected roots execute in ordered concurrent waves;
all admission remains serial and uses the archived witness-verifying API.
Timing measures remaining work, including classification, rather than a replay.
"""
module FocusedRootsPass
using VBFSearch,TOML,SHA
const FP=VBFSearch
include("closure_baseline.jl")
const _closure_rows=FP._closure_rows
const _closure_count=FP._closure_count

"""Complete selected roots without executing any discovered parent's jobs."""
function run(config)
    directory=abspath(config["run"]);out=abspath(config["evidence"])
    parents=Int.(config["parent_ids"]);isempty(parents) && error("empty root selection")
    length(unique(parents))==length(parents) || error("duplicate root selection")
    issorted(parents) || error("roots must be ordered")
    concurrency=Int(get(config,"concurrency",32));concurrency>0 || error("invalid concurrency")
    ispath(out) && error("evidence directory must be new")
    mkpath(out)
    helper=abspath(config["seed_progress_helper"])
    reporter=Base.include(@__MODULE__,helper)
    seed_summary(db)=Base.invokelatest(reporter,db)
    for (source,name) in ((@__FILE__,"controller.jl"),(joinpath(@__DIR__,"closure_baseline.jl"),"baseline-controller.jl"),(helper,"seed-progress-helper.jl"))
        cp(source,joinpath(out,name))
    end
    FP.DiscoveryStore.atomic_toml(joinpath(out,"config.toml"),config)
    base=TOML.parsefile(joinpath(directory,"progress.toml"))
    FP.DiscoveryStore.atomic_toml(joinpath(out,"progress-before.toml"),base)
    ids=join(parents,",");selected=Set(parents)
    started=time();active_started=0.0;deadline=started+Float64(get(config,"duration_seconds",86400.0))
    s=nothing;state="failed";tasks=Task[];processed=0;evaluated=0;baseline=nothing
    before_jobs=Any[];before_paths=0;last_report=0.0;timings=Dict{Int,Dict{String,Any}}()
    stop_path=joinpath(directory,"STOP");prior_stop=isfile(stop_path) ? read(stop_path) : nothing
    contexts=[FP.ClosureWorkContext() for _ in 1:concurrency]
    external()=isfile(stop_path) || isfile(joinpath(out,"STOP"))
    stopped()=external() || time()>=deadline
    construction()=FP._closure_rows(s.db,"SELECT * FROM jobs WHERE parent_id IN ($ids) AND kind IN ('prepare_v5','v5','switching') ORDER BY parent_id,id")
    paths()=FP._closure_count(s.db,"SELECT COUNT(*) n FROM paths WHERE job_id IN (SELECT id FROM jobs WHERE parent_id IN ($ids) AND kind IN ('prepare_v5','v5','switching'))")
    cosets(rows)=sum(max(0,Int(j["direction"])-1) for j in rows if j["kind"]=="v5";init=0)
    count_status(rows,kinds,status)=count(j->j["kind"] in kinds && j["status"]==status,rows)
    function record_completed!(jobs)
        for parent in parents
            t=timings[parent];haskey(t,"completed_utc") && continue
            own=filter(j->j["parent_id"]==parent,jobs)
            all(j->j["status"]=="done",own) || continue
            pending=FP._closure_count(s.db,"SELECT COUNT(*) n FROM paths p JOIN candidates c ON c.id=p.child_id WHERE p.job_id IN (SELECT id FROM jobs WHERE parent_id=? AND kind IN ('prepare_v5','v5','switching')) AND c.apn=1 AND c.degree=2 AND c.class_id IS NULL",(parent,))
            pending==0 || continue
            now=time();t["completed_utc"]=FP._closure_now()
            t["batch_completion_seconds"]=now-active_started
            t["elapsed_from_first_dispatch_seconds"]=now-get(t,"first_dispatch_epoch",now)
            t["remaining_cosets_completed"]=cosets(own)-t["previous_cosets"]
            t["total_cosets_completed"]=cosets(own)
            t["construction_jobs"]=length(own)
            println(FP.JSON3.write(Dict("event"=>"seed_completed","parent_id"=>parent,"timing"=>t)));flush(stdout)
        end
    end
    function publish!(;finished=false,force=false)
        !force && time()-last_report<15 && return
        now=FP._closure_now();jobs=construction();report=deepcopy(base)
        report["updated_utc"]=now;report["heartbeat_utc"]=now
        report["heartbeat_age_seconds"]=0.0;report["heartbeat_stale"]=false
        report["running"]=!finished;report["state"]=finished ? state : "running"
        report["seed_progress"]=seed_summary(s.db)
        for (key,sql) in (("total_parents","SELECT COUNT(*) n FROM parents"),("promoted_parents","SELECT COUNT(*) n FROM parents WHERE origin='discovered'"),
                ("exact_luts","SELECT COUNT(*) n FROM candidates"),("quadratic_apn_luts","SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2"),
                ("unresolved_equivalence","SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2 AND class_id IS NULL"))
            report[key]=FP._closure_count(s.db,sql)
        end
        newparents=report["total_parents"]-base["total_parents"]
        for (name,kinds) in (("v5",("prepare_v5","v5")),("switching",("switching",)))
            method=report["methods"][name]
            for status in ("pending","paused","running","done","failed","blocked")
                method["jobs_"*status]+=count_status(jobs,kinds,status)-count_status(before_jobs,kinds,status)+(status=="pending" ? newparents : 0)
            end
            completed(rows)=count(p->all(j->j["status"]=="done",filter(j->j["parent_id"]==p && j["kind"] in kinds,rows)),parents)
            method["parents_completed"]+=completed(jobs)-completed(before_jobs)
        end
        report["methods"]["v5"]["cosets_checked"]+=cosets(jobs)-cosets(before_jobs)
        addedpaths=paths()-before_paths
        report["construction_paths"]+=addedpaths
        report["methods"]["v5"]["candidates"]+=addedpaths
        complete(rows)=count(p->all(j->j["status"]=="done",filter(j->j["parent_id"]==p,rows)),parents)
        report["completed_parents"]+=complete(jobs)-complete(before_jobs)
        report["active_parents"]=0
        report["queued_parents"]=max(0,report["total_parents"]-report["completed_parents"]-report["blocked_parents"])
        report["cluster"]["enabled"]=false;report["cluster"]["workers"]=Any[]
        report["cluster"]["verified_equivalent_luts"]=FP._closure_count(s.db,"SELECT COUNT(*) n FROM candidates WHERE state='equivalent'")
        if finished
            report["signature_buckets"]=FP._closure_count(s.db,"SELECT COUNT(DISTINCT sigma) n FROM candidates WHERE apn=1 AND degree=2")
            report["cluster"]["repeated_derivation_paths"]=FP._closure_count(s.db,"SELECT COUNT(*) n FROM paths")-FP._closure_count(s.db,"SELECT COUNT(DISTINCT child_id) n FROM paths")
        end
        FP._closure_exec(s.db,"UPDATE sessions SET heartbeat=?,jobs=?,evaluations=? WHERE id=?",(now,processed,evaluated,s.session))
        row=only(FP._closure_rows(s.db,"SELECT id,started,finished,heartbeat,pid,host,state,jobs,evaluations FROM sessions WHERE id=?",(s.session,)))
        report["sessions"]=vcat([row],base["sessions"])
        batch=Dict("first_parent"=>first(parents),"last_parent"=>last(parents),"target_count"=>length(parents),
            "completed"=>count(t->haskey(t,"completed_utc"),values(timings)),"processed_packets"=>processed,
            "elapsed_seconds"=>time()-started,"active_seconds"=>active_started>0 ? time()-active_started : 0.0,
            "scope"=>"remaining selected-root construction and classification; descendants queued")
        report["root_batch"]=batch
        FP.DiscoveryStore.atomic_toml(joinpath(directory,"progress.toml"),report)
        payload=Dict("state"=>report["state"],"running"=>!finished,"session_id"=>s.session,"pid"=>getpid(),
            "batch"=>batch,"seed_progress"=>report["seed_progress"],"total_parents"=>report["total_parents"],
            "exact_luts"=>report["exact_luts"],"unresolved_equivalence"=>report["unresolved_equivalence"],
            "timings"=>[timings[p] for p in parents])
        tmp=joinpath(out,"progress.json.tmp");write(tmp,FP.JSON3.write(payload));mv(tmp,joinpath(out,"progress.json");force=true)
        println(FP.JSON3.write(Dict("event"=>"batch_progress","batch"=>batch)));flush(stdout);last_report=time()
    end
    function compute_wave(jobs;equivalence=false)
        items=Any[];empty!(tasks)
        for (i,job) in enumerate(jobs)
            FP._closure_exec(s.db,"UPDATE jobs SET status='running',last_session=?,error='' WHERE id=?",(s.session,job["id"]))
            if !equivalence
                t=timings[Int(job["parent_id"])]
                get!(t,"first_dispatch_epoch",time());get!(t,"first_dispatch_utc",FP._closure_now())
            end
            packet=equivalence ? FP._closure_equivalence_packet(s,job) : FP._closure_work_packet(s,job)
            push!(items,(job,packet))
        end
        # Do not enter SQLite while compute tasks may be waiting for Julia GC.
        for (i,(job,packet)) in enumerate(items)
            context=contexts[i]
            push!(tasks,Threads.@spawn begin
                began=time_ns()
                value=if equivalence
                    FP._closure_equivalence_compute(packet;seconds=Float64(get(config,"equivalence_seconds",30.0)),nodes=Int(get(config,"equivalence_nodes",100_000)))
                else
                    FP._closure_compute(packet;context,seconds=max(0.0,min(300.0,deadline-time())),evaluations=256,stop_requested=stopped)
                end
                (value,Float64(time_ns()-began)/1e9)
            end)
        end
        while !all(istaskdone,tasks);sleep(.05);end
        for (i,(job,packet)) in enumerate(items)
            value,compute_seconds=fetch(tasks[i]);apply_started=time_ns()
            if equivalence
                FP._closure_equivalence_apply!(s,job,packet,value)
            else
                evaluated+=FP._closure_apply!(s,job,value)
            end
            apply_seconds=Float64(time_ns()-apply_started)/1e9
            t=timings[Int(job["parent_id"])];key=equivalence ? "ea_task_seconds" : "construction_task_seconds"
            t[key]=get(t,key,0.0)+compute_seconds
            t["application_seconds"]=get(t,"application_seconds",0.0)+apply_seconds
            metric=Dict("parent_id"=>job["parent_id"],"job_id"=>job["id"],"kind"=>job["kind"],
                "first_direction"=>job["direction"],"compute_wall_seconds"=>compute_seconds,"application_wall_seconds"=>apply_seconds,
                "processed_cosets"=>equivalence ? 0 : get(value["work"],"processed_cosets",0))
            open(joinpath(out,"packet-metrics.jsonl"),"a") do io;println(io,FP.JSON3.write(metric));end
            processed+=1
        end
        empty!(tasks)
    end
    try
        println("Opening archived checkpoint once for roots ",first(parents),"–",last(parents));flush(stdout)
        opened=time();s=FP._closure_open(directory);validated=time()
        FP._closure_count(s.db,"SELECT COUNT(*) n FROM sessions WHERE finished='' ")==0 || error("source session unfinished")
        FP._closure_count(s.db,"SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2 AND class_id IS NULL")==0 || error("pre-existing classification pending")
        roots=FP._closure_rows(s.db,"SELECT id,source,origin FROM parents WHERE id IN ($ids) ORDER BY id")
        length(roots)==length(parents) && all(p->p["origin"]=="root",roots) || error("selection includes an unpublished parent")
        before_jobs=construction();before_paths=paths()
        all(p->any(j->j["parent_id"]==p,before_jobs),parents) || error("root has no jobs")
        all(j->j["status"]=="done",filter(j->j["kind"] in ("prepare_v5","switching"),before_jobs)) || error("this measurement requires previously completed preparation and switching")
        baseline=ea_baseline!(s,out);FP.DiscoveryStore.atomic_toml(joinpath(out,"baseline.toml"),baseline)
        for root in roots
            p=Int(root["id"]);own=filter(j->j["parent_id"]==p,before_jobs)
            timings[p]=Dict("parent_id"=>p,"source"=>root["source"],"previous_cosets"=>cosets(own),
                "maximizing_five_spaces"=>count(j->j["kind"]=="v5",own),
                "previous_completed_spaces"=>count(j->j["kind"]=="v5" && j["status"]=="done",own),
                "switching_previously_complete"=>all(j->j["status"]=="done",filter(j->j["kind"]=="switching",own)))
        end
        active_started=time()
        budgets=Dict("execution_scope"=>"finish selected published roots; classify outputs; do not expand descendants",
            "parent_ids"=>parents,"concurrency"=>concurrency,"threads"=>Threads.nthreads(:default),
            "controller_sha256"=>FP.DiscoveryEvidence.filehash(@__FILE__),"baseline_sha256"=>baseline["sha256"],
            "baseline_controller_sha256"=>FP.DiscoveryEvidence.filehash(joinpath(@__DIR__,"closure_baseline.jl")),
            "seed_progress_helper_sha256"=>FP.DiscoveryEvidence.filehash(helper),"duration_seconds"=>deadline-started,
            "equivalence_seconds"=>Float64(get(config,"equivalence_seconds",30.0)),"equivalence_nodes"=>Int(get(config,"equivalence_nodes",100_000)),
            "validation_seconds"=>validated-opened,"baseline_and_setup_seconds"=>active_started-validated,"descendant_expansion"=>false)
        FP._closure_exec(s.db,"INSERT INTO sessions(started,heartbeat,pid,host,state,budgets) VALUES(?,?,?,?,?,?)",(FP._closure_now(),FP._closure_now(),getpid(),get(ENV,"HOSTNAME","localhost"),"running",FP._closure_text(budgets)))
        s.session=Int(only(FP._closure_rows(s.db,"SELECT last_insert_rowid() id"))["id"])
        if prior_stop!==nothing
            write(joinpath(out,"STOP-before.txt"),prior_stop)
            isfile(stop_path) && read(stop_path)==prior_stop && rm(stop_path)
        end
        publish!(;force=true)
        while !stopped()
            ea=FP._closure_rows(s.db,"SELECT * FROM jobs WHERE parent_id IN ($ids) AND kind='deduplicate' AND status IN ('pending','paused') AND last_session!=? ORDER BY id LIMIT ?",(s.session,concurrency))
            if !isempty(ea)
                compute_wave(ea;equivalence=true);publish!();continue
            end
            jobs=construction();record_completed!(jobs);publish!()
            if all(j->j["status"]=="done",jobs)
                state=all(t->haskey(t,"completed_utc"),values(timings)) ? "paused_roots_complete" : "paused_roots_unresolved";break
            end
            any(j->j["status"] in ("failed","blocked"),jobs) && error("selected-root coverage is blocked")
            pending=filter(j->j["status"] in ("pending","paused"),jobs)
            isempty(pending) && error("no runnable selected-root work")
            compute_wave(pending[1:min(concurrency,length(pending))])
        end
        stopped() && (state=external() ? "paused_external" : "paused_budget")
        FP._closure_exec(s.db,"ATTACH DATABASE ? AS focused_before",(baseline["path"],))
        try
            changed=FP._closure_count(s.db,"SELECT COUNT(*) n FROM focused_before.jobs b LEFT JOIN jobs j ON j.id=b.id WHERE b.parent_id NOT IN ($ids) AND b.kind!='deduplicate' AND (j.id IS NULL OR j.status IS NOT b.status OR j.direction IS NOT b.direction OR j.combination IS NOT b.combination OR j.last_session IS NOT b.last_session OR j.payload IS NOT b.payload OR j.result IS NOT b.result OR j.error IS NOT b.error)")
            changed==0 || error("another parent's construction changed")
        finally
            FP._closure_exec(s.db,"DETACH DATABASE focused_before")
        end
    catch
        state="failed";rethrow()
    finally
        for task in tasks;try;wait(task);catch;end;end
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
    result=Dict("state"=>state,"parent_ids"=>parents,"processed_packets"=>processed,"evaluations"=>evaluated,
        "baseline"=>baseline,"descendants_expanded"=>false,"other_construction_cursors_unchanged"=>true,
        "elapsed_seconds"=>time()-started,"active_seconds"=>active_started>0 ? time()-active_started : 0.0,
        "timings"=>[timings[p] for p in parents])
    write(joinpath(out,"result.json"),FP.JSON3.write(result));result
end
end

if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==1 || error("usage: closure_finish_roots.jl CONFIG.toml under the archived project")
    println(FocusedRootsPass.FP.JSON3.write(FocusedRootsPass.run(FocusedRootsPass.TOML.parsefile(only(ARGS)))))
end
