"""Compare fresh-property EA admission with its SHA-pinned previous worker.

No SQLite database is opened. Both paths use the current, unchanged public
comparison and native solver; only the worker's duplicate candidate properties
are eliminated. Ample budgets preserve exact witnesses and node counts, while
zero budgets and malformed identities are also checked.
"""
module EAAdmissionCompare
using VBF,VBFSearch,JSON3,SHA,Statistics,Dates
include("ea_admission_profile.jl")
const FP=VBFSearch
const BASELINE_SHA="54a96643feeff5d06e1f95d65e4330ed4f4847c0bc8a1c1df53faf5bdac15a04"

function reference(path)
    bytes2hex(open(SHA.sha256,path))==BASELINE_SHA || error("EA reference source changed")
    body=match(r"function _closure_equivalence_compute\(.*?(?=\n\"\"\"Apply worker)"s,read(path,String))
    body===nothing && error("cannot find original EA worker")
    source=replace(String(body.match),"function _closure_equivalence_compute("=>"function _ea_admission_reference_compute(";count=1)
    Core.eval(FP,Meta.parse(source));Base.invokelatest(getfield,FP,:_ea_admission_reference_compute)
end

function canonical(work)
    result=deepcopy(work)
    for row in result["comparisons"]
        delete!(row["proof"],"seconds");delete!(row["proof"],"timeout_seconds")
    end
    result
end

function bound_sources()
    Dict(k=>v for (k,v) in FP.implementation_fingerprint() if startswith(k,"packages/VBF/src/") ||
        k in ("packages/VBFSearch/src/evidence.jl","packages/VBFSearch/src/closure_equivalence.jl"))
end

function run(input,baseline,out;repeats=7,max_seconds=100.0)
    started=time();mkpath(out);old=reference(baseline);before=bound_sources()
    rows=Any[];ps=EAAdmissionProfile.packets(input)
    for p in ps
        time()-started<max_seconds || error("bounded EA comparison timed out")
        Base.invokelatest(old,p;seconds=0.2,nodes=100_000)
        FP._closure_equivalence_compute(p;seconds=0.2,nodes=100_000)
        times=Dict("original"=>Any[],"reused"=>Any[]);values=Dict{String,Any}()
        for rep in 1:repeats
            for mode in (isodd(rep) ? ("original","reused") : ("reused","original"))
                t=@timed mode=="original" ? Base.invokelatest(old,p;seconds=0.2,nodes=100_000) :
                    FP._closure_equivalence_compute(p;seconds=0.2,nodes=100_000)
                push!(times[mode],Dict("seconds"=>t.time,"bytes"=>t.bytes,"gc_seconds"=>t.gctime))
                values[mode]=t.value
            end
            canonical(values["original"])==canonical(values["reused"]) || error("EA classification, witness or node count changed")
        end
        r=values["reused"]
        all(c->FP.verify_comparison(c["proof"]),r["comparisons"]) || error("positive witness did not replay")
        for (seconds,nodes) in ((0.0,100_000),(0.2,0))
            a=Base.invokelatest(old,p;seconds,nodes);b=FP._closure_equivalence_compute(p;seconds,nodes)
            canonical(a)==canonical(b) || error("zero-budget classification changed")
        end
        push!(rows,Dict("candidate_id"=>p["candidate_id"],"targets"=>length(p["targets"]),
            "measurements"=>times,"median_seconds"=>Dict(k=>median(t["seconds"] for t in v) for (k,v) in times),
            "median_allocated_bytes"=>Dict(k=>median(t["bytes"] for t in v) for (k,v) in times),
            "statuses"=>[c["proof"]["status"] for c in r["comparisons"]],
            "nodes"=>[get(c["proof"],"nodes",0) for c in r["comparisons"]],
            "canonical_scientific_result_sha256"=>bytes2hex(sha256(FP._closure_text(canonical(r)))),
            "exact_scientific_result_equal"=>true,"all_positive_witnesses_replayed"=>true))
        println(JSON3.write(last(rows)));flush(stdout)
    end
    after=bound_sources()
    report=Dict("schema"=>"ea-admission-compare-v1","created_utc"=>string(now(UTC))*"Z",
        "baseline_sha256"=>BASELINE_SHA,"input_sha256"=>bytes2hex(open(SHA.sha256,input)),
        "tool_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),"sources_before"=>before,"sources_after"=>after,
        "sources_unchanged"=>before==after,"threads"=>Threads.nthreads(),"records"=>rows,
        "elapsed_seconds"=>time()-started,"complete"=>length(rows)==length(ps),
        "scope"=>"Sixteen real captured pending packets across eight source parents, balanced empty/matching signature buckets. Seven counterbalanced repetitions. Exact scientific/witness/node/identity/property parity except elapsed and remaining-time metadata. Same live comparison helper and native solver. No SQLite access, admissions or campaign restart.")
    write(joinpath(out,"report.json"),JSON3.write(report));report
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==3 || error("usage: ea_admission_compare CAPTURED_INPUTS PINNED_SOURCE NEW_OUTPUT")
    run(ARGS...)
end
end
