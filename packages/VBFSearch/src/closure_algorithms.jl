function _closure_parent(s, job)
    row=only(_closure_rows(s.db,"SELECT c.* FROM parents p JOIN candidates c ON c.id=p.candidate_id WHERE p.id=?",(job["parent_id"],)))
    F=SBox{8,UInt8}(hex2bytes(row["lut_hex"]))
    differential_uniformity(F)==2 && algebraic_degree(F)==2 || error("construction parent is not a quadratic APN")
    VBF.sigma_hash(F)==row["sigma"] || error("construction parent signature differs from pinned evidence")
    F
end

function _closure_claim!(s)
    _closure_transaction(s) do
        # Resolve each newly observed candidate once per session before deriving
        # its descendants. Inconclusive pairs wait for the next explicit run.
        rows=_closure_rows(s.db,"SELECT * FROM jobs WHERE kind='deduplicate' AND status IN ('pending','paused') AND last_session!=? ORDER BY id LIMIT 1",(s.session,))
        if isempty(rows)
            meta=Dict(r["key"]=>r["value"] for r in _closure_rows(s.db,"SELECT key,value FROM metadata WHERE key IN ('origin_turn','method_turn','dispatch_sequence')"))
            wanted_origin=meta["origin_turn"];wanted_method=meta["method_turn"]
            # Ranking supplies a deterministic fallback if either queue is empty.
            rows=_closure_rows(s.db,"SELECT j.* FROM jobs j JOIN parents p ON p.id=j.parent_id WHERE j.kind IN ('prepare_v5','v5','switching') AND j.status IN ('pending','paused') ORDER BY (p.origin!=?), (CASE WHEN j.kind='switching' THEN 'switching' ELSE 'v5' END !=?),p.last_dispatch,p.id,j.id LIMIT 1",
                (wanted_origin,wanted_method))
            isempty(rows) && return nothing
            job=only(rows);origin=only(_closure_rows(s.db,"SELECT origin FROM parents WHERE id=?",(job["parent_id"],)))["origin"]
            sequence=parse(Int,meta["dispatch_sequence"])+1
            _closure_exec(s.db,"UPDATE parents SET last_dispatch=? WHERE id=?",(sequence,job["parent_id"]))
            for (key,value) in (("dispatch_sequence",string(sequence)),("origin_turn",origin=="root" ? "discovered" : "root"),("method_turn",job["kind"]=="switching" ? "v5" : "switching"))
                _closure_exec(s.db,"UPDATE metadata SET value=? WHERE key=?",(value,key))
            end
        end
        job=only(rows)
        _closure_exec(s.db,"UPDATE jobs SET status='running',last_session=?,error='' WHERE id=?",(s.session,job["id"]))
        job
    end
end

function _closure_finish!(s,job,result;done=false,blocked=false)
    _closure_exec(s.db,"UPDATE jobs SET status=?,result=? WHERE id=?",
        (blocked ? "blocked" : done ? "done" : "paused",_closure_text(result),job["id"]))
end

"""Mutable Fourier scratch owned by one exclusive compute slot, never by a thread ID.

A task may migrate between Julia threads. Its slot context remains private and
can be reused for subsequent packets; simultaneous use is rejected explicitly.
"""
mutable struct ClosureWorkContext
    geometry::Any
    work::Any
    guard::ReentrantLock
end
ClosureWorkContext()=ClosureWorkContext(nothing,nothing,ReentrantLock())
ClosureWorkContext(geometry,work)=ClosureWorkContext(geometry,work,ReentrantLock())

const CLOSURE_WORK_SCHEMA="vbfsearch-closure-work-v1"
const CLOSURE_RESULT_SCHEMA="vbfsearch-closure-result-v1"

function _closure_packet_digest(packet)
    body=Dict{String,Any}(String(k)=>v for (k,v) in packet if String(k)!="packet_sha256")
    bytes2hex(SHA.sha256(_closure_text(body)))
end

