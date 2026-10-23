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
using VBFSearch,TOML,SHA
const FP=VBFSearch
const SQLite=FP.SQLite
const DBInterface=FP.DBInterface
include("closure_baseline.jl")
include("closure_refill.jl")
include("closure_batches.jl")
include("closure_operations.jl")
include("closure_completion.jl")
using .ClosureOperations: validate_resources
const _closure_rows=FP._closure_rows
const _closure_count=FP._closure_count

"""Render ordinary controller events without exposing their JSON transport."""
function console_event(event;human=false,io=stdout)
    if !human
        println(io,FP.JSON3.write(event))
    elseif event["event"]=="window_started"
        origin=event["origin"]=="root" ? "initial seeds" : "discovered parents"
        action=get(event,"rolling",false) ? "Adding" : "Processing"
        label=event["origin"]=="root" && haskey(event,"first_seed") ? "audited rows " : "parent IDs "
        println(io,action," ",origin,": ",label,get(event,"first_seed",event["first"]),"–",get(event,"last_seed",event["last"]),
            " (",get(event,"active_windows",1)," scheduling window(s) active).")
    elseif event["event"]=="seed_completed"
        # Full per-parent timing records remain in seed-timings.jsonl. Bursts of
        # one hundred near-identical lines obscure the campaign-level progress.
        return nothing
    elseif event["event"]=="window_drained"
        println(io,"Construction window ",event["first"],"–",event["last"],
            " drained; updating progress and selecting further work.")
    elseif event["event"]=="batch_progress"
        batch=event["batch"]
        published=get(event,"window_origin","root")=="root"
        origin=published && haskey(batch,"first_seed") ? "Published seed rows" : published ? "Published parents" : "Discovered parents"
        print(io,"[",round(batch["elapsed_seconds"];digits=1),"s] ",origin," ",
            get(batch,"first_seed",get(batch,"first_parent","?")),"–",get(batch,"last_seed",get(batch,"last_parent","?")),": ",
            batch["completed"],"/",batch["target_count"]," parents in window")
        statistics=get(event,"seed_statistics",Dict())
        haskey(statistics,"completed_this_session") && print(io,"; expanded this run: ",statistics["completed_this_session"])
        println(io,".")
        if haskey(statistics,"published_completed_this_session")
            println(io,"  Published seeds completed this run: ",statistics["published_completed_this_session"],
                "/",statistics["published_selected"]," selected.")
        end
        metrics=get(event,"runtime_metrics",Dict());scheduler=get(metrics,"scheduler",Dict())
        resources=get(metrics,"resources",Dict())
        print(io,"  ",batch["processed_packets"]," work packets")
        haskey(metrics,"recent_packets_per_second") && print(io," (+",metrics["recent_packets"],
            "; ",round(metrics["recent_packets_per_second"];digits=1),"/s)")
        if haskey(scheduler,"workers_computing")
            print(io,"; results waiting to apply: ",get(scheduler,"completed",0)+get(scheduler,"completed_uncollected",0))
        end
        println(io,".")
        if get(metrics,"process_cpu_available",false) && haskey(metrics,"recent_average_cpu_cores")
            cores=metrics["recent_average_cpu_cores"];allocation=get(resources,"cpu_allocation",0)
            print(io,"  Recent CPU: ",round(cores;digits=1)," busy cores")
            allocation>0 && print(io," / ",allocation," allocated (",round(100cores/allocation;digits=1),"%)")
            println(io,"; GC: ",round(metrics["recent_gc_pause_seconds"];digits=2),"s.")
            println(io,"  Recent coordinator apply: ",round(metrics["recent_apply_seconds"];digits=2),
                "s; progress update: ",round(get(event,"publication_seconds",metrics["recent_reporting_seconds"]);digits=2),"s over ",
                round(metrics["recent_wall_seconds"];digits=1),"s (wall timers overlap).")
        end
    end
    flush(io)
    nothing
end

"""Translate a root's run-local parent ID back to its audited input row."""
function published_row(progress,parent)
    get(progress,"root_order","forward")=="reverse" ?
        Int(progress["root_last"])-parent+1 : Int(get(progress,"root_first",1))+parent-1
end

"""Keep original dispatch accounting while a retired seed waits for admission.

Fallback equivalence or idle selection must retain an existing construction
timing record. A newly selected construction cohort starts a fresh baseline.
"""
function seed_timing!(timings,root,jobs;preserve_existing=false)
    parent=Int(root["id"])
    preserve_existing && haskey(timings,parent) && return timings[parent]
    own=filter(j->j["parent_id"]==parent,jobs)
    timings[parent]=Dict("parent_id"=>parent,"origin"=>root["origin"],"source"=>root["source"],
        "previous_cosets"=>sum(max(0,Int(j["direction"])-1) for j in own if j["kind"]=="v5";init=0),
        "maximizing_five_spaces"=>count(j->j["kind"]=="v5",own),
        "previous_completed_spaces"=>count(j->j["kind"]=="v5" && j["status"]=="done",own),
        "switching_previously_complete"=>all(j->j["status"]=="done",filter(j->j["kind"]=="switching",own)))
end

"""Build one explicit read-only rank table and exclusive scratch contexts.

The table is shared across slots; geometry and Fourier work remain lazily
owned by each context. Optional preparation happens before the active search
deadline and is reported separately. Small fixtures can disable it explicitly.
"""
function worker_contexts(concurrency;precompute_rank_table=true,packed_rank_table=true,
    shared_property_cache_entries::Int=8192,geometry=FP.Fourier.geometry(8))
    concurrency>0 || throw(ArgumentError("invalid concurrency"))
    precompute_rank_table isa Bool || throw(ArgumentError("precompute_rank_table must be Boolean"))
    packed_rank_table isa Bool || throw(ArgumentError("packed_rank_table must be Boolean"))
    shared_property_cache_entries>=0 || throw(ArgumentError("invalid shared property cache capacity"))
    started=time_ns()
    table=precompute_rank_table ? (packed_rank_table ? FP.Fourier.PackedPolarRankTable(geometry) : FP.Fourier.PolarRankTable(geometry)) : nothing
    cache=shared_property_cache_entries==0 ? nothing : FP.DiscoveryEvidence.PropertyCache(;max_entries=shared_property_cache_entries)
    contexts=[FP.ClosureWorkContext(;rank_table=table,property_cache=cache) for _ in 1:concurrency]
    (;contexts,rank_table_build_seconds=(time_ns()-started)*1e-9,
        rank_table_bytes=table===nothing ? 0 : table isa FP.Fourier.PackedPolarRankTable ? length(table.codes) : length(table.ranks),
        rank_table_encoding=table===nothing ? "none" : packed_rank_table ? "two-bit" : "byte")
