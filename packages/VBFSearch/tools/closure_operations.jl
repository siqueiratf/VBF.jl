"""Bounded operational state for long-running, scheduler-independent campaigns.

These controls do not change construction coverage or equivalence decisions.
Storage checks run on the coordinator; workers only observe a latched stop bit.
"""
module ClosureOperations
using VBFSearch, TOML
const FP=VBFSearch

"""Validate compute slots and optional allocation against the actual Julia pools."""
function validate_resources(config;default_threads=Threads.nthreads(:default),
    interactive_threads=Threads.nthreads(:interactive),gc_threads=Threads.ngcthreads(),env=ENV,
    heap_size_hint=Int(Base.JLOptions().heap_size_hint))
    concurrency=Int(get(config,"concurrency",default_threads))
    concurrency>0 && concurrency<=default_threads || throw(ArgumentError("concurrency must be between 1 and Julia's $default_threads default threads"))
    explicit=Int(get(config,"cpu_allocation",0))
    scheduler=haskey(env,"SLURM_CPUS_PER_TASK") ? parse(Int,env["SLURM_CPUS_PER_TASK"]) : 0
    explicit>=0 && scheduler>=0 || throw(ArgumentError("CPU allocations must be nonnegative"))
    limits=filter(>(0),[explicit,scheduler]);allocation=isempty(limits) ? 0 : minimum(limits)
    runtime_threads=default_threads+interactive_threads+gc_threads
    allocation==0 || runtime_threads<=allocation || throw(ArgumentError("Julia compute, interactive and GC pools require $runtime_threads CPUs, exceeding allocation $allocation"))
    # V5Work owns 2^23 Int32 counts and Int16 transform entries per
    # slot at n=8. This is a lower bound, excluding DU7/EA/result allocations.
    rank_bytes=get(config,"precompute_rank_table",true) ? (get(config,"packed_rank_table",true) ? 1<<26 : 1<<28) : 0
    work_bytes=concurrency*(6*(1<<23)+256*sizeof(Int))+rank_bytes
    heap_size_hint>=0 || throw(ArgumentError("heap size hint must be nonnegative"))
    warnings=String[]
    heap_size_hint>0 && heap_size_hint<2work_bytes && push!(warnings,
        "Julia heap-size-hint $(heap_size_hint) bytes leaves limited headroom above V5 work buffers ($work_bytes bytes minimum); measure a larger hint within the job memory allocation to reduce GC")
    Dict{String,Any}("concurrency"=>concurrency,"default_threads"=>default_threads,
        "interactive_threads"=>interactive_threads,"gc_threads"=>gc_threads,
        "runtime_threads"=>runtime_threads,"cpu_allocation"=>allocation,
        "concurrency_source"=>haskey(config,"concurrency") ? "explicit" : "all default-pool threads",
        "work_buffer_lower_bound_bytes"=>work_bytes,"heap_size_hint_bytes"=>heap_size_hint,
        "memory_estimate_scope"=>"n=8 primary V5 arrays and shared rank lookup only; excludes runtime, EA, DU7 and buffered results",
        "warnings"=>warnings,
        "host"=>get(env,"HOSTNAME",Base.Libc.gethostname()),"pid"=>getpid(),
        "job_id"=>get(env,"SLURM_JOB_ID","none"))
end

const REPORT_COUNTER_FIELDS=("total_parents","promoted_parents","exact_luts","quadratic_apn_luts",
    "nonquadratic_apn_luts","unresolved_equivalence","verified_equivalent_luts")
const REPORT_COUNTER_SELECT="SELECT "*join(REPORT_COUNTER_FIELDS,",")*" FROM temp.closure_runtime_counts WHERE singleton=1"

"""Connection-local exact report counters under the store's exclusive writer lease.

Seed with the controller's first fresh count results. TEMP triggers update one
wide row in the same transaction/savepoint as scientific changes, including
rollbacks. Physical tables are used so normalized-view writes count once. No
counter or trigger enters a checkpoint, and each invocation recounts initially.
"""
struct ReportCounters
    store::FP.ClosureStore