"""Coordinator-only descriptor construction; no database handle crosses transport."""
function _closure_work_packet(s,job)
    job["kind"] in ("prepare_v5","v5","switching") || error("not a transportable construction job")
    parent=only(_closure_rows(s.db,"SELECT c.id,c.lut_hex,c.sigma FROM parents p JOIN candidates c ON c.id=p.candidate_id WHERE p.id=?",(job["parent_id"],)))
    packet=Dict{String,Any}("schema"=>CLOSURE_WORK_SCHEMA,"job_id"=>Int(job["id"]),
        "parent_id"=>Int(job["parent_id"]),"job_key"=>String(job["job_key"]),"kind"=>String(job["kind"]),
        "direction"=>Int(job["direction"]),"combination"=>String(job["combination"]),
        "payload"=>TOML.parse(job["payload"]),"target_b6"=>Int(s.identity["scientific"]["target_b6"]),
        "max_kernel"=>23,"extension_cosets"=>Int(get(s.identity["scientific"],"extension_cosets",1)),
        "switching_directions"=>Int(get(s.identity["scientific"],"switching_directions",1)),
        "parent"=>Dict("lut_sha256"=>String(parent["id"]),
            "lut_hex"=>String(parent["lut_hex"]),"sigma"=>String(parent["sigma"])))
    packet["packet_sha256"]=_closure_packet_digest(packet)
    packet
end

function _closure_compute_parent(packet)
    packet["schema"]==CLOSURE_WORK_SCHEMA || error("unsupported closure work packet")
    packet["packet_sha256"]==_closure_packet_digest(packet) || error("closure work packet digest mismatch")
    packet["target_b6"]==52 && packet["max_kernel"]==23 || error("unsupported construction parameters")
    get(packet,"extension_cosets",1) isa Integer && get(packet,"extension_cosets",1)>0 || error("invalid extension coset batch")
    directions=get(packet,"switching_directions",1)
    directions isa Integer && 1<=directions<=255 || error("invalid switching direction batch")
    parent=packet["parent"];lut=hex2bytes(parent["lut_hex"])
    length(lut)==256 && DiscoveryEvidence.lut_id(lut)==parent["lut_sha256"] || error("worker parent digest mismatch")
    F=SBox{8,UInt8}(lut)
    differential_uniformity(F)==2 && algebraic_degree(F)==2 || error("worker parent is not a quadratic APN")
    VBF.sigma_hash(F)==parent["sigma"] || error("worker parent signature mismatch")
    F
end

function _closure_context_geometry!(context)
    context.geometry===nothing && (context.geometry=Fourier.geometry(8))
    context.geometry
end
function _closure_context_work!(context)
    context.work===nothing && (context.work=Fourier.V5Work(23))
    context.work
end

function _closure_compute_prepare(packet,F,context)
    G=_closure_context_geometry!(context);a=anf(F)
    coefficients=UInt16[a[((1<<i)|(1<<j))+1] for i in 0:7 for j in i+1:7]
    components=Fourier.comp_forms(Fourier.coord_forms(coefficients,8))
    bent=Fourier.bent_mask(G,components);best=first(Fourier.max_bent_dim(components,bent,5))
    spaces=Fourier.subspaces_of_comp(components,bent,5;keep=n->n==best)
    canonical=sort!([Int.(Fourier.rref(V.forms)[1]) for V in spaces];by=v->Tuple(v))
    Dict{String,Any}("spaces"=>canonical,"max_b5"=>best,"done"=>true,"evaluations"=>0,
        "proof"=>Dict("max_b5"=>best,"five_spaces"=>length(canonical),"all_maximizers"=>true))
end