end

"""Snapshot each distinct verified-property cache once, under its own short lock."""
function property_cache_statistics(contexts)
    seen=Base.IdSet{FP.DiscoveryEvidence.PropertyCache}()
    totals=Dict("caches"=>0,"capacity"=>0,"entries"=>0,"hits"=>0,"misses"=>0)
    for context in contexts
        cache=context.property_cache
        cache in seen && continue
        push!(seen,cache)
        lock(cache.guard) do
            totals["caches"]+=1;totals["capacity"]+=cache.max_entries
            totals["entries"]+=length(cache.values);totals["hits"]+=cache.hits;totals["misses"]+=cache.misses
        end
    end
    totals
end

"""Select unfinished construction parents, optionally with EA/idle bookkeeping.

Fallback owners may lie outside the construction scope; their selection kind
instructs the controller to dispatch only global EA work and no constructions.
"""
function select_parents(db,window_size;parent_scope="all",fallback=false,excluded_parents=Int[],only_origin=nothing)
    window_size>0 || throw(ArgumentError("invalid window size"))
    parent_scope in ("all","discovered") || throw(ArgumentError("invalid parent scope"))
    excluded=isempty(excluded_parents) ? "0" : join(sort!(unique(Int.(excluded_parents))),",")
    unfinished="p.id NOT IN ($excluded) AND EXISTS(SELECT 1 FROM jobs j WHERE j.parent_id=p.id AND j.kind IN ('prepare_v5','v5','switching') AND j.status!='done')"
    origins=parent_scope=="discovered" ? ("discovered",) : ("root","discovered")
    for origin in origins
        only_origin===nothing || origin==only_origin || continue
        rows=FP._closure_rows(db,"SELECT id,source,origin FROM parents p WHERE p.origin=? AND $unfinished ORDER BY id LIMIT ?",(origin,window_size))
        isempty(rows) || return rows
    end
    if fallback
        rows=FP._closure_rows(db,"SELECT p.id,p.source,p.origin FROM parents p WHERE EXISTS(SELECT 1 FROM jobs j WHERE j.parent_id=p.id AND j.kind='deduplicate' AND j.status IN ('pending','paused')) ORDER BY p.id LIMIT ?",(window_size,))
        kind="equivalence"
        if isempty(rows)
            rows=FP._closure_rows(db,"SELECT id,source,origin FROM parents ORDER BY id LIMIT 1")
            kind="idle"
        end
        for row in rows;row["selection_kind"]=kind;end
        return rows
    end
    Any[]
end

"""Bind bounded reservation sets without generating a new SQL program per packet.

SQLite's JSON table is statement-local: no durable reservation state or extra
writer is introduced. Inputs are controller-owned integer IDs, never SQL text.
The partial queue index and deterministic ordering match the literal queries.
"""
_reservation_ids_json(ids)=String(FP.JSON3.write(sort!(Int[id for id in ids])))
function _reservation_ea_sql(indexed)
    index=indexed ? " INDEXED BY jobs_pending_ea" : ""
    "SELECT * FROM jobs$index WHERE kind='deduplicate' AND status IN ('pending','paused') AND (last_session!=? OR id IN (SELECT value FROM json_each(?))) AND id NOT IN (SELECT value FROM json_each(?)) ORDER BY id LIMIT ?"
end
function _reservation_construction_sql(ids,indexed=false)
    index=indexed ? " INDEXED BY jobs_pending_construction" : ""
    "SELECT * FROM jobs$index WHERE parent_id IN ($ids) AND kind IN ('prepare_v5','v5','switching') AND status IN ('pending','paused') AND id NOT IN (SELECT value FROM json_each(?)) ORDER BY parent_id,id LIMIT ?"
