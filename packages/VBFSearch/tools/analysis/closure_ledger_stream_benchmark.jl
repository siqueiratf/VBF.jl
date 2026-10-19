"""Paired byte-for-byte benchmark of the pinned and streaming ledger writer."""
module ClosureLedgerStreamBenchmark
using VBF,VBFSearch,JSON3,SHA,Statistics,Dates
include("closure_worker_integration_audit.jl")
const FP=VBFSearch
const Q=VBF.QuadraticExtensions

"""Replay the exact pre-change ledger-row function under a private name."""
function load_old(path)
    source=read(path,String)
    bytes2hex(SHA.sha256(source))=="b5aaad78c08c77c1eff1d5078fc42954f08bc600ca925fb4472e9a77367b5e8f" || error("wrong pinned ledger source")
    body=match(r"function _closure_ledger_row\(.*?(?=\n\"\"\"Persist)"s,source)
    body===nothing && error("cannot locate pinned ledger body")
    text=replace(String(body.match),"function _closure_ledger_row("=>"function _analysis_pinned_ledger_row(";count=1)
    Core.eval(FP,Meta.parse(text))
end

"""Use a real complete packet's chunks; write only an isolated tiny fixture."""
function run(holdout_input,parents_input,pinned,out;repeats=5)
    load_old(pinned);mkpath(out);started=time()
    h=JSON3.read(read(holdout_input,String));record=h["records"][1]
    parents=Dict(Int(p["parent_id"])=>p for p in JSON3.read(read(parents_input,String))["parents"])
    s,jobs=ClosureWorkerIntegrationAudit.fixture(joinpath(out,"isolated-fixture"),[record],parents)
    packet=try FP._closure_work_packet(s,only(jobs)) finally FP._closure_close(s) end
    G=Q.geometry(8);table=Q.PolarRankTable(G);context=FP.ClosureWorkContext(G,Q.V5Work(23),ReentrantLock(),table)
    result=FP._closure_compute(packet;context,seconds=60,evaluations=256)
    result["work"]["done"] || error("incomplete fixture packet")
    chunks=result["work"]["chunks"];job=Int(packet["job_id"])
    old=Base.invokelatest(FP._analysis_pinned_ledger_row,job,chunks)
    new=FP._closure_ledger_row(job,chunks);old==new || error("ledger bytes changed")
    measurements=Dict("old"=>Any[],"streamed"=>Any[])
    for i in 1:repeats
        for method in (isodd(i) ? (:old,:streamed) : (:streamed,:old))
            t=method===:old ? (@timed Base.invokelatest(FP._analysis_pinned_ledger_row,job,chunks)) :
                (@timed FP._closure_ledger_row(job,chunks))
            t.value==old || error("ledger bytes drifted")
            push!(measurements[String(method)],Dict("seconds"=>t.time,"bytes"=>t.bytes,"gc_seconds"=>t.gctime))
        end
    end
    summary=Dict(k=>Dict("median_seconds"=>median(r["seconds"] for r in rows),
        "median_bytes"=>median(r["bytes"] for r in rows)) for (k,rows) in measurements)
    report=Dict("schema"=>"vbfsearch-streamed-ledger-byte-parity-v1","created_utc"=>string(now(UTC))*"Z",
        "parent_id"=>record["parent_id"],"cosets"=>length(chunks),"repeats"=>repeats,
        "byte_for_byte_equal"=>true,"compressed_bytes"=>length(new.evidence),
        "compressed_sha256"=>bytes2hex(SHA.sha256(new.evidence)),"summary"=>summary,"measurements"=>measurements,
        "allocation_reduction"=>1-summary["streamed"]["median_bytes"]/summary["old"]["median_bytes"],
        "median_speedup"=>summary["old"]["median_seconds"]/summary["streamed"]["median_seconds"],
        "old_source_sha256"=>bytes2hex(open(SHA.sha256,pinned)),
        "new_source_sha256"=>bytes2hex(open(SHA.sha256,joinpath(dirname(pathof(FP)),"closure_ledger.jl"))),
        "tool_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),"elapsed_seconds"=>time()-started,
        "scope"=>"One real complete holdout packet; exact prior body and generic packer versus direct streaming; schema, persistent bytes and corruption bounds unchanged; no campaign restart")
    write(joinpath(out,"report.json"),JSON3.write(report));println(JSON3.write(report));report
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==4 || error("usage: closure_ledger_stream_benchmark HOLDOUT_JSON PARENTS_JSON PINNED_LEDGER NEW_OUTPUT_DIRECTORY")
    run(ARGS[1],ARGS[2],ARGS[3],ARGS[4])
end
end
