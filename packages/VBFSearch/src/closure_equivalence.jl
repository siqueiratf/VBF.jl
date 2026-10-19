"""Immutable EA work against a frozen, ordered snapshot of the global parent set.

Workers never receive a database. Admission remains a single-writer operation:
a negative snapshot is not enough when another same-signature parent has since
been admitted. Such work is requeued against the enlarged set before promotion.
"""
const CLOSURE_EQUIVALENCE_SCHEMA="vbfsearch-closure-equivalence-v1"

function _closure_equivalence_packet(s,job)
    id=TOML.parse(job["payload"])["candidate_id"]
    candidate=only(_closure_rows(s.db,"SELECT id,lut_hex,sigma FROM candidates WHERE id=?",(id,)))
    targets=Dict{String,Any}[];current_solver=nothing
    for target in _closure_rows(s.db,"SELECT p.id,c.id candidate_id,c.lut_hex FROM parents p JOIN candidates c ON c.id=p.candidate_id WHERE p.sigma=? ORDER BY p.id",(candidate["sigma"],))
        saved=_closure_rows(s.db,"SELECT status,evidence FROM comparisons WHERE candidate_id=? AND target_parent=? ORDER BY id DESC LIMIT 1",(id,target["id"]))
        saved_exhaustive=false
        if !isempty(saved) && only(saved)["status"]=="inequivalent_by_exhaustive_solver"
            proof=TOML.tryparse(only(saved)["evidence"])
            saved_solver=proof isa AbstractDict ? get(proof,"solver_implementation_sha256",nothing) : nothing
            if saved_solver isa String && get(proof,"status",nothing)=="inequivalent_by_exhaustive_solver"
                # An upgrade can retain records produced by another solver.
                # Hash current sources only once, and only for reusable-looking
                # negatives; malformed or unbound evidence is checked afresh.
                current_solver===nothing && (current_solver=DiscoveryEvidence.solver_fingerprint())
                saved_exhaustive=saved_solver==current_solver
            end
        end
        push!(targets,Dict{String,Any}("parent_id"=>Int(target["id"]),"candidate_id"=>target["candidate_id"],
            "lut_hex"=>target["lut_hex"],"saved_exhaustive"=>saved_exhaustive))
    end
    packet=Dict{String,Any}("schema"=>CLOSURE_EQUIVALENCE_SCHEMA,"job_id"=>Int(job["id"]),
        "job_key"=>job["job_key"],"candidate_id"=>id,"lut_hex"=>candidate["lut_hex"],
        "sigma"=>candidate["sigma"],"targets"=>targets)
    packet["packet_sha256"]=_closure_packet_digest(packet)
    packet
end

function _closure_equivalence_compute(packet;seconds,nodes)
    packet["schema"]==CLOSURE_EQUIVALENCE_SCHEMA || error("unsupported equivalence packet")
    packet["packet_sha256"]==_closure_packet_digest(packet) || error("equivalence packet digest differs")
    started=time_ns();nodes_left=nodes
    candidate_lut=hex2bytes(packet["lut_hex"])
    p=properties(candidate_lut)
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
        target_properties=properties(target_lut)
        proof=DiscoveryEvidence._compare_verified_properties(candidate_lut,target_lut,p,target_properties;
            relation=:ea,timeout_seconds=remaining,max_nodes=nodes_left)
        nodes_left=max(0,nodes_left-Int(get(proof,"nodes",0)))
        push!(comparisons,Dict{String,Any}("target_parent"=>target["parent_id"],"proof"=>proof))
        proof["status"]=="equivalent_with_verified_witness" && break
    end
    Dict{String,Any}("schema"=>CLOSURE_EQUIVALENCE_SCHEMA,"packet_sha256"=>packet["packet_sha256"],
        "candidate_id"=>packet["candidate_id"],"properties"=>p,"comparisons"=>comparisons,"complete"=>complete)
end

