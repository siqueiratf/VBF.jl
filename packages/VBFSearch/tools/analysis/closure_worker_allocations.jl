"""Allocation isolation of the real closure worker without protocol changes.

Analysis-only variants replace fresh candidate properties by an exact canonical
output-space cache, then omit final ledger encoding. All remaining chunks,
records and aggregate proofs are compared to the unchanged worker. Existing
VBF mathematics and the original ledger encoder are reused throughout.
"""
module ClosureWorkerAllocations
using VBF,VBFSearch,JSON3,SHA,Statistics,Dates
include("closure_worker_integration_audit.jl")
const FP=VBFSearch
const Q=VBF.QuadraticExtensions

"""Fail closed if the installed worker body no longer matches the variant."""
function replace_once(source,old,new)
    length(findall(old,source))==1 || error("worker source fragment changed")
    replace(source,old=>new;count=1)
end

const algorithms_path=joinpath(dirname(pathof(FP)),"closure_algorithms.jl")
const algorithms_sha256=bytes2hex(open(SHA.sha256,algorithms_path))
body=match(r"function _closure_compute_v5\(.*?(?=\nfunction _closure_compute_switching)"s,read(algorithms_path,String))
body===nothing && error("cannot locate worker kernel")
cached=replace_once(String(body.match),"function _closure_compute_v5(packet,F,context,stop_requested)",
    "function _analysis_v5_cached_properties(packet,F,context,stop_requested,property_cache)")
cached=replace_once(cached,"_,H=Fourier.function_of(G,S);p=properties(H.lut)","p=property_cache[Tuple(S)]")
Core.eval(FP,Meta.parse(cached))
noledger=replace_once(cached,"function _analysis_v5_cached_properties(","function _analysis_v5_no_ledger(")
noledger=replace_once(noledger,"ledger=isempty(chunks) ? nothing : _closure_ledger_row(Int(packet[\"job_id\"]),chunks)","ledger=nothing")
Core.eval(FP,Meta.parse(noledger))

"""Warm call followed by paired measurements of time, allocation and GC."""
function measurements(f;repeats=3)
    f();rows=Any[];result=nothing
    for _ in 1:repeats
        t=@timed f();result=t.value
        push!(rows,Dict("seconds"=>t.time,"bytes"=>t.bytes,"gc_seconds"=>t.gctime))
    end
    Dict("median_seconds"=>median(r["seconds"] for r in rows),
        "median_bytes"=>median(r["bytes"] for r in rows),"measurements"=>rows),result
end

"""Separate real properties, per-coset proof work and unchanged ledger encoding."""
function run(holdout_input,parents_input,out)
    mkpath(out);started=time();solver_start=FP.equivalence_solver_fingerprint()
    holdout=JSON3.read(read(holdout_input,String));record=holdout["records"][1]
    parents=Dict(Int(p["parent_id"])=>p for p in JSON3.read(read(parents_input,String))["parents"])
    s,jobs=ClosureWorkerIntegrationAudit.fixture(joinpath(out,"isolated-fixture"),[record],parents)
    packet=try FP._closure_work_packet(s,only(jobs)) finally FP._closure_close(s) end
    G=Q.geometry(8);table=Q.PolarRankTable(G);context=FP.ClosureWorkContext(G,Q.V5Work(23),ReentrantLock(),table)
    F=FP._closure_compute_parent(packet)
    native=()->Q.v5_extensions(G,UInt32.(record["forms"]),Int(record["need"]),context.work;
        beta=Q.BETA8,max_kernel=23,du7_filter=:bitsets,rank_table=table)
    raw_timing,raw=measurements(native)
    outputs=sort!(collect(raw.Ss);by=Tuple)
    properties_call=()->Dict(Tuple(S)=>FP.properties(last(Q.function_of(G,S)).lut) for S in outputs)
    properties_timing,property_cache=measurements(properties_call)
    full_timing,full=measurements(()->FP._closure_compute_v5(packet,F,context,()->false))
    cached_timing,reused=measurements(()->FP._analysis_v5_cached_properties(packet,F,context,()->false,property_cache))
    noledger_timing,noencoding=measurements(()->FP._analysis_v5_no_ledger(packet,F,context,()->false,property_cache))
    full==reused || error("cached-properties variant changed work evidence")
    all(full[k]==noencoding[k] for k in keys(full) if k!="ledger") || error("no-ledger variant changed chunks/records/proofs")
    encoding_timing,encoded=measurements(()->FP._closure_ledger_row(Int(packet["job_id"]),full["chunks"]))
    encoded==full["ledger"] || error("standalone ledger bytes differ")
    validation_timing,_=measurements(()->FP._closure_compute_parent(packet);repeats=10)
    report=Dict("schema"=>"vbfsearch-worker-allocation-isolation-v1","created_utc"=>string(now(UTC))*"Z",
        "parent_id"=>record["parent_id"],"cosets"=>full["processed_cosets"],
        "distinct_properties_computed"=>length(property_cache),"candidate_records"=>length(full["records"]),
        "raw_native"=>raw_timing,"candidate_properties_only"=>properties_timing,
        "worker_v5_body"=>full_timing,"worker_cached_properties"=>cached_timing,
        "worker_cached_properties_no_encoding"=>noledger_timing,"ledger_encoding_only"=>encoding_timing,
        "parent_validation_only"=>validation_timing,"all_work_evidence_equal"=>true,
        "all_persistent_ledger_bytes_equal"=>true,"algorithms_sha256"=>algorithms_sha256,
        "solver_sha256"=>solver_start,"solver_sources_unchanged"=>solver_start==FP.equivalence_solver_fingerprint(),
        "tool_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),"elapsed_seconds"=>time()-started,
        "scope"=>"One existing uniform-parent holdout job; warmed three-repeat allocation isolations. Cache and omitted encoder are analysis-only; no production/ledger protocol changes, no campaign restart.")
    write(joinpath(out,"report.json"),JSON3.write(report));println(JSON3.write(report));report
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==3 || error("usage: closure_worker_allocations HOLDOUT_JSON PARENTS_JSON NEW_OUTPUT_DIRECTORY")
    run(ARGS[1],ARGS[2],ARGS[3])
end
end