function _closure_compute_v5(packet,F,context,stop_requested)
    G=_closure_context_geometry!(context);work=_closure_context_work!(context)
    payload=packet["payload"];first_x=Int(packet["direction"])
    chunks=Dict{String,Any}[];records=Dict{String,Any}[]
    checked=Dict{Tuple,Dict{String,Any}}()
    function observe(event)
        local_records=Dict{String,Any}[]
        for S in sort!(collect(event.Ss);by=v->Tuple(v))
            # Retain every coset edge while avoiding repeated APN verification
            # of the identical canonical output space within this packet.
            p=get!(checked,Tuple(S)) do
                _,H=Fourier.function_of(G,S);p=properties(H.lut)
                p["apn"] && p["quadratic"] || error("invalid quadratic APN completion")
                p
            end
            witness=Dict("V5_forms"=>payload["forms"],"eligible_coset_index"=>event.index,
                "coset_representative"=>Int(event.representative),"need"=>payload["need"],
                "output_forms"=>Int.(S),"target_b6"=>52)
            push!(local_records,Dict("properties"=>p,"cursor"=>string(event.index),"witness"=>witness))
        end
        proof=Dict{String,Any}("first_x"=>event.index,"next_x"=>event.next_x,"total_x"=>event.total_x,
            "capped"=>event.capped,"candidate_spaces"=>length(local_records),"linear_system_candidates"=>event.ncand,
            "du_reject"=>event.du_reject,"completion_spaces"=>event.nT,"heuristic_pruning"=>false,
            "V5_forms"=>payload["forms"],"coset_order"=>"increasing nonzero quotient integer with exact bent count",
            "coset_representative"=>Int(event.representative))
        push!(chunks,Dict("proof"=>proof,"records"=>local_records,"processed_cosets"=>1))
        append!(records,local_records)
    end
    result=Fourier.v5_extensions(G,UInt32.(payload["forms"]),Int(payload["need"]),work;
        beta=Fourier.BETA8,max_kernel=23,max_x=Int(get(packet,"extension_cosets",1)),start_x=first_x,
        should_stop=stop_requested,coset_observer=observe)
    result.skipped && error("unexpected heuristic skip")
    length(chunks)==result.nX_used || error("extension callback lost a complete coset")
    proof=Dict{String,Any}("first_x"=>first_x,"next_x"=>result.next_x,"total_x"=>result.nX,
        "capped"=>result.capped,"candidate_spaces"=>length(records),"linear_system_candidates"=>result.ncand,
        "du_reject"=>result.du_reject,"completion_spaces"=>result.nT,"heuristic_pruning"=>false,
        "V5_forms"=>payload["forms"],"coset_order"=>"increasing nonzero quotient integer with exact bent count")
    if result.nX_used==1
        # Preserve the historical one-coset proof exactly.
        proof=copy(only(chunks)["proof"])
    elseif result.nX_used>1
        proof["distinct_candidate_spaces"]=length(result.Ss)
    elseif result.nX==0
        # The existing cursor ledger uses one empty exhaustion marker when the
        # selected five-space has no eligible six-space extensions.
        push!(chunks,Dict("proof"=>copy(proof),"records"=>Dict{String,Any}[],"processed_cosets"=>0))
    end
    # Encode the coverage ledger in the worker; the single writer only checks and stores it.
    ledger=isempty(chunks) ? nothing : _closure_ledger_row(Int(packet["job_id"]),chunks)
    Dict{String,Any}("chunks"=>chunks,"records"=>records,"proof"=>proof,"processed_cosets"=>result.nX_used,"ledger"=>ledger,
        "commit_chunk"=>!isempty(chunks),"blocked"=>result.capped,"apn_luts_checked"=>length(checked),
        "done"=>result.next_x>result.nX && !result.capped,"evaluations"=>result.ncand+length(records))
end

function _closure_compute_switching(packet,F;seconds,evaluations,stop_requested)
    direction_limit=Int(get(packet,"switching_directions",1))
    directions_done=Ref(0);events=Dict{String,Any}[]
    next_direction=Ref(Int(packet["direction"]));next_combination=Ref(String(packet["combination"]))
    function checkpoint(event,value)
        if event===:kernel
            evidence=Dict("direction"=>value.direction,"raw_dimension"=>value.raw_dimension,
                "quotient_dimension"=>value.quotient_dimension,
                "basis_hex"=>[bytes2hex(UInt8.(b)) for b in value.basis],"complete_constraints"=>true)
            push!(events,Dict("event"=>"kernel","direction"=>value.direction,
                "dimension"=>value.quotient_dimension,"evidence"=>evidence))
        elseif event===:candidate_complete
            p=properties(value.candidate.lut)
            p["apn"]==value.apn || error("switching APN check disagrees with fresh VBF validation")
            witness=Dict("direction"=>value.direction,"quotient_combination"=>string(value.combination),
                "kernel_job"=>packet["job_id"],"kernel_direction"=>value.direction)
            push!(events,Dict("event"=>"candidate_complete","direction"=>value.direction,
                "combination"=>string(value.combination),"next_direction"=>value.next_direction,
                "next_combination"=>string(value.next_combination),"properties"=>p,
                "cursor"=>string(value.direction)*":"*string(value.combination),"witness"=>witness))
            next_direction[]=value.next_direction;next_combination[]=string(value.next_combination)
        elseif event===:direction_complete
            push!(events,Dict("event"=>"direction_complete","direction"=>value.direction,
                "next_direction"=>value.next_direction,"next_combination"=>string(value.next_combination)))
            next_direction[]=value.next_direction;next_combination[]=string(value.next_combination)
            directions_done[]+=1
        end
    end
    result=switching_neighbors_bounded(F;max_evaluations=min(evaluations,256),timeout_seconds=seconds,
        start_direction=Int(packet["direction"]),start_combination=parse(BigInt,packet["combination"]),checkpoint,
        stop_requested=()->directions_done[]>=direction_limit || stop_requested())
    proof=Dict("evaluations"=>nodes_visited(result),"next_direction"=>next_direction[],
        "next_combination"=>next_combination[],"stop"=>result isa Exhausted ? "none" : string(result.where_it_stopped.reason))
    Dict{String,Any}("events"=>events,"proof"=>proof,"evaluations"=>nodes_visited(result),
        "done"=>next_direction[]==256 && next_combination[]=="1")
