"""Bounded replay of V5 compute, durable apply and EA admission on tiny fixtures.

This completes only the selected V5 jobs and their admission queue. It neither
expands whole parents nor runs recursive descendants. Archived reference and
current admission/apply implementations consume the same computed packets.
"""
module ClosurePipelineAudit
using VBF,VBFSearch,JSON3,SHA,Dates,Statistics,TOML
include("closure_worker_integration_audit.jl")
const FP=VBFSearch
const Q=VBF.QuadraticExtensions
const BASELINES=Dict("closure_algorithms.jl"=>"cb963bc0d3b30d28d14f248affc68293dd54c68fa75c723de4dcb681b228feac",
    "closure_equivalence.jl"=>"54a96643feeff5d06e1f95d65e4330ed4f4847c0bc8a1c1df53faf5bdac15a04")

"""Extract only the pinned function, retaining normal calls to shared helpers."""
function reference_function(path,old,new)
    bytes2hex(open(SHA.sha256,path))==BASELINES[basename(path)] || error("reference source changed")
    function find_function(ex)
        ex isa Expr || return nothing
        if ex.head===:function
            head=ex.args[1]
            head isa Expr && head.head===:call && first(head.args)===old && return ex
        end
        for child in ex.args
            found=find_function(child)
            found===nothing || return found
        end
        nothing
    end
    source=find_function(Meta.parseall(read(path,String)))
    source===nothing && error("reference function missing")
    renamed=deepcopy(source);renamed.args[1].args[1]=new
    Core.eval(FP,renamed)
    Base.invokelatest(getfield,FP,new)
end

"""Compare class assignments using representative LUTs rather than row numbers."""
function science(s)
    rows(sql)=FP._closure_rows(s.db,sql)
    classes=Dict(Int(p["id"])=>String(p["candidate_id"]) for p in rows("SELECT id,candidate_id FROM parents"))
    assignments=Dict(String(c["id"])=>(ismissing(c["class_id"]) ? nothing : classes[Int(c["class_id"])])
        for c in rows("SELECT id,class_id FROM candidates ORDER BY id"))
    paths=[(r["parent_id"],r["job_id"],r["method"],r["cursor"],r["child_id"],r["witness"])
        for r in rows("SELECT * FROM paths ORDER BY job_id,cursor,child_id")]
    ledger=[(r["job_id"],r["first_x"],r["next_x"],r["total_x"],r["capped"],
             r["evidence"] isa String ? r["evidence"] : bytes2hex(SHA.sha256(r["evidence"])))
        for r in rows("SELECT * FROM chunks ORDER BY job_id,first_x")]
    (;assignments,paths,ledger)
end

"""Replay within a bounded wall budget; unknowns never become new classes."""
function admission_phase(s,jobs,results,applyfn,computefn;max_seconds=90.0,max_ea_jobs=256)
    started=time();apply_rows=Any[];ea_rows=Any[]
    for (job,result) in zip(jobs,results)
        t=@timed Base.invokelatest(applyfn,s,job,result)
        push!(apply_rows,Dict("job_id"=>job["id"],"seconds"=>t.time,"bytes"=>t.bytes,"gc_seconds"=>t.gctime))
    end
    attempted=Set{Int}();seen_unknown=false
    while length(ea_rows)<max_ea_jobs && time()-started<max_seconds-2
        pending=FP._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='deduplicate' AND status IN ('pending','paused') ORDER BY id")
        available=filter(j->!(Int(j["id"]) in attempted),pending)
        isempty(available) && break
        job=first(available);push!(attempted,Int(job["id"]))
        packet_time=@timed FP._closure_equivalence_packet(s,job)
        packet=packet_time.value
        t=@timed Base.invokelatest(computefn,packet;seconds=2.0,nodes=100_000)
        a=@timed FP._closure_equivalence_apply!(s,job,packet,t.value)
        if a.value===:revalidate
            delete!(attempted,Int(job["id"]))
        elseif a.value===:unresolved
            seen_unknown=true
        end
        push!(ea_rows,Dict("job_id"=>job["id"],"candidate_id"=>packet["candidate_id"],
            "targets"=>length(packet["targets"]),"packet_seconds"=>packet_time.time,
            "compute_seconds"=>t.time,"compute_bytes"=>t.bytes,"gc_seconds"=>t.gctime,
            "apply_seconds"=>a.time,"outcome"=>String(a.value)))
    end
    pending=FP._closure_count(s.db,"SELECT COUNT(*) n FROM jobs WHERE kind='deduplicate' AND status!='done'")
    counts=Dict("parents_in_fixture"=>FP._closure_count(s.db,"SELECT COUNT(*) n FROM parents"),
        "candidate_luts"=>FP._closure_count(s.db,"SELECT COUNT(*) n FROM candidates"),
        "paths"=>FP._closure_count(s.db,"SELECT COUNT(*) n FROM paths"),"pending_ea"=>pending)
    Dict("apply"=>apply_rows,"ea"=>ea_rows,"counts"=>counts,"complete"=>pending==0,
        "unknown_seen"=>seen_unknown,"elapsed_seconds"=>time()-started,
        "construction_apply_seconds"=>sum(r["seconds"] for r in apply_rows),
        "ea_packet_seconds"=>sum(r["packet_seconds"] for r in ea_rows;init=0.0),
        "ea_compute_seconds"=>sum(r["compute_seconds"] for r in ea_rows;init=0.0),
        "ea_apply_seconds"=>sum(r["apply_seconds"] for r in ea_rows;init=0.0))