end
function _reservation_failed_construction_sql(ids,indexed=false)
    index=indexed ? " INDEXED BY jobs_failed_construction" : ""
    "SELECT EXISTS(SELECT 1 FROM jobs$index WHERE parent_id IN ($ids) AND kind IN ('prepare_v5','v5','switching') AND status IN ('failed','blocked') LIMIT 1) n"
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
    resources=validate_resources(config);concurrency=resources["concurrency"]
    human_progress=get(config,"human_progress",false)
    human_progress isa Bool || throw(ArgumentError("human_progress must be Boolean"))
    console(event)=console_event(event;human=human_progress)
    for message in resources["warnings"];println(stderr,message);end
    cached_global_counts=get(config,"cached_global_counts",false)
    cached_global_counts isa Bool || throw(ArgumentError("cached_global_counts must be Boolean"))
    report_counters=nothing;seed_summary_cache=ClosureOperations.SeedSummaryCache()
    report_interval=Float64(get(config,"report_interval_seconds",15.0))
    global_count_interval=Float64(get(config,"global_count_interval_seconds",60.0))
    isfinite(report_interval) && report_interval>0 || throw(ArgumentError("invalid report interval"))
    isfinite(global_count_interval) && global_count_interval>=0 || throw(ArgumentError("invalid global count interval"))
    max_pending=Int(get(config,"reservation_horizon",2concurrency))
    max_pending>=concurrency || error("reservation horizon must cover every slot")
    reservation_refill_batch=Int(get(config,"reservation_refill_batch",1))
    1<=reservation_refill_batch<=max_pending || throw(ArgumentError("reservation refill batch must be between 1 and the reservation horizon"))
    max_apply_per_step=Int(get(config,"max_apply_per_step",concurrency))
    max_apply_per_step>0 || throw(ArgumentError("invalid application step bound"))
    indexed_ea_queue=get(config,"indexed_ea_queue",true)
    indexed_ea_queue isa Bool || throw(ArgumentError("indexed_ea_queue must be Boolean"))
    indexed_construction_queue=get(config,"indexed_construction_queue",true)
    indexed_construction_queue isa Bool || throw(ArgumentError("indexed_construction_queue must be Boolean"))
    ea_queue_sql=_reservation_ea_sql(indexed_ea_queue)
    Int(get(config,"window_size",100))>0 || error("invalid window size")
    rolling_windows=get(config,"rolling_windows",false)
    rolling_windows isa Bool || throw(ArgumentError("rolling_windows must be Boolean"))
    max_windows=Int(get(config,"max_windows",typemax(Int)))
    max_windows>0 || throw(ArgumentError("invalid window limit"))
    parent_scope=String(get(config,"parent_scope","all"))
    parent_scope in ("all","discovered") || throw(ArgumentError("invalid parent scope"))
    execution_scope=parent_scope=="discovered" ? "recursively expand discovered quadratic classes only; published roots retained as completed provenance" : "finish remaining published roots, then recursively expand admitted quadratic classes"
    ispath(out) && error("evidence directory must be new")
    mkpath(out)
    telemetry=ClosureOperations.TelemetryLog(out,config)
    telemetry_error=""
    function emit!(name,value)
        isempty(telemetry_error) || return
        try
            ClosureOperations.telemetry!(telemetry,name,value)
        catch error
            telemetry_error=sprint(showerror,error)
            println(stderr,"Telemetry disabled after an operational error: ",telemetry_error)
            try
                FP.DiscoveryStore.atomic_toml(joinpath(out,"telemetry-error.toml"),Dict("error"=>telemetry_error,"scientific_evidence_retained"=>true))
            catch
            end
        end
    end
    runtime=ClosureOperations.RuntimeMetrics()
    last_console_metrics=(wall=0.0,cpu=0.0,gc=0.0,apply=0.0,reporting=0.0,packets=0)
    storage_paths=vcat([directory,out],String.(get(config,"storage_paths",String[])))
    checkpoint_root=String(get(config,"checkpoint_directory",""))
    isempty(checkpoint_root) || push!(storage_paths,abspath(checkpoint_root))
    storage=ClosureOperations.StorageGuard(config,storage_paths)
    checkpoint_interval=Float64(get(config,"checkpoint_interval_seconds",0.0))
    checkpoint_keep=Int(get(config,"checkpoint_keep",2))
    isfinite(checkpoint_interval) && checkpoint_interval>=0 && checkpoint_keep>=1 || throw(ArgumentError("invalid checkpoint policy"))
    checkpoint_interval==0 || !isempty(checkpoint_root) || throw(ArgumentError("checkpoint interval requires checkpoint_directory"))
    checkpoint_generation=0;last_checkpoint=time();checkpoint_exports=String[];checkpoint_error=""
    cold_directory=String(get(config,"evidence_segment_directory",""))
    isempty(cold_directory) || push!(storage.paths,abspath(cold_directory))
    segment_interval=Float64(get(config,"evidence_segment_interval_seconds",60.0));last_segment=time()
    isfinite(segment_interval) && segment_interval>0 || throw(ArgumentError("invalid evidence segment interval"))
    for key in ("measure_result_bytes","checkpoint_on_stop")
        get(config,key,false) isa Bool || throw(ArgumentError("$key must be Boolean"))
    end
    if !isempty(cold_directory)
        rows=Int(get(config,"evidence_segment_rows",256));bytes=Int(get(config,"evidence_segment_bytes",16*1024^2))
        1<=rows<=65536 && 12<=bytes<=256*1024^2 || throw(ArgumentError("invalid evidence segment bounds"))
    end
    helper=abspath(get(config,"seed_progress_helper",joinpath(@__DIR__,"closure_seed_progress.jl")))
    reporter=Base.include(@__MODULE__,helper)
    seed_summary(store)=ClosureOperations.seed_summary!(seed_summary_cache,
        db->Base.invokelatest(reporter,db),store,Int(store.identity["initial_roots"]))
    for (source,name) in ((@__FILE__,"controller.jl"),(joinpath(@__DIR__,"closure_baseline.jl"),"baseline-controller.jl"),
            (joinpath(@__DIR__,"closure_refill.jl"),"refill-controller.jl"),
            (joinpath(@__DIR__,"closure_batches.jl"),"batches-controller.jl"),
            (joinpath(@__DIR__,"closure_completion.jl"),"completion-controller.jl"),
            (joinpath(@__DIR__,"closure_operations.jl"),"operations-controller.jl"),(helper,"seed-progress-helper.jl"))
        cp(source,joinpath(out,name))
        # Preserve the literal include filenames as well as historical evidence
        # aliases, so the copied controller can resolve every sibling helper.
        basename(source)==name || cp(source,joinpath(out,basename(source)))
    end
    FP.DiscoveryStore.atomic_toml(joinpath(out,"config.toml"),config)
    base=TOML.parsefile(joinpath(directory,"progress.toml"))
    base["directory"]=directory
    FP.DiscoveryStore.atomic_toml(joinpath(out,"progress-before.toml"),base)
    ids="0";window_origin="root";window_kind="construction";windows_completed=0;window_active=true;completed_this_session=0
    published_completed_this_session=0
    windows_started=0;cohorts=Vector{Vector{Int}}()
    context_setup=worker_contexts(concurrency;precompute_rank_table=get(config,"precompute_rank_table",true),
        packed_rank_table=get(config,"packed_rank_table",true),
        shared_property_cache_entries=Int(get(config,"shared_property_cache_entries",8192)))
    started=time();active_started=0.0;deadline=started+Float64(get(config,"duration_seconds",Inf))
    s=nothing;state="failed";processed=0;evaluated=0;baseline=nothing;primary_failure=nothing
    execute_control=sql->FP._closure_exec(s,sql)
    last_completion_check=0.0;completion=nothing;completion_record_seconds=0.0;completion_metrics=Dict{String,Any}()
    target_cache=nothing
    global_counts=Dict{String,Any}();last_global_count=-Inf;last_publication_key=nothing;last_publication_fresh=false
    before_jobs=Any[];before_paths=Dict{String,Int}();before_kernels=0;last_report=0.0;timings=Dict{Int,Dict{String,Any}}();history=Dict{String,Any}[];completion_events=Float64[];deferred=Dict{Int,Float64}();ea_attempts=Dict{Int,Int}()
    stop_path=joinpath(directory,"STOP");prior_stop=isfile(stop_path) ? read(stop_path) : nothing
    contexts=context_setup.contexts
    external=FP._closure_stop_poller(stop_path,joinpath(out,"STOP"),String.(get(config,"stop_files",String[]))...)
    stopped()=external() || storage.stopped[] || time()>=deadline
    construction()=FP._closure_rows(s,"SELECT * FROM jobs WHERE parent_id IN ($ids) AND kind IN ('prepare_v5','v5','switching') ORDER BY parent_id,id")
    paths(kind)=FP._closure_count(s,"SELECT COUNT(*) n FROM paths WHERE job_id IN (SELECT id FROM jobs WHERE parent_id IN ($ids) AND kind=?)",(kind,))
    kernels()=FP._closure_count(s,"SELECT COUNT(*) n FROM kernels WHERE job_id IN (SELECT id FROM jobs WHERE parent_id IN ($ids) AND kind='switching') AND dimension>0")
    cosets(rows)=sum(max(0,Int(j["direction"])-1) for j in rows if j["kind"]=="v5";init=0)
    count_status(rows,kinds,status)=count(j->j["kind"] in kinds && j["status"]==status,rows)
    function select_window!()
        roots=select_parents(s,Int(get(config,"window_size",100));parent_scope,fallback=true)
        isempty(roots) && return false
        for p in parents
            haskey(timings,p) && haskey(timings[p],"completed_utc") && delete!(timings,p)
        end
        window_kind=String(get(first(roots),"selection_kind","construction"));window_active=window_kind=="construction"
        parents=Int[r["id"] for r in roots];ids=window_active ? join(parents,",") : "0";window_origin=String(first(roots)["origin"])
        empty!(cohorts)
        if window_active
            push!(cohorts,copy(parents));windows_started+=1
            ClosureCompletion.track!(completion,parents)
        end
        before_jobs=construction();before_paths=Dict(kind=>paths(kind) for kind in ("v5","switching"));before_kernels=kernels()
        for root in roots
            seed_timing!(timings,root,before_jobs;preserve_existing=!window_active)
        end
        event=Dict{String,Any}("event"=>"window_started","origin"=>window_origin,"kind"=>window_kind,"first"=>first(parents),"last"=>last(parents))
        window_origin=="root" && merge!(event,Dict("first_seed"=>published_row(base,first(parents)),"last_seed"=>published_row(base,last(parents))))
        console(event)
        true
    end
    function record_completed!(jobs=nothing;selected_parents=nothing)
        completion===nothing && return
        SQLite.intransaction(s.db) && return
        check_started=time_ns()
        try
        ready=ClosureCompletion.ready(completion)
        selected_parents===nothing || filter!(p->p in selected_parents,ready)
        isempty(ready) && return
        if jobs===nothing
            selected_json=String(FP.JSON3.write(ready))
            jobs=FP._closure_rows(s,"SELECT * FROM jobs WHERE parent_id IN (SELECT value FROM json_each(?)) AND kind IN ('prepare_v5','v5','switching')",(selected_json,))
        end
        for parent in ready
            t=timings[parent];haskey(t,"completed_utc") && continue
            own=filter(j->j["parent_id"]==parent,jobs)
            now=time();t["completed_utc"]=FP._closure_now()
            t["batch_completion_seconds"]=now-active_started
            t["elapsed_from_first_dispatch_seconds"]=now-get(t,"first_dispatch_epoch",now)
            t["remaining_cosets_completed"]=cosets(own)-t["previous_cosets"]
            t["total_cosets_completed"]=cosets(own)
            t["construction_jobs"]=length(own)
            t["maximizing_five_spaces"]=count(j->j["kind"]=="v5",own)
            push!(history,deepcopy(t));push!(completion_events,now)
            completed_this_session+=1
            get(t,"origin","root")=="root" && (published_completed_this_session+=1)
            same_origin=findall(x->get(x,"origin","root")==t["origin"],history)
            length(same_origin)>100 && deleteat!(history,first(same_origin))
            filter!(t->now-t<=300,completion_events)
            emit!("seed-timings.jsonl",t)
            console(Dict("event"=>"seed_completed","parent_id"=>parent,"timing"=>t,
                "completed_this_session"=>completed_this_session))
        end
        ClosureCompletion.release!(completion,ready)
        active_parent_ids=Set(parents)
        for p in ready
            !(p in active_parent_ids) && haskey(timings[p],"completed_utc") && delete!(timings,p)
        end
        finally
            completion_record_seconds+=(time_ns()-check_started)*1e-9
        end
    end
    function publish!(;finished=false,force=false,fresh_counts=false)
        !force && time()-last_report<report_interval && return
        publication_key=(processed,windows_completed,Tuple(parents),state,finished)
        # Boundary/final checkpoint exports can request the report just written.
        force && publication_key==last_publication_key && (!fresh_counts || last_publication_fresh) && time()-last_report<report_interval && return
        publish_started=time_ns();publish_times=Dict{String,Float64}()
        now=FP._closure_now();jobs=construction();report=deepcopy(base)
        report["updated_utc"]=now;report["heartbeat_utc"]=now
        report["heartbeat_age_seconds"]=0.0;report["heartbeat_stale"]=false
        report["running"]=!finished;report["state"]=finished || state=="waiting_frontier" ? state : "running"
        recount=finished || fresh_counts || time()-last_global_count>=global_count_interval
        if recount
            stage_started=time_ns();global_counts["seed_progress"]=seed_summary(s)
            publish_times["seed_progress"]=(time_ns()-stage_started)*1e-9
            if report_counters===nothing
                for (key,sql) in (("total_parents","SELECT COUNT(*) n FROM parents"),("promoted_parents","SELECT COUNT(*) n FROM parents WHERE origin='discovered'"),
                        ("exact_luts","SELECT COUNT(*) n FROM candidates"),("quadratic_apn_luts","SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2"),
                        ("nonquadratic_apn_luts","SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree>2"),
                        ("unresolved_equivalence","SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2 AND class_id IS NULL"))
                    stage_started=time_ns();global_counts[key]=FP._closure_count(s,sql)
                    publish_times[key]=(time_ns()-stage_started)*1e-9
                end
                global_counts["verified_equivalent_luts"]=FP._closure_count(s,"SELECT COUNT(*) n FROM candidates WHERE state='equivalent'")
                if cached_global_counts
                    stage_started=time_ns();report_counters=ClosureOperations.install_report_counters!(s,global_counts)
                    publish_times["counter_setup"]=(time_ns()-stage_started)*1e-9
                end
            else
                stage_started=time_ns();merge!(global_counts,ClosureOperations.report_counter_snapshot(report_counters))
                publish_times["transactional_counters"]=(time_ns()-stage_started)*1e-9
            end
            last_global_count=time()
        end
        for (key,value) in global_counts
            key=="verified_equivalent_luts" || (report[key]=deepcopy(value))
        end
        report["global_count_policy"]=cached_global_counts ? "session-local transactional TEMP counters; fresh initial backfill" : "periodic exact SQL counts"
        report["seed_progress_cache"]=Dict("terminal"=>seed_summary_cache.terminal!==nothing,"hits"=>seed_summary_cache.hits,"misses"=>seed_summary_cache.misses)
        report["global_counts_current"]=recount
        report["global_counts_age_seconds"]=max(0.0,time()-last_global_count)
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
        report["cluster"]["verified_equivalent_luts"]=global_counts["verified_equivalent_luts"]
        publish_times["equivalent_count"]=(time_ns()-stage_started)*1e-9
        stage_started=time_ns()
        # These global DISTINCT aggregates can spill hundreds of GiB to a
        # temporary sorter. Shutdown must not depend on cosmetic recounts.
        # Keep the last cached values and explicitly mark their freshness.
        report["signature_buckets_current"]=false
        report["cluster"]["repeated_derivation_paths_current"]=false
        publish_times["finished_counters"]=(time_ns()-stage_started)*1e-9
        FP._closure_exec(s,"UPDATE sessions SET heartbeat=?,jobs=?,evaluations=? WHERE id=?",(now,processed,evaluated,s.session))
        row=only(FP._closure_rows(s,"SELECT id,started,finished,heartbeat,pid,host,state,jobs,evaluations FROM sessions WHERE id=?",(s.session,)))
        report["sessions"]=vcat([row],[r for r in base["sessions"] if r["id"]!=s.session])
        batch=Dict("first_parent"=>isempty(parents) ? 0 : first(parents),"last_parent"=>isempty(parents) ? 0 : last(parents),"target_count"=>window_kind=="construction" ? length(parents) : 0,"window_kind"=>window_kind,
            "completed"=>count(p->haskey(timings,p) && haskey(timings[p],"completed_utc"),parents),"processed_packets"=>processed,
            "elapsed_seconds"=>time()-started,"active_seconds"=>active_started>0 ? time()-active_started : 0.0,
            "scope"=>execution_scope*"; both constructions; EA admission before recursion")
        report["root_batch"]=batch
        if window_origin=="root" && !isempty(parents)
            batch["first_seed"]=published_row(base,first(parents));batch["last_seed"]=published_row(base,last(parents))
        end
        report["continuous_search"]=merge(batch,Dict("window_origin"=>window_origin,"windows_completed"=>windows_completed,"windows_started"=>windows_started,"rolling_windows"=>rolling_windows,"active_windows"=>window_active ? length(cohorts) : 0,"duration_policy"=>"until STOP","parent_scope"=>parent_scope))
        report["seed_statistics"]=seed_statistics(history,completion_events,active_started;now=time(),completed_this_session,parent_scope)
        report["seed_statistics"]["published_completed_this_session"]=published_completed_this_session
        report["seed_statistics"]["published_selected"]=Int(s.identity["initial_roots"])
        report["runtime_metrics"]=ClosureOperations.runtime_snapshot(runtime,resources)
        metrics=report["runtime_metrics"]
        apply_total=sum(get(t,"apply_wall_seconds",0.0) for t in values(metrics["packet_totals"]);init=0.0)
        current=(wall=metrics["wall_seconds"],cpu=metrics["process_cpu_seconds"],
            gc=metrics["gc_pause_seconds"],apply=apply_total,reporting=metrics["reporting_seconds"],packets=processed)
        interval=max(0.0,current.wall-last_console_metrics.wall)
        metrics["recent_wall_seconds"]=interval
        metrics["recent_average_cpu_cores"]=interval>0 ? max(0.0,current.cpu-last_console_metrics.cpu)/interval : 0.0
        metrics["recent_gc_pause_seconds"]=max(0.0,current.gc-last_console_metrics.gc)
        metrics["recent_apply_seconds"]=max(0.0,current.apply-last_console_metrics.apply)
        metrics["recent_reporting_seconds"]=max(0.0,current.reporting-last_console_metrics.reporting)
        metrics["recent_packets"]=max(0,current.packets-last_console_metrics.packets)
        metrics["recent_packets_per_second"]=interval>0 ? metrics["recent_packets"]/interval : 0.0
        last_console_metrics=current
        completion_metrics=completion===nothing ? Dict{String,Any}() : merge(ClosureCompletion.snapshot(completion),Dict("record_seconds"=>completion_record_seconds))
        report["runtime_metrics"]["completion"]=completion_metrics
        report["runtime_metrics"]["parent_target_cache"]=target_cache===nothing ? Dict{String,Any}() : FP._closure_parent_target_cache_stats(target_cache)
        report["runtime_metrics"]["statement_cache"]=FP.DiscoveryStore.statement_cache_stats(s.statements)
        report["runtime_metrics"]["property_cache"]=property_cache_statistics(contexts)
        report["storage_policy"]=merge(copy(storage.snapshot),Dict("stop_reason"=>storage.reason))
        report["checkpoint_error"]=checkpoint_error
        report["telemetry"]=Dict("enabled"=>isempty(telemetry_error),"error"=>telemetry_error,
            "segment_bytes"=>telemetry.segment_bytes,"keep_segments"=>telemetry.keep)
        FP.DiscoveryStore.atomic_toml(joinpath(directory,"progress.toml"),report)
        payload=Dict("state"=>report["state"],"running"=>!finished,"session_id"=>s.session,"pid"=>getpid(),
            "batch"=>batch,"seed_progress"=>report["seed_progress"],"total_parents"=>report["total_parents"],
            "exact_luts"=>report["exact_luts"],"unresolved_equivalence"=>report["unresolved_equivalence"],
            "seed_statistics"=>report["seed_statistics"],"window_origin"=>window_origin,
            "runtime_metrics"=>report["runtime_metrics"],"storage_policy"=>report["storage_policy"])
        tmp=joinpath(out,"progress.json.tmp");write(tmp,FP.JSON3.write(payload));mv(tmp,joinpath(out,"progress.json");force=true)
        publish_times["total"]=(time_ns()-publish_started)*1e-9
        runtime.reporting_seconds+=publish_times["total"]
        emit!("publish-metrics.jsonl",Dict("utc"=>FP._closure_now(),"finished"=>finished,"processed_packets"=>processed,"seconds"=>publish_times))
        console(Dict("event"=>"batch_progress","batch"=>batch,"window_origin"=>window_origin,
            "seed_statistics"=>report["seed_statistics"],"runtime_metrics"=>report["runtime_metrics"],
            "publication_seconds"=>publish_times["total"]));last_report=time();last_publication_key=publication_key;last_publication_fresh=recount
    end
    function prepare_item(item,ticket,slot)
        job=item.job;equivalence=item.equivalence
        FP._closure_exec(s,"UPDATE jobs SET status='running',last_session=?,error='' WHERE id=?",(s.session,job["id"]))
        if !equivalence
            t=timings[Int(job["parent_id"])]
            get!(t,"first_dispatch_epoch",time());get!(t,"first_dispatch_utc",FP._closure_now())
        end
        packet=equivalence ? FP._closure_equivalence_packet(s,job;native=true,target_cache) : FP._closure_work_packet(s,job)
        level=min(get(ea_attempts,Int(job["id"]),0),2)
        (;job,packet,equivalence,level,ticket,slot)
    end
    function compute_item(item,slot,pool_stopped)
        if item.equivalence
            FP._closure_equivalence_compute(item.packet;
                seconds=min(300.0,Float64(get(config,"equivalence_seconds",30.0))*4^item.level),
                nodes=min(1_000_000,Int(get(config,"equivalence_nodes",100_000))*4^item.level),
                context=contexts[slot],solver_session=s.solver_session)
        else
            FP._closure_compute(item.packet;context=contexts[slot],
                seconds=max(0.0,min(300.0,deadline-time())),evaluations=256,stop_requested=pool_stopped)
        end
    end
    function finish_item(item,value,compute_seconds,scheduling)
            job=item.job;packet=item.packet;equivalence=item.equivalence;apply_started=time_ns()
            if equivalence
                outcome=closure_apply_savepoint!(s.db;execute_control) do
                    FP._closure_equivalence_apply!(s,job,packet,value;target_cache)
                end
                if outcome==:unresolved
                    deferred[Int(job["id"])]=time()+300
                    ea_attempts[Int(job["id"])]=get(ea_attempts,Int(job["id"]),0)+1
                else
                    delete!(deferred,Int(job["id"]));delete!(ea_attempts,Int(job["id"]))
                end
            else
                evaluated+=closure_apply_savepoint!(s.db;execute_control) do
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
            ClosureOperations.record_packet!(runtime,job["kind"],compute_seconds,apply_seconds,scheduling.ready_wait_seconds)
            emit!("packet-metrics.jsonl",metric)
            processed+=1
    end
    # At most two deterministic parent cohorts overlap. A new cohort becomes
    # eligible only from the committed prefix and only when the existing queue
    # cannot fill the reservation horizon. Retired cohort deltas are folded into
    # the persisted report before their local accounting is released.
    function advance_rolling_window!()
        rolling_windows && window_kind=="construction" || return false
        changed=false
        while !isempty(cohorts)
            cohort=first(cohorts);selected=join(cohort,",")
            unfinished=FP._closure_count(s,"SELECT EXISTS(SELECT 1 FROM jobs WHERE parent_id IN ($selected) AND kind IN ('prepare_v5','v5','switching') AND status!='done') n")
            unfinished==0 || break
            record_completed!(construction();selected_parents=cohort)
            windows_completed+=1
            console(Dict("event"=>"window_drained","first"=>first(cohort),"last"=>last(cohort)))
            publish!(;force=true,fresh_counts=true)
            base=TOML.parsefile(joinpath(directory,"progress.toml"))
            popfirst!(cohorts);filter!(p->!(p in cohort),parents)
            for p in cohort
                haskey(timings,p) && haskey(timings[p],"completed_utc") && delete!(timings,p)
            end
            ids=isempty(parents) ? "0" : join(parents,",")
            before_jobs=construction();before_paths=Dict(kind=>paths(kind) for kind in ("v5","switching"));before_kernels=kernels()
            changed=true
        end
        if length(cohorts)<2 && windows_started<max_windows && !stopped()
            roots=select_parents(s,Int(get(config,"window_size",100));parent_scope,
                excluded_parents=parents,only_origin=window_origin)
            if !isempty(roots)
                # Fold existing deltas once before adding potentially resumed
                # parents, whose previous work is already included in base.
                if !isempty(parents)
                    publish!(;force=true,fresh_counts=true)
                    base=TOML.parsefile(joinpath(directory,"progress.toml"))
                end
                selected=Int[r["id"] for r in roots]
                ClosureCompletion.track!(completion,selected)
                append!(parents,selected);ids=join(parents,",")
                before_jobs=construction();before_paths=Dict(kind=>paths(kind) for kind in ("v5","switching"));before_kernels=kernels()
                for root in roots
                    seed_timing!(timings,root,before_jobs)
                end
                push!(cohorts,selected);windows_started+=1;changed=true
                event=Dict{String,Any}("event"=>"window_started","origin"=>window_origin,"kind"=>"construction",
                    "first"=>first(selected),"last"=>last(selected),"rolling"=>true,"active_windows"=>length(cohorts))
                window_origin=="root" && merge!(event,Dict("first_seed"=>published_row(base,first(selected)),"last_seed"=>published_row(base,last(selected))))
                console(event)
            end
        end
        window_active=!isempty(cohorts)
        changed
    end
    function reserve_items(limit,excluded)
        retries_json=_reservation_ids_json(id for (id,when) in deferred if when<=time())
        excluded_json=_reservation_ids_json(excluded)
        ea=FP._closure_rows(s,ea_queue_sql,(s.session,retries_json,excluded_json,limit))
        items=Any[(job=j,equivalence=true) for j in ea]
        length(items)==limit && return items
        failed=FP._closure_count(s,_reservation_failed_construction_sql(ids,indexed_construction_queue))
        failed==0 || error("parent coverage requires recovery")
        pending=FP._closure_rows(s,_reservation_construction_sql(ids,indexed_construction_queue),(excluded_json,limit-length(items)))
        append!(items,[(job=j,equivalence=false) for j in pending])
        if length(items)<limit && advance_rolling_window!()
            # Requery after the bounded frontier changes. Existing descriptors
            # remain in the FIFO, and exclusions preserve unique reservations.
            used=union(excluded,Set(Int[item.job["id"] for item in items]))
            used_json=_reservation_ids_json(used)
            extra=FP._closure_rows(s,_reservation_construction_sql(ids,indexed_construction_queue),(used_json,limit-length(items)))
            append!(items,[(job=j,equivalence=false) for j in extra])
        end
        items
    end
    function report_tick()
        target_cache===nothing || FP._closure_parent_target_cache_boundary!(target_cache)
        ClosureOperations.check_storage!(storage)
        if time()-last_completion_check>=1.0
            record_completed!();last_completion_check=time()
        end
        publish!()
        maintenance!()
    end
    function export_checkpoint!(;force=false)
        isempty(checkpoint_root) && return
        !force && (checkpoint_interval==0 || time()-last_checkpoint<checkpoint_interval) && return
        ClosureOperations.check_storage!(storage;force=true)
        storage.stopped[] && return
        SQLite.intransaction(s.db) && error("checkpoint export requires a committed boundary")
        checkpoint_generation+=1
        target=joinpath(checkpoint_root,"checkpoint-$(s.session)-$(round(Int,time()*1000))-$(checkpoint_generation)")
        t=time()
        project=get(config,"checkpoint_active_project",nothing)
        stage="preflight"
        try
        mkpath(checkpoint_root)
        # Include staged replay, active DB, WAL and external cold segments. The
        # destination file-system preflight additionally runs inside export.
        needed=Int128(filesize(joinpath(directory,"closure.sqlite")))
        wal=joinpath(directory,"closure.sqlite-wal");isfile(wal) && (needed+=filesize(wal))
        needed+=FP._closure_portable_tree_bytes(joinpath(directory,"replay"))
        needed+=FP._closure_portable_tree_bytes(joinpath(directory,"execution"))
        needed+=sum((filesize(p) for p in values(FP.closure_segment_artifacts(s.db,directory)));init=Int128(0))
        needed=cld(11needed,10)+1024^2
        over_limit=storage.maximum>0 && Int128(storage.snapshot["bytes"])+needed+storage.reserve>=storage.maximum
        quota_free=get(storage.snapshot,"quota_available_bytes",typemax(Int))
        if over_limit || Int128(quota_free)<needed+storage.reserve+storage.minimum_free
            storage.reason=over_limit ? "checkpoint_storage_max_bytes" : "checkpoint_quota_available_bytes";storage.stopped[]=true
            return
        end
        stage="progress"
        publish!(;force=true,finished=force,fresh_counts=true)
        stage="export"
        FP.closure_export_checkpoint(s;output=target,active_project=project,reserve_bytes=storage.minimum_free+storage.reserve)
        stage="retention"
        identity_sha=FP.DiscoveryEvidence.filehash(joinpath(directory,"identity.toml"))
        checkpoint_exports=ClosureOperations.checkpoint_generations(checkpoint_root,identity_sha;excluded_paths=[directory])
        # A newly verified generation is kept even if an older manifest claims
        # a future creation date. Never remove it during this retention pass.
        filter!(p->p!=target,checkpoint_exports);push!(checkpoint_exports,target)
        last_checkpoint=time();runtime.checkpoint_seconds+=last_checkpoint-t
        while length(checkpoint_exports)>checkpoint_keep
            rm(first(checkpoint_exports);recursive=true);popfirst!(checkpoint_exports)
        end
        emit!("checkpoint-metrics.jsonl",Dict("utc"=>FP._closure_now(),"path"=>target,"seconds"=>last_checkpoint-t))
        catch error
            checkpoint_error=sprint(showerror,error);storage.reason="checkpoint_$(stage)_failed";storage.stopped[]=true
            try
                FP.DiscoveryStore.atomic_toml(joinpath(out,"checkpoint-export-error.toml"),Dict("target"=>target,"stage"=>stage,"error"=>checkpoint_error,"previous_generations_preserved"=>true))
            catch
            end
        end
    end
    function maintenance!()
        ClosureOperations.check_storage!(storage)
        stopped() && return
        if !isempty(cold_directory) && time()-last_segment>=segment_interval
            FP.closure_seal_segments!(s;cold_directory,
                max_rows=Int(get(config,"evidence_segment_rows",256)),max_bytes=Int(get(config,"evidence_segment_bytes",16*1024^2)))
            last_segment=time()
        end
        export_checkpoint!()
    end
    try
        println(human_progress ? "Starting recursive search…" : "Opening the archived checkpoint once for continuous seed expansion");flush(stdout)
        opened=time();s=FP._closure_open(directory);validated=time()
        active_environment=ClosureOperations.bind_active_environment!(s)
        if !isempty(checkpoint_root)
            checkpoint_exports=ClosureOperations.checkpoint_generations(checkpoint_root,
                FP.DiscoveryEvidence.filehash(joinpath(directory,"identity.toml"));excluded_paths=[directory])
        end
        bound_cold=FP._closure_rows(s,"SELECT value FROM metadata WHERE key='closure_segment_root'")
        isempty(bound_cold) || push!(storage.paths,FP._closure_segment_root(s.db,directory))
        sources=String[@__FILE__,helper]
        append!(sources,[joinpath(@__DIR__,name) for name in ("closure_baseline.jl","closure_refill.jl","closure_batches.jl","closure_operations.jl","closure_completion.jl","closure_run.jl","closure_supervise.py")])
        digests=Dict(basename(path)=>FP.DiscoveryEvidence.filehash(path) for path in sources if isfile(path))
        bundle_digest=bytes2hex(SHA.sha256(FP._closure_text(digests)))
        controller_archive=joinpath(directory,"execution","controllers",bundle_digest);mkpath(controller_archive)
        for source in sources
            isfile(source) || continue
            target=joinpath(controller_archive,basename(source))
            if isfile(target)
                FP.DiscoveryEvidence.filehash(target)==FP.DiscoveryEvidence.filehash(source) || error("archived controller helper differs")
            else
                cp(source,target)
            end
            FP.DiscoveryEvidence.filehash(target)==digests[basename(source)] || error("controller source changed during archival")
        end
        FP.DiscoveryStore.atomic_toml(joinpath(controller_archive,"files.toml"),digests)
        FP._closure_count(s,"SELECT COUNT(*) n FROM sessions WHERE finished='' ")==0 || error("source session unfinished")
        if indexed_ea_queue
            FP._closure_exec(s,"CREATE INDEX IF NOT EXISTS jobs_pending_ea ON jobs(id,last_session) WHERE kind='deduplicate' AND status IN ('pending','paused')")
        end
        if indexed_construction_queue
            FP._closure_exec(s,"CREATE INDEX IF NOT EXISTS jobs_pending_construction ON jobs(parent_id,id) WHERE kind IN ('prepare_v5','v5','switching') AND status IN ('pending','paused')")
            FP._closure_exec(s,"CREATE INDEX IF NOT EXISTS jobs_failed_construction ON jobs(parent_id) WHERE kind IN ('prepare_v5','v5','switching') AND status IN ('failed','blocked')")
        end
        baseline=continuous_baseline!(s,out;policy=String(get(config,"baseline_policy","summary")),
            cached_progress=base,full_reserve_bytes=Int(get(config,"full_baseline_reserve_bytes",8*1024^3)))
        FP.DiscoveryStore.atomic_toml(joinpath(out,"baseline.toml"),baseline)
        ClosureOperations.check_storage!(storage;force=true)
        if haskey(config,"timing_history")
            prior=FP.JSON3.read(read(config["timing_history"],String),Dict{String,Any})
            append!(history,[Dict{String,Any}(t) for t in prior["timings"]])
        end
        completion=ClosureCompletion.install!(s)
        target_cache=FP._ClosureParentTargetCache(s)
        select_window!() || error("closure checkpoint contains no parent")
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
            "shared_property_cache_entries"=>Int(get(config,"shared_property_cache_entries",8192)),
            "scheduler"=>"bounded reserved FIFO; continuous slot refill; ordered durable apply",
            "scheduler_determinism"=>"FIFO reservation and application for a fixed eligible frontier; retry cooldowns and wall-clock budgets retained",
            "reservation_horizon"=>max_pending,"reservation_refill_batch"=>reservation_refill_batch,"rolling_windows"=>rolling_windows,"max_overlapping_windows"=>rolling_windows ? 2 : 1,
            "report_interval_seconds"=>report_interval,"global_count_interval_seconds"=>global_count_interval,"cached_global_counts"=>cached_global_counts,
            "coordinator_transactions"=>"bounded steps, per-application savepoints, FULL synchronous commit",
            "max_apply_per_step"=>max_apply_per_step,"cached_control_statements"=>true,
            "indexed_ea_queue"=>indexed_ea_queue,"indexed_construction_queue"=>indexed_construction_queue,
            "reservation_sets"=>"bound integer JSON arrays; statement-local exclusions",
            "batches_controller_sha256"=>FP.DiscoveryEvidence.filehash(joinpath(@__DIR__,"closure_batches.jl")),
            "refill_controller_sha256"=>FP.DiscoveryEvidence.filehash(joinpath(@__DIR__,"closure_refill.jl")),
            "operations_controller_sha256"=>FP.DiscoveryEvidence.filehash(joinpath(@__DIR__,"closure_operations.jl")),
            "completion_controller_sha256"=>FP.DiscoveryEvidence.filehash(joinpath(@__DIR__,"closure_completion.jl")),
            "controller_bundle"=>relpath(controller_archive,directory),"controller_bundle_sha256"=>bundle_digest,
            "resources"=>resources,
            "active_environment"=>active_environment,
            "validation_seconds"=>validated-opened,"baseline_and_setup_seconds"=>active_started-validated,"descendant_expansion"=>true)
        FP._closure_exec(s,"INSERT INTO sessions(started,heartbeat,pid,host,state,budgets) VALUES(?,?,?,?,?,?)",(FP._closure_now(),FP._closure_now(),getpid(),get(ENV,"HOSTNAME","localhost"),"running",FP._closure_text(budgets)))
        s.session=Int(only(FP._closure_rows(s,"SELECT last_insert_rowid() id"))["id"])
        FP.DiscoveryStore.atomic_toml(joinpath(directory,"execution","session-$(s.session).toml"),
            Dict("config"=>config,"controller_bundle"=>relpath(controller_archive,directory),"resources"=>resources))
        if prior_stop!==nothing
            write(joinpath(out,"STOP-before.txt"),prior_stop)
            isfile(stop_path) && read(stop_path)==prior_stop && rm(stop_path)
        end
        publish!(;force=true)
        while true
            pool=run_refill_pool!(reserve_items,prepare_item,compute_item,finish_item;
                concurrency,max_pending,max_apply_per_step,reservation_refill_batch,key=item->Int(item.job["id"]),stop_requested=stopped,on_tick=report_tick,
                on_wait=maintenance!,
                on_state=x->merge!(runtime.scheduler,Dict(string(k)=>v for (k,v) in pairs(x))),
                measure_result_bytes=get(config,"measure_result_bytes",false),
                coordinator_step=f->closure_coordinator_step!(f,s.db;execute_control))
            emit!("scheduler-metrics.jsonl",Dict(string(k)=>v for (k,v) in pairs(pool)))
            maintenance!()
            record_completed!();publish!()
            stopped() && break
            if rolling_windows && windows_completed>=max_windows
                state="paused_window_limit";break
            end
            if pool.dispatched==0 && !window_active
                state="waiting_frontier";publish!()
                stopped() || sleep(min(.25,max(0.0,deadline-time())))
                continue
            end
            # Nothing runs and nothing is runnable: the current window is complete.
            jobs=construction();record_completed!()
            all(j->j["status"]=="done",jobs) || error("parent coverage requires recovery")
            if window_active
                windows_completed+=1;window_active=false
                console(Dict("event"=>"window_drained","first"=>first(parents),"last"=>last(parents)))
                publish!(;force=true,fresh_counts=true)
                base=TOML.parsefile(joinpath(directory,"progress.toml"))
                before_jobs=deepcopy(jobs);before_paths=Dict(kind=>paths(kind) for kind in ("v5","switching"));before_kernels=kernels()
                if windows_completed>=max_windows
                    state="paused_window_limit";break
                end
            end
            base=TOML.parsefile(joinpath(directory,"progress.toml"))
            if !select_window!()
                state="waiting_frontier";publish!(;force=true)
                sleep(min(.25,max(0.0,deadline-time())));continue
            end
            state=window_kind=="idle" ? "waiting_frontier" : "running"
            window_active=window_kind=="construction"
            if pool.dispatched==0 && !window_active
                publish!()
                stopped() || sleep(min(.25,max(0.0,deadline-time())))
            end
        end
        stopped() && (state=!isempty(checkpoint_error) ? "paused_checkpoint_error" : external() ? "paused_external" : storage.stopped[] ? "paused_storage" : "paused_budget")
    catch error
        primary_failure=(exception=error,backtrace=catch_backtrace())
        state="failed";rethrow()
    finally
        if s!==nothing
            cleanup_failure=nothing
            try
                if s.session>0
                    FP._closure_exec(s,"UPDATE jobs SET status='paused' WHERE last_session=? AND status='running'",(s.session,))
                    FP._closure_exec(s,"UPDATE sessions SET state=?,finished=?,heartbeat=?,jobs=?,evaluations=? WHERE id=?",(state,FP._closure_now(),FP._closure_now(),processed,evaluated,s.session))
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
                    if primary_failure===nothing && get(config,"checkpoint_on_stop",true)
                        prior_state=state
                        export_checkpoint!(;force=true)
                        if !isempty(checkpoint_error)
                            state="paused_checkpoint_error"
                        elseif storage.stopped[]
                            state="paused_storage"
                        end
                        if state!=prior_state
                            FP._closure_exec(s,"UPDATE sessions SET state=? WHERE id=?",(state,s.session))
                            try
                                publish!(;force=true,finished=true)
                            catch error
                                println(stderr,"Final export status is committed; progress refresh failed: ",sprint(showerror,error))
                            end
                        end
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
        "storage_stop_reason"=>storage.reason,"storage"=>storage.snapshot,
        "runtime_metrics"=>ClosureOperations.runtime_snapshot(runtime,resources),"checkpoint_exports"=>checkpoint_exports,
        "checkpoint_error"=>checkpoint_error,
        "telemetry_error"=>telemetry_error,
        "elapsed_seconds"=>time()-started,"active_seconds"=>active_started>0 ? time()-active_started : 0.0,
        "seed_statistics"=>seed_statistics(history,completion_events,active_started;now=time(),completed_this_session,parent_scope),"window_origin"=>window_origin)
    result["seed_statistics"]["published_completed_this_session"]=published_completed_this_session
    result["seed_statistics"]["published_selected"]=Int(s.identity["initial_roots"])
    result["runtime_metrics"]["property_cache"]=property_cache_statistics(contexts)
    result["runtime_metrics"]["completion"]=completion_metrics
    result["runtime_metrics"]["parent_target_cache"]=FP._closure_parent_target_cache_stats(target_cache)
    result["runtime_metrics"]["statement_cache"]=FP.DiscoveryStore.statement_cache_stats(s.statements)
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
