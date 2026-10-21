"""Bounded native V5 application experiment; no SQLite operations in this module.

This is an application/storage comparison, not a recursive search backend. The
production VBFSearch packet/coset validation is reused. Evidence stays structured
and a copy-on-write state swap commits each fully staged packet atomically.
"""
module NativeV5Application
using VBFSearch, SHA, Serialization
const FP=VBFSearch

struct Candidate
    id::String
    lut::String
    sigma::String
    apn::Bool
    degree::Int
    properties::FP._ClosureFrozenProofMap
    class_id::Union{Nothing,Int}
    state::String
end
struct Parent
    id::Int
    candidate_id::String
end
struct Job
    id::Int
    parent_id::Int
    kind::String
    key::String
    payload::FP._ClosureFrozenProofMap
    status::String
    direction::Int
    combination::String
    result::Union{String,FP._ClosureFrozenProofMap}
end
struct Path
    parent_id::Int
    job_id::Int
    method::String
    cursor::String
    child_id::String
    witness::FP._ClosureFrozenProofMap
end
struct State
    candidates::Dict{String,Candidate}
    parents::Dict{Int,Parent}
    jobs::Dict{Int,Job}
    job_keys::Dict{String,Int}
    paths::Vector{Path}
    path_keys::Set{Tuple{Int,String,String}}
    coverage::Dict{Int,Vector{FP._ClosureCosetProof}}
    next_job::Int
end
mutable struct Store
    state::State
    scientific::Dict{String,Any}
end

fields(p::FP._ClosurePreparedCandidate)=p.fields
fields(w::FP._ClosurePreparedWitness)=w.fields
fields(p)=FP._closure_freeze_proof(p)
text(p::FP._ClosureFrozenProofMap)=FP._closure_text(FP._closure_thaw_proof(p))
text(p::String)=p

function initialize(input)
    candidates=Dict{String,Candidate}();parents=Dict{Int,Parent}()
    for row in input["parents"]
        id=Int(row["id"]);p=row["properties"];cid=String(row["candidate_id"])
        p["lut_sha256"]==cid && p["lut_hex"]==row["lut_hex"] && p["sigma_hash"]==row["sigma"] || error("native reference identity differs")
        haskey(candidates,cid) && error("duplicate native reference")
        candidates[cid]=Candidate(cid,row["lut_hex"],row["sigma"],p["apn"],Int(p["algebraic_degree"]),fields(p),id,"admitted")
        parents[id]=Parent(id,cid)
    end
    jobs=Dict{Int,Job}();job_keys=Dict{String,Int}()
    for row in input["jobs"]
        id=Int(row["id"]);key=String(row["job_key"])
        haskey(job_keys,key) && error("duplicate native job key")
        jobs[id]=Job(id,Int(row["parent_id"]),row["kind"],key,fields(row["payload"]),"pending",1,"1","")
        job_keys[key]=id
    end
    Store(State(candidates,parents,jobs,job_keys,Path[],Set{Tuple{Int,String,String}}(),
        Dict{Int,Vector{FP._ClosureCosetProof}}(),maximum(keys(jobs))+1),copy(input["scientific"]))
end

"""The production work-descriptor schema assembled from native committed rows."""
function packet(store,job)
    s=store.state;parent=s.parents[job.parent_id];candidate=s.candidates[parent.candidate_id]
    packet=Dict{String,Any}("schema"=>FP.CLOSURE_WORK_SCHEMA,"job_id"=>job.id,"parent_id"=>job.parent_id,
        "job_key"=>job.key,"kind"=>job.kind,"direction"=>job.direction,"combination"=>job.combination,
        "payload"=>FP._closure_thaw_proof(job.payload),"target_b6"=>Int(store.scientific["target_b6"]),
        "max_kernel"=>23,"extension_cosets"=>Int(store.scientific["extension_cosets"]),
        "switching_directions"=>Int(store.scientific["switching_directions"]),
        "parent"=>Dict("lut_sha256"=>candidate.id,"lut_hex"=>candidate.lut,"sigma"=>candidate.sigma))
    packet["packet_sha256"]=FP._closure_packet_digest(packet)
    packet