end

"""Bind every timing to source and inputs; all mutations target new fixtures."""
function run(holdout_input,parents_input,baseline,out;limit=4,max_seconds=90.0)
    ispath(out) && error("output must be new")
    mkpath(out);started=time();sources=FP.implementation_fingerprint()
    applyref=reference_function(joinpath(baseline,"closure_algorithms.jl"),:_closure_apply!,:_analysis_pipeline_apply!)
    computeref=reference_function(joinpath(baseline,"closure_equivalence.jl"),:_closure_equivalence_compute,:_analysis_pipeline_ea_compute)
    h=JSON3.read(read(holdout_input,String));h["complete"] || error("incomplete holdout")
    receipt=JSON3.read(read(joinpath(dirname(parents_input),"provenance-validation.json"),String))
    receipt["complete"] && receipt["bindings"]["parents.json"]==bytes2hex(open(SHA.sha256,parents_input)) || error("invalid parent receipt")
    records=h["records"][1:min(limit,length(h["records"]))]
    parents=Dict(Int(p["parent_id"])=>p for p in JSON3.read(read(parents_input,String))["parents"])
    table=Q.PackedPolarRankTable(Q.geometry(8));context=FP.ClosureWorkContext(;rank_table=table)
    s,jobs=ClosureWorkerIntegrationAudit.fixture(joinpath(out,"reference-fixture"),records,parents)
    t,currentjobs=ClosureWorkerIntegrationAudit.fixture(joinpath(out,"current-fixture"),records,parents)
    report=Dict{String,Any}()
    try
        warm=FP._closure_work_packet(s,first(jobs));warm["extension_cosets"]=8
        warm["packet_sha256"]=FP._closure_packet_digest(warm)
        FP._closure_compute(warm;context,seconds=60,evaluations=256)
        results=Any[];compute=Any[]
        for (i,job) in enumerate(jobs)
            packet=FP._closure_work_packet(s,job)
            packet==FP._closure_work_packet(t,currentjobs[i]) || error("fixture descriptors differ")
            measured=@timed FP._closure_compute(packet;context,seconds=60,evaluations=256)
            measured.value["work"]["done"] || error("selected V5 did not exhaust")
            push!(results,measured.value)
            push!(compute,Dict("parent_id"=>Int(records[i]["parent_id"]),"seconds"=>measured.time,
                "bytes"=>measured.bytes,"cosets"=>measured.value["work"]["processed_cosets"],
                "candidate_records"=>length(measured.value["work"]["records"])))
        end
        # Compile an actual matching-bucket solver path outside measured phases.
        # The translated control is verified but never inserted into either DB.
        warm_started=time()
        f=hex2bytes(first(first(results)["work"]["records"])["properties"]["lut_hex"])
        g=f .⊻ UInt8(17);pf=FP.properties(f);pg=FP.properties(g)
        ea_control=Dict{String,Any}("schema"=>FP.CLOSURE_EQUIVALENCE_SCHEMA,"job_id"=>0,"job_key"=>"offline-warmup",
            "candidate_id"=>pg["lut_sha256"],"lut_hex"=>pg["lut_hex"],"sigma"=>pg["sigma_hash"],
            "targets"=>[Dict{String,Any}("parent_id"=>1,"candidate_id"=>pf["lut_sha256"],
                "lut_hex"=>pf["lut_hex"],"saved_exhaustive"=>false)])
        ea_control["packet_sha256"]=FP._closure_packet_digest(ea_control)
        for fn in (computeref,FP._closure_equivalence_compute)
            for _ in 1:2
                Base.invokelatest(fn,ea_control;seconds=5.0,nodes=100_000)
            end
        end
        ea_warmup_seconds=time()-warm_started
        # Compile both validators under rollback; scientific state stays empty.
        for (store,fn,job,eafn) in ((s,applyref,first(jobs),computeref),
                (t,FP._closure_apply!,first(currentjobs),FP._closure_equivalence_compute))
            FP._closure_exec(store.db,"BEGIN IMMEDIATE")
            try
                Base.invokelatest(fn,store,job,first(results))
                ea_jobs=FP._closure_rows(store.db,"SELECT * FROM jobs WHERE kind='deduplicate' ORDER BY id LIMIT 1")
                if !isempty(ea_jobs)
                    ea_job=first(ea_jobs);packet=FP._closure_equivalence_packet(store,ea_job)
                    value=Base.invokelatest(eafn,packet;seconds=5.0,nodes=100_000)
                    FP._closure_equivalence_apply!(store,ea_job,packet,value)
                end
            finally
                FP._closure_exec(store.db,"ROLLBACK")
            end
        end
        reference=admission_phase(s,jobs,results,applyref,computeref;max_seconds)
        current=admission_phase(t,currentjobs,results,FP._closure_apply!,FP._closure_equivalence_compute;max_seconds)
        a=science(s);b=science(t)
        a.paths==b.paths && a.ledger==b.ledger || error("durable construction evidence differs")
        parity=a.assignments==b.assignments
        reference["complete"] && current["complete"] && !parity && error("completed admission partitions differ")
        report=Dict("schema"=>"vbfsearch-bounded-pipeline-audit-v1","created_utc"=>string(now(UTC))*"Z",
            "compute"=>compute,"reference"=>reference,"current"=>current,
            "admission_assignments_equal"=>parity,"construction_evidence_equal"=>true,
            "ea_warmup_seconds"=>ea_warmup_seconds,
            "source_bindings"=>sources,"sources_unchanged"=>sources==FP.implementation_fingerprint(),
            "holdout_sha256"=>bytes2hex(open(SHA.sha256,holdout_input)),
            "parents_sha256"=>bytes2hex(open(SHA.sha256,parents_input)),
            "tool_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),"elapsed_seconds"=>time()-started,
            "scope"=>"Four selected V5 jobs, durable writes, bounded output admission against a tiny evolving fixture parent set. Both implementations consume identical current-worker results. Pinned reference EA packet body calls current public compare/shared provenance: this isolates candidate-property reuse, not the complete old EA stack. Excludes complete parent expansion, recursive descendants, network and production-size indices. Reference then current; first-use EA compilation can affect timings; not campaign throughput.")
        report["sources_unchanged"] || error("source changed during replay")
        open(io->JSON3.pretty(io,report),joinpath(out,"report.json"),"w")
        println(JSON3.write(Dict("event"=>"bounded_pipeline_finished","reference"=>reference["counts"],
            "current"=>current["counts"],"admission_assignments_equal"=>parity)))
        report
    finally
        FP._closure_close(s);FP._closure_close(t)
    end
end
end

if abspath(PROGRAM_FILE)==(@__FILE__)
    length(ARGS)==4 || error("usage: closure_pipeline_audit HOLDOUT PARENTS PINNED_BASELINE NEW_OUTPUT")
    ClosurePipelineAudit.run(ARGS...)
end