end
function install_report_counters!(s::FP.ClosureStore,counts)
    isopen(s.lease) || error("report counters require the open exclusive writer store")
    FP.SQLite.intransaction(s.db) && error("install report counters at a committed boundary")
    values=Int[counts[k] for k in REPORT_COUNTER_FIELDS]
    all(>=(0),values) || throw(ArgumentError("report counters must be nonnegative"))
    physical=FP._closure_normalized(s.db) ? "closure_candidates" : "candidates"
    predicates(alias)=(
        "quadratic_apn_luts"=>"($alias.apn=1 AND $alias.degree=2)",
        "nonquadratic_apn_luts"=>"($alias.apn=1 AND $alias.degree>2)",
        "unresolved_equivalence"=>"($alias.apn=1 AND $alias.degree=2 AND $alias.class_id IS NULL)",
        "verified_equivalent_luts"=>"($alias.state='equivalent')")
    insert_values=join(["$key=$key+$value" for (key,value) in predicates("NEW")],",")
    delete_values=join(["$key=$key-$value" for (key,value) in predicates("OLD")],",")
    updates=join(["$key=$key+($new)-($old)" for ((key,new),(_,old)) in zip(predicates("NEW"),predicates("OLD"))],",")
    changed="OLD.apn IS NOT NEW.apn OR OLD.degree IS NOT NEW.degree OR (OLD.class_id IS NULL)!=(NEW.class_id IS NULL) OR (OLD.state='equivalent')!=(NEW.state='equivalent')"
    FP._closure_transaction(s) do
        columns=join(["$key INTEGER NOT NULL CHECK($key>=0)" for key in REPORT_COUNTER_FIELDS],",")
        FP._closure_exec(s,"CREATE TEMP TABLE closure_runtime_counts(singleton INTEGER PRIMARY KEY CHECK(singleton=1),$columns)")
        placeholders=join(fill("?",length(values)),",")
        FP._closure_exec(s,"INSERT INTO temp.closure_runtime_counts VALUES(1,$placeholders)",Tuple(values))
        for (name,operation,body) in (
                ("candidate_insert","AFTER INSERT ON main.$physical","exact_luts=exact_luts+1,$insert_values"),
                ("candidate_delete","AFTER DELETE ON main.$physical","exact_luts=exact_luts-1,$delete_values"),
                ("candidate_update","AFTER UPDATE OF apn,degree,class_id,state ON main.$physical WHEN $changed",updates),
                ("parent_insert","AFTER INSERT ON main.parents","total_parents=total_parents+1,promoted_parents=promoted_parents+(NEW.origin='discovered')"),
                ("parent_delete","AFTER DELETE ON main.parents","total_parents=total_parents-1,promoted_parents=promoted_parents-(OLD.origin='discovered')"),
                ("parent_update","AFTER UPDATE OF origin ON main.parents WHEN OLD.origin IS NOT NEW.origin","promoted_parents=promoted_parents+(NEW.origin='discovered')-(OLD.origin='discovered')"))
            FP._closure_exec(s,"CREATE TEMP TRIGGER closure_runtime_$name $operation BEGIN UPDATE closure_runtime_counts SET $body WHERE singleton=1; END")
        end
    end
    ReportCounters(s)
end
report_counter_snapshot(counters::ReportCounters)=only(FP._closure_rows(counters.store,REPORT_COUNTER_SELECT))

"""Cache a freshly observed terminal published-root summary within one invocation.

Controller admission adds discovered parents only; completed construction jobs
never reopen. Only a committed boundary can populate this cache; a rolled-back
packet must not make a partial root set appear permanently complete. Partial
root summaries and helpers with additional fields continue to query the archived
reporter. The expected root count comes from the validated scientific identity.
"""
mutable struct SeedSummaryCache
    terminal::Union{Nothing,Dict{String,Any}}
    expected_roots::Int
    hits::Int
    misses::Int
end
SeedSummaryCache()=SeedSummaryCache(nothing,-1,0,0)
function seed_summary!(cache::SeedSummaryCache,reader,db,expected_roots::Int)
    expected_roots>=0 || throw(ArgumentError("expected root count must be nonnegative"))
    if cache.expected_roots!=expected_roots
        cache.terminal=nothing;cache.expected_roots=expected_roots
    end
    if cache.terminal!==nothing
        cache.hits+=1;return deepcopy(cache.terminal)
    end
    cache.misses+=1;value=reader(db)
    connection=db isa FP.ClosureStore ? db.db : db isa FP.SQLite.DB ? db : nothing
    committed=connection!==nothing && !FP.SQLite.intransaction(connection)
    if committed && value isa AbstractDict && length(value)==5 && get(value,"focus_available",true)===false &&
            all(key->get(value,key,-1)==expected_roots,("total","completed","v5_completed","switching_completed"))
        cache.terminal=Dict{String,Any}(String(k)=>deepcopy(v) for (k,v) in pairs(value))
    end
    value
