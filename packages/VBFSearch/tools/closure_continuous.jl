"""Continuously finish published seeds, then recursively expand admitted classes.

The checkpoint is opened once with its ordinary identity and coverage checks.
Construction jobs use exclusive compute slots with a bounded reservation FIFO;
all admission remains serial and uses the archived witness-verifying API.
Free slots take the next reserved job immediately. Results apply in reservation
order. For a fixed eligible frontier, reservation order depends on the committed
prefix rather than worker completion order; existing retry cooldowns and
wall-clock budgets retain their ordinary eligibility effects.
Timing measures remaining work, including classification, rather than a replay.
The store stays open until cooperative STOP, with no default time limit.
"""
module ContinuousSeedSearch
using VBFSearch,TOML,SHA,SQLite,DBInterface
const FP=VBFSearch
include("closure_baseline.jl")
include("closure_refill.jl")
include("closure_batches.jl")
const _closure_rows=FP._closure_rows
const _closure_count=FP._closure_count

"""Build one explicit read-only rank table and exclusive scratch contexts.

The table is shared across slots; geometry and Fourier work remain lazily
owned by each context. Optional preparation happens before the active search
deadline and is reported separately. Small fixtures can disable it explicitly.
"""
function worker_contexts(concurrency;precompute_rank_table=true,packed_rank_table=true,geometry=FP.Fourier.geometry(8))
    concurrency>0 || throw(ArgumentError("invalid concurrency"))
    precompute_rank_table isa Bool || throw(ArgumentError("precompute_rank_table must be Boolean"))
    packed_rank_table isa Bool || throw(ArgumentError("packed_rank_table must be Boolean"))
    started=time_ns()
    table=precompute_rank_table ? (packed_rank_table ? FP.Fourier.PackedPolarRankTable(geometry) : FP.Fourier.PolarRankTable(geometry)) : nothing
    contexts=[FP.ClosureWorkContext(;rank_table=table) for _ in 1:concurrency]
    (;contexts,rank_table_build_seconds=(time_ns()-started)*1e-9,
        rank_table_bytes=table===nothing ? 0 : table isa FP.Fourier.PackedPolarRankTable ? length(table.codes) : length(table.ranks),
        rank_table_encoding=table===nothing ? "none" : packed_rank_table ? "two-bit" : "byte")
end

"""Select unfinished parents deterministically, optionally excluding published roots."""
function select_parents(db,window_size;parent_scope="all")
    window_size>0 || throw(ArgumentError("invalid window size"))
    parent_scope in ("all","discovered") || throw(ArgumentError("invalid parent scope"))
    unfinished="EXISTS(SELECT 1 FROM jobs j WHERE j.parent_id=p.id AND j.kind IN ('prepare_v5','v5','switching') AND j.status!='done')"
    origins=parent_scope=="discovered" ? ("discovered",) : ("root","discovered")
    for origin in origins
        rows=FP._closure_rows(db,"SELECT id,source,origin FROM parents p WHERE p.origin=? AND $unfinished ORDER BY id LIMIT ?",(origin,window_size))
        isempty(rows) || return rows
    end
    Any[]
end

"""Rolling completion latency and throughput, excluding checkpoint startup.

Latency is first construction dispatch through completion of that parent's own
constructions and output classification. Concurrent parents overlap in time.
The latency sample uses the latest 100 published roots; recursive parents have
a separate sample. Previous measured roots may seed the latency sample only.
"""
function seed_statistics(history,events,started;now=time(),completed_this_session=length(events),parent_scope="all")
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
        "scheduling"=>parent_scope=="discovered" ? "discovered parents only, in admission order" : "published seeds first, then discovered parents in admission order")
end

