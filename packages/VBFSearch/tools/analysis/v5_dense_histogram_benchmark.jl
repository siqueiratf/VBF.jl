"""Bounded differential and timing control for the isolated dense V5 histograms."""
module V5DenseHistogramBenchmark
using VBF,JSON3,SHA,Dates,Statistics
include(joinpath(@__DIR__,"v5_dense_histogram.jl"))
include(joinpath(@__DIR__,"v5_frontier_symmetry_audit.jl"))
const Q=VBF.QuadraticExtensions
const D=V5DenseHistogram
const FSA=V5FrontierSymmetryAudit
file_sha(path)=bytes2hex(open(SHA.sha256,path))

function timed_variant(fn,G,V,need,work;max_x)
    result=@timed fn(G,V,need,work;beta=Q.BETA8,max_x)
    return result.value,Dict("seconds"=>result.time,"bytes"=>result.bytes,"gc_seconds"=>result.gctime)
end

function audit(input,output;repetitions=3,max_seconds=280.0,variant_module=D,
        prototype_file=joinpath(@__DIR__,"v5_dense_histogram.jl"),
        reference_function=D.original_v5_extensions)
    started=time();source_sha=file_sha(input)
    source=JSON3.read(read(input,String),Dict{String,Any})
    parent_path=source["input"]
    source["input_sha256"]==file_sha(parent_path) || error("parent source changed")
    parents=JSON3.read(read(parent_path,String),Dict{String,Any})["parents"]
    by_parent=Dict(p["parent_id"]=>p for p in parents)
    G=Q.geometry(8);work=Q.V5Work(23,8)
    records=Dict{String,Any}[]
    for job in source["jobs"]
        time()-started<max_seconds || break
        parent=by_parent[job["parent_id"]];FSA.validate_prepared_parent(G,parent)
        job["forms"] in parent["maximizing_v5_forms"] || error("benchmark space has wrong parent")
        V=UInt32.(job["forms"]);need=Int(job["need"])
        baseline_events=Any[];dense_events=Any[]
        baseline=reference_function(G,V,need,work;beta=Q.BETA8,
            coset_observer=e->push!(baseline_events,e))
        dense=variant_module.dense_v5_extensions(G,V,need,work;beta=Q.BETA8,
            coset_observer=e->push!(dense_events,e))
        baseline==dense || error("full result mismatch")
        baseline_events==dense_events || error("full event mismatch")
        baseline.nX_used==baseline.nX && !baseline.capped || error("incomplete control")
        suites=Dict{String,Any}()
        for (label,cap) in (("setup_only",0),("full",typemax(Int)))
            # Warm each keyword specialization before timing.
            a=reference_function(G,V,need,work;beta=Q.BETA8,max_x=cap)
            b=variant_module.dense_v5_extensions(G,V,need,work;beta=Q.BETA8,max_x=cap)
            a==b || error("warm result mismatch")
            old=Dict{String,Any}[];new=Dict{String,Any}[]
            for iteration in 1:repetitions
                time()-started<max_seconds || break
                sequence=isodd(iteration) ? (:original,:dense) : (:dense,:original)
                values=Dict{Symbol,Any}()
                for which in sequence
                    fn=which==:original ? reference_function : variant_module.dense_v5_extensions
                    result,measurement=timed_variant(fn,G,V,need,work;max_x=cap)
                    push!(which==:original ? old : new,measurement);values[which]=result
                end
                values[:original]==values[:dense] || error("timed result mismatch")
            end
            isempty(old) && break
            old_median=median(x["seconds"] for x in old)
            new_median=median(x["seconds"] for x in new)
            suites[label]=Dict("original"=>old,"dense"=>new,
                "original_median_seconds"=>old_median,"dense_median_seconds"=>new_median,
                "speedup"=>old_median/new_median,"fraction_saved"=>1-new_median/old_median)
        end
        push!(records,Dict("parent_id"=>job["parent_id"],"queue_state"=>job["queue_state"],
            "forms"=>Int.(V),"b5"=>job["b5"],"need"=>need,"nX"=>baseline.nX,
            "full_completion_count"=>length(baseline.Ss),"full_candidate_count"=>baseline.ncand,
            "exact_keys_results_and_all_coset_events_match"=>true,"suites"=>suites))
        println(JSON3.write(Dict("event"=>"dense_histogram_job","parent_id"=>job["parent_id"],
            "elapsed_seconds"=>time()-started,"suites"=>Dict(k=>Dict("speedup"=>v["speedup"],
            "original_median_seconds"=>v["original_median_seconds"],"dense_median_seconds"=>v["dense_median_seconds"])
            for (k,v) in suites))));flush(stdout)
    end
    source_sha==file_sha(input) || error("benchmark roster changed")
    source["input_sha256"]==file_sha(parent_path) || error("parent source changed")
    variant_module.source_sha256==file_sha(variant_module.source_file) || error("VBF source changed during benchmark")
    result=Dict("schema"=>"vbfsearch-dense-histogram-benchmark-v1","created_utc"=>string(now(UTC)),
        "input"=>abspath(input),"input_sha256"=>source_sha,
        "parent_source"=>parent_path,"parent_source_sha256"=>source["input_sha256"],
        "installed_vbf_source_sha256"=>variant_module.source_sha256,"variant_sha256"=>variant_module.variant_sha256,
        "reference_function"=>string(reference_function),"reference_fragment_sha256"=>D.original_variant_sha256,
        "prototype"=>abspath(prototype_file),"prototype_sha256"=>file_sha(prototype_file),
        "tool_sha256"=>file_sha(@__FILE__),"repetitions"=>repetitions,"max_seconds"=>max_seconds,
        "elapsed_seconds"=>time()-started,"julia_version"=>string(VERSION),"threads"=>Threads.nthreads(),
        "all_inputs_unchanged"=>true,"complete"=>length(records)==length(source["jobs"]),"jobs"=>records,
        "scope"=>"Four descriptive real-data controls; no population speedup estimate, no campaign write. Full results include all output spaces and all original observer events.")
    mkpath(dirname(output));open(io->JSON3.pretty(io,result),output,"w")
    result
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS) in (2,3) || error("expected KERNEL_BENCHMARK OUTPUT [REPETITIONS]")
    audit(ARGS[1],ARGS[2];repetitions=length(ARGS)==3 ? parse(Int,ARGS[3]) : 3)
end
end