"""Apply worker evidence, or requeue a stale parent snapshot without admitting it."""
function _closure_equivalence_apply!(s,job,packet,result)
    _closure_transaction(s) do
        result["schema"]==packet["schema"]==CLOSURE_EQUIVALENCE_SCHEMA || error("equivalence result schema differs")
        packet["packet_sha256"]==_closure_packet_digest(packet)==result["packet_sha256"] || error("equivalence result packet differs")
        job["id"]==packet["job_id"] && job["job_key"]==packet["job_key"] || error("equivalence result job differs")
        id=TOML.parse(job["payload"])["candidate_id"]
        id==packet["candidate_id"]==result["candidate_id"] || error("equivalence candidate differs")
        current=only(_closure_rows(s.db,"SELECT * FROM candidates WHERE id=?",(id,)))
        current["lut_hex"]==packet["lut_hex"] && current["sigma"]==packet["sigma"] || error("equivalence candidate changed")
        if !ismissing(current["class_id"])
            _closure_finish!(s,job,Dict("already_admitted"=>true);done=true)
            return :done
        end
        p=result["properties"]
        p["lut_sha256"]==id && p["lut_hex"]==packet["lut_hex"] && p["apn"] && p["quadratic"] && p["sigma_hash"]==packet["sigma"] || error("equivalence properties differ")
        targets=Dict(Int(t["parent_id"])=>t for t in packet["targets"])
        checked=Set(Int(t["parent_id"]) for t in packet["targets"] if t["saved_exhaustive"])
        unresolved=false;equivalent=nothing
        for comparison in result["comparisons"]
            targetid=Int(comparison["target_parent"])
            haskey(targets,targetid) && !(targetid in checked) || error("unexpected or repeated equivalence target")
            target=targets[targetid];proof=comparison["proof"]
            actual=only(_closure_rows(s.db,"SELECT p.candidate_id,c.lut_hex FROM parents p JOIN candidates c ON c.id=p.candidate_id WHERE p.id=?",(targetid,)))
            actual["candidate_id"]==target["candidate_id"] && actual["lut_hex"]==target["lut_hex"] || error("equivalence target changed")
            proof["relation"]=="ea" && proof["candidate_sha256"]==id && proof["target_sha256"]==target["candidate_id"] &&
                proof["candidate_lut_hex"]==packet["lut_hex"] && proof["target_lut_hex"]==target["lut_hex"] || error("equivalence proof is bound to another pair")
            status=proof["status"]
            if status=="equivalent_with_verified_witness"
                verify_comparison(proof) || error("EA witness failed full replay")
                equivalent=targetid
            elseif status=="inequivalent_by_exhaustive_solver"
                proof["solver_implementation_sha256"]==DiscoveryEvidence.solver_fingerprint() || error("EA negative uses another solver")
            elseif status=="inconclusive_budget"
                unresolved=true
            else
                error("unexpected equal-signature equivalence outcome")
            end
            _closure_exec(s.db,"INSERT INTO comparisons(candidate_id,target_parent,status,evidence,session_id) VALUES(?,?,?,?,?)",
                (id,targetid,status,_closure_text(proof),s.session))
            push!(checked,targetid)
            equivalent===nothing || break
        end
        if equivalent!==nothing
            _closure_exec(s.db,"UPDATE candidates SET class_id=?,state='equivalent' WHERE id=?",(equivalent,id))
            _closure_finish!(s,job,Dict("verified_equivalent_parent"=>equivalent);done=true)
            return :done
        end
        complete=result["complete"]
        complete isa Bool || error("invalid equivalence completion flag")
        complete && length(checked)!=length(targets) && error("equivalence result omitted a snapshot target")
        if !complete
            _closure_exec(s.db,"UPDATE candidates SET state='unresolved_equivalence' WHERE id=?",(id,))
            _closure_finish!(s,job,Dict("unresolved_equivalence"=>true,"snapshot_incomplete"=>true,
                "checked_parents"=>length(checked),"snapshot_parents"=>length(targets)))
            # Exhaustive negative prefixes remain reusable at the next bounded
            # session; a budget stop never certifies the omitted parent suffix.
            return :unresolved
        end
        current_targets=Set(Int(r["id"]) for r in _closure_rows(s.db,"SELECT id FROM parents WHERE sigma=?",(packet["sigma"],)))
        if current_targets!=Set(keys(targets))
            issubset(Set(keys(targets)),current_targets) || error("admitted parent set shrank")
            _closure_exec(s.db,"UPDATE jobs SET status='paused',last_session=0,result=? WHERE id=?",
                (_closure_text(Dict("snapshot_stale"=>true,"snapshot_parents"=>length(targets),"current_parents"=>length(current_targets))),job["id"]))
            return :revalidate
        elseif unresolved
            _closure_exec(s.db,"UPDATE candidates SET state='unresolved_equivalence' WHERE id=?",(id,))
            _closure_finish!(s,job,Dict("unresolved_equivalence"=>true))
            return :unresolved
        end
        parent=_closure_add_parent!(s,id,packet["sigma"])
        _closure_finish!(s,job,Dict("promoted_parent"=>parent,"descendant_profile_filter"=>"none");done=true)
        :done
    end
end
