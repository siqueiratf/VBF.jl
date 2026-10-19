"""Read-only timing-log audit and explicit fixed-work scheduler simulations.

Historical packet metrics have no wave IDs or dispatch timestamps. Simulations
therefore replay the recorded ordered work as already available, preserving
durable apply order; they are not measurements of historical CPU utilization
or predictions including future recursive admission dependencies.
"""
module ClosureSchedulerReplay
using JSON3,SHA,Statistics,Dates

"""Replay ordered waves with apply of wavek overlapping computation of k+1."""
function waves(compute,apply,workers;poll=0.0)
    elapsed=0.0;previous_apply=0.0;count=0
    for first in 1:workers:length(compute)
        last=min(first+workers-1,length(compute))
        task_time=maximum(@view compute[first:last])
        wait=max(0.0,task_time-previous_apply)
        poll>0 && (wait=ceil(wait/poll)*poll)
        elapsed+=previous_apply+wait
        previous_apply=sum(@view apply[first:last]);count+=1
    end
    elapsed+previous_apply,count
end

"""FIFO compute refill inside fixed cohorts, then ordered durable application.

At most cohort_size completed results can be buffered. Parent admission order
is the recorded order; compute dispatch can vary without changing that order.
The next cohort waits for the entire preceding durable-apply prefix.
"""
function cohorts(compute,apply,workers,cohort_size)
    elapsed=0.0;count=0
    for first in 1:cohort_size:length(compute)
        last=min(first+cohort_size-1,length(compute))
        free=zeros(Float64,workers);writer=0.0
        for i in first:last
            slot=argmin(free)
            finish=free[slot]+compute[i];free[slot]=finish
            writer=max(writer,finish)+apply[i]
        end
        elapsed+=writer;count+=1
    end
    elapsed,count
end

"""Summarize every historical packet without opening the scientific SQLite."""
function run(metrics,output;workers=32)
    started=time();compute=Float64[];apply=Float64[]
    bykind=Dict{String,Tuple{Vector{Float64},Vector{Float64},Int}}()
    phases=Tuple{Int,Int,Bool}[];phase_first=1;last_ea=false;firstrow=true
    for line in eachline(metrics)
        r=JSON3.read(line);kind=String(r["kind"]);c=Float64(r["compute_wall_seconds"]);a=Float64(r["application_wall_seconds"])
        push!(compute,c);push!(apply,a);ea=kind=="deduplicate"
        if !firstrow && ea!=last_ea
            push!(phases,(phase_first,length(compute)-1,last_ea));phase_first=length(compute)
        end
        firstrow=false;last_ea=ea
        cs,as,cosets=get!(() -> (Float64[],Float64[],0),bykind,kind)
        push!(cs,c);push!(as,a);bykind[kind]=(cs,as,cosets+Int(get(r,"processed_cosets",0)))
    end
    push!(phases,(phase_first,length(compute),last_ea))
    summaries=Dict{String,Any}()
    for (kind,(cs,as,cosets)) in bykind
        summaries[kind]=Dict("packets"=>length(cs),"compute_task_wall_sum"=>sum(cs),
            "compute_median"=>median(cs),"compute_p95"=>quantile(cs,.95),"compute_maximum"=>maximum(cs),
            "apply_serial_sum"=>sum(as),"apply_median"=>median(as),"apply_p95"=>quantile(as,.95),"processed_cosets"=>cosets)
    end
    simulations=Dict{String,Any}()
    for (label,selector) in (("all",nothing),("EA_phases",true),("construction_phases",false))
        selected=selector===nothing ? phases : filter(p->p[3]==selector,phases)
        row=Dict{String,Any}("phases"=>length(selected),"packets"=>sum(p[2]-p[1]+1 for p in selected))
        for (name,method) in (("wave_no_poll",(c,a)->waves(c,a,workers)),
                ("wave_50ms_poll",(c,a)->waves(c,a,workers;poll=.05)),
                ("ordered_apply_refill_4x_cohort",(c,a)->cohorts(c,a,workers,4workers)),
                ("ordered_apply_refill_16x_cohort",(c,a)->cohorts(c,a,workers,16workers)))
            elapsed=0.0;cohort_count=0
            for (first,last,_) in selected
                seconds,count=method(@view(compute[first:last]),@view(apply[first:last]))
                elapsed+=seconds;cohort_count+=count
            end
            row[name]=Dict("simulated_seconds"=>elapsed,"cohorts"=>cohort_count)
        end
        simulations[label]=row
    end
    report=Dict("schema"=>"vbfsearch-fixed-work-scheduler-replay-v1","created_utc"=>string(now(UTC))*"Z",
        "input_sha256"=>bytes2hex(open(SHA.sha256,metrics)),"tool_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),
        "input_bytes"=>filesize(metrics),"packets"=>length(compute),"workers_assumed"=>workers,
        "physical_cores_on_current_host"=>16,"logical_CPUs_on_current_host"=>32,
        "per_kind"=>summaries,"simulations"=>simulations,"elapsed_seconds"=>time()-started,
        "scope"=>"Optimistic fixed recorded work replay, not measured campaign speedup. Recorded task walltimes include historical contention/GC; actual phase/wave boundaries and dispatch times were not logged. Phase boundaries inferred only from EA-vs-construction kind. Causal availability and window changes omitted. No SQL/source mutation; writer ordering retained.")
    write(output,JSON3.write(report));report
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==2 || error("usage: closure_scheduler_replay METRICS_JSONL OUTPUT_JSON")
    run(ARGS[1],ARGS[2])
end
end