end

"""Archive and pin the actual active workspace environment before dispatch.

Relative package sources retain their layout inside `replay/workspace`. An
existing pin cannot be replaced by silently resolving a different environment.
"""
function bind_active_environment!(store)
    project=Base.active_project();project===nothing && error("a pinned active project is required")
    relative=FP._closure_portable_relative(relpath(project,FP.DiscoveryInputs.ROOT))
    target=joinpath(store.directory,"replay","workspace",relative)
    for (source,destination) in ((project,target),(joinpath(dirname(project),"Manifest.toml"),joinpath(dirname(target),"Manifest.toml")))
        isfile(source) || error("active environment must be instantiated before dispatch")
        if isfile(destination)
            FP.DiscoveryEvidence.filehash(source)==FP.DiscoveryEvidence.filehash(destination) || error("active environment differs from its frozen archive")
        else
            mkpath(dirname(destination));cp(source,destination)
        end
    end
    environment=FP._closure_portable_environment(store.directory,target)
    prior=FP._closure_execution_map(store.directory,store.identity)
    if prior===nothing || !haskey(prior,"active_environment")
        FP._closure_write_execution_map(store.directory,store.identity;active_environment=environment,
            origin="threaded controller launch; verified active environment and archived input bindings")
    else
        FP._closure_validate_active_runtime_environment(store.directory,store.identity)
    end
    environment
end

"""Find only atomically published controller-owned generations for this identity.

Retention survives controller restarts. Unrelated paths, staging directories,
symlinks and generations from other campaigns are never selected for deletion.
"""
function checkpoint_generations(root,identity_sha256;excluded_paths=String[])
    isdir(root) || return String[]
    selected=String[]
    for name in readdir(root)
        occursin(r"^checkpoint-[0-9]+-[0-9]+-[0-9]+$",name) || continue
        path=joinpath(root,name);islink(path) && continue
        any(e->abspath(e)==abspath(path) || startswith(abspath(e),abspath(path)*string(Base.Filesystem.path_separator)),excluded_paths) && continue
        manifest=joinpath(path,"checkpoint-manifest.toml")
        isfile(manifest) && !islink(manifest) || continue
        value=try TOML.parsefile(manifest) catch;continue;end
        get(value,"schema","")=="vbfsearch-checkpoint-bundle-v1" || continue
        get(value,"identity_sha256","")==identity_sha256 || continue
        identity=joinpath(path,"identity.toml")
        isfile(identity) && !islink(identity) && FP.DiscoveryEvidence.filehash(identity)==identity_sha256 || continue
        push!(selected,path)
    end
    sort!(selected;by=p->get(TOML.parsefile(joinpath(p,"checkpoint-manifest.toml")),"created_utc",""))
end

"""Count regular files once across overlapping roots and hard links; never follow symlinks."""
function storage_snapshot(paths)
    roots=String[]
    for p in sort!(unique(abspath.(String.(paths)));by=length)
        any(r->p==r || startswith(p,r*string(Base.Filesystem.path_separator)),roots) || push!(roots,p)
    end
    seen=Set{Tuple{UInt64,UInt64}}();bytes=Int128(0);files=0;available=typemax(Int64)
    for root in roots
        parent=root
        while !ispath(parent);next=dirname(parent);next==parent && error("no existing parent for $root");parent=next;end
        available=min(available,Int64(Base.Filesystem.diskstat(parent).available))
        names=isfile(root) ? [root] : isdir(root) ? (joinpath(d,f) for (d,_,fs) in walkdir(root;follow_symlinks=false) for f in fs) : String[]
        for path in names
            islink(path) && continue
            info=try stat(path) catch;ispath(path) && rethrow();continue;end
            isfile(info) || continue
            key=(UInt64(info.device),UInt64(info.inode));key in seen && continue
            push!(seen,key);bytes+=info.size;files+=1
        end
    end
    Dict{String,Any}("bytes"=>Int(bytes),"files"=>files,"available_bytes"=>available,"paths"=>roots)