end

"""
    _closure_compute(packet; context=ClosureWorkContext(), stop_requested=()->false,
        seconds=60, evaluations=128)

Pure, transportable mathematical work: no SQLite access or shared writer state.
One exclusive slot owns `context`; never use a thread ID to select mutable scratch.
Switching returns at most 256 complete candidate events and at most the frozen
`switching_directions` complete directions, amortizing the complete constraint
system across them. Candidate budgets can pause within a direction. V5
amortizes setup over the frozen `extension_cosets` bound. It stops only between
complete eligible cosets, so the final coset may overrun its remaining budget.
Only kernel setup is discarded on interruption; all returned events are complete.
"""
function _closure_compute(packet;context=ClosureWorkContext(),stop_requested=()->false,seconds=60.0,evaluations=128)
    seconds>=0 && (isfinite(seconds) || seconds==Inf) && evaluations>=0 || throw(ArgumentError("invalid compute budgets"))
    trylock(context.guard) || error("closure compute context is already in use by another task")
    started=time_ns();start_thread=Threads.threadid()
    elapsed()=Float64(time_ns()-started)/1e9
    stopped()=stop_requested() || elapsed()>=seconds
    try
        F=_closure_compute_parent(packet)
        work=if stopped()
            Dict{String,Any}("noop"=>true,"evaluations"=>0,"done"=>false,"proof"=>Dict("stop"=>"time_or_external"))
        elseif packet["kind"]=="prepare_v5"
            _closure_compute_prepare(packet,F,context)
        elseif packet["kind"]=="v5"
            _closure_compute_v5(packet,F,context,stopped)
        elseif packet["kind"]=="switching"
            _closure_compute_switching(packet,F;seconds=max(0.0,seconds-elapsed()),evaluations,stop_requested=stopped)
        else
            error("unknown closure compute kind")
        end
        Dict{String,Any}("schema"=>CLOSURE_RESULT_SCHEMA,"packet_sha256"=>packet["packet_sha256"],
            "packet"=>packet,"kind"=>packet["kind"],"job_id"=>packet["job_id"],"work"=>work,
            "worker"=>Dict("host"=>Base.gethostname(),"pid"=>getpid(),"thread_id"=>start_thread,
                "finish_thread_id"=>Threads.threadid(),"elapsed_seconds"=>elapsed(),"task_id"=>string(objectid(current_task()))))
    finally
        unlock(context.guard)
    end
end

function _closure_check_result_properties(p)
    lut=hex2bytes(p["lut_hex"])
    length(lut)==256 && DiscoveryEvidence.lut_id(lut)==p["lut_sha256"] || error("worker candidate digest mismatch")
    p["quadratic"]==(p["algebraic_degree"]==2) || error("worker candidate degree fields disagree")
    p["apn"]==(p["differential_uniformity"]==2) || error("worker candidate APN fields disagree")
    true
end

const _CLOSURE_COSET_INTEGER_FIELDS=("candidate_spaces","completion_spaces","coset_representative",
    "du_reject","first_x","linear_system_candidates","next_x","total_x")

