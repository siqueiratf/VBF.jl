"""Native dictionary storage for the bounded positive EA admission experiment.

This file performs no SQLite operations. It retains the production mathematics,
ordered refill pool, pair binding and full EA witness replay. It deliberately
uses native packets and evidence instead of database-oriented text encodings.
It is an experiment for this admission workload, not a recursive search backend.
"""
mutable struct NativeAdmissionStore
    candidates::Dict{String,Dict{String,Any}}
    parents::Dict{Int,Dict{String,Any}}
    buckets::Dict{String,Vector{Int}}
    jobs::Vector{Dict{String,Any}}
    comparisons::Vector{Dict{String,Any}}
    next_reserved::Int
    solver_session::Any
end

"""Load fixture rows and build candidate, parent, signature and job indexes."""
function native_initialize(fixture,selected)
    input=JSON3.read(read(fixture,String),Dict{String,Any})
    candidates=Dict{String,Dict{String,Any}}()
    parents=Dict{Int,Dict{String,Any}}()
    buckets=Dict{String,Vector{Int}}()
    for row in input["reference_parents"]
        p=TOML.parse(row["properties"]);id=String(row["candidate_id"]);parent=Int(row["original_id"])
        p["lut_sha256"]==id || error("native reference identity differs")
        candidates[id]=Dict("id"=>id,"lut_hex"=>row["lut_hex"],"sigma"=>row["sigma"],
            "properties"=>p,"class_id"=>parent,"state"=>"admitted")
        parents[parent]=Dict("id"=>parent,"candidate_id"=>id,"lut_hex"=>row["lut_hex"],"sigma"=>row["sigma"])
        push!(get!(buckets,String(row["sigma"]),Int[]),parent)
    end
    foreach(sort!,values(buckets))
    jobs=Dict{String,Any}[]
    for (i,row) in enumerate(input["work_candidates"][selected])
        p=TOML.parse(row["properties"]);id=String(row["candidate_id"])
        p["lut_sha256"]==id || error("native candidate identity differs")
        haskey(candidates,id) && error("native fixture candidate is already a parent")
        haskey(parents,Int(row["owner_parent"])) || error("native job owner is absent")
        candidates[id]=Dict("id"=>id,"lut_hex"=>row["lut_hex"],"sigma"=>row["sigma"],
            "properties"=>p,"class_id"=>nothing,"state"=>"awaiting_equivalence")
        push!(jobs,Dict("id"=>i,"parent_id"=>Int(row["owner_parent"]),"kind"=>"deduplicate",
            "job_key"=>"storage-bench:"*id,"candidate_id"=>id,"status"=>"pending","result"=>Dict{String,Any}()))
    end
    NativeAdmissionStore(candidates,parents,buckets,jobs,Dict{String,Any}[],1,FP._equivalence_solver_session())
end

"""Compute native EA evidence with the same VBF solver and per-packet budgets."""
function native_compute(packet,context,solver_session)
    trylock(context.guard) || error("native context already in use")
    try
        started=time_ns();nodes_left=100_000
        candidate_lut=hex2bytes(packet.candidate_id_lut)
        p=FP.properties(candidate_lut;cache=context.property_cache)
        p["lut_sha256"]==packet.candidate_id && p["apn"] && p["quadratic"] && p["sigma_hash"]==packet.sigma || error("invalid native candidate")
        comparisons=Dict{String,Any}[];complete=true
        for target in packet.targets
            target_lut=hex2bytes(target["lut_hex"])
            FP.DiscoveryEvidence.lut_id(target_lut)==target["candidate_id"] || error("native target digest differs")
            remaining=max(0.0,1.0-Float64(time_ns()-started)/1e9)
            if remaining<=0 || nodes_left<=0
                complete=false;break
            end
            target_properties=FP.properties(target_lut;cache=context.property_cache)
            proof=FP.DiscoveryEvidence._compare_verified_properties(candidate_lut,target_lut,p,target_properties;
                relation=:ea,timeout_seconds=remaining,max_nodes=nodes_left,solver_session)
            nodes_left=max(0,nodes_left-Int(get(proof,"nodes",0)))
            push!(comparisons,Dict("target_parent"=>target["id"],"proof"=>proof))
            proof["status"]=="equivalent_with_verified_witness" && break
        end
        (;candidate_id=packet.candidate_id,properties=p,comparisons,complete)
    finally
        unlock(context.guard)
    end
end

"""Apply a positive EA result after checking identities, pair bindings and witness."""
function native_apply!(s,item,result)
    packet=item.packet;job=item.job;id=job["candidate_id"]
    packet.job_id==job["id"] && packet.job_key==job["job_key"] || error("native job changed")
    id==packet.candidate_id==result.candidate_id || error("native result candidate differs")
    current=s.candidates[id];p=result.properties
    current["lut_hex"]==packet.candidate_id_lut && current["sigma"]==packet.sigma || error("native candidate changed")
    p["lut_sha256"]==id && p["lut_hex"]==packet.candidate_id_lut && p["apn"] && p["quadratic"] && p["sigma_hash"]==packet.sigma || error("native properties differ")
    targets=Dict(Int(t["id"])=>t for t in packet.targets)
    checked=Set{Int}();staged=Dict{String,Any}[];equivalent=nothing
    for comparison in result.comparisons
        targetid=Int(comparison["target_parent"])
        haskey(targets,targetid) && !(targetid in checked) || error("unexpected native target")
        target=targets[targetid];actual=s.parents[targetid];proof=comparison["proof"]
        actual["candidate_id"]==target["candidate_id"] && actual["lut_hex"]==target["lut_hex"] || error("native target changed")
        proof["relation"]=="ea" && proof["candidate_sha256"]==id && proof["target_sha256"]==target["candidate_id"] &&
            proof["candidate_lut_hex"]==packet.candidate_id_lut && proof["target_lut_hex"]==target["lut_hex"] || error("native proof is bound to another pair")
        status=proof["status"]
        if status=="equivalent_with_verified_witness"
            FP.verify_comparison(proof) || error("native EA witness failed replay")
            equivalent=targetid
        elseif status=="inequivalent_by_exhaustive_solver"
            proof["solver_implementation_sha256"]==FP.DiscoveryEvidence.solver_fingerprint(s.solver_session) || error("native negative uses another solver")
        elseif status!="inconclusive_budget"
            error("unexpected native comparison outcome")
        end
        push!(staged,Dict("candidate_id"=>id,"target_parent"=>targetid,"status"=>status,"proof"=>proof))
        push!(checked,targetid)
        equivalent===nothing || break
    end
    equivalent===nothing && error("positive-only native fixture did not produce its verified witness")
    # Commit only after the entire packet's bindings and witness have passed.
    append!(s.comparisons,staged)
    current["class_id"]=equivalent;current["state"]="equivalent"
    job["status"]="done";job["result"]=Dict("verified_equivalent_parent"=>equivalent)
    nothing
