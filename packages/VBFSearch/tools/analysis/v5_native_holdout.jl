"""Paired native V5 timings on a fixed uniform queued-parent holdout.

The reference body is loaded from the archived pre-optimization source rather
than the live routine. Every output set and completion cursor is compared.
"""
module V5NativeHoldout
using VBF,VBFSearch,JSON3,SHA,Random,Statistics,Dates
include("v5_parent_provenance.jl")
include("v6_completion_reuse_triangles.jl")
const Q=VBF.QuadraticExtensions
const reference=V6CompletionReuseTriangles.reference_v5_extensions

function run(input,output;parents_limit=16,max_seconds=180.0,seed=18105271)
    started=time();solver_before=VBFSearch.equivalence_solver_fingerprint()
    bytes=read(input);raw=JSON3.read(String(copy(bytes)))
    receipt=JSON3.read(read(joinpath(dirname(input),"provenance-validation.json"),String))
    receipt["complete"] && receipt["bindings"]["parents.json"]==bytes2hex(SHA.sha256(bytes)) || error("invalid parent provenance")
    parents=[p for p in raw["parents"] if p["uniform_parent_sample"] && p["queued_parent"]]
    rng=Xoshiro(seed);shuffle!(rng,parents);resize!(parents,min(parents_limit,length(parents)))
    G=Q.geometry(8);t=time();table=Q.PolarRankTable(G);table_seconds=time()-t
    reference_work=Q.V5Work(23);native_work=Q.V5Work(23);records=Dict{String,Any}[]
    stable=(:Ss,:nX,:nX_used,:next_x,:du_reject,:nT,:key,:capped,:skipped)
    for (i,p) in enumerate(parents)
        time()-started>=max_seconds && break
        vi=rand(rng,1:length(p["maximizing_v5_forms"]));V=UInt32.(p["maximizing_v5_forms"][vi]);need=Int(p["need"])
        parent=V5ParentProvenance.parent_component_space(hex2bytes(String(p["lut_hex"])))
        V5ParentProvenance.contained_five_space(parent,V) || error("incorrect parent association")
        if i==1
            reference(G,V,need,reference_work;beta=Q.BETA8,max_x=8,max_kernel=23)
            Q.v5_extensions(G,V,need,native_work;beta=Q.BETA8,max_x=8,max_kernel=23,du7_filter=:bitsets,rank_table=table)
        end
        a=nothing;b=nothing;ta=0.0;tb=0.0
        for which in (isodd(i) ? (:reference,:native) : (:native,:reference))
            t=time()
            if which===:reference
                a=reference(G,V,need,reference_work;beta=Q.BETA8,max_kernel=23);ta=time()-t
            else
                b=Q.v5_extensions(G,V,need,native_work;beta=Q.BETA8,max_kernel=23,du7_filter=:bitsets,rank_table=table);tb=time()-t
            end
        end
        all(getproperty(a,k)==getproperty(b,k) for k in stable) || error("native completion/cursor mismatch")
        !a.capped && a.next_x==a.nX+1 || error("holdout did not fully exhaust its V5 job")
        all(differential_uniformity(last(Q.function_of(G,S)))==2 for S in b.Ss) || error("invalid native output")
        push!(records,Dict("parent_id"=>Int(p["parent_id"]),"parent_candidate_id"=>String(p["candidate_id"]),
            "v5_index"=>vi,"forms"=>Int.(V),"b5"=>Int(p["b5"]),"need"=>need,"cosets"=>a.nX,
            "reference_seconds"=>ta,"native_seconds"=>tb,"speedup"=>ta/tb,"exact_output_parity"=>true,
            "output_count"=>length(a.Ss),"reference_candidates"=>a.ncand,"native_candidates"=>b.ncand))
        println(JSON3.write(Dict("event"=>"holdout_parent","parents"=>i,"speedup"=>ta/tb,"seconds"=>time()-started)));flush(stdout)
    end
    VBFSearch.equivalence_solver_fingerprint()==solver_before || error("native solver sources changed during benchmark")
    report=Dict("schema"=>"vbfsearch-native-v5-uniform-parent-holdout-v1","created_utc"=>string(now(UTC))*"Z",
        "seed"=>seed,"parents"=>length(records),"requested_parents"=>parents_limit,"complete"=>length(records)==length(parents),
        "input_sha256"=>bytes2hex(SHA.sha256(bytes)),"baseline_source_sha256"=>V6CompletionReuseTriangles.source_sha256,
        "native_solver_sha256"=>solver_before,"solver_sources_unchanged"=>true,"tool_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),
        "rank_table_bytes"=>length(table.ranks),"rank_table_build_seconds"=>table_seconds,
        "median_job_speedup"=>median(r["speedup"] for r in records),
        "paired_total_speedup"=>sum(r["reference_seconds"] for r in records)/sum(r["native_seconds"] for r in records),
        "elapsed_seconds"=>time()-started,"records"=>records,
        "scope"=>"Uniform parents from the frozen validated queued sample; one uniformly chosen maximizing V5 per parent, not a job-weighted census. Single Julia compute thread; paired counterbalanced ordering; excludes campaign SQL and whole-process scheduling.")
    open(io->JSON3.pretty(io,report),output,"w");report
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && V5NativeHoldout.run(ARGS[1],ARGS[2];parents_limit=length(ARGS)>2 ? parse(Int,ARGS[3]) : 16)