"""Encode the fixed complete-coset proof exactly as the generic sorted TOML writer.

The common schema contains only native integers, Booleans, five integer forms
and one fixed ASCII string. Unknown fields, types and variants retain the generic
encoder, including empty exhaustion markers. This changes no evidence bytes or
validation and keeps encoding on the sole writer.
"""
function _closure_coset_evidence_text(proof)
    fallback()=_closure_text(proof)
    proof isa AbstractDict && length(proof)==12 || return fallback()
    all(key->get(proof,key,nothing) isa Int,_CLOSURE_COSET_INTEGER_FIELDS) || return fallback()
    get(proof,"capped",nothing) isa Bool && get(proof,"heuristic_pruning",nothing)===false || return fallback()
    order=get(proof,"coset_order",nothing)
    order isa String && order=="increasing nonzero quotient integer with exact bent count" || return fallback()
    forms=get(proof,"V5_forms",nothing)
    forms isa Vector && length(forms)==5 && all(x->x isa Int,forms) || return fallback()
    sprint(;sizehint=512) do io
        print(io,"V5_forms = [",forms[1]::Int,", ",forms[2]::Int,", ",forms[3]::Int,", ",forms[4]::Int,", ",forms[5]::Int,
            "]\ncandidate_spaces = ",proof["candidate_spaces"]::Int,"\ncapped = ",proof["capped"]::Bool,
            "\ncompletion_spaces = ",proof["completion_spaces"]::Int,
            "\ncoset_order = \"increasing nonzero quotient integer with exact bent count\"\ncoset_representative = ",proof["coset_representative"]::Int,
            "\ndu_reject = ",proof["du_reject"]::Int,"\nfirst_x = ",proof["first_x"]::Int,
            "\nheuristic_pruning = false\nlinear_system_candidates = ",proof["linear_system_candidates"]::Int,
            "\nnext_x = ",proof["next_x"]::Int,"\ntotal_x = ",proof["total_x"]::Int,'\n')
    end
end

