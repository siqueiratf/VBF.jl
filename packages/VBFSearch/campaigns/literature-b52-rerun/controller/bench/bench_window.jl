# Fixed-window benchmark of the pinned session-11 closure controller, threaded or
# with worker processes. One complete 64-parent window from the published roots
# 4401..4464, switching_directions=255, extension_cosets=65536.
#
#   julia --threads=N,1 --project=STATE/workspace/docs/inspector bench_window.jl BASE LABEL [WORKERS]
#
# BASE/initial is created once with closure_init and copied for each LABEL.
# WORKERS (optional) is a space-separated list of CPU lists, each optionally
# followed by :THREADS (default 8), e.g. "56-63 64-71:8 72-79,184-191:16".
# Env: WORKER_GC (GC threads per worker), WORKER_HEAP (heap size hint per worker),
# WORKER_DEPTH (coordinator slots per worker thread, default 2).
using VBFSearch, Printf
const FP=VBFSearch
const bundle=abspath(joinpath(@__DIR__,"..",".."))
include(joinpath(bundle,"controller","closure_continuous.jl"))
const base=abspath(ARGS[1]); const label=ARGS[2]
const workers=length(ARGS)>=3 ? split(ARGS[3]) : String[]
# ROOT_LAST (4464), WINDOWS (1) and ROLLING (false) give multi-window runs from
# the published roots 4401..ROOT_LAST; the default is the fixed 64-parent window.
const root_last=parse(Int,get(ENV,"ROOT_LAST","4464"))
const initial=joinpath(base,root_last==4464 ? "initial" : "initial-4401-$root_last")
isdir(initial) || FP.closure_init(joinpath(bundle,"inputs","campaign.toml");output=initial,
    root_first=4401,root_last=root_last,extension_cosets=65536,switching_directions=255)
function cpu_seconds()
    f=split(last(split(read("/proc/self/stat",String),") ";limit=2)))
    (parse(Int,f[12])+parse(Int,f[13]))/ccall(:sysconf,Clong,(Cint,),2)
end
# RESUME=1 continues BASE/LABEL/run (after a STOP or failure) with a new evidence folder.
resume=get(ENV,"RESUME","0")=="1"
folder=joinpath(base,label); run=joinpath(folder,"run")
if resume
    isdir(run) || error("nothing to resume in $run")
else
    rm(folder;recursive=true,force=true); mkpath(folder); cp(initial,run)
end
evidence=joinpath(folder,resume ? "evidence-resume-$(round(Int,time()))" : "evidence")
specs=Any[]
for w in workers
    cpus,threads=occursin(':',w) ? split(w,':') : (w,"8")
    spec=Dict{String,Any}("cpus"=>String(cpus),"threads"=>parse(Int,threads))
    haskey(ENV,"WORKER_GC") && (spec["gc_threads"]=parse(Int,ENV["WORKER_GC"]))
    haskey(ENV,"WORKER_HEAP") && (spec["heap_size_hint"]=ENV["WORKER_HEAP"])
    push!(specs,spec)
end
depth=parse(Int,get(ENV,"WORKER_DEPTH","2"))
n=isempty(specs) ? Threads.nthreads(:default) : depth*sum(s["threads"] for s in specs)
config=Dict{String,Any}("run"=>run,"evidence"=>evidence,
    "concurrency"=>n,"window_size"=>64,"max_windows"=>parse(Int,get(ENV,"WINDOWS","1")),
    "reservation_horizon"=>max(1024,4n),"reservation_refill_batch"=>16,"max_apply_per_step"=>32,
    "rolling_windows"=>get(ENV,"ROLLING","false")=="true","duration_seconds"=>1800.0,"report_interval_seconds"=>15.0,
    "cached_global_counts"=>true,"indexed_ea_queue"=>true,"baseline_policy"=>"summary",
    "checkpoint_on_stop"=>false,"shared_property_cache_entries"=>8192,"parent_scope"=>"all",
    "equivalence_seconds"=>1.0,"equivalence_nodes"=>100000,
    "precompute_rank_table"=>true,"packed_rank_table"=>true)
isempty(specs) || (config["worker_processes"]=specs;config["worker_queue_depth"]=depth)
GC.gc(true); g0=Base.gc_num(); c0=cpu_seconds(); t0=time()
result=try
    ContinuousSeedSearch.run(config)
catch error
    println("RUN_FAILED ",label," wall=",round(time()-t0;digits=2)," ",sprint(showerror,error)[1:min(end,2000)])
    exit(3)
end
wall=time()-t0; cpu=cpu_seconds()-c0; d=Base.GC_Diff(Base.gc_num(),g0)
remote=get(result["runtime_metrics"],"worker_processes",nothing)
stats=remote===nothing ? Any[] : remote["worker_statistics"]
any(isnothing,stats) && error("missing worker statistics")
wcpu=sum((st["cpu_seconds"] for st in stats);init=0.0)
wgc=sum((st["gc_seconds"] for st in stats);init=0.0)
walloc=sum((st["allocated_bytes"]/1e9 for st in stats);init=0.0)
ready=remote===nothing ? 0.0 : remote["ready_seconds"]
pools=[FP.JSON3.read(l) for l in readlines(joinpath(evidence,"scheduler-metrics.jsonl")) if !isempty(strip(l))]
sched=Dict(k=>sum(Float64(p[k]) for p in pools) for k in ("apply_seconds","prepare_seconds","reserve_seconds"))
sched["slot_occupancy"]=last(pools)["slot_occupancy"]
@printf("RESULT %s slots=%d workers=%d wall=%.2f active=%.2f ready=%.2f coord_cpu=%.1f worker_cpu=%.1f cores=%.1f coord_gc=%.2f worker_gc=%.2f alloc_GB=%.2f+%.2f apply=%.2f prepare=%.2f reserve=%.2f occupancy=%.3f state=%s\n",
    label,n,length(specs),wall,result["active_seconds"],ready,cpu,wcpu,(cpu+wcpu)/wall,d.total_time/1e9,wgc,d.allocd/1e9,walloc,
    sched["apply_seconds"],sched["prepare_seconds"],sched["reserve_seconds"],sched["slot_occupancy"],result["state"])