end

"""Stage validation and all allocation before one state-pointer commit.

No existing dictionary, vector, candidate or job object is mutated. Consequently
late validation failures and allocation failures before the swap retain the
entire previously committed state. Evidence is stored as frozen native fields,
not SQL-oriented property/witness strings or packed coverage blobs.
"""
function apply!(store,job_id,result;fail_before_commit=false)
    s=store.state;job=s.jobs[job_id]
    job.status in ("pending","paused","running") || error("result targets a completed or blocked job")
    job.kind=="v5" && result["schema"]==FP.CLOSURE_RESULT_SCHEMA || error("unsupported native experiment result")
    expected=packet(store,job)
    result["job_id"]==job.id && result["kind"]==job.kind || error("closure result job mismatch")
    result["packet_sha256"]==expected["packet_sha256"] && FP._closure_packet_digest(result["packet"])==expected["packet_sha256"] || error("stale or mismatched closure result cursor")
    work=result["work"];get(work,"noop",false) && error("bounded experiment requires completed construction work")
    proof=work["proof"];first_x=job.direction;processed=Int(work["processed_cosets"])
    proof["first_x"]==first_x && 0<=processed<=expected["extension_cosets"] && proof["next_x"]==first_x+processed || error("extension result cursor mismatch")
    proof["V5_forms"]==expected["payload"]["forms"] && proof["heuristic_pruning"]===false || error("extension result scientific scope mismatch")
    chunks=work["chunks"];records=FP._closure_v5_record_buffer(chunks)
    work["commit_chunk"]==!isempty(chunks) || error("extension commit flag disagrees with coset ledger")
    length(chunks)==processed || (processed==0 && proof["total_x"]==0 && length(chunks)==1) || error("extension result lost per-coset coverage")
    cursor,cosets,candidates,du,completions,capped=FP._closure_apply_v5_cosets!(nothing,nothing,expected,proof,chunks,first_x,records)
    cursor==proof["next_x"] && cosets==processed && records==work["records"] || error("extension aggregate lost coset paths")
    length(records)==proof["candidate_spaces"] && candidates==proof["linear_system_candidates"] && du==proof["du_reject"] &&
        completions==proof["completion_spaces"] && capped==proof["capped"] || error("extension aggregate counters disagree with cosets")
    work["evaluations"]==candidates+length(records) || error("extension evaluation count mismatch")
    if haskey(proof,"distinct_candidate_spaces")
        proof["distinct_candidate_spaces"]==length(unique(r["properties"]["lut_sha256"] for r in records)) || error("extension distinct output count mismatch")
    end
    if !isempty(chunks)
        # Match the production envelope guard, but retain direct proof objects.
        encoded=get(work,"ledger",nothing)
        row=encoded isa NamedTuple ? encoded : FP._closure_ledger_row(job.id,chunks)
        row.job_id==job.id && row.first_x==first(chunks)["proof"]["first_x"] && row.next_x==last(chunks)["proof"]["next_x"] &&
            row.total_x==first(chunks)["proof"]["total_x"] && row.capped==maximum(Int(c["proof"]["capped"]) for c in chunks) || error("encoded coverage envelope differs from validated cosets")
    end
    done=cursor>proof["total_x"] && !capped
    work["done"]==done && work["blocked"]==capped || error("extension completion flag mismatch")
    new_candidates=copy(s.candidates);new_jobs=copy(s.jobs);new_keys=copy(s.job_keys)
    new_paths=copy(s.paths);new_path_keys=copy(s.path_keys);new_coverage=copy(s.coverage);next_job=s.next_job
    for record in records
        p=record["properties"];id=String(p["lut_sha256"]);lut=String(p["lut_hex"])
        old=get(new_candidates,id,nothing)
        if old===nothing
            new_candidates[id]=Candidate(id,lut,p["sigma_hash"],p["apn"],Int(p["algebraic_degree"]),fields(p),nothing,"awaiting_equivalence")
        else
            old.lut==lut || error("LUT digest collision")
            old.class_id===nothing && (new_candidates[id]=Candidate(old.id,old.lut,old.sigma,old.apn,old.degree,old.properties,nothing,"awaiting_equivalence"))
        end
        if old===nothing || old.class_id===nothing
            key="deduplicate:$id"
            if !haskey(new_keys,key)
                new_jobs[next_job]=Job(next_job,job.parent_id,"deduplicate",key,fields(Dict("candidate_id"=>id)),"pending",1,"1","")
                new_keys[key]=next_job;next_job+=1
            end
        end
        path_key=(job.id,String(record["cursor"]),id)
        if !(path_key in new_path_keys)
            push!(new_paths,Path(job.parent_id,job.id,job.kind,path_key[2],id,fields(record["witness"])))
            push!(new_path_keys,path_key)
        end
    end
    if !isempty(chunks)
        haskey(new_coverage,job.id) && error("bounded replay expects one complete packet per job")
        new_coverage[job.id]=FP._ClosureCosetProof[c["proof"] for c in chunks]
    end
    new_jobs[job.id]=Job(job.id,job.parent_id,job.kind,job.key,job.payload,capped ? "blocked" : done ? "done" : "paused",cursor,job.combination,fields(proof))
    committed=State(new_candidates,s.parents,new_jobs,new_keys,new_paths,new_path_keys,new_coverage,next_job)
    fail_before_commit && error("injected failure after complete packet staging")
    store.state=committed
    Int(work["evaluations"])