end

"""Run the same bounded FIFO using native reservation, snapshots and admission."""
function native_replay(s,controller,contexts,config)
    function reserve(limit,excluded)
        last=min(length(s.jobs),s.next_reserved+limit-1)
        items=[(job=s.jobs[i],) for i in s.next_reserved:last]
        s.next_reserved=last+1
        items
    end
    function prepare(item,ticket,slot)
        job=item.job;job["status"]="running";c=s.candidates[job["candidate_id"]]
        targets=[copy(s.parents[id]) for id in get(s.buckets,String(c["sigma"]),Int[])]
        packet=(;job_id=job["id"],job_key=job["job_key"],candidate_id=c["id"],
            candidate_id_lut=c["lut_hex"],sigma=c["sigma"],targets)
        (;job,packet,ticket,slot)
    end
    controller.run_refill_pool!(reserve,prepare,
        (item,slot,stopped)->native_compute(item.packet,contexts[slot],s.solver_session),
        (item,result,seconds,scheduling)->native_apply!(s,item,result);
        concurrency=Int(config["concurrency"]),max_pending=Int(config["reservation_horizon"]),
        reservation_refill_batch=Int(config["reservation_refill_batch"]),
        max_apply_per_step=Int(config["max_apply_per_step"]),key=item->Int(item.job["id"]))
end

"""Measure native setup, computation, memory and durable saving separately."""
function native_trial(fixture,selected,controller,config;label)
    setup=@timed native_initialize(fixture,selected);s=setup.value
    contexts=controller.worker_contexts(Int(config["concurrency"]);
        precompute_rank_table=true,packed_rank_table=true,shared_property_cache_entries=8192).contexts
    GC.gc();before=counters();measured=@timed native_replay(s,controller,contexts,config);after=counters()
    jobs=sort(s.jobs;by=r->r["job_key"])
    all(r->r["status"]=="done",jobs) || error("native unfinished jobs")
    candidates=sort([r for r in values(s.candidates) if r["state"]!="admitted"];by=r->r["id"])
    length(candidates)==length(selected) && all(r->r["state"]=="equivalent",candidates) || error("native classes differ")
    comparisons=sort(s.comparisons;by=r->(r["candidate_id"],r["target_parent"]))
    witnesses=[(r["candidate_id"],r["target_parent"],r["status"],
        get(r["proof"],"graph_map_columns",nothing),get(r["proof"],"graph_map_constant",nothing),get(r["proof"],"rng_seed",nothing)) for r in comparisons]
    science=Dict("jobs"=>fingerprint((r["job_key"],r["status"],FP._closure_text(r["result"])) for r in jobs),
        "classes"=>fingerprint((r["id"],r["class_id"],r["state"]) for r in candidates),"witnesses"=>fingerprint(witnesses))
    destination=joinpath(config["native_output"],label*".jls");mkpath(dirname(destination))
    saving=@elapsed open(destination,"w") do io
        Serialization.serialize(io,(;candidates=s.candidates,parents=s.parents,buckets=s.buckets,jobs=s.jobs,comparisons=s.comparisons))
        flush(io);ccall(:fsync,Cint,(Cint,),fd(io))==0 || error("native result fsync failed")
    end
    restored=Serialization.deserialize(destination)
    length(restored.jobs)==length(selected) && all(r->r["status"]=="done",restored.jobs) || error("native saved results differ")
    Dict{String,Any}("label"=>label,"storage"=>"native","jobs"=>length(selected),
        "setup_seconds"=>setup.time,"wall_seconds"=>measured.time,"cpu_seconds"=>after.cpu-before.cpu,
        "mean_cpu_cores"=>(after.cpu-before.cpu)/measured.time,"coordinator_cpu_seconds"=>after.coordinator-before.coordinator,
        "jobs_per_second"=>length(selected)/measured.time,"gc_seconds"=>measured.gctime,
        "allocated_bytes"=>measured.bytes,"compile_seconds"=>measured.compile_time,"peak_rss_bytes"=>Sys.maxrss(),
        "io_deltas"=>Dict(k=>after.io[k]-v for (k,v) in before.io),
        "scheduler"=>Dict(string(k)=>v for (k,v) in pairs(measured.value)),"science"=>science,
        "comparison_rows"=>length(comparisons),"close_seconds"=>saving,"saved_bytes"=>filesize(destination),
        "native_state_bytes"=>Base.summarysize(s),"saved_path"=>destination,
        "durability"=>"state saved and fsynced after timed native computation; no per-packet durable writes")
end
