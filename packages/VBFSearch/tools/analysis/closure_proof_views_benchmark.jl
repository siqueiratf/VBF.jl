"""Bounded native proof-view versus pinned dictionary-worker comparison.

Reads only existing JSON evidence; every database write targets a fresh fixture.
Both workers use the same installed ledger encoder, isolating representation
cost while requiring byte-identical persistent evidence and equal wire values.
"""
module ClosureProofViewsBenchmark
using VBF,VBFSearch,JSON3,SHA,Statistics,Dates,Serialization
include("closure_worker_integration_audit.jl")
const FP=VBFSearch
const Q=VBF.QuadraticExtensions
const BASELINE_SHA="eb8aa65092e95e5a4f0684b020770fb5f27f5f2cf1dde28b5cbc6d4bb239736a"
sha(path)=bytes2hex(open(SHA.sha256,path))

"""Compile the unchanged, archived dictionary-producing worker only."""
function install_baseline(path)
    sha(path)==BASELINE_SHA || error("baseline source digest mismatch")
    body=match(r"function _closure_compute_v5\(.*?(?=\nfunction _closure_compute_switching)"s,read(path,String))
    body===nothing && error("pinned worker not found")
    source=replace(String(body.match),"function _closure_compute_v5("=>"function _analysis_dictionary_v5(";count=1)
    Core.eval(FP,Meta.parse(source))
    Base.invokelatest(getfield,FP,:_analysis_dictionary_v5)
end

function run(holdout_input,parents_input,baseline,out;limit=4,repeats=3,max_seconds=150.0)
    started=time();mkpath(out);dictionary_worker=install_baseline(baseline)
    vbf_before=FP.equivalence_solver_fingerprint()
    sources=Dict(name=>joinpath(dirname(pathof(FP)),name) for name in
        ("closure_algorithms.jl","closure_coset_proofs.jl","closure_ledger.jl"))
    hashes_before=Dict(k=>sha(v) for (k,v) in sources)
    records=JSON3.read(read(holdout_input,String))["records"][1:limit]
    parents=Dict(Int(p["parent_id"])=>p for p in JSON3.read(read(parents_input,String))["parents"])
    s,jobs=ClosureWorkerIntegrationAudit.fixture(joinpath(out,"isolated-fixture"),records,parents)
    table=Q.PolarRankTable(Q.geometry(8));context=FP.ClosureWorkContext(;rank_table=table)
    rows=Any[]
    try
        for (i,job) in enumerate(jobs)
            time()-started<max_seconds || error("bounded proof comparison timed out")
            packet=FP._closure_work_packet(s,job);F=FP._closure_compute_parent(packet)
            warm=deepcopy(packet);warm["extension_cosets"]=8
            Base.invokelatest(dictionary_worker,warm,F,context,()->false)
            FP._closure_compute_v5(warm,F,context,()->false)
            timings=Dict("dictionary"=>Any[],"views"=>Any[])
            reference=nothing;result=nothing
            for rep in 1:repeats
                order=isodd(rep) ? ("dictionary","views") : ("views","dictionary")
                for mode in order
                    t=@timed mode=="dictionary" ? Base.invokelatest(dictionary_worker,packet,F,context,()->false) :
                        FP._closure_compute_v5(packet,F,context,()->false)
                    push!(timings[mode],Dict("seconds"=>t.time,"allocated_bytes"=>t.bytes,"gc_seconds"=>t.gctime))
                    if mode=="dictionary"
                        reference=t.value
                    else
                        result=t.value
                    end
                end
                result==reference || error("native worker value differs")
                result["ledger"]==reference["ledger"] || error("persistent ledger bytes differ")
            end
            old_json=@timed JSON3.write(reference)
            new_json=@timed JSON3.write(result)
            JSON3.read(old_json.value,Dict{String,Any})==JSON3.read(new_json.value,Dict{String,Any}) || error("wire values differ")
            io=IOBuffer();serialize(io,result);serialized=take!(io)
            deserialize(IOBuffer(serialized))==reference || error("binary serialization differs")
            push!(rows,Dict("parent_id"=>Int(records[i]["parent_id"]),"job_id"=>job["id"],
                "processed_cosets"=>result["processed_cosets"],"candidate_records"=>length(result["records"]),
                "timings"=>timings,"median_seconds"=>Dict(k=>median(t["seconds"] for t in v) for (k,v) in timings),
                "median_allocated_bytes"=>Dict(k=>median(t["allocated_bytes"] for t in v) for (k,v) in timings),
                "json"=>Dict("dictionary_seconds"=>old_json.time,"view_seconds"=>new_json.time,
                    "dictionary_bytes"=>sizeof(old_json.value),"view_bytes"=>sizeof(new_json.value)),
                "serialized_bytes"=>length(serialized),"work_values_equal"=>true,"persistent_bytes_equal"=>true,
                "ledger_sha256"=>bytes2hex(sha256(result["ledger"].evidence))))
            println(JSON3.write(last(rows)));flush(stdout)
        end
        hashes_after=Dict(k=>sha(v) for (k,v) in sources)
        report=Dict("schema"=>"closure-proof-view-comparison-v1","created_utc"=>string(now(UTC))*"Z",
            "baseline_sha256"=>BASELINE_SHA,"source_hashes_before"=>hashes_before,"source_hashes_after"=>hashes_after,
            "sources_unchanged"=>hashes_before==hashes_after,"threads"=>Threads.nthreads(),
            "vbf_sources_sha256"=>vbf_before,"vbf_sources_unchanged"=>vbf_before==FP.equivalence_solver_fingerprint(),
            "records"=>rows,"elapsed_seconds"=>time()-started,"complete"=>length(rows)==limit,
            "scope"=>"Four existing uniform-parent holdout jobs, same live ledger encoder, warmed counterbalanced repetitions. Read-only source JSON; only a fresh isolated SQLite fixture receives writes. Campaign remains stopped.")
        write(joinpath(out,"report.json"),JSON3.write(report));report
    finally
        FP._closure_close(s)
    end
end

if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==4 || error("usage: closure_proof_views_benchmark HOLDOUT PARENTS PINNED_SOURCE NEW_OUT")
    run(ARGS...)
end
end