"""Apply one result on the sole coordinator, bound to the current persisted cursor.

The entire returned chunk is atomic. Failed or lost remote tasks leave its input
cursor intact and can be retried; completed/stale results cannot advance coverage.
Fresh APN/degree/signature checks run in the frozen compute implementation, while
this coordinator rechecks transport identities and cursor/event consistency.
"""
function _closure_apply!(s,job,result)
    result["schema"]==CLOSURE_RESULT_SCHEMA || error("unsupported closure result")
    _closure_transaction(s) do
        current=only(_closure_rows(s.db,"SELECT * FROM jobs WHERE id=?",(job["id"],)))
        current["status"] in ("pending","paused","running") || error("result targets a completed or blocked job")
        expected=_closure_work_packet(s,current)
        result["job_id"]==current["id"] && result["kind"]==current["kind"] || error("closure result job mismatch")
        result["packet_sha256"]==expected["packet_sha256"] &&
            _closure_packet_digest(result["packet"])==expected["packet_sha256"] || error("stale or mismatched closure result cursor")
        work=result["work"];kind=current["kind"]
        if get(work,"noop",false)
            _closure_finish!(s,current,work["proof"])
        elseif kind=="prepare_v5"
            spaces=work["spaces"];proof=work["proof"]
            length(spaces)==proof["five_spaces"] && proof["all_maximizers"]===true || error("incomplete five-space preparation result")
            for V in spaces
                length(V)==5 || error("invalid five-space basis")
                payload=Dict("forms"=>Int.(V),"need"=>expected["target_b6"]-work["max_b5"],"b5"=>work["max_b5"])
                key=string(current["parent_id"])*":v5:"*join(V,",")
                _closure_add_job!(s,current["parent_id"],"v5",key,payload)
            end
            work["done"]===true || error("partial five-space preparation cannot be committed")
            _closure_finish!(s,current,proof;done=true)
        elseif kind=="v5"
            proof=work["proof"];first_x=Int(current["direction"])
            limit=Int(get(expected,"extension_cosets",1));processed=Int(work["processed_cosets"])
            proof["first_x"]==first_x && 0<=processed<=limit &&
                proof["next_x"]==first_x+processed || error("extension result cursor mismatch")
            proof["V5_forms"]==expected["payload"]["forms"] && proof["heuristic_pruning"]===false || error("extension result scientific scope mismatch")
            chunks=work["chunks"];flat_records=Dict{String,Any}[]
            work["commit_chunk"]==!isempty(chunks) || error("extension commit flag disagrees with coset ledger")
            length(chunks)==processed ||
                (processed==0 && proof["total_x"]==0 && length(chunks)==1) || error("extension result lost per-coset coverage")
            cursor=first_x;count_cosets=0;count_candidates=0;count_du=0;count_completions=0;capped=false
            for chunk in chunks
                cp=chunk["proof"];step=Int(chunk["processed_cosets"])
                cp["first_x"]==cursor && cp["next_x"]==cursor+step && cp["total_x"]==proof["total_x"] || error("noncontiguous extension coset ledger")
                cp["V5_forms"]==expected["payload"]["forms"] && cp["heuristic_pruning"]===false || error("extension coset scientific scope mismatch")
                step==1 || (step==0 && cp["total_x"]==0 && cursor==1 && isempty(chunk["records"])) || error("invalid extension coset coverage step")
                0<=cp["du_reject"]<=step && cp["linear_system_candidates"]>=0 && cp["completion_spaces"]>=0 || error("invalid extension coset counters")
                length(chunk["records"])==cp["candidate_spaces"] || error("extension coset lost candidate records")
                if step==1
                    1<=cursor<=cp["total_x"] && 0<cp["coset_representative"]<(1<<28) || error("invalid eligible extension coset")
                end
                for record in chunk["records"]
                    p=record["properties"];_closure_check_result_properties(p)
                    p["apn"] && p["quadratic"] || error("worker returned an invalid APN completion")
                    record["cursor"]==string(cursor) || error("extension record cursor mismatch")
                    witness=record["witness"]
                    witness["eligible_coset_index"]==cursor && witness["coset_representative"]==cp["coset_representative"] &&
                        witness["V5_forms"]==cp["V5_forms"] && witness["need"]==expected["payload"]["need"] &&
                        witness["target_b6"]==expected["target_b6"] && length(witness["output_forms"])==8 || error("extension construction witness mismatch")
                    _closure_record_candidate!(s,current,p,record["cursor"],witness)
                end
                append!(flat_records,chunk["records"])
                cursor+=step;count_cosets+=step;count_candidates+=cp["linear_system_candidates"]
                count_du+=cp["du_reject"];count_completions+=cp["completion_spaces"];capped|=cp["capped"]
            end
            cursor==proof["next_x"] && count_cosets==processed && flat_records==work["records"] || error("extension aggregate lost coset paths")
            length(flat_records)==proof["candidate_spaces"] && count_candidates==proof["linear_system_candidates"] &&
                count_du==proof["du_reject"] && count_completions==proof["completion_spaces"] && capped==proof["capped"] || error("extension aggregate counters disagree with cosets")
            work["evaluations"]==count_candidates+length(flat_records) || error("extension evaluation count mismatch")
            if haskey(proof,"distinct_candidate_spaces")
                proof["distinct_candidate_spaces"]==length(unique(r["properties"]["lut_sha256"] for r in flat_records)) || error("extension distinct output count mismatch")
            end
            _closure_insert_chunks!(s,current["id"],chunks;encoded=get(work,"ledger",nothing))
            _closure_exec(s.db,"UPDATE jobs SET direction=? WHERE id=?",(cursor,current["id"]))
            done=cursor>proof["total_x"] && !capped
            work["done"]==done && work["blocked"]==capped || error("extension completion flag mismatch")
            _closure_finish!(s,current,proof;done,blocked=capped)
        elseif kind=="switching"
            direction=Int(current["direction"]);combination=parse(BigInt,current["combination"])
            count_candidates=0;completed_directions=0
            for event in work["events"]
                event["direction"]==direction || error("switching result event cursor mismatch")
                if event["event"]=="kernel"
                    evidence=event["evidence"]
                    evidence["complete_constraints"]===true && length(evidence["basis_hex"])==event["dimension"] || error("incomplete switching kernel evidence")
                    previous=_closure_rows(s.db,"SELECT evidence FROM kernels WHERE job_id=? AND direction=?",(current["id"],direction))
                    isempty(previous) || TOML.parse(only(previous)["evidence"])==evidence || error("resumed switching kernel changed")
                    _closure_exec(s.db,"INSERT OR IGNORE INTO kernels VALUES(?,?,?,?)",(current["id"],direction,event["dimension"],_closure_text(evidence)))
                elseif event["event"]=="candidate_complete"
                    parse(BigInt,event["combination"])==combination && event["next_direction"]==direction &&
                        parse(BigInt,event["next_combination"])==combination+1 || error("switching candidate sequence mismatch")
                    p=event["properties"];_closure_check_result_properties(p)
                    event["cursor"]==string(direction)*":"*string(combination) || error("switching path cursor mismatch")
                    child=_closure_record_candidate!(s,current,p,event["cursor"],event["witness"])
                    _closure_exec(s.db,"INSERT INTO evaluations VALUES(?,?,?,?,?)",(current["id"],direction,string(combination),child,Int(p["apn"])))
                    combination+=1;count_candidates+=1
                elseif event["event"]=="direction_complete"
                    event["next_direction"]==direction+1 && event["next_combination"]=="1" || error("switching direction transition mismatch")
                    kernel=only(_closure_rows(s.db,"SELECT dimension FROM kernels WHERE job_id=? AND direction=?",(current["id"],direction)))
                    total=(big(1)<<Int(kernel["dimension"]))-1
                    combination==total+1 && _closure_count(s.db,"SELECT COUNT(*) n FROM evaluations WHERE job_id=? AND direction=?",(current["id"],direction))==total || error("switching direction completion lacks full candidate coverage")
                    direction+=1;combination=big(1);completed_directions+=1
                else
                    error("unknown switching checkpoint event")
                end
            end
            proof=work["proof"]
            direction_limit=Int(get(expected,"switching_directions",1))
            count_candidates==work["evaluations"]==proof["evaluations"] && count_candidates<=256 && completed_directions<=direction_limit || error("switching result exceeded its packet scope")
            proof["next_direction"]==direction && parse(BigInt,proof["next_combination"])==combination || error("switching result final cursor mismatch")
            done=direction==256 && combination==1
            work["done"]==done || error("switching exhaustion flag mismatch")
            _closure_exec(s.db,"UPDATE jobs SET direction=?,combination=? WHERE id=?",(direction,string(combination),current["id"]))
            _closure_finish!(s,current,proof;done)
        else
            error("unknown construction result kind")
        end
        Int(work["evaluations"])
    end
