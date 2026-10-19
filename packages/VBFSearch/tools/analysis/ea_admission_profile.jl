"""Bounded EA-admission decomposition on captured immutable campaign packets.

The input contains only a small, SHA-bound row export. This tool never opens
the scientific DB and never admits a candidate. Controls deliberately include
empty and nonempty signature buckets; they are not a population estimate.
"""
module EAAdmissionProfile
using VBF,VBFSearch,JSON3,SHA,Statistics,Dates,Profile
const FP=VBFSearch
const DE=FP.DiscoveryEvidence

function packets(path)
    raw=JSON3.read(read(path,String),Dict{String,Any})
    result=Dict{String,Any}[]
    for row in raw["packets"]
        p=Dict{String,Any}(k=>v for (k,v) in row if k ∉ ("source_parent_id","original_target_count"))
        p["packet_sha256"]=FP._closure_packet_digest(p);push!(result,p)
    end
    result
end

function measured(f;repeats=5)
    f();rows=Any[];value=nothing
    for _ in 1:repeats
        t=@timed f();value=t.value
        push!(rows,Dict("seconds"=>t.time,"bytes"=>t.bytes,"gc_seconds"=>t.gctime))
    end
    Dict("median_seconds"=>median(r["seconds"] for r in rows),
        "median_bytes"=>median(r["bytes"] for r in rows),"measurements"=>rows),value
end

function run(input,out;max_seconds=120.0)
    mkpath(out);started=time();source_before=FP.implementation_fingerprint()
    ps=packets(input);results=Any[]
    # Compile each actual solver path before recording low-millisecond phases.
    for p in ps
        FP._closure_equivalence_compute(p;seconds=0.2,nodes=100_000)
    end
    for p in ps
        time()-started<max_seconds || error("bounded EA admission profile expired")
        full,r=measured(()->FP._closure_equivalence_compute(p;seconds=0.2,nodes=100_000))
        validation,prop=measured(()->FP.properties(hex2bytes(p["lut_hex"])))
        digest,_=measured(()->FP._closure_packet_digest(p))
        row=Dict{String,Any}("candidate_id"=>p["candidate_id"],"targets"=>length(p["targets"]),
            "full_compute"=>full,"candidate_properties"=>validation,"packet_digest"=>digest,
            "statuses"=>[c["proof"]["status"] for c in r["comparisons"]],"complete"=>r["complete"])
        if !isempty(p["targets"])
            target=first(p["targets"]);f=hex2bytes(p["lut_hex"]);g=hex2bytes(target["lut_hex"])
            target_properties,_=measured(()->FP.properties(g))
            comparison,proof=measured(()->FP.compare(f,g;relation=:ea,timeout_seconds=0.2,max_nodes=100_000))
            F=SBox{8,UInt8}(f);G=SBox{8,UInt8}(g)
            native,nproof=measured(()->FP.equivalence_evidence(F,G;relation=:ea,timeout_seconds=0.2,max_nodes=100_000))
            replay,_=measured(()->FP.verify_comparison(proof))
            merge!(row,Dict("target_properties"=>target_properties,"public_comparison"=>comparison,
                "native_equivalence"=>native,"witness_replay"=>replay,"native_status"=>nproof["status"]))
        end
        push!(results,row);println(JSON3.write(row));flush(stdout)
    end
    fingerprint,_=measured(()->FP.equivalence_solver_fingerprint();repeats=20)
    evidencehash,_=measured(()->DE.filehash(joinpath(dirname(pathof(FP)),"evidence.jl"));repeats=20)
    Profile.clear()
    @profile for _ in 1:20,p in ps
        FP._closure_equivalence_compute(p;seconds=0.2,nodes=100_000)
    end
    open(joinpath(out,"profile.txt"),"w") do io
        Profile.print(io;format=:flat,sortedby=:count,mincount=2)
    end
    report=Dict("schema"=>"ea-admission-profile-v1","created_utc"=>string(now(UTC))*"Z",
        "input_sha256"=>bytes2hex(open(SHA.sha256,input)),"sources_before"=>source_before,
        "sources_unchanged"=>source_before==FP.implementation_fingerprint(),"records"=>results,
        "solver_fingerprint_only"=>fingerprint,"evidence_filehash_only"=>evidencehash,
        "elapsed_seconds"=>time()-started,"threads"=>Threads.nthreads(),
        "scope"=>"Sixteen captured actual pending packets across eight source parents; first empty and matching bucket per parent. No SQLite writes, no campaign restart, no admission decisions.")
    write(joinpath(out,"report.json"),JSON3.write(report));report
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==2 || error("usage: ea_admission_profile CAPTURED_INPUTS NEW_OUTPUT")
    run(ARGS...)
end
end
