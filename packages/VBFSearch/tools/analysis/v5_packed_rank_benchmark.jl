"""Counterbalanced full/native-clone/packed Fourier lookup benchmark."""
module V5PackedRankBenchmark
using VBF,JSON3,SHA,Statistics,Dates
include(joinpath(@__DIR__,"v5_packed_rank.jl"))
const P=V5PackedRank
const Q=VBF.QuadraticExtensions
sha(path)=bytes2hex(open(SHA.sha256,path))
function run(input,output;job_limit=4,repetitions=3)
    jobs=JSON3.read(read(input,String),Dict{String,Any})["records"][1:job_limit]
    G=Q.geometry(8);t=time();full=Q.PolarRankTable(G);build=time()-t
    t=time();packed=P.PackedPolarRanks(full);compress=time()-t;work=Q.V5Work(23)
    methods=Dict(:native=>Q.v5_extensions,:clone=>P.clone_v5_extensions,:packed=>P.packed_v5_extensions)
    records=Dict{String,Any}[];started=time();fresh_apn_outputs=0
    for job in jobs
        V=UInt32.(job["forms"]);need=Int(job["need"]);suites=Dict{String,Any}()
        for (scope,cap) in (("setup_only",0),("full",typemax(Int)))
            expected=nothing
            for name in (:native,:clone,:packed)
                method=methods[name];table=name==:packed ? packed : full
                result=method(G,V,need,work;beta=Q.BETA8,du7_filter=:bitsets,rank_table=table,max_kernel=23,max_x=cap)
                expected===nothing ? (expected=result) : result==expected || error("warm parity failed")
            end
            if scope=="full"
                !expected.capped && expected.next_x==expected.nX+1 || error("incomplete control")
                for S in expected.Ss
                    differential_uniformity(last(Q.function_of(G,S)))==2 || error("invalid packed output")
                    fresh_apn_outputs+=1
                end
            end
            trials=Dict(k=>Any[] for k in keys(methods))
            for repetition in 1:repetitions,name in circshift([:native,:clone,:packed],repetition-1)
                method=methods[name];table=name==:packed ? packed : full
                sample=@timed method(G,V,need,work;beta=Q.BETA8,du7_filter=:bitsets,rank_table=table,max_kernel=23,max_x=cap)
                sample.value==expected || error("timed parity failed")
                push!(trials[name],Dict("seconds"=>sample.time,"bytes"=>sample.bytes,"gc_seconds"=>sample.gctime))
            end
            medians=Dict(string(k)=>median(x["seconds"] for x in v) for (k,v) in trials)
            suites[scope]=Dict("trials"=>trials,"median_seconds"=>medians,
                "speedup_vs_native"=>medians["native"]/medians["packed"],
                "speedup_vs_clone"=>medians["clone"]/medians["packed"],
                "nX"=>expected.nX,"outputs"=>length(expected.Ss),"candidates"=>expected.ncand)
        end
        push!(records,Dict("parent_id"=>job["parent_id"],"forms"=>job["forms"],"need"=>need,
            "all_results_exactly_equal"=>true,"suites"=>suites))
        println(JSON3.write(last(records)));flush(stdout)
    end
    report=Dict("schema"=>"vbfsearch-packed-rank-benchmark-v1","created_utc"=>string(now(UTC)),
        "input"=>abspath(input),"input_sha256"=>sha(input),"baseline_source"=>P.source_file,
        "baseline_source_sha256"=>P.source_sha256,"variant_sha256"=>P.variant_sha256,
        "prototype_sha256"=>sha(joinpath(@__DIR__,"v5_packed_rank.jl")),"tool_sha256"=>sha(@__FILE__),
        "full_rank_bytes"=>length(full.ranks),"packed_rank_bytes"=>length(packed.codes),
        "full_rank_build_seconds"=>build,"packing_seconds"=>compress,
        "elapsed_seconds"=>time()-started,"repetitions"=>repetitions,"threads"=>Threads.nthreads(),
        "fresh_apn_outputs_checked"=>fresh_apn_outputs,"records"=>records,
        "paired_total_speedup_vs_native"=>sum(r["suites"]["full"]["median_seconds"]["native"] for r in records)/sum(r["suites"]["full"]["median_seconds"]["packed"] for r in records),
        "paired_total_speedup_vs_clone"=>sum(r["suites"]["full"]["median_seconds"]["clone"] for r in records)/sum(r["suites"]["full"]["median_seconds"]["packed"] for r in records),
        "scope"=>"Four descriptive holdout controls; all result fields equal and APN outputs freshly checked. No campaign writes.")
    open(io->JSON3.pretty(io,report),output,"w");report
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==2 || error("expected HOLDOUT OUTPUT")
    run(ARGS...)
end
end
