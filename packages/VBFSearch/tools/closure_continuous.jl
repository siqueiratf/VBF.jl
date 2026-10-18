"""Continuously finish published seeds, then recursively expand admitted classes.

The checkpoint is opened once with its ordinary identity and coverage checks.
Construction jobs from the selected roots execute in ordered concurrent waves;
all admission remains serial and uses the archived witness-verifying API.
Two waves overlap: the coordinator applies wave k while wave k+1 computes.
Wave k+1 is selected from the state after wave k-1, without the running jobs
of wave k, so the schedule stays deterministic for a fixed concurrency.
Timing measures remaining work, including classification, rather than a replay.
The store stays open until cooperative STOP, with no default time limit.
"""
module ContinuousSeedSearch
using VBFSearch,TOML,SHA
const FP=VBFSearch
include("closure_baseline.jl")
const _closure_rows=FP._closure_rows
const _closure_count=FP._closure_count

"""Rolling completion latency and throughput, excluding checkpoint startup.

Latency is first construction dispatch through completion of that parent's own
constructions and output classification. Concurrent parents overlap in time.
The latency sample uses the latest 100 published roots; recursive parents have
a separate sample. Previous measured roots may seed the latency sample only.
"""
function seed_statistics(history,events,started;now=time(),completed_this_session=length(events))
    function sample(origin)
        rows=filter(t->get(t,"origin","root")==origin,history)
        rows=rows[max(1,length(rows)-99):end]
        xs=sort!(Float64[t["elapsed_from_first_dispatch_seconds"] for t in rows])
        isempty(xs) && return Dict{String,Any}("samples"=>0)
        n=length(xs);middle=isodd(n) ? xs[(n+1)÷2] : (xs[n÷2]+xs[n÷2+1])/2
        Dict{String,Any}("samples"=>n,"median_seconds"=>middle,"mean_seconds"=>sum(xs)/n,
            "p95_seconds"=>xs[clamp(ceil(Int,.95n),1,n)],"last_seconds"=>last(rows)["elapsed_from_first_dispatch_seconds"])
    end
    elapsed=started>0 ? max(0.0,now-started) : 0.0
    recent=count(t->0<=now-t<=300,events)
    Dict{String,Any}("published"=>sample("root"),"recursive"=>sample("discovered"),
        "completed_this_session"=>completed_this_session,"active_seconds"=>elapsed,
        "seeds_per_minute_session"=>elapsed>0 ? 60completed_this_session/elapsed : 0.0,
        "seeds_per_minute_recent"=>elapsed>0 ? 60recent/min(300.0,elapsed) : 0.0,
        "latency_scope"=>"latest 100 completed published seeds; concurrent dispatch-to-completion; retained checkpoint work",
        "scheduling"=>"published seeds first, then discovered parents in admission order")
end