end

function fingerprint(rows)
    h=SHA.SHA2_256_CTX();n=0
    for row in rows
        for v in row
            b=ismissing(v) ? UInt8[] : v isa Vector{UInt8} ? v : Vector{UInt8}(codeunits(string(v)))
            SHA.update!(h,codeunits(string(length(b))*":"));SHA.update!(h,b)
        end
        n+=1
    end
    Dict("rows"=>n,"sha256"=>bytes2hex(SHA.digest!(h)))
end

"""Canonical SQL-compatible fingerprints, outside native setup/apply/save timers."""
function science(store)
    s=store.state
    candidates=sort!(collect(values(s.candidates));by=c->c.id)
    jobs=sort!(collect(values(s.jobs));by=j->j.id)
    paths=sort(copy(s.paths);by=p->(p.parent_id,p.job_id,p.cursor,p.child_id))
    rows=Any[]
    for id in sort!(collect(keys(s.coverage)))
        chunks=[Dict("proof"=>p) for p in s.coverage[id]]
        row=FP._closure_ledger_row(id,chunks)
        push!(rows,(id,row.first_x,row.next_x,row.total_x,row.capped,row.evidence))
    end
    Dict("candidates"=>fingerprint((c.id,c.lut,c.sigma,Int(c.apn),c.degree,text(c.properties),c.class_id===nothing ? missing : c.class_id,c.state) for c in candidates),
        "jobs"=>fingerprint((j.id,j.parent_id,j.kind,j.key,text(j.payload),j.status,j.direction,j.combination,text(j.result)) for j in jobs),
        "paths"=>fingerprint((p.parent_id,p.job_id,p.method,p.cursor,p.child_id,text(p.witness)) for p in paths),
        "coverage"=>fingerprint(rows))
end
path_order(store)=fingerprint((p.parent_id,p.job_id,p.method,p.cursor,p.child_id,text(p.witness)) for p in store.state.paths)

function save(store,path,binding)
    open(path,"w") do io
        serialize(io,(;binding,state=store.state,scientific=store.scientific))
        flush(io);ccall(:fsync,Cint,(Cint,),fd(io))==0 || error("native V5 fsync failed")
    end
    directory=ccall(:open,Cint,(Cstring,Cint),dirname(path),0x10000)
    directory>=0 || error("native V5 directory open failed")
    try
        ccall(:fsync,Cint,(Cint,),directory)==0 || error("native V5 directory fsync failed")
    finally
        ccall(:close,Cint,(Cint,),directory)
    end
    nothing
end
function restore(path,binding)
    data=deserialize(path)
    data.binding==binding || error("native V5 save binding differs")
    Store(data.state,data.scientific)
end
end