end

"""Latched coordinator-side storage policy, including an optional quota-adapter JSON."""
mutable struct StorageGuard
    paths::Vector{String}
    maximum::Int
    minimum_free::Int
    reserve::Int
    interval::Float64
    quota_file::String
    quota_max_age::Float64
    checked::Float64
    reason::String
    snapshot::Dict{String,Any}
    stopped::Threads.Atomic{Bool}
end

"""Build explicit operational limits; zero maximum means no total-size ceiling."""
function StorageGuard(config,paths)
    maximum=Int(get(config,"storage_max_bytes",0));minimum=Int(get(config,"min_free_bytes",2*1024^3))
    reserve=Int(get(config,"storage_reserve_bytes",1024^3));interval=Float64(get(config,"storage_check_seconds",15.0))
    age=Float64(get(config,"quota_max_age_seconds",300.0))
    minimum>=0 && reserve>=0 && maximum>=0 && isfinite(interval) && interval>0 && isfinite(age) && age>0 || throw(ArgumentError("invalid storage policy"))
    StorageGuard(abspath.(String.(paths)),maximum,minimum,reserve,interval,
        String(get(config,"quota_status_file","")),age,-Inf,"",Dict{String,Any}(),Threads.Atomic{Bool}(false))
end

"""Latch STOP before a high-water boundary, leaving the configured drain reserve.

The reserve is an operator-chosen allowance, not a proof of maximum packet size.
Quota adapters write `{available_bytes, updated_epoch}` atomically; stale or
invalid readings stop work rather than silently disabling the quota check.
"""
function check_storage!(guard;force=false,now=time(),sample=storage_snapshot)
    guard.stopped[] && return true
    !force && now-guard.checked<guard.interval && return false
    guard.checked=now
    try
        value=sample(guard.paths);reason=""
        if guard.maximum>0 && Int128(value["bytes"])+guard.reserve>=guard.maximum
            reason="storage_max_bytes"
        elseif Int128(value["available_bytes"])<Int128(guard.minimum_free)+guard.reserve
            reason="min_free_bytes"
        end
        if !isempty(guard.quota_file)
            quota=FP.JSON3.read(read(guard.quota_file,String),Dict{String,Any})
            free=Int(quota["available_bytes"]);updated=Float64(quota["updated_epoch"])
            free>=0 && isfinite(updated) && -5<=now-updated<=guard.quota_max_age || error("stale or invalid quota adapter")
            value["quota_available_bytes"]=free
            free<guard.reserve+guard.minimum_free && (reason="quota_available_bytes")
        end
        value["checked_epoch"]=now;value["reserve_bytes"]=guard.reserve;value["maximum_bytes"]=guard.maximum
        value["minimum_free_bytes"]=guard.minimum_free;guard.snapshot=value;guard.reason=reason
    catch error
        guard.reason="storage_check_failed"
        guard.snapshot=Dict("checked_epoch"=>now,"error"=>sprint(showerror,error))
    end
    guard.stopped[]=!isempty(guard.reason)
    guard.stopped[]
end

"""Finite telemetry retention: one active JSONL plus a bounded set of zstd segments."""
struct TelemetryLog
    directory::String
    segment_bytes::Int
    keep::Int
end

"""Create a telemetry policy; derivation evidence is never deleted by this policy."""
function TelemetryLog(directory,config=Dict())
    size=Int(get(config,"telemetry_segment_bytes",16*1024^2));keep=Int(get(config,"telemetry_keep_segments",4))
    size>0 && keep>=0 || throw(ArgumentError("invalid telemetry retention"))
    TelemetryLog(abspath(directory),size,keep)
end

