"""Focused frozen-function-clone control after the four-job native comparisons."""
module V5DenseHistogramCloneControl
using VBF,JSON3,SHA,Statistics,Dates
include(joinpath(@__DIR__,"v5_dense_histogram_helper.jl"))
const H=V5DenseHistogramHelper
const D=H.V5DenseHistogram
const Q=VBF.QuadraticExtensions
function audit(input,output)
    job=only(j for j in JSON3.read(read(input,String),Dict{String,Any})["jobs"] if j["parent_id"]==170)
    G=Q.geometry(8);V=UInt32.(job["forms"]);need=Int(job["need"]);work=Q.V5Work(23,8)
    methods=Dict(:original_clone=>D.original_v5_extensions,:dense_helper=>H.dense_v5_extensions)
    expected=nothing
    for method in values(methods)
        result=method(G,V,need,work;beta=Q.BETA8)
        expected===nothing ? (expected=result) : result==expected || error("warm parity failed")
    end
    records=Dict(k=>Any[] for k in keys(methods))
    for iteration in 1:3
        order=isodd(iteration) ? (:original_clone,:dense_helper) : (:dense_helper,:original_clone)
        for name in order
            method=methods[name]
            trial=@timed method(G,V,need,work;beta=Q.BETA8)
            trial.value==expected || error("timed parity failed")
            push!(records[name],Dict("seconds"=>trial.time,"bytes"=>trial.bytes,"gc_seconds"=>trial.gctime))
        end
    end
    original=median(r["seconds"] for r in records[:original_clone])
    dense=median(r["seconds"] for r in records[:dense_helper])
    report=Dict("schema"=>"vbfsearch-dense-histogram-clone-control-v1",
        "created_utc"=>string(now(UTC)),"source_file"=>D.source_file,"source_sha256"=>D.source_sha256,
        "original_fragment_sha256"=>D.original_variant_sha256,"dense_fragment_sha256"=>H.variant_sha256,
        "input"=>abspath(input),"input_sha256"=>bytes2hex(open(SHA.sha256,input)),
        "tool_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),"parent_id"=>170,
        "exact_all_results_match"=>true,"nX"=>expected.nX,"outputs"=>length(expected.Ss),
        "trials"=>records,"original_clone_median_seconds"=>original,"dense_helper_median_seconds"=>dense,
        "speedup"=>original/dense,"threads"=>Threads.nthreads(),
        "scope"=>"One descriptive b5=30 control with a frozen extracted original function. No campaign writes.")
    open(io->JSON3.pretty(io,report),output,"w")
    println(JSON3.write(report))
    report
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==2 || error("expected INPUT OUTPUT")
    audit(ARGS...)
end
end