end

function _closure_prepare!(s,job,G)
    packet=_closure_work_packet(s,job)
    result=_closure_compute(packet;context=ClosureWorkContext(G,nothing),seconds=Inf,evaluations=0)
    _closure_apply!(s,job,result)
end

function _closure_v5!(s,job,G,work,stop_requested)
    packet=_closure_work_packet(s,job)
    result=_closure_compute(packet;context=ClosureWorkContext(G,work),seconds=Inf,stop_requested)
    _closure_apply!(s,job,result)
end

function _closure_switching!(s,job;seconds,evaluations,stop_requested)
    packet=_closure_work_packet(s,job)
    result=_closure_compute(packet;seconds,evaluations,stop_requested)
    _closure_apply!(s,job,result)
end

function _closure_deduplicate!(s,job;seconds,nodes,stop_requested)
    id=TOML.parse(job["payload"])["candidate_id"]
    candidate=only(_closure_rows(s.db,"SELECT * FROM candidates WHERE id=?",(id,)))
    !ismissing(candidate["class_id"]) && return (_closure_finish!(s,job,Dict("already_admitted"=>true);done=true);0)
    p=properties(hex2bytes(candidate["lut_hex"]))
    p["apn"] && p["quadratic"] && p["sigma_hash"]==candidate["sigma"] || error("invalid pending quadratic candidate")
    unresolved=false
    for target in _closure_rows(s.db,"SELECT p.id,c.lut_hex FROM parents p JOIN candidates c ON c.id=p.candidate_id WHERE p.sigma=? ORDER BY p.id",(candidate["sigma"],))
        stop_requested() && return (_closure_finish!(s,job,Dict("stop"=>"session_budget"));0)
        saved=_closure_rows(s.db,"SELECT * FROM comparisons WHERE candidate_id=? AND target_parent=? ORDER BY id DESC LIMIT 1",(id,target["id"]))
        if !isempty(saved) && first(saved)["status"]=="inequivalent_by_exhaustive_solver"
            continue
        end
        proof=compare(hex2bytes(candidate["lut_hex"]),hex2bytes(target["lut_hex"]);relation=:ea,timeout_seconds=seconds,max_nodes=nodes)
        _closure_transaction(s) do
            _closure_exec(s.db,"INSERT INTO comparisons(candidate_id,target_parent,status,evidence,session_id) VALUES(?,?,?,?,?)",
                (id,target["id"],proof["status"],_closure_text(proof),s.session))
            if proof["status"]=="equivalent_with_verified_witness"
                verify_comparison(proof) || error("EA witness failed full replay")
                _closure_exec(s.db,"UPDATE candidates SET class_id=?,state='equivalent' WHERE id=?",(target["id"],id))
                _closure_finish!(s,job,Dict("verified_equivalent_parent"=>target["id"]);done=true)
            end
        end
        proof["status"]=="equivalent_with_verified_witness" && return 0
        proof["status"]=="inconclusive_budget" && (unresolved=true)
        _closure_report!(s)
    end
    _closure_transaction(s) do
        if unresolved
            _closure_exec(s.db,"UPDATE candidates SET state='unresolved_equivalence' WHERE id=?",(id,))
            _closure_finish!(s,job,Dict("unresolved_equivalence"=>true))
        else
            parent=_closure_add_parent!(s,id,candidate["sigma"])
            _closure_finish!(s,job,Dict("promoted_parent"=>parent,"descendant_profile_filter"=>"none");done=true)
        end
    end
    0
end

