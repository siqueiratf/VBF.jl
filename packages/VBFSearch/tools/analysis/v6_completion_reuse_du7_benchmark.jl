"""Bounded full-job differential benchmark for the odd-three-circuit filter."""
module V6CompletionReuseDU7Benchmark
using VBF, JSON3, SHA, Dates
include("v6_completion_reuse_du7_masks.jl")
using .V6CompletionReuseDU7Masks
const Q=VBF.QuadraticExtensions

"""Compare exact outputs and logical counts, then measure warm job repeats."""
function run(input_file,output_file;repeats=3,max_seconds=180.0)
    started=time();source_sha=bytes2hex(open(SHA.sha256,input_file))
    input=JSON3.read(read(input_file,String));G=Q.geometry(8)
    reports=Any[]
    for job in input["jobs"]
        time()-started<max_seconds || break
        V=UInt32.(job["forms"]);need=Int(job["need"])
        work=Q.V5Work(23,8)
        base=V6CompletionReuseDU7Masks.T.reference_v5_extensions(G,V,need,work;beta=Q.BETA8,max_kernel=23)
        stats=V6CompletionReuseDU7Masks.TriangleStats()
        altered=V6CompletionReuseDU7Masks.du7_v5_extensions(G,V,need,work;
            beta=Q.BETA8,max_kernel=23,audit_stats=stats)
        equal=base.Ss==altered.Ss && base.nT==altered.nT && base.ncand==altered.ncand &&
            base.du_reject==altered.du_reject && base.nX_used==altered.nX_used && base.key==altered.key &&
            !base.capped && !altered.capped && base.nX_used==base.nX
        equal || error("DU7 mask variant failed full-job parity")
        plain=Float64[];filtered=Float64[]
        for iteration in 1:repeats
            time()-started<max_seconds || break
            # Alternate order to reduce drift from the other bounded audit jobs.
            methods=isodd(iteration) ? (:plain,:filtered) : (:filtered,:plain)
            for method in methods
                t=time_ns()
                if method==:plain
                    V6CompletionReuseDU7Masks.T.reference_v5_extensions(G,V,need,work;beta=Q.BETA8,max_kernel=23)
                    push!(plain,(time_ns()-t)*1e-9)
                else
                    V6CompletionReuseDU7Masks.du7_v5_extensions(G,V,need,work;
                        beta=Q.BETA8,max_kernel=23)
                    push!(filtered,(time_ns()-t)*1e-9)
                end
            end
        end
        sort!(plain);sort!(filtered)
        record=Dict("parent_id"=>job["parent_id"],"b5"=>job["b5"],"queue_state"=>job["queue_state"],
            "forms"=>job["forms"],"need"=>need,"full_parity"=>equal,"nX"=>base.nX,
            "du_reject"=>base.du_reject,"logical_candidates"=>base.ncand,
            "completion_spaces"=>length(base.Ss),"triangle_pairs_total"=>stats.pairs,
            "triangle_cosets"=>stats.cosets,"triangle_rejections"=>stats.rejected,
            "triangle_pair_tests"=>stats.pair_tests,
            "remaining_solve_ones_calls"=>base.ncand-stats.rejected,
            "plain_seconds"=>plain,"filtered_seconds"=>filtered,
            "plain_median_seconds"=>plain[cld(length(plain),2)],
            "filtered_median_seconds"=>filtered[cld(length(filtered),2)],
            "median_speedup"=>plain[cld(length(plain),2)]/filtered[cld(length(filtered),2)])
        push!(reports,record)
        println(JSON3.write(record));flush(stdout)
    end
    report=Dict("schema"=>"vbfsearch-du7-mask-prefilter-benchmark-v1",
        "created_utc"=>string(now(UTC)),"input"=>abspath(input_file),"input_sha256"=>source_sha,
        "vbf_quadratic_extensions_sha256"=>V6CompletionReuseDU7Masks.T.source_sha256,
        "tool_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),
        "prototype_sha256"=>bytes2hex(open(SHA.sha256,joinpath(@__DIR__,"v6_completion_reuse_du7_masks.jl"))),
        "julia_version"=>string(VERSION),"threads"=>Threads.nthreads(),
        "repeats_requested"=>repeats,"max_seconds"=>max_seconds,"elapsed_seconds"=>time()-started,
        "complete"=>length(reports)==length(input["jobs"]) && all(r->length(r["plain_seconds"])==repeats,reports),
        "jobs"=>reports,"scope"=>"Descriptive four-job prototype benchmark; no population speedup estimate; campaign unchanged")
    write(output_file,JSON3.write(report));report
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==2 || error("usage: triangle_benchmark INPUT_JSON OUTPUT_JSON")
    run(ARGS[1],ARGS[2])
end
end
