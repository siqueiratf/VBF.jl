"""Immutable EA work against a frozen, ordered snapshot of the global parent set.

Workers never receive a database. Admission remains a single-writer operation:
a negative snapshot is not enough when another same-signature parent has since
been admitted. Such work is requeued against the enlarged set before promotion.
"""
const CLOSURE_EQUIVALENCE_SCHEMA="vbfsearch-closure-equivalence-v1"

"""Decode the canonical queued ID while retaining ordinary TOML for other payloads.

Construction jobs emit one lowercase SHA-256 field. Recognizing its exact bytes
avoids parsing the same tiny document during both preparation and application.
Whitespace, escapes, extra fields and future payload formats use the parser.
"""
function _closure_equivalence_candidate_id(payload::AbstractString)
    if ncodeunits(payload)==82 && startswith(payload,"candidate_id = \"") && endswith(payload,"\"\n")
        bytes=codeunits(payload)
        canonical=true
        @inbounds for index in 17:80
            byte=bytes[index]
            if !(UInt8('0')<=byte<=UInt8('9') || UInt8('a')<=byte<=UInt8('f'))
                canonical=false
                break
            end
        end
        canonical && return String(SubString(payload,17,80))
    end
    TOML.parse(payload)["candidate_id"]
end

function _closure_equivalence_packet(s,job;native=false,target_cache=nothing)
    native isa Bool || throw(ArgumentError("native packet selection must be Boolean"))
    id=_closure_equivalence_candidate_id(job["payload"])
    candidate=only(_closure_rows(s,"SELECT id,lut_hex,sigma FROM candidates WHERE id=?",(id,)))
    targets=Dict{String,Any}[];current_solver=nothing
    table=_closure_normalized(s.db) ? "closure_comparisons" : "comparisons"
    latest=Dict(Int(r["target_parent"])=>r for r in _closure_rows(s,
        "SELECT e.id,e.target_parent,e.status FROM $table e JOIN (SELECT target_parent,MAX(id) latest FROM $table WHERE candidate_id=? GROUP BY target_parent) q ON e.id=q.latest",(id,)))
    for target in _closure_parent_targets(s,candidate["sigma"],target_cache)
        saved=get(latest,Int(target["id"]),nothing)
        saved_exhaustive=false
        if saved!==nothing && saved["status"]=="inequivalent_by_exhaustive_solver"
            evidence=only(_closure_rows(s,"SELECT evidence FROM comparisons WHERE id=?",(saved["id"],)))["evidence"]
            proof=TOML.tryparse(evidence)
            saved_solver=proof isa AbstractDict ? get(proof,"solver_implementation_sha256",nothing) : nothing
            if saved_solver isa String && get(proof,"status",nothing)=="inequivalent_by_exhaustive_solver"
                # An upgrade can retain records produced by another solver.
                # Hash current sources only once, and only for reusable-looking
                # negatives; malformed or unbound evidence is checked afresh.
                current_solver===nothing && (current_solver=DiscoveryEvidence.solver_fingerprint(_closure_solver_session(s)))
                saved_exhaustive=saved_solver==current_solver
            end
        end
        push!(targets,Dict{String,Any}("parent_id"=>Int(target["id"]),"candidate_id"=>target["candidate_id"],
            "lut_hex"=>target["lut_hex"],"saved_exhaustive"=>saved_exhaustive))
    end
    packet=Dict{String,Any}("schema"=>CLOSURE_EQUIVALENCE_SCHEMA,"job_id"=>Int(job["id"]),
        "job_key"=>job["job_key"],"candidate_id"=>id,"lut_hex"=>candidate["lut_hex"],
        "sigma"=>candidate["sigma"],"targets"=>targets)
    native && return _ClosureEquivalencePacket(packet)
    packet["packet_sha256"]=_closure_packet_digest(packet)
    packet
end

function _closure_equivalence_compute(packet;seconds,nodes,context=nothing,solver_session=nothing)
    packet["schema"]==CLOSURE_EQUIVALENCE_SCHEMA || error("unsupported equivalence packet")
    packet["packet_sha256"]==_closure_packet_digest(packet) || error("equivalence packet digest differs")
    context===nothing || trylock(context.guard) || error("closure compute context is already in use by another task")
    try
        started=time_ns();nodes_left=nodes
        candidate_lut=hex2bytes(packet["lut_hex"])
        cache=context===nothing ? nothing : context.property_cache
        p=properties(candidate_lut;cache)
        p["lut_sha256"]==packet["candidate_id"] && p["apn"] && p["quadratic"] && p["sigma_hash"]==packet["sigma"] || error("invalid pending quadratic candidate")
        comparisons=Dict{String,Any}[];complete=true
        for target in packet["targets"]
            target_lut=hex2bytes(target["lut_hex"])
            DiscoveryEvidence.lut_id(target_lut)==target["candidate_id"] || error("equivalence target digest differs")
            target["saved_exhaustive"] && continue
            remaining=max(0.0,seconds-Float64(time_ns()-started)/1e9)
            if remaining<=0 || nodes_left<=0
                complete=false;break
            end
            target_properties=properties(target_lut;cache)
            proof=DiscoveryEvidence._compare_verified_properties(candidate_lut,target_lut,p,target_properties;
                relation=:ea,timeout_seconds=remaining,max_nodes=nodes_left,solver_session)
            nodes_left=max(0,nodes_left-Int(get(proof,"nodes",0)))
            push!(comparisons,Dict{String,Any}("target_parent"=>target["parent_id"],"proof"=>proof))
            proof["status"]=="equivalent_with_verified_witness" && break
        end
        # Storage preparation must not consume the next target's solver budget.
        for comparison in comparisons
            proof=comparison["proof"]
            comparison["proof"]=_closure_prepare_comparison_proof(proof,
                (packet["lut_hex"],proof["target_lut_hex"],packet["candidate_id"],proof["target_sha256"]))
        end
        Dict{String,Any}("schema"=>CLOSURE_EQUIVALENCE_SCHEMA,"packet_sha256"=>packet["packet_sha256"],
            "candidate_id"=>packet["candidate_id"],"properties"=>p,"comparisons"=>comparisons,"complete"=>complete)
    finally
        context===nothing || unlock(context.guard)
    end
