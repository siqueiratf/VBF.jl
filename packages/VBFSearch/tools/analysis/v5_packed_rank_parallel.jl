"""Bounded parallel cache/bandwidth control for exact packed polar ranks.

Scratch buffers and shared tables are initialized before timing. Campaign SQL,
admission, ledger encoding and network transport are outside this experiment.
"""
module V5PackedRankParallel
using VBF,JSON3,SHA,Statistics,Dates
include(joinpath(@__DIR__,"v5_packed_rank.jl"))
const P=V5PackedRank
const Q=VBF.QuadraticExtensions
sha(path)=bytes2hex(open(SHA.sha256,path))
function cpu_seconds(ticks)
    fields=split(last(split(read("/proc/self/stat",String),')';limit=2)))
    (parse(Float64,fields[12])+parse(Float64,fields[13]))/ticks
end
function peak_rss_kib()
    line=only(filter(s->startswith(s,"VmHWM:"),readlines("/proc/self/status")))
    parse(Int,split(line)[2])
end
function result_digest(result)
    normalized=(;Ss=sort!(collect(result.Ss);by=Tuple),nX=result.nX,nX_used=result.nX_used,
        next_x=result.next_x,du_reject=result.du_reject,ncand=result.ncand,nT=result.nT,
        key=result.key,capped=result.capped,skipped=result.skipped)
    bytes2hex(sha256(JSON3.write(normalized)))
end
function worker(indices,records,G,table,method,work)
    out=Any[]
    for i in indices
        job=records[i];V=UInt32.(job["forms"]);need=Int(job["need"])
        result=method(G,V,need,work;beta=Q.BETA8,du7_filter=:bitsets,rank_table=table,max_kernel=23)
        !result.capped && result.next_x==result.nX+1 || error("parallel control did not exhaust")
        push!(out,(i,result_digest(result),collect(result.Ss)))
    end
    out
end
function run(input,output;workers=32,repetitions=2)
    source=JSON3.read(read(input,String),Dict{String,Any})
    jobs=source["records"];records=vcat(jobs,jobs)
    workers=min(workers,Threads.nthreads(),length(records));G=Q.geometry(8)
    t=time();full=Q.PolarRankTable(G);build=time()-t
    t=time();packed=P.PackedPolarRanks(full);compression=time()-t
    t=time();works=[Q.V5Work(23) for _ in 1:workers];work_setup=time()-t
    methods=Dict(:native=>Q.v5_extensions,:clone=>P.clone_v5_extensions,:packed=>P.packed_v5_extensions)
    tables=Dict(:native=>full,:clone=>full,:packed=>packed)
    first_job=first(records);V=UInt32.(first_job["forms"]);need=Int(first_job["need"])
    for name in (:native,:clone,:packed)
        method=methods[name];table=tables[name]
        method(G,V,need,works[1];beta=Q.BETA8,du7_filter=:bitsets,rank_table=table,max_kernel=23)
        worker(1:workers:0,records,G,table,method,works[1])
    end
    ticks=parse(Float64,read(`getconf CLK_TCK`,String));trials=Dict(k=>Any[] for k in keys(methods))
    expected=nothing;fresh_checked=Set{String}();fresh_apn_outputs=0
    for repetition in 1:repetitions,name in (isodd(repetition) ? (:native,:clone,:packed) : (:packed,:clone,:native))
        method=methods[name];table=tables[name];GC.gc()
        cpu=cpu_seconds(ticks);started=time()
        tasks=[Threads.@spawn worker(i:workers:length(records),records,G,table,method,works[i]) for i in 1:workers]
        results=sort!(reduce(vcat,fetch.(tasks));by=first)
        seconds=time()-started;used_cpu=cpu_seconds(ticks)-cpu
        digests=[(r[1],r[2]) for r in results]
        expected===nothing ? (expected=digests) : digests==expected || error("parallel result mismatch")
        # Independent APN checks happen after the timed section.
        for (_,digest,outputs) in results
            digest in fresh_checked && continue
            for S in outputs
                differential_uniformity(last(Q.function_of(G,S)))==2 || error("non-APN output")
                fresh_apn_outputs+=1
            end
            push!(fresh_checked,digest)
        end
        push!(trials[name],Dict("repetition"=>repetition,"wall_seconds"=>seconds,
            "process_cpu_seconds"=>used_cpu,"average_active_logical_cpus"=>used_cpu/seconds,
            "jobs_per_second"=>length(records)/seconds,"peak_rss_kib"=>peak_rss_kib()))
        println(JSON3.write(Dict("phase"=>string(name),"repetition"=>repetition,"trial"=>last(trials[name]))));flush(stdout)
    end
    median_wall=Dict(string(k)=>median(r["wall_seconds"] for r in v) for (k,v) in trials)
    report=Dict("schema"=>"vbfsearch-packed-rank-parallel-v1","created_utc"=>string(now(UTC)),
        "input"=>abspath(input),"input_sha256"=>sha(input),"baseline_source"=>P.source_file,
        "baseline_source_sha256"=>P.source_sha256,"variant_sha256"=>P.variant_sha256,
        "tool_sha256"=>sha(@__FILE__),"workers"=>workers,"julia_threads"=>Threads.nthreads(),
        "jobs"=>length(records),"distinct_parent_inputs"=>length(jobs),"repetitions"=>repetitions,
        "full_rank_bytes"=>length(full.ranks),"packed_rank_bytes"=>length(packed.codes),
        "full_rank_build_seconds"=>build,"packing_seconds"=>compression,
        "scratch_setup_seconds"=>work_setup,"trials"=>trials,"median_wall_seconds"=>median_wall,
        "packed_speedup_vs_native"=>median_wall["native"]/median_wall["packed"],
        "packed_speedup_vs_clone"=>median_wall["clone"]/median_wall["packed"],
        "all_output_counter_and_cursor_digests_match"=>true,"output_digests"=>expected,
        "fresh_apn_outputs_checked"=>fresh_apn_outputs,"peak_rss_kib"=>peak_rss_kib(),
        "scope"=>"Bounded in-memory kernel batch. Shared tables and private scratch initialized before timing; fresh APN checks after timing. Excludes campaign SQL, admission, ledger and transport.")
    open(io->JSON3.pretty(io,report),output,"w");report
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS) in (2,3) || error("expected HOLDOUT OUTPUT [WORKERS]")
    run(ARGS[1],ARGS[2];workers=length(ARGS)==3 ? parse(Int,ARGS[3]) : 32)
end
end
