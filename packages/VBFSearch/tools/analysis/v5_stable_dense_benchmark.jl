"""Paired dense-setup experiment after concrete-iterator repair."""
module V5StableDenseBenchmark
using VBF,JSON3,SHA,Statistics,Dates
include(joinpath(@__DIR__,"v5_stable_dense.jl"))
const D=V5StableDense
const Q=VBF.QuadraticExtensions
sha(path)=bytes2hex(open(SHA.sha256,path))
function run(input,output;job_limit=4,repetitions=3)
    jobs=JSON3.read(read(input,String),Dict{String,Any})["records"][1:job_limit]
    G=Q.geometry(8);t=time();table=Q.PolarRankTable(G);build=time()-t;work=Q.V5Work(23)
    functions=Dict(:native=>Q.v5_extensions,:stable_clone=>D.S.stable_v5_extensions,:dense=>D.stable_dense_v5_extensions)
    records=Dict{String,Any}[];started=time()
    for job in jobs
        V=UInt32.(job["forms"]);need=Int(job["need"]);suites=Dict{String,Any}()
        for (scope,cap) in (("setup_only",0),("full",typemax(Int)))
            expected=nothing
            for method in values(functions)
                result=method(G,V,need,work;beta=Q.BETA8,du7_filter=:bitsets,rank_table=table,max_kernel=23,max_x=cap)
                expected===nothing ? (expected=result) : result==expected || error("warm parity failed")
            end
            trials=Dict(k=>Any[] for k in keys(functions))
            for repetition in 1:repetitions,name in circshift([:native,:stable_clone,:dense],repetition-1)
                method=functions[name]
                sample=@timed method(G,V,need,work;beta=Q.BETA8,du7_filter=:bitsets,rank_table=table,max_kernel=23,max_x=cap)
                sample.value==expected || error("timed parity failed")
                push!(trials[name],Dict("seconds"=>sample.time,"bytes"=>sample.bytes,"gc_seconds"=>sample.gctime))
            end
            medians=Dict(string(k)=>median(t["seconds"] for t in v) for (k,v) in trials)
            suites[scope]=Dict("trials"=>trials,"median_seconds"=>medians,
                "speedup_vs_native"=>medians["native"]/medians["dense"],
                "speedup_vs_same_module_clone"=>medians["stable_clone"]/medians["dense"],
                "nX"=>expected.nX,"outputs"=>length(expected.Ss),"candidates"=>expected.ncand)
        end
        push!(records,Dict("parent_id"=>job["parent_id"],"forms"=>job["forms"],"need"=>need,
            "all_results_exactly_equal"=>true,"suites"=>suites))
        println(JSON3.write(last(records)));flush(stdout)
    end
    report=Dict("schema"=>"vbfsearch-stable-dense-composition-v1","created_utc"=>string(now(UTC)),
        "input"=>abspath(input),"input_sha256"=>sha(input),"baseline_source"=>D.S.source_file,
        "baseline_source_sha256"=>D.S.source_sha256,"variant_sha256"=>D.variant_sha256,
        "prototype_sha256"=>sha(joinpath(@__DIR__,"v5_stable_dense.jl")),"tool_sha256"=>sha(@__FILE__),
        "rank_table_build_seconds"=>build,"elapsed_seconds"=>time()-started,"repetitions"=>repetitions,
        "records"=>records,"paired_total_speedup_vs_native"=>sum(r["suites"]["full"]["median_seconds"]["native"] for r in records)/sum(r["suites"]["full"]["median_seconds"]["dense"] for r in records),
        "paired_total_speedup_vs_same_module_clone"=>sum(r["suites"]["full"]["median_seconds"]["stable_clone"] for r in records)/sum(r["suites"]["full"]["median_seconds"]["dense"] for r in records),
        "scope"=>"Four descriptive existing holdout controls; full exact-result parity and no campaign writes.")
    open(io->JSON3.pretty(io,report),output,"w");report
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==2 || error("expected HOLDOUT OUTPUT")
    run(ARGS...)
end
end