end

"""Apply worker evidence, or requeue a stale parent snapshot without admitting it."""
function _closure_equivalence_apply!(s,job,packet,result;target_cache=nothing)
    _closure_transaction(s) do
        result["schema"]==packet["schema"]==CLOSURE_EQUIVALENCE_SCHEMA || error("equivalence result schema differs")
        packet["packet_sha256"]==_closure_packet_digest(packet)==result["packet_sha256"] || error("equivalence result packet differs")
        job["id"]==packet["job_id"] && job["job_key"]==packet["job_key"] || error("equivalence result job differs")
        id=_closure_equivalence_candidate_id(job["payload"])
        id==packet["candidate_id"]==result["candidate_id"] || error("equivalence candidate differs")
        current=only(_closure_rows(s,"SELECT lut_hex,sigma,class_id FROM candidates WHERE id=?",(id,)))
        current["lut_hex"]==packet["lut_hex"] && current["sigma"]==packet["sigma"] || error("equivalence candidate changed")
        if !ismissing(current["class_id"])
            _closure_finish!(s,job,Dict("already_admitted"=>true);done=true)
            return :done
        end
        p=result["properties"]
        p["lut_sha256"]==id && p["lut_hex"]==packet["lut_hex"] && p["apn"] && p["quadratic"] && p["sigma_hash"]==packet["sigma"] || error("equivalence properties differ")
        snapshot_targets=packet["targets"]
        targets=Dict(Int(t["parent_id"])=>t for t in snapshot_targets)
        checked=Set(Int(t["parent_id"]) for t in snapshot_targets if t["saved_exhaustive"])
        unresolved=false;equivalent=nothing
        for comparison in result["comparisons"]
            targetid=Int(comparison["target_parent"])
            haskey(targets,targetid) && !(targetid in checked) || error("unexpected or repeated equivalence target")
            target=targets[targetid];proof=comparison["proof"]
            actual=_closure_parent_target(s,targetid,target_cache)
            actual["candidate_id"]==target["candidate_id"] && actual["lut_hex"]==target["lut_hex"] || error("equivalence target changed")
            proof["relation"]=="ea" && proof["candidate_sha256"]==id && proof["target_sha256"]==target["candidate_id"] &&
                proof["candidate_lut_hex"]==packet["lut_hex"] && proof["target_lut_hex"]==target["lut_hex"] || error("equivalence proof is bound to another pair")
            status=proof["status"]
            if status=="equivalent_with_verified_witness"
                verify_comparison(proof) || error("EA witness failed full replay")
                equivalent=targetid
            elseif status=="inequivalent_by_exhaustive_solver"
                proof["solver_implementation_sha256"]==DiscoveryEvidence.solver_fingerprint(_closure_solver_session(s)) || error("EA negative uses another solver")
            elseif status=="inconclusive_budget"
                unresolved=true
            else
                error("unexpected equal-signature equivalence outcome")
            end
            _closure_insert_comparison!(s,id,targetid,proof;
                bound_pair=(packet["lut_hex"],target["lut_hex"],id,target["candidate_id"]))
            push!(checked,targetid)
            equivalent===nothing || break
        end
        if equivalent!==nothing
            _closure_candidate_state!(s,id,"equivalent";class_id=equivalent)
            _closure_finish!(s,job,Dict("verified_equivalent_parent"=>equivalent);done=true)
            return :done
        end
        complete=result["complete"]
        complete isa Bool || error("invalid equivalence completion flag")
        complete && length(checked)!=length(targets) && error("equivalence result omitted a snapshot target")
        if !complete
            _closure_candidate_state!(s,id,"unresolved_equivalence")
            _closure_finish!(s,job,Dict("unresolved_equivalence"=>true,"snapshot_incomplete"=>true,
                "checked_parents"=>length(checked),"snapshot_parents"=>length(targets)))
            # Exhaustive negative prefixes remain reusable at the next bounded
            # session; a budget stop never certifies the omitted parent suffix.
            return :unresolved
        end
        current_targets=Set(Int(r["id"]) for r in _closure_rows(s,"SELECT id FROM parents WHERE sigma=?",(packet["sigma"],)))
        if current_targets!=Set(keys(targets))
            issubset(Set(keys(targets)),current_targets) || error("admitted parent set shrank")
            _closure_exec(s,"UPDATE jobs SET status='paused',last_session=0,result=? WHERE id=?",
                (_closure_text(Dict("snapshot_stale"=>true,"snapshot_parents"=>length(targets),"current_parents"=>length(current_targets))),job["id"]))
            return :revalidate
        elseif unresolved
            _closure_candidate_state!(s,id,"unresolved_equivalence")
            _closure_finish!(s,job,Dict("unresolved_equivalence"=>true))
            return :unresolved
        end
        parent=_closure_add_parent!(s,id,packet["sigma"])
        _closure_finish!(s,job,Dict("promoted_parent"=>parent,"descendant_profile_filter"=>"none");done=true)
        :done
    end
end