"""Complete parents in admission order, prioritizing remaining published roots."""
function run(config)
    directory=abspath(config["run"]);out=abspath(config["evidence"])
    parents=Int[]
    concurrency=Int(get(config,"concurrency",32));concurrency>0 || error("invalid concurrency")
    Int(get(config,"window_size",100))>0 || error("invalid window size")
    ispath(out) && error("evidence directory must be new")
    mkpath(out)
    helper=abspath(get(config,"seed_progress_helper",joinpath(@__DIR__,"closure_seed_progress.jl")))
    reporter=Base.include(@__MODULE__,helper)
    seed_summary(db)=Base.invokelatest(reporter,db)
    for (source,name) in ((@__FILE__,"controller.jl"),(joinpath(@__DIR__,"closure_baseline.jl"),"baseline-controller.jl"),(helper,"seed-progress-helper.jl"))
        cp(source,joinpath(out,name))
    end
    FP.DiscoveryStore.atomic_toml(joinpath(out,"config.toml"),config)
    base=TOML.parsefile(joinpath(directory,"progress.toml"))
    FP.DiscoveryStore.atomic_toml(joinpath(out,"progress-before.toml"),base)
    ids="0";window_origin="root";windows_completed=0;window_active=true;completed_this_session=0
    started=time();active_started=0.0;deadline=started+Float64(get(config,"duration_seconds",Inf))
    s=nothing;state="failed";tasks=Task[];processed=0;evaluated=0;baseline=nothing
    before_jobs=Any[];before_paths=Dict{String,Int}();before_kernels=0;last_report=0.0;timings=Dict{Int,Dict{String,Any}}();history=Dict{String,Any}[];completion_events=Float64[];deferred=Dict{Int,Float64}();ea_attempts=Dict{Int,Int}()
    stop_path=joinpath(directory,"STOP");prior_stop=isfile(stop_path) ? read(stop_path) : nothing
    contexts=[FP.ClosureWorkContext() for _ in 1:concurrency]
    external=FP._closure_stop_poller(stop_path,joinpath(out,"STOP"))
    stopped()=external() || time()>=deadline
    construction()=FP._closure_rows(s.db,"SELECT * FROM jobs WHERE parent_id IN ($ids) AND kind IN ('prepare_v5','v5','switching') ORDER BY parent_id,id")
    paths(kind)=FP._closure_count(s.db,"SELECT COUNT(*) n FROM paths WHERE job_id IN (SELECT id FROM jobs WHERE parent_id IN ($ids) AND kind=?)",(kind,))
    kernels()=FP._closure_count(s.db,"SELECT COUNT(*) n FROM kernels WHERE job_id IN (SELECT id FROM jobs WHERE parent_id IN ($ids) AND kind='switching') AND dimension>0")
    cosets(rows)=sum(max(0,Int(j["direction"])-1) for j in rows if j["kind"]=="v5";init=0)
    count_status(rows,kinds,status)=count(j->j["kind"] in kinds && j["status"]==status,rows)
    function select_window!()
        unfinished="EXISTS(SELECT 1 FROM jobs j WHERE j.parent_id=p.id AND j.kind IN ('prepare_v5','v5','switching') AND j.status!='done')"
        roots=FP._closure_rows(s.db,"SELECT id,source,origin FROM parents p WHERE p.origin='root' AND $unfinished ORDER BY id LIMIT ?",(Int(get(config,"window_size",100)),))
        if isempty(roots)
            roots=FP._closure_rows(s.db,"SELECT id,source,origin FROM parents p WHERE p.origin='discovered' AND $unfinished ORDER BY id LIMIT ?",(Int(get(config,"window_size",100)),))
        end
        isempty(roots) && return false
        for p in parents
            haskey(timings,p) && haskey(timings[p],"completed_utc") && delete!(timings,p)
        end
        parents=Int[r["id"] for r in roots];ids=join(parents,",");window_origin=String(first(roots)["origin"])
        before_jobs=construction();before_paths=Dict(kind=>paths(kind) for kind in ("v5","switching"));before_kernels=kernels()
        for root in roots
            p=Int(root["id"]);own=filter(j->j["parent_id"]==p,before_jobs)
            timings[p]=Dict("parent_id"=>p,"origin"=>root["origin"],"source"=>root["source"],"previous_cosets"=>cosets(own),
                "maximizing_five_spaces"=>count(j->j["kind"]=="v5",own),
                "previous_completed_spaces"=>count(j->j["kind"]=="v5" && j["status"]=="done",own),
                "switching_previously_complete"=>all(j->j["status"]=="done",filter(j->j["kind"]=="switching",own)))
        end
        println(FP.JSON3.write(Dict("event"=>"window_started","origin"=>window_origin,"first"=>first(parents),"last"=>last(parents))));flush(stdout)
        true
    end
    function record_completed!(jobs;selected_parents=parents)
        for parent in selected_parents
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
            t["maximizing_five_spaces"]=count(j->j["kind"]=="v5",own)
            push!(history,deepcopy(t));push!(completion_events,now)
            completed_this_session+=1
            same_origin=findall(x->get(x,"origin","root")==t["origin"],history)
            length(same_origin)>100 && deleteat!(history,first(same_origin))
            filter!(t->now-t<=300,completion_events)
            open(joinpath(out,"seed-timings.jsonl"),"a") do io;println(io,FP.JSON3.write(t));end
            println(FP.JSON3.write(Dict("event"=>"seed_completed","parent_id"=>parent,"timing"=>t)));flush(stdout)
        end
    end
    function publish!(;finished=false,force=false)
        !force && time()-last_report<15 && return
        now=FP._closure_now();jobs=construction();report=deepcopy(base)
        report["updated_utc"]=now;report["heartbeat_utc"]=now
        report["heartbeat_age_seconds"]=0.0;report["heartbeat_stale"]=false
        report["running"]=!finished;report["state"]=finished || state=="waiting_frontier" ? state : "running"
        report["seed_progress"]=seed_summary(s.db)
        for (key,sql) in (("total_parents","SELECT COUNT(*) n FROM parents"),("promoted_parents","SELECT COUNT(*) n FROM parents WHERE origin='discovered'"),
                ("exact_luts","SELECT COUNT(*) n FROM candidates"),("quadratic_apn_luts","SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2"),
                ("nonquadratic_apn_luts","SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree>2"),
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
        addedv5=paths("v5")-before_paths["v5"];addedswitching=paths("switching")-before_paths["switching"]
        report["construction_paths"]+=addedv5+addedswitching
        report["methods"]["v5"]["candidates"]+=addedv5
        report["methods"]["switching"]["candidates"]+=addedswitching
        report["methods"]["switching"]["directions_checked"]+=sum(j["direction"]-1 for j in jobs if j["kind"]=="switching";init=0)-sum(j["direction"]-1 for j in before_jobs if j["kind"]=="switching";init=0)
        report["methods"]["switching"]["nontrivial_kernels"]+=kernels()-before_kernels
        report["methods"]["v5"]["parents_prepared"]+=count_status(jobs,("prepare_v5",),"done")-count_status(before_jobs,("prepare_v5",),"done")
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
        report["sessions"]=vcat([row],[r for r in base["sessions"] if r["id"]!=s.session])
        batch=Dict("first_parent"=>first(parents),"last_parent"=>last(parents),"target_count"=>length(parents),
            "completed"=>count(p->haskey(timings,p) && haskey(timings[p],"completed_utc"),parents),"processed_packets"=>processed,
            "elapsed_seconds"=>time()-started,"active_seconds"=>active_started>0 ? time()-active_started : 0.0,
            "scope"=>"published roots first, then discovered parents; both constructions; EA admission before recursion")
        report["root_batch"]=batch
        report["continuous_search"]=merge(batch,Dict("window_origin"=>window_origin,"windows_completed"=>windows_completed,"duration_policy"=>"until STOP"))
        report["seed_statistics"]=seed_statistics(history,completion_events,active_started;now=time(),completed_this_session)
        FP.DiscoveryStore.atomic_toml(joinpath(directory,"progress.toml"),report)
        payload=Dict("state"=>report["state"],"running"=>!finished,"session_id"=>s.session,"pid"=>getpid(),
            "batch"=>batch,"seed_progress"=>report["seed_progress"],"total_parents"=>report["total_parents"],
            "exact_luts"=>report["exact_luts"],"unresolved_equivalence"=>report["unresolved_equivalence"],
            "seed_statistics"=>report["seed_statistics"],"window_origin"=>window_origin)
        tmp=joinpath(out,"progress.json.tmp");write(tmp,FP.JSON3.write(payload));mv(tmp,joinpath(out,"progress.json");force=true)
        println(FP.JSON3.write(Dict("event"=>"batch_progress","batch"=>batch)));flush(stdout);last_report=time()
    end
    function spawn_wave(jobs;equivalence=false)
        items=Any[];wave_tasks=Task[]
        for (i,job) in enumerate(jobs)
            FP._closure_exec(s.db,"UPDATE jobs SET status='running',last_session=?,error='' WHERE id=?",(s.session,job["id"]))
            if !equivalence
                t=timings[Int(job["parent_id"])]
                get!(t,"first_dispatch_epoch",time());get!(t,"first_dispatch_utc",FP._closure_now())
            end
            packet=equivalence ? FP._closure_equivalence_packet(s,job) : FP._closure_work_packet(s,job)
            push!(items,(job,packet))
        end
        # The previous wave is applied while these tasks run. The worst time to a
        # GC safepoint stayed below 10 ms with SQLite applies during computation.
        for (i,(job,packet)) in enumerate(items)
            context=contexts[i]
            level=min(get(ea_attempts,Int(job["id"]),0),2)
            push!(wave_tasks,Threads.@spawn begin
                began=time_ns()
                value=if equivalence
                    FP._closure_equivalence_compute(packet;seconds=min(300.0,Float64(get(config,"equivalence_seconds",30.0))*4^level),nodes=min(1_000_000,Int(get(config,"equivalence_nodes",100_000))*4^level))
                else
                    FP._closure_compute(packet;context,seconds=max(0.0,min(300.0,deadline-time())),evaluations=256,stop_requested=stopped)
                end
                (value,Float64(time_ns()-began)/1e9)
            end)
        end
        append!(tasks,wave_tasks)
        (jobs=jobs,equivalence=equivalence,items=items,tasks=wave_tasks)
    end
    wait_wave(wave)=(while !all(istaskdone,wave.tasks);sleep(.05);end)
    function finish_wave(wave)
        equivalence=wave.equivalence
        for (i,(job,packet)) in enumerate(wave.items)
            value,compute_seconds=fetch(wave.tasks[i]);apply_started=time_ns()
            if equivalence
                outcome=FP._closure_equivalence_apply!(s,job,packet,value)
                if outcome==:unresolved
                    deferred[Int(job["id"])]=time()+300
                    ea_attempts[Int(job["id"])]=get(ea_attempts,Int(job["id"]),0)+1
                else
                    delete!(deferred,Int(job["id"]));delete!(ea_attempts,Int(job["id"]))
                    parent=Int(job["parent_id"])
                    if outcome==:done && !(parent in parents) && haskey(timings,parent)
                        own=FP._closure_rows(s.db,"SELECT * FROM jobs WHERE parent_id=? AND kind IN ('prepare_v5','v5','switching')",(parent,))
                        record_completed!(own;selected_parents=[parent])
                    end
                end
            else
                evaluated+=FP._closure_apply!(s,job,value)
            end
            apply_seconds=Float64(time_ns()-apply_started)/1e9
            t=get(timings,Int(job["parent_id"]),Dict{String,Any}());key=equivalence ? "ea_task_seconds" : "construction_task_seconds"
            t[key]=get(t,key,0.0)+compute_seconds
            t["application_seconds"]=get(t,"application_seconds",0.0)+apply_seconds
            metric=Dict("parent_id"=>job["parent_id"],"job_id"=>job["id"],"kind"=>job["kind"],
                "first_direction"=>job["direction"],"compute_wall_seconds"=>compute_seconds,"application_wall_seconds"=>apply_seconds,
                "processed_cosets"=>equivalence ? 0 : get(value["work"],"processed_cosets",0))
            open(joinpath(out,"packet-metrics.jsonl"),"a") do io;println(io,FP.JSON3.write(metric));end
            processed+=1
        end
        filter!(task->!(task in wave.tasks),tasks)
    end
    function select_wave()
        retries=join([id for (id,when) in deferred if when<=time()],",")
        isempty(retries) && (retries="0")
        ea=FP._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='deduplicate' AND status IN ('pending','paused') AND (last_session!=? OR id IN ($retries)) ORDER BY id LIMIT ?",(s.session,concurrency))
        isempty(ea) || return (ea[1:min(concurrency,length(ea))],true)
        jobs=construction()
        any(j->j["status"] in ("failed","blocked"),jobs) && error("parent coverage requires recovery")
        pending=filter(j->j["status"] in ("pending","paused"),jobs)
        isempty(pending) ? nothing : (pending[1:min(concurrency,length(pending))],false)
    end
    try
        println("Opening the archived checkpoint once for continuous seed expansion");flush(stdout)
        opened=time();s=FP._closure_open(directory);validated=time()
        FP._closure_count(s.db,"SELECT COUNT(*) n FROM sessions WHERE finished='' ")==0 || error("source session unfinished")
        baseline=ea_baseline!(s,out);FP.DiscoveryStore.atomic_toml(joinpath(out,"baseline.toml"),baseline)
        if haskey(config,"timing_history")
            prior=FP.JSON3.read(read(config["timing_history"],String),Dict{String,Any})
            append!(history,[Dict{String,Any}(t) for t in prior["timings"]])
        end
        select_window!() || error("no unfinished parent exists")
        active_started=time()
        budgets=Dict("execution_scope"=>"finish remaining published roots, then recursively expand admitted quadratic classes",
            "initial_parent_ids"=>copy(parents),"concurrency"=>concurrency,"threads"=>Threads.nthreads(:default),
            "controller_sha256"=>FP.DiscoveryEvidence.filehash(@__FILE__),"baseline_sha256"=>baseline["sha256"],
            "baseline_controller_sha256"=>FP.DiscoveryEvidence.filehash(joinpath(@__DIR__,"closure_baseline.jl")),
            "seed_progress_helper_sha256"=>FP.DiscoveryEvidence.filehash(helper),"duration_seconds"=>isfinite(deadline) ? deadline-started : -1.0,"duration_policy"=>"until STOP",
            "timing_history_sha256"=>haskey(config,"timing_history") ? FP.DiscoveryEvidence.filehash(config["timing_history"]) : "none",
            "equivalence_seconds"=>Float64(get(config,"equivalence_seconds",30.0)),"equivalence_nodes"=>Int(get(config,"equivalence_nodes",100_000)),
            "equivalence_retry_seconds_max"=>300.0,"equivalence_retry_nodes_max"=>1_000_000,"equivalence_retry_cooldown_seconds"=>300.0,
            "validation_seconds"=>validated-opened,"baseline_and_setup_seconds"=>active_started-validated,"descendant_expansion"=>true)
        FP._closure_exec(s.db,"INSERT INTO sessions(started,heartbeat,pid,host,state,budgets) VALUES(?,?,?,?,?,?)",(FP._closure_now(),FP._closure_now(),getpid(),get(ENV,"HOSTNAME","localhost"),"running",FP._closure_text(budgets)))
        s.session=Int(only(FP._closure_rows(s.db,"SELECT last_insert_rowid() id"))["id"])
        if prior_stop!==nothing
            write(joinpath(out,"STOP-before.txt"),prior_stop)
            isfile(stop_path) && read(stop_path)==prior_stop && rm(stop_path)
        end
        publish!(;force=true)
        inflight=nothing
        while true
            spawned=nothing
            inflight===nothing || wait_wave(inflight)
            if !stopped()
                selected=select_wave()
                selected===nothing || (spawned=spawn_wave(selected[1];equivalence=selected[2]))
            end
            if inflight!==nothing
                finish_wave(inflight)
                record_completed!(construction());publish!()
            end
            inflight=spawned
            inflight===nothing || continue
            stopped() && break
            selected=select_wave()
            if selected!==nothing
                inflight=spawn_wave(selected[1];equivalence=selected[2]);continue
            end
            # Nothing runs and nothing is runnable: the current window is complete.
            jobs=construction();record_completed!(jobs)
            all(j->j["status"]=="done",jobs) || error("parent coverage requires recovery")
            if window_active
                publish!(;force=true)
                base=TOML.parsefile(joinpath(directory,"progress.toml"))
                before_jobs=deepcopy(jobs);before_paths=Dict(kind=>paths(kind) for kind in ("v5","switching"));before_kernels=kernels()
                windows_completed+=1;window_active=false
                if windows_completed>=Int(get(config,"max_windows",typemax(Int)))
                    state="paused_window_limit";break
                end
            end
            publish!(;force=true);base=TOML.parsefile(joinpath(directory,"progress.toml"))
            if !select_window!()
                state="waiting_frontier";publish!(;force=true)
                sleep(5);continue
            end
            state="running";window_active=true
        end
        stopped() && (state=external() ? "paused_external" : "paused_budget")
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
    result=Dict("state"=>state,"last_parent_ids"=>copy(parents),"processed_packets"=>processed,"evaluations"=>evaluated,
        "baseline"=>baseline,"descendants_expanded"=>window_origin=="discovered",
        "elapsed_seconds"=>time()-started,"active_seconds"=>active_started>0 ? time()-active_started : 0.0,
        "seed_statistics"=>seed_statistics(history,completion_events,active_started;now=time(),completed_this_session),"window_origin"=>window_origin)
    write(joinpath(out,"result.json"),FP.JSON3.write(result));result
end
end

if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==1 || error("usage: closure_continuous.jl CONFIG.toml under the archived project")
    println(ContinuousSeedSearch.FP.JSON3.write(ContinuousSeedSearch.run(ContinuousSeedSearch.TOML.parsefile(only(ARGS)))))
end
