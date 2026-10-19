"""Counterbalanced current-native / frozen-clone / stable-iterator experiment."""
module V5StableIteratorBenchmark
using VBF,JSON3,SHA,Statistics,Dates
include(joinpath(@__DIR__,"v5_stable_iterator.jl"))
const S=V5StableIterator
const Q=VBF.QuadraticExtensions
sha(path)=bytes2hex(open(SHA.sha256,path))
function run(input,output;job_limit=4,repetitions=3)
    source=JSON3.read(read(input,String),Dict{String,Any})
    jobs=source["records"][1:min(job_limit,length(source["records"]))]
    G=Q.geometry(8);t=time();table=Q.PolarRankTable(G);build=time()-t
    work=Q.V5Work(23)
    methods=Dict(:native=>Q.v5_extensions,:clone=>S.baseline_v5_extensions,:stable=>S.stable_v5_extensions)
    records=Dict{String,Any}[];started=time()
    for job in jobs
        V=UInt32.(job["forms"]);need=Int(job["need"])
        expected=nothing
        for method in values(methods)
            result=method(G,V,need,work;beta=Q.BETA8,du7_filter=:bitsets,rank_table=table,max_kernel=23)
            expected===nothing ? (expected=result) : result==expected || error("warm result mismatch")
        end
        trials=Dict(k=>Any[] for k in keys(methods))
        for repetition in 1:repetitions
            order=circshift([:native,:clone,:stable],repetition-1)
            for name in order
                method=methods[name]
                sample=@timed method(G,V,need,work;beta=Q.BETA8,du7_filter=:bitsets,rank_table=table,max_kernel=23)
                sample.value==expected || error("timed result mismatch")
                push!(trials[name],Dict("seconds"=>sample.time,"bytes"=>sample.bytes,"gc_seconds"=>sample.gctime))
            end
        end
        medians=Dict(string(k)=>median(t["seconds"] for t in v) for (k,v) in trials)
        push!(records,Dict("parent_id"=>job["parent_id"],"forms"=>job["forms"],"need"=>need,
            "nX"=>expected.nX,"outputs"=>length(expected.Ss),"candidates"=>expected.ncand,
            "all_results_exactly_equal"=>true,"trials"=>trials,"median_seconds"=>medians,
            "speedup_vs_native"=>medians["native"]/medians["stable"],
            "speedup_vs_clone"=>medians["clone"]/medians["stable"]))
        println(JSON3.write(last(records)));flush(stdout)
    end
    report=Dict("schema"=>"vbfsearch-stable-iterator-benchmark-v1","created_utc"=>string(now(UTC)),
        "input"=>abspath(input),"input_sha256"=>sha(input),"baseline_source"=>S.source_file,
        "baseline_source_sha256"=>S.source_sha256,"variant_sha256"=>S.variant_sha256,
        "prototype_sha256"=>sha(joinpath(@__DIR__,"v5_stable_iterator.jl")),
        "tool_sha256"=>sha(@__FILE__),"rank_table_build_seconds"=>build,
        "elapsed_seconds"=>time()-started,"repetitions"=>repetitions,"threads"=>Threads.nthreads(),
        "records"=>records,"paired_total_speedup"=>sum(r["median_seconds"]["native"] for r in records)/sum(r["median_seconds"]["stable"] for r in records),
        "scope"=>"Four existing holdout jobs; descriptive implementation experiment, no campaign writes.")
    open(io->JSON3.pretty(io,report),output,"w")
    report
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==2 || error("expected HOLDOUT OUTPUT")
    run(ARGS...)
end
end