"""Complete parents in admission order, prioritizing remaining published roots."""
function run(config)
    directory=abspath(config["run"]);out=abspath(config["evidence"])
    parents=Int[]
    concurrency=Int(get(config,"concurrency",32));concurrency>0 || error("invalid concurrency")
    max_pending=Int(get(config,"reservation_horizon",2concurrency))
    max_pending>=concurrency || error("reservation horizon must cover every slot")
    Int(get(config,"window_size",100))>0 || error("invalid window size")
    parent_scope=String(get(config,"parent_scope","all"))
    parent_scope in ("all","discovered") || throw(ArgumentError("invalid parent scope"))
    execution_scope=parent_scope=="discovered" ? "recursively expand discovered quadratic classes only; published roots retained as completed provenance" : "finish remaining published roots, then recursively expand admitted quadratic classes"
    ispath(out) && error("evidence directory must be new")
    mkpath(out)
    helper=abspath(get(config,"seed_progress_helper",joinpath(@__DIR__,"closure_seed_progress.jl")))
    reporter=Base.include(@__MODULE__,helper)
    seed_summary(db)=Base.invokelatest(reporter,db)
    for (source,name) in ((@__FILE__,"controller.jl"),(joinpath(@__DIR__,"closure_baseline.jl"),"baseline-controller.jl"),
            (joinpath(@__DIR__,"closure_refill.jl"),"refill-controller.jl"),
            (joinpath(@__DIR__,"closure_batches.jl"),"batches-controller.jl"),(helper,"seed-progress-helper.jl"))
        cp(source,joinpath(out,name))
        # Preserve the literal include filenames as well as historical evidence
        # aliases, so the copied controller can resolve every sibling helper.
        basename(source)==name || cp(source,joinpath(out,basename(source)))
    end
    FP.DiscoveryStore.atomic_toml(joinpath(out,"config.toml"),config)
    base=TOML.parsefile(joinpath(directory,"progress.toml"))
    FP.DiscoveryStore.atomic_toml(joinpath(out,"progress-before.toml"),base)
    ids="0";window_origin="root";windows_completed=0;window_active=true;completed_this_session=0
    context_setup=worker_contexts(concurrency;precompute_rank_table=get(config,"precompute_rank_table",true),
        packed_rank_table=get(config,"packed_rank_table",true))
    started=time();active_started=0.0;deadline=started+Float64(get(config,"duration_seconds",Inf))
    s=nothing;state="failed";processed=0;evaluated=0;baseline=nothing;primary_failure=nothing
    last_completion_check=0.0
    before_jobs=Any[];before_paths=Dict{String,Int}();before_kernels=0;last_report=0.0;timings=Dict{Int,Dict{String,Any}}();history=Dict{String,Any}[];completion_events=Float64[];deferred=Dict{Int,Float64}();ea_attempts=Dict{Int,Int}()
    stop_path=joinpath(directory,"STOP");prior_stop=isfile(stop_path) ? read(stop_path) : nothing
    contexts=context_setup.contexts
    external=FP._closure_stop_poller(stop_path,joinpath(out,"STOP"))
    stopped()=external() || time()>=deadline
    construction()=FP._closure_rows(s.db,"SELECT * FROM jobs WHERE parent_id IN ($ids) AND kind IN ('prepare_v5','v5','switching') ORDER BY parent_id,id")
    paths(kind)=FP._closure_count(s.db,"SELECT COUNT(*) n FROM paths WHERE job_id IN (SELECT id FROM jobs WHERE parent_id IN ($ids) AND kind=?)",(kind,))
    kernels()=FP._closure_count(s.db,"SELECT COUNT(*) n FROM kernels WHERE job_id IN (SELECT id FROM jobs WHERE parent_id IN ($ids) AND kind='switching') AND dimension>0")
    cosets(rows)=sum(max(0,Int(j["direction"])-1) for j in rows if j["kind"]=="v5";init=0)
    count_status(rows,kinds,status)=count(j->j["kind"] in kinds && j["status"]==status,rows)
    function select_window!()
        roots=select_parents(s.db,Int(get(config,"window_size",100));parent_scope)
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
        publish_started=time_ns();publish_times=Dict{String,Float64}()
        now=FP._closure_now();jobs=construction();report=deepcopy(base)
        report["updated_utc"]=now;report["heartbeat_utc"]=now
        report["heartbeat_age_seconds"]=0.0;report["heartbeat_stale"]=false
        report["running"]=!finished;report["state"]=finished || state=="waiting_frontier" ? state : "running"
        stage_started=time_ns();report["seed_progress"]=seed_summary(s.db)
        publish_times["seed_progress"]=(time_ns()-stage_started)*1e-9
        for (key,sql) in (("total_parents","SELECT COUNT(*) n FROM parents"),("promoted_parents","SELECT COUNT(*) n FROM parents WHERE origin='discovered'"),
                ("exact_luts","SELECT COUNT(*) n FROM candidates"),("quadratic_apn_luts","SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2"),
                ("nonquadratic_apn_luts","SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree>2"),
                ("unresolved_equivalence","SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2 AND class_id IS NULL"))
            stage_started=time_ns();report[key]=FP._closure_count(s.db,sql)
            publish_times[key]=(time_ns()-stage_started)*1e-9
        end
        stage_started=time_ns()
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
        publish_times["window_counters"]=(time_ns()-stage_started)*1e-9
        stage_started=time_ns()
        report["cluster"]["verified_equivalent_luts"]=FP._closure_count(s.db,"SELECT COUNT(*) n FROM candidates WHERE state='equivalent'")
        publish_times["equivalent_count"]=(time_ns()-stage_started)*1e-9
        stage_started=time_ns()
        # These global DISTINCT aggregates can spill hundreds of GiB to a
        # temporary sorter. Shutdown must not depend on cosmetic recounts.
        # Keep the last cached values and explicitly mark their freshness.
        report["signature_buckets_current"]=false
        report["cluster"]["repeated_derivation_paths_current"]=false
        publish_times["finished_counters"]=(time_ns()-stage_started)*1e-9
        FP._closure_exec(s.db,"UPDATE sessions SET heartbeat=?,jobs=?,evaluations=? WHERE id=?",(now,processed,evaluated,s.session))
        row=only(FP._closure_rows(s.db,"SELECT id,started,finished,heartbeat,pid,host,state,jobs,evaluations FROM sessions WHERE id=?",(s.session,)))
        report["sessions"]=vcat([row],[r for r in base["sessions"] if r["id"]!=s.session])
        batch=Dict("first_parent"=>first(parents),"last_parent"=>last(parents),"target_count"=>length(parents),
            "completed"=>count(p->haskey(timings,p) && haskey(timings[p],"completed_utc"),parents),"processed_packets"=>processed,
            "elapsed_seconds"=>time()-started,"active_seconds"=>active_started>0 ? time()-active_started : 0.0,
            "scope"=>execution_scope*"; both constructions; EA admission before recursion")
        report["root_batch"]=batch
        report["continuous_search"]=merge(batch,Dict("window_origin"=>window_origin,"windows_completed"=>windows_completed,"duration_policy"=>"until STOP","parent_scope"=>parent_scope))
        report["seed_statistics"]=seed_statistics(history,completion_events,active_started;now=time(),completed_this_session,parent_scope)
        FP.DiscoveryStore.atomic_toml(joinpath(directory,"progress.toml"),report)
        payload=Dict("state"=>report["state"],"running"=>!finished,"session_id"=>s.session,"pid"=>getpid(),
            "batch"=>batch,"seed_progress"=>report["seed_progress"],"total_parents"=>report["total_parents"],
            "exact_luts"=>report["exact_luts"],"unresolved_equivalence"=>report["unresolved_equivalence"],
            "seed_statistics"=>report["seed_statistics"],"window_origin"=>window_origin)
        tmp=joinpath(out,"progress.json.tmp");write(tmp,FP.JSON3.write(payload));mv(tmp,joinpath(out,"progress.json");force=true)
        publish_times["total"]=(time_ns()-publish_started)*1e-9
        open(joinpath(out,"publish-metrics.jsonl"),"a") do io
            println(io,FP.JSON3.write(Dict("utc"=>FP._closure_now(),"finished"=>finished,"processed_packets"=>processed,"seconds"=>publish_times)))
        end
        println(FP.JSON3.write(Dict("event"=>"batch_progress","batch"=>batch)));flush(stdout);last_report=time()
    end
    function prepare_item(item,ticket,slot)
        job=item.job;equivalence=item.equivalence
        FP._closure_exec(s.db,"UPDATE jobs SET status='running',last_session=?,error='' WHERE id=?",(s.session,job["id"]))
        if !equivalence
            t=timings[Int(job["parent_id"])]
            get!(t,"first_dispatch_epoch",time());get!(t,"first_dispatch_utc",FP._closure_now())
        end
        packet=equivalence ? FP._closure_equivalence_packet(s,job) : FP._closure_work_packet(s,job)
        level=min(get(ea_attempts,Int(job["id"]),0),2)
        (;job,packet,equivalence,level,ticket,slot)
    end
    function compute_item(item,slot,pool_stopped)
        if item.equivalence
            FP._closure_equivalence_compute(item.packet;
                seconds=min(300.0,Float64(get(config,"equivalence_seconds",30.0))*4^item.level),
                nodes=min(1_000_000,Int(get(config,"equivalence_nodes",100_000))*4^item.level))
        else
            FP._closure_compute(item.packet;context=contexts[slot],
                seconds=max(0.0,min(300.0,deadline-time())),evaluations=256,stop_requested=pool_stopped)
        end
    end
    function finish_item(item,value,compute_seconds,scheduling)
            job=item.job;packet=item.packet;equivalence=item.equivalence;apply_started=time_ns()
            if equivalence
                outcome=closure_apply_savepoint!(s.db) do
                    FP._closure_equivalence_apply!(s,job,packet,value)
                end
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
                evaluated+=closure_apply_savepoint!(s.db) do
                    FP._closure_apply!(s,job,value)
                end
            end
            apply_seconds=Float64(time_ns()-apply_started)/1e9
            t=get(timings,Int(job["parent_id"]),Dict{String,Any}());key=equivalence ? "ea_task_seconds" : "construction_task_seconds"
            t[key]=get(t,key,0.0)+compute_seconds
            t["application_seconds"]=get(t,"application_seconds",0.0)+apply_seconds
            metric=Dict("parent_id"=>job["parent_id"],"job_id"=>job["id"],"kind"=>job["kind"],
                "first_direction"=>job["direction"],"compute_wall_seconds"=>compute_seconds,"application_wall_seconds"=>apply_seconds,
                "reservation_ticket"=>scheduling.ticket,"compute_slot"=>scheduling.slot,"ready_wait_seconds"=>scheduling.ready_wait_seconds,
                "processed_cosets"=>equivalence ? 0 : get(value["work"],"processed_cosets",0))
            open(joinpath(out,"packet-metrics.jsonl"),"a") do io;println(io,FP.JSON3.write(metric));end
            processed+=1
    end
    function reserve_items(limit,excluded)
        retries=join([id for (id,when) in deferred if when<=time()],",")
        isempty(retries) && (retries="0")
        excluded_sql=isempty(excluded) ? "0" : join(sort!(Int[x for x in excluded]),",")
        ea=FP._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='deduplicate' AND status IN ('pending','paused') AND (last_session!=? OR id IN ($retries)) AND id NOT IN ($excluded_sql) ORDER BY id LIMIT ?",(s.session,limit))
        items=Any[(job=j,equivalence=true) for j in ea]
        length(items)==limit && return items
        failed=FP._closure_count(s.db,"SELECT EXISTS(SELECT 1 FROM jobs WHERE parent_id IN ($ids) AND kind IN ('prepare_v5','v5','switching') AND status IN ('failed','blocked') LIMIT 1) n")
        failed==0 || error("parent coverage requires recovery")
        pending=FP._closure_rows(s.db,"SELECT * FROM jobs WHERE parent_id IN ($ids) AND kind IN ('prepare_v5','v5','switching') AND status IN ('pending','paused') AND id NOT IN ($excluded_sql) ORDER BY parent_id,id LIMIT ?",(limit-length(items),))
        append!(items,[(job=j,equivalence=false) for j in pending])
        items
    end
    function report_tick()
        if time()-last_completion_check>=1.0
            record_completed!(construction());last_completion_check=time()
        end
        publish!()
    end
    try
        println("Opening the archived checkpoint once for continuous seed expansion");flush(stdout)
        opened=time();s=FP._closure_open(directory);validated=time()
        FP._closure_count(s.db,"SELECT COUNT(*) n FROM sessions WHERE finished='' ")==0 || error("source session unfinished")
        baseline=continuous_baseline!(s,out;policy=String(get(config,"baseline_policy","summary")),
            cached_progress=base,full_reserve_bytes=Int(get(config,"full_baseline_reserve_bytes",8*1024^3)))
        FP.DiscoveryStore.atomic_toml(joinpath(out,"baseline.toml"),baseline)
        if haskey(config,"timing_history")
            prior=FP.JSON3.read(read(config["timing_history"],String),Dict{String,Any})
            append!(history,[Dict{String,Any}(t) for t in prior["timings"]])
        end
        select_window!() || error("no unfinished parent exists")
        active_started=time()
        budgets=Dict("execution_scope"=>execution_scope,"parent_scope"=>parent_scope,
            "initial_parent_ids"=>copy(parents),"concurrency"=>concurrency,"threads"=>Threads.nthreads(:default),
            "controller_sha256"=>FP.DiscoveryEvidence.filehash(@__FILE__),"baseline_sha256"=>baseline["sha256"],
            "baseline_policy"=>baseline["policy"],
            "baseline_controller_sha256"=>FP.DiscoveryEvidence.filehash(joinpath(@__DIR__,"closure_baseline.jl")),
            "seed_progress_helper_sha256"=>FP.DiscoveryEvidence.filehash(helper),"duration_seconds"=>isfinite(deadline) ? deadline-started : -1.0,"duration_policy"=>"until STOP",
            "timing_history_sha256"=>haskey(config,"timing_history") ? FP.DiscoveryEvidence.filehash(config["timing_history"]) : "none",
            "equivalence_seconds"=>Float64(get(config,"equivalence_seconds",30.0)),"equivalence_nodes"=>Int(get(config,"equivalence_nodes",100_000)),
            "equivalence_retry_seconds_max"=>300.0,"equivalence_retry_nodes_max"=>1_000_000,"equivalence_retry_cooldown_seconds"=>300.0,
            "rank_table_bytes"=>context_setup.rank_table_bytes,"rank_table_build_seconds"=>context_setup.rank_table_build_seconds,
            "rank_table_encoding"=>context_setup.rank_table_encoding,
            "scheduler"=>"bounded reserved FIFO; continuous slot refill; ordered durable apply",
            "scheduler_determinism"=>"FIFO reservation and application for a fixed eligible frontier; retry cooldowns and wall-clock budgets retained",
            "reservation_horizon"=>max_pending,
            "coordinator_transactions"=>"bounded steps, per-application savepoints, FULL synchronous commit",
            "batches_controller_sha256"=>FP.DiscoveryEvidence.filehash(joinpath(@__DIR__,"closure_batches.jl")),
            "refill_controller_sha256"=>FP.DiscoveryEvidence.filehash(joinpath(@__DIR__,"closure_refill.jl")),
            "validation_seconds"=>validated-opened,"baseline_and_setup_seconds"=>active_started-validated,"descendant_expansion"=>true)
        FP._closure_exec(s.db,"INSERT INTO sessions(started,heartbeat,pid,host,state,budgets) VALUES(?,?,?,?,?,?)",(FP._closure_now(),FP._closure_now(),getpid(),get(ENV,"HOSTNAME","localhost"),"running",FP._closure_text(budgets)))
        s.session=Int(only(FP._closure_rows(s.db,"SELECT last_insert_rowid() id"))["id"])
        if prior_stop!==nothing
            write(joinpath(out,"STOP-before.txt"),prior_stop)
            isfile(stop_path) && read(stop_path)==prior_stop && rm(stop_path)
        end
        publish!(;force=true)
        while true
            pool=run_refill_pool!(reserve_items,prepare_item,compute_item,finish_item;
                concurrency,max_pending,key=item->Int(item.job["id"]),stop_requested=stopped,on_tick=report_tick,
                coordinator_step=f->closure_coordinator_step!(f,s.db))
            open(joinpath(out,"scheduler-metrics.jsonl"),"a") do io
                println(io,FP.JSON3.write(Dict(string(k)=>v for (k,v) in pairs(pool))))
            end
            record_completed!(construction());publish!()
            stopped() && break
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
    catch error
        primary_failure=(exception=error,backtrace=catch_backtrace())
        state="failed";rethrow()
    finally
        if s!==nothing
            cleanup_failure=nothing
            try
                if s.session>0
                    FP._closure_exec(s.db,"UPDATE jobs SET status='paused' WHERE last_session=? AND status='running'",(s.session,))
                    FP._closure_exec(s.db,"UPDATE sessions SET state=?,finished=?,heartbeat=?,jobs=?,evaluations=? WHERE id=?",(state,FP._closure_now(),FP._closure_now(),processed,evaluated,s.session))
                    try
                        publish!(;force=true,finished=true)
                    catch error
                        # Session state and cursors are durable already. A
                        # cosmetic report must not turn STOP into a failed run
                        # or replace an earlier worker/application exception.
                        diagnostic=Dict("state"=>state,"session_id"=>s.session,
                            "utc"=>FP._closure_now(),"error"=>sprint(showerror,error),
                            "session_state_committed"=>true,"progress_refresh_failed"=>true)
                        try
                            FP.DiscoveryStore.atomic_toml(joinpath(out,"final-report-error.toml"),diagnostic)
                        catch
                        end
                        println(stderr,"Final progress refresh failed after durable session close: ",sprint(showerror,error))
                    end
                end
            catch error
                cleanup_failure=error
                if primary_failure===nothing
                    rethrow()
                end
                println(stderr,"Session cleanup also failed; preserving the original error: ",sprint(showerror,error))
            finally
                try
                    FP._closure_close(s)
                catch error
                    if primary_failure===nothing && cleanup_failure===nothing
                        rethrow()
                    end
                    println(stderr,"Checkpoint close also failed; preserving the original error: ",sprint(showerror,error))
                end
            end
        end
    end
    result=Dict("state"=>state,"last_parent_ids"=>copy(parents),"processed_packets"=>processed,"evaluations"=>evaluated,
        "baseline"=>baseline,"descendants_expanded"=>window_origin=="discovered",
        "elapsed_seconds"=>time()-started,"active_seconds"=>active_started>0 ? time()-active_started : 0.0,
        "seed_statistics"=>seed_statistics(history,completion_events,active_started;now=time(),completed_this_session,parent_scope),"window_origin"=>window_origin)
    try
        write(joinpath(out,"result.json"),FP.JSON3.write(result))
    catch error
        println(stderr,"Result report failed after durable session close: ",sprint(showerror,error))
    end
    result
end
end

if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==1 || error("usage: closure_continuous.jl CONFIG.toml under the archived project")
    println(ContinuousSeedSearch.FP.JSON3.write(ContinuousSeedSearch.run(ContinuousSeedSearch.TOML.parsefile(only(ARGS)))))
end