"""
    closure_run!(directory; duration_seconds=60, max_evaluations=1000,
        max_jobs=16, max_parents=0, equivalence_seconds=2, equivalence_nodes=100000)

Run/resume the immutable recursive frontier with explicit finite session limits.
`max_parents=0` leaves the parent-admission count uncapped. Every admitted parent
gets both methods. Stopping pauses coverage; it never certifies exhaustion.

Extension completion is atomic per eligible six-space coset. Its setup and one
coset may exceed the remaining wall/evaluation budget; no incomplete coset is
marked done. Switching checkpoints each candidate and each direction. This first
controller runs one mathematical worker and fairly interleaves both methods.
"""
function closure_run!(directory;duration_seconds=60.0,max_evaluations=1000,max_jobs=16,max_parents=0,
    equivalence_seconds=2.0,equivalence_nodes=100_000)
    isfinite(duration_seconds) && duration_seconds>0 || throw(ArgumentError("positive finite duration required"))
    max_evaluations>0 && max_jobs>0 && max_parents>=0 && equivalence_seconds>=0 && isfinite(equivalence_seconds) && equivalence_nodes>=0 || throw(ArgumentError("invalid closure session limits"))
    s=_closure_open(directory);started=time_ns();processed=0;evaluated=0;reason="paused_budget"
    elapsed()=Float64(time_ns()-started)/1e9
    remaining()=max(0.0,duration_seconds-elapsed())
    external=_closure_stop_poller(joinpath(s.directory,"STOP"))
    stopped()=external() || remaining()<=0
    G=nothing;work=nothing
    try
        rm(joinpath(s.directory,"STOP");force=true)
        budgets=Dict("duration_seconds"=>duration_seconds,"max_evaluations"=>max_evaluations,"max_jobs"=>max_jobs,
            "max_parents"=>max_parents,"equivalence_seconds"=>equivalence_seconds,"equivalence_nodes"=>equivalence_nodes)
        _closure_exec(s.db,"INSERT INTO sessions(started,heartbeat,pid,host,state,budgets) VALUES(?,?,?,?,?,?)",
            (_closure_now(),_closure_now(),getpid(),get(ENV,"HOSTNAME","localhost"),"running",_closure_text(budgets)))
        s.session=Int(only(_closure_rows(s.db,"SELECT last_insert_rowid() id"))["id"])
        _closure_report!(s;force=true)
        while !stopped() && processed<max_jobs && evaluated<max_evaluations
            if max_parents>0 && _closure_count(s.db,"SELECT COUNT(*) n FROM parents")>=max_parents
                reason="paused_parent_limit";break
            end
            job=_closure_claim!(s)
            if job===nothing
                snapshot=closure_snapshot(s.directory)
                reason=snapshot["closure_complete"] ? "exhausted" : "paused_unresolved"
                break
            end
            try
                n=if job["kind"]=="deduplicate"
                    _closure_deduplicate!(s,job;seconds=min(equivalence_seconds,remaining()),nodes=equivalence_nodes,stop_requested=stopped)
                elseif job["kind"]=="switching"
                    _closure_switching!(s,job;seconds=remaining(),evaluations=max_evaluations-evaluated,stop_requested=stopped)
                else
                    if G===nothing
                        G=Fourier.geometry(8);work=Fourier.V5Work(23)
                    end
                    job["kind"]=="prepare_v5" ? _closure_prepare!(s,job,G) : _closure_v5!(s,job,G,work,stopped)
                end
                evaluated+=n;processed+=1
                _closure_exec(s.db,"UPDATE sessions SET jobs=?,evaluations=? WHERE id=?",(processed,evaluated,s.session))
                _closure_report!(s)
            catch err
                interrupted=err isa InterruptException
                _closure_exec(s.db,"UPDATE jobs SET status=?,error=? WHERE id=?",(interrupted ? "paused" : "failed",sprint(showerror,err),job["id"]))
                reason=interrupted ? "interrupted" : "failed";rethrow()
            end
        end
        external() && (reason="paused_external")
    catch err
        reason=err isa InterruptException ? "interrupted" : "failed";rethrow()
    finally
        try
            if s.session>0
                _closure_exec(s.db,"UPDATE sessions SET state=?,finished=?,heartbeat=?,jobs=?,evaluations=? WHERE id=?",
                    (reason,_closure_now(),_closure_now(),processed,evaluated,s.session))
                _closure_report!(s;force=true)
            end
        finally
            _closure_close(s)
        end
    end
    closure_snapshot(directory)
end