"""Append one complete bounded record, rotating through atomic compressed files."""
function telemetry!(log,name,value)
    occursin(r"^[a-z][a-z0-9-]*\.jsonl$",name) || throw(ArgumentError("invalid telemetry name"))
    line=String(FP.JSON3.write(value))*"\n";ncodeunits(line)<=log.segment_bytes || throw(ArgumentError("telemetry record exceeds segment budget"))
    path=joinpath(log.directory,name)
    if isfile(path) && filesize(path)+ncodeunits(line)>log.segment_bytes
        if log.keep>0
            temporary=tempname(log.directory)
            try
                write(temporary,transcode(FP.CodecZstd.ZstdCompressor,read(path)))
                # Verify before retiring the only uncompressed copy.
                transcode(FP.CodecZstd.ZstdDecompressor,read(temporary))==read(path) || error("telemetry compression verification failed")
                for i in log.keep:-1:2
                    old=path*".$(i-1).zst";isfile(old) && mv(old,path*".$i.zst";force=true)
                end
                mv(temporary,path*".1.zst";force=true)
            finally
                isfile(temporary) && rm(temporary)
            end
        end
        rm(path)
    end
    open(path,"a") do io;write(io,line);end
    nothing
end

"""Linux process CPU seconds using the runtime tick frequency, without PID guessing."""
function process_cpu_seconds()
    Sys.islinux() || return -1.0
    try
        text=read("/proc/self/stat",String);fields=split(text[findlast(')',text)+2:end])
        ticks=ccall(:sysconf,Clong,(Cint,),2)
        ticks>0 || return -1.0
        (parse(Float64,fields[12])+parse(Float64,fields[13]))/ticks
    catch
        -1.0
    end
end

"""Aggregate bounded lifetime metrics instead of retaining all packet samples."""
mutable struct RuntimeMetrics
    started::Float64
    cpu_started::Float64
    gc_started_ns::Int
    kinds::Dict{String,Dict{String,Float64}}
    scheduler::Dict{String,Any}
    reporting_seconds::Float64
    checkpoint_seconds::Float64
end
RuntimeMetrics()=RuntimeMetrics(time(),process_cpu_seconds(),Int(Base.gc_num().total_time),Dict(),Dict(),0.0,0.0)

"""Record an applied packet attempt's compute, apply and ordered-result wait."""
function record_packet!(metrics,kind,compute,apply,ready_wait)
    totals=get!(metrics.kinds,String(kind),Dict("packets"=>0.0,"compute_wall_seconds"=>0.0,"apply_wall_seconds"=>0.0,"ready_wait_seconds"=>0.0))
    totals["packets"]+=1;totals["compute_wall_seconds"]+=compute
    totals["apply_wall_seconds"]+=apply;totals["ready_wait_seconds"]+=ready_wait
end

"""Snapshot process-owned metrics, labeling CPU time separately from overlapping slot time."""
function runtime_snapshot(metrics,resources)
    elapsed=max(0.0,time()-metrics.started);cpu=process_cpu_seconds()
    cpu_known=cpu>=0 && metrics.cpu_started>=0
    used=cpu_known ? max(0.0,cpu-metrics.cpu_started) : 0.0
    Dict{String,Any}("resources"=>resources,"wall_seconds"=>elapsed,"process_cpu_available"=>cpu_known,
        "process_cpu_seconds"=>used,"average_cpu_cores"=>elapsed>0 ? used/elapsed : 0.0,
        "gc_pause_seconds"=>max(0.0,(Int(Base.gc_num().total_time)-metrics.gc_started_ns)*1e-9),
        "packet_totals"=>deepcopy(metrics.kinds),"scheduler"=>copy(metrics.scheduler),
        "scheduler_scope"=>"current or latest refill pool; packet totals cover this process run",
        "scheduler_active_scope"=>"dispatched tasks whose events have not been collected, including finished tasks; slot occupancy is not CPU utilization",
        "scheduler_compute_scope"=>"workers_computing counts entered compute calls, including blocked calls and GC; use average_cpu_cores for process CPU use",
        "coordinator_timing_scope"=>"step includes reserve, prepare, apply, scheduling and transaction control; transaction_control is nested; tick includes completion checking, publication and maintenance; wait_maintenance is excluded from event_wait",
        "reporting_scope"=>"publication only; completion checks are reported separately by the controller",
        "reporting_seconds"=>metrics.reporting_seconds,"checkpoint_seconds"=>metrics.checkpoint_seconds,
        "scope"=>"this controller process; compute durations overlap across slots; CPU includes GC and coordinator")
end
end
