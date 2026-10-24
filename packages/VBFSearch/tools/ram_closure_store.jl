"""Bounded RAM candidate identity and verified EA-class admission.

Exact LUTs and EA classes are separate. Digest shards publish compact candidate
records; signature shards own class membership and stale-snapshot versions.
Expensive comparison runs outside those locks through the existing VBFSearch
worker. Full properties are recomputed through caller-owned bounded caches,
never retained once per historical LUT. This module performs no SQLite calls.
Construction paths, cursor coverage and their compressed evidence belong to the
runner; this store retains only its bounded comparison evidence.
"""
module RAMClosureStore
using VBFSearch,Dates
using Base.Threads
const FP=VBFSearch
const Digest=NTuple{32,UInt8}
const ZERO_DIGEST=ntuple(_->UInt8(0),32)
const STATES=("observed","awaiting_equivalence","admitted","equivalent","unresolved_equivalence")
export Store,StoreFull,initialize_roots!,observe_candidate!,candidate,class_record,
    candidate_rows,class_rows,comparison_rows,stats,
    classify_if_empty!,prepare_admission,compute_admission,commit_admission!,classify_candidate!,
    compact_record_properties,COMPACT_RECORD_PROPERTIES_FORMAT

const COMPACT_RECORD_PROPERTIES_FORMAT="vbfsearch-ram-candidate-core-v1"

"""Snapshot validated candidate fields needed by a persistent RAM evidence frame.

The caller must first perform the existing native construction/coverage and VBF
mathematical validation. This helper checks the copied live transport fields; it
does not freshly certify APN status, degree or the equivalence signature. Actual
LUT bytes and differential uniformity are retained, including for candidates not
yet observed in the store. A nonempty failure witness is copied without sharing
mutable nested values. Construction witnesses, ledgers and packet proofs remain
in their original frame fields and must never be replaced by this snapshot.

Ortho-derivatives, DDT/Walsh spectra, ANF and prepared SQL encodings are derived
from the retained LUT and can be recomputed through bounded worker caches. The
runner labels frames with `COMPACT_RECORD_PROPERTIES_FORMAT`; this ordinary Dict
contains no prepared SQL text or historical full property dictionary.
"""
function compact_record_properties(p::AbstractDict)
    FP._closure_check_result_properties(p)
    apn=p["apn"];quadratic=p["quadratic"]
    apn isa Bool && quadratic isa Bool || error("candidate flags must be Boolean")
    degree=p["algebraic_degree"];uniformity=p["differential_uniformity"]
    degree isa Integer && !(degree isa Bool) && 0<=degree<=8 || error("invalid eight-bit algebraic degree")
    uniformity isa Integer && !(uniformity isa Bool) && 2<=uniformity<=256 || error("invalid eight-bit differential uniformity")
    result=Dict{String,Any}("lut_sha256"=>String(p["lut_sha256"]),"lut_hex"=>String(p["lut_hex"]),
        "apn"=>apn,"quadratic"=>quadratic,
        "algebraic_degree"=>FP._closure_thaw_proof(FP._closure_freeze_proof(degree)),
        "differential_uniformity"=>FP._closure_thaw_proof(FP._closure_freeze_proof(uniformity)))
    sigma=get(p,"sigma_hash",nothing)
    if sigma!==nothing
        sigma isa AbstractString && length(hex2bytes(sigma))==32 || error("invalid candidate signature digest")
        result["sigma_hash"]=String(sigma)
    end
    failure=get(p,"non_apn_witness",nothing)
    if failure!==nothing
        failure isa AbstractDict || error("candidate failure witness must be a dictionary")
        isempty(failure) || (result["non_apn_witness"]=FP._closure_thaw_proof(FP._closure_freeze_proof(failure)))
    end
    # Dispatch on the ordinary owned dictionary, even when the input was a
    # constructor-bound native record whose original check was cached.
    FP._closure_check_result_properties(result)
    result
end

"""A bounded-store rejection; retained input evidence remains inspectable."""
struct StoreFull <: Exception
    kind::Symbol
    capacity::Int
    required::Int
    retained::Any
end
Base.showerror(io::IO,e::StoreFull)=print(io,"RAM ",e.kind," capacity exceeded: ",e.required," > ",e.capacity)

"""Class membership and reusable solver-bound negative prefixes for one signature."""
mutable struct SignatureBucket
    parents::Vector{Int}
    version::UInt64
    negatives::Dict{Tuple{Int,Int},String}
end
SignatureBucket()=SignatureBucket(Int[],UInt64(0),Dict{Tuple{Int,Int},String}())

"""Fixed candidate/class columns and bounded comparison references.

Only compact values persist per candidate. Hash heads and next links use O(N)
space even if all digests map to one shard; there is no N-sized table per shard.
Mutable class/state columns are guarded by their signature owner. Snapshots and
exports must run after workers join. Caller-owned properties are never retained.
"""
struct Store
    luts::Matrix{UInt8}
    ids::Vector{Digest}
    sigmas::Vector{Digest}
    degrees::Vector{UInt8}
    apn::Vector{UInt8}
    class_ids::Vector{Int}
    states::Vector{UInt8}
    next::Vector{Int}
    heads::Vector{Int}
    index_locks::Vector{ReentrantLock}
    used::Atomic{Int}
    class_candidates::Vector{Int}
    class_origins::Vector{UInt8}
    class_sources::Vector{String}
    class_times::Vector{Float64}
    classes_used::Atomic{Int}
    buckets::Vector{Dict{Digest,SignatureBucket}}
    signature_locks::Vector{ReentrantLock}
    comparisons::Vector{Any}
    comparison_lock::ReentrantLock
    comparisons_used::Atomic{Int}
    comparison_bytes::Atomic{Int}
    comparison_byte_limit::Int
    solver_session::Any
    solver_hash::String
end

"""Reserve metadata capacity without allocating mathematical preparation per LUT."""
function Store(;candidate_capacity::Integer,class_capacity::Integer=candidate_capacity,
    comparison_capacity::Integer=100_000,comparison_bytes::Integer=256<<20,
    nshards::Integer=32,solver_session=FP._equivalence_solver_session())
    all(>=(0),(candidate_capacity,class_capacity,comparison_capacity,comparison_bytes)) ||
        throw(ArgumentError("capacities must be nonnegative"))
    nshards>0 || throw(ArgumentError("positive shard count required"))
    n=Int(candidate_capacity);m=Int(class_capacity);c=Int(comparison_capacity)
    n<=typemax(Int)÷2 || throw(ArgumentError("candidate capacity too large"))
    Store(Matrix{UInt8}(undef,256,n),Vector{Digest}(undef,n),Vector{Digest}(undef,n),
        Vector{UInt8}(undef,n),Vector{UInt8}(undef,n),zeros(Int,n),zeros(UInt8,n),zeros(Int,n),
        zeros(Int,nextpow(2,max(8,2n))),[ReentrantLock() for _ in 1:nshards],Atomic{Int}(0),
        Vector{Int}(undef,m),Vector{UInt8}(undef,m),Vector{String}(undef,m),Vector{Float64}(undef,m),
        Atomic{Int}(0),[Dict{Digest,SignatureBucket}() for _ in 1:nshards],
        [ReentrantLock() for _ in 1:nshards],Vector{Any}(undef,c),ReentrantLock(),Atomic{Int}(0),
        Atomic{Int}(0),Int(comparison_bytes),solver_session,FP.DiscoveryEvidence.solver_fingerprint(solver_session))
end

"""Stable digest bits used only for indexing; equality always checks all bytes."""
function word(d::Digest)
    value=UInt64(0)
    for i in 1:8;value=(value<<8)|UInt64(d[i]);end
    value
end
signature_shard(s,sigma)=Int(mod(word(sigma),UInt64(length(s.signature_locks))))+1

"""Claim a bounded slot, leaving its counter unchanged on exhaustion."""
function claim!(counter,capacity,kind;retained=nothing)
    while true
        old=counter[]
        old<capacity || throw(StoreFull(kind,capacity,old+1,retained))
        atomic_cas!(counter,old,old+1)==old && return old+1
    end
end

"""Check locally produced properties, or freshly verify arbitrary input claims."""
function checked_properties(p;trusted=false)
    FP._closure_check_result_properties(p)
    if !trusted
        fresh=FP.properties(hex2bytes(p["lut_hex"]))
        for key in ("lut_sha256","lut_hex","apn","algebraic_degree","quadratic")
            fresh[key]==p[key] || error("candidate properties differ from fresh VBF verification")
        end
        get(fresh,"sigma_hash",nothing)==get(p,"sigma_hash",nothing) || error("candidate signature differs")
    end
    p
end

"""Register an exact LUT after validation; return its stable slot and novelty.

`trusted=true` is the existing local-worker boundary: the runner has bound and
validated an original result whose producer performed fresh VBF checks. Default
calls repeat those checks. No supplied property object is retained in the store.
"""
function observe_candidate!(s::Store,p::AbstractDict;trusted=false)
    checked_properties(p;trusted)
    lut=hex2bytes(p["lut_hex"]);id=Digest(Tuple(hex2bytes(p["lut_sha256"])))
    degree=Int(p["algebraic_degree"]);0<=degree<=8 || error("invalid eight-bit algebraic degree")
    apn=p["apn"]::Bool
    sigma=apn && degree==2 ? Digest(Tuple(hex2bytes(p["sigma_hash"]))) : ZERO_DIGEST
    head=Int(mod(word(id),UInt64(length(s.heads))))+1
    owner=mod1(head,length(s.index_locks));guard=s.index_locks[owner]
    lock(guard)
    try
        slot=s.heads[head]
        while slot!=0
            if s.ids[slot]==id
                @inbounds for x in 1:256
                    s.luts[x,slot]==lut[x] || error("LUT digest collision")
                end
                s.sigmas[slot]==sigma && s.degrees[slot]==degree && s.apn[slot]==apn || error("candidate properties changed")
                return (slot,false)
            end
            slot=s.next[slot]
        end
        slot=claim!(s.used,length(s.ids),:candidates;retained=p)
        @inbounds for x in 1:256;s.luts[x,slot]=lut[x];end
        s.ids[slot]=id;s.sigmas[slot]=sigma;s.degrees[slot]=UInt8(degree);s.apn[slot]=UInt8(apn)
        s.class_ids[slot]=0;s.states[slot]=apn && degree==2 ? UInt8(2) : UInt8(1)
        s.next[slot]=s.heads[head];s.heads[head]=slot
        (slot,true)
    finally
        unlock(guard)
    end
end
observe_candidate!(s::Store,lut::AbstractVector)=observe_candidate!(s,FP.properties(lut);trusted=true)

"""Read immutable candidate identity after its insertion has returned."""
function candidate_identity(s::Store,slot::Integer)
    1<=slot<=s.used[] || throw(ArgumentError("unknown candidate slot"))
    (;slot=Int(slot),id=bytes2hex(collect(s.ids[slot])),lut_hex=bytes2hex(@view s.luts[:,slot]),
        sigma=s.apn[slot]==1 && s.degrees[slot]==2 ? bytes2hex(collect(s.sigmas[slot])) : nothing,
        apn=s.apn[slot]==1,degree=Int(s.degrees[slot]))
end

"""Snapshot a candidate; admission fields are read under their signature owner."""
function candidate(s::Store,slot::Integer)
    immutable=candidate_identity(s,slot);owner=signature_shard(s,s.sigmas[slot])
    lock(s.signature_locks[owner]) do
        merge(immutable,(class_id=s.class_ids[slot],state=STATES[s.states[slot]]))
    end
end

"""Recompute full properties through an optional bounded worker cache."""
candidate_properties(s::Store,slot::Integer;cache=nothing)=FP.properties(hex2bytes(candidate_identity(s,slot).lut_hex);cache)

"""Read a published immutable class representative; IDs preserve admission order."""
function class_record(s::Store,id::Integer)
    1<=id<=s.classes_used[] || throw(ArgumentError("unknown class"))
    slot=s.class_candidates[id];row=candidate_identity(s,slot)
    (;id=Int(id),candidate_slot=slot,candidate_id=row.id,lut_hex=row.lut_hex,sigma=row.sigma,
        origin=s.class_origins[id]==1 ? "root" : "discovered",source=s.class_sources[id],
        admitted_utc=string(Dates.unix2datetime(s.class_times[id]))*"Z")
end

"""Publish a class while its signature owner is held."""
function add_class!(s,slot,bucket;origin="discovered",source="construction")
    owned_source=String(source);admitted=time()
    # Complete allocations before claiming a globally visible class ID.
    sizehint!(bucket.parents,length(bucket.parents)+1)
    id=claim!(s.classes_used,length(s.class_candidates),:classes)
    s.class_candidates[id]=slot;s.class_origins[id]=origin=="root" ? UInt8(1) : UInt8(2)
    s.class_sources[id]=owned_source;s.class_times[id]=admitted
    push!(bucket.parents,id);bucket.version+=1
    s.class_ids[slot]=id;s.states[slot]=UInt8(3)
    id
end

"""Read symbol/string keyed root rows without imposing one transport type."""
field(row,key::Symbol,default=nothing)=row isa AbstractDict ? get(row,String(key),get(row,key,default)) :
    hasproperty(row,key) ? getproperty(row,key) : default

"""Preadmit pinned audited roots in their published order, without EA re-search.

The explicit audited flag requires the caller's existing input-audit gate. The
minimal properties are already bound to that audit, as in closure initialization.
"""
function initialize_roots!(s::Store,roots;audited=false)
    audited || throw(ArgumentError("root preadmission requires a pinned completed audit"))
    s.classes_used[]==0 && s.used[]==0 || throw(ArgumentError("roots require a fresh store"))
    n=length(roots)
    n<=length(s.ids) || throw(StoreFull(:candidates,length(s.ids),n,roots))
    n<=length(s.class_candidates) || throw(StoreFull(:classes,length(s.class_candidates),n,roots))
    slots=Int[];sizehint!(slots,n)
    for (ordinal,row) in enumerate(roots)
        p=field(row,:properties,row);field(row,:id,ordinal)==ordinal || error("root IDs must retain audited order")
        slot,isnew=observe_candidate!(s,p;trusted=true)
        isnew && s.apn[slot]==1 && s.degrees[slot]==2 || error("audited roots must be distinct quadratic APNs")
        owner=signature_shard(s,s.sigmas[slot])
        lock(s.signature_locks[owner]) do
            bucket=get!(SignatureBucket,s.buckets[owner],s.sigmas[slot])
            id=add_class!(s,slot,bucket;origin="root",source=field(row,:source,field(row,:catalog_id,"audited root")))
            id==ordinal || error("root class order changed")
        end
        push!(slots,slot)
    end
    slots
end

"""Admit an empty-signature candidate with no tiny worker or packet allocation."""
function classify_if_empty!(s::Store,slot::Integer)
    1<=slot<=s.used[] || throw(ArgumentError("unknown candidate slot"))
    s.apn[slot]==1 && s.degrees[slot]==2 || return (status=:ineligible,class_id=0)
    owner=signature_shard(s,s.sigmas[slot]);guard=s.signature_locks[owner]
    lock(guard)
    try
        s.class_ids[slot]!=0 && return (status=:already_classified,class_id=s.class_ids[slot])
        bucket=get!(SignatureBucket,s.buckets[owner],s.sigmas[slot])
        isempty(bucket.parents) || return (status=:requires_comparison,class_id=0)
        id=add_class!(s,slot,bucket)
        (status=:admitted,class_id=id)
    finally
        unlock(guard)
    end
end

"""A frozen native worker packet plus the signature membership it observed."""
struct AdmissionSnapshot
    slot::Int
    sigma::Digest
    version::UInt64
    target_ids::Vector{Int}
    packet::Union{Nothing,FP._ClosureEquivalencePacket}
    status::Symbol
    class_id::Int
end

"""Freeze current representatives and valid exhaustive-negative prefixes."""
function prepare_admission(s::Store,slot::Integer)
    row=candidate_identity(s,slot);sigma=s.sigmas[slot];owner=signature_shard(s,sigma)
    lock(s.signature_locks[owner]) do
        if !row.apn || row.degree!=2
            return AdmissionSnapshot(Int(slot),sigma,0,Int[],nothing,:ineligible,0)
        elseif s.class_ids[slot]!=0
            return AdmissionSnapshot(Int(slot),sigma,0,Int[],nothing,:already_classified,s.class_ids[slot])
        end
        bucket=get!(SignatureBucket,s.buckets[owner],sigma)
        ids=copy(bucket.parents)
        targets=Dict{String,Any}[]
        for id in ids
            target=class_record(s,id)
            push!(targets,Dict("parent_id"=>id,"candidate_id"=>target.candidate_id,"lut_hex"=>target.lut_hex,
                "saved_exhaustive"=>get(bucket.negatives,(Int(slot),id),nothing)==s.solver_hash))
        end
        packet=FP._ClosureEquivalencePacket(Dict{String,Any}("schema"=>FP.CLOSURE_EQUIVALENCE_SCHEMA,
            "job_id"=>Int(slot),"job_key"=>"deduplicate:"*row.id,"candidate_id"=>row.id,
            "lut_hex"=>row.lut_hex,"sigma"=>row.sigma,"targets"=>targets))
        AdmissionSnapshot(Int(slot),sigma,bucket.version,ids,packet,:pending,0)
    end
end

"""Use the unchanged native EA worker outside signature-owner locks."""
function compute_admission(s::Store,snapshot::AdmissionSnapshot;seconds=30.0,nodes=100_000,context=nothing)
    snapshot.status==:pending || return nothing
    seconds>=0 && (isfinite(seconds) || seconds==Inf) && nodes>=0 || throw(ArgumentError("invalid EA budgets"))
    FP._closure_equivalence_compute(snapshot.packet;seconds,nodes,context,solver_session=s.solver_session)
end

"""Freeze comparison fields without retaining SQL-oriented prepared encodings."""
frozen(proof::FP._ClosurePreparedProof)=proof.fields
frozen(proof)=FP._closure_freeze_proof(proof)

"""Check every proof binding and scientific outcome before publication."""
function checked_comparisons(s,snapshot,result)
    packet=snapshot.packet;slot=snapshot.slot;row=candidate_identity(s,slot)
    snapshot.sigma==s.sigmas[slot] || error("signature owner differs from candidate")
    packet["job_id"]==slot && packet["job_key"]=="deduplicate:"*row.id || error("EA snapshot job differs")
    result["schema"]==packet["schema"]==FP.CLOSURE_EQUIVALENCE_SCHEMA || error("equivalence schema differs")
    result["packet_sha256"]==packet["packet_sha256"]==FP._closure_packet_digest(packet) || error("equivalence packet differs")
    result["candidate_id"]==row.id==packet["candidate_id"] || error("equivalence candidate differs")
    row.lut_hex==packet["lut_hex"] && row.sigma==packet["sigma"] || error("equivalence candidate changed")
    p=result["properties"]
    p["lut_sha256"]==row.id && p["lut_hex"]==row.lut_hex && p["apn"] && p["quadratic"] &&
        p["algebraic_degree"]==row.degree && p["sigma_hash"]==row.sigma || error("equivalence properties differ")
    targets=Dict(Int(t["parent_id"])=>t for t in packet["targets"])
    [Int(t["parent_id"]) for t in packet["targets"]]==snapshot.target_ids || error("EA snapshot membership differs")
    checked=Set(Int(t["parent_id"]) for t in packet["targets"] if t["saved_exhaustive"])
    staged=Any[];equivalent=0;unresolved=false
    for comparison in result["comparisons"]
        id=Int(comparison["target_parent"])
        haskey(targets,id) && !(id in checked) || error("unexpected or repeated EA target")
        target=targets[id];actual=class_record(s,id);proof=comparison["proof"]
        actual.candidate_id==target["candidate_id"] && actual.lut_hex==target["lut_hex"] || error("EA target changed")
        proof["relation"]=="ea" && proof["candidate_sha256"]==row.id && proof["target_sha256"]==actual.candidate_id &&
            proof["candidate_lut_hex"]==row.lut_hex && proof["target_lut_hex"]==actual.lut_hex || error("EA proof bound to another pair")
        status=String(proof["status"])
        if status=="equivalent_with_verified_witness"
            FP.verify_comparison(proof) || error("EA witness failed full replay")
            equivalent=id
        elseif status=="inequivalent_by_exhaustive_solver"
            proof["solver_implementation_sha256"]==s.solver_hash || error("EA negative uses another solver")
        elseif status=="inconclusive_budget"
            unresolved=true
        else
            error("unexpected equal-signature EA outcome")
        end
        fields=frozen(proof)
        push!(staged,(candidate_slot=slot,target_parent=id,status,proof=fields,bytes=Base.summarysize(fields)+64))
        push!(checked,id)
        equivalent!=0 && break
    end
    complete=result["complete"];complete isa Bool || error("invalid completion flag")
    equivalent==0 && complete && length(checked)!=length(targets) && error("EA result omitted a snapshot target")
    (;staged,equivalent,unresolved,complete)
end

"""Append a whole checked comparison batch before changing candidate admission."""
function append_comparisons!(s,staged;retained)
    isempty(staged) && return
    bytes=sum(row.bytes for row in staged)
    lock(s.comparison_lock) do
        n=s.comparisons_used[];total=n+length(staged)
        total<=length(s.comparisons) || throw(StoreFull(:comparisons,length(s.comparisons),total,retained))
        required=s.comparison_bytes[]+bytes
        required<=s.comparison_byte_limit || throw(StoreFull(:comparison_bytes,s.comparison_byte_limit,required,retained))
        for (offset,row) in enumerate(staged);s.comparisons[n+offset]=row;end
        s.comparison_bytes[]=required;s.comparisons_used[]=total
    end
    nothing
end

"""Commit checked evidence, revalidating negatives against current membership.

The runner can call this in logical result order for exact benchmark replay.
Independent signature owners may otherwise commit concurrently. Positive proof
replay occurs before locking. Capacity errors retain the input proof batch;
previously appended valid comparison prefixes remain scientific evidence.
"""
function commit_admission!(s::Store,snapshot::AdmissionSnapshot,result)
    snapshot.status==:pending || return (status=snapshot.status,class_id=snapshot.class_id)
    checked=checked_comparisons(s,snapshot,result)
    slot=snapshot.slot;owner=signature_shard(s,snapshot.sigma);guard=s.signature_locks[owner]
    lock(guard)
    try
        s.class_ids[slot]!=0 && return (status=:already_classified,class_id=s.class_ids[slot])
        bucket=s.buckets[owner][snapshot.sigma]
        append_comparisons!(s,checked.staged;retained=(;snapshot,result))
        for row in checked.staged
            row.status=="inequivalent_by_exhaustive_solver" && (bucket.negatives[(slot,row.target_parent)]=s.solver_hash)
        end
        if checked.equivalent!=0
            s.class_ids[slot]=checked.equivalent;s.states[slot]=UInt8(4)
            return (status=:equivalent,class_id=checked.equivalent)
        elseif !checked.complete
            s.states[slot]=UInt8(5)
            return (status=:unresolved,class_id=0)
        elseif bucket.version!=snapshot.version || bucket.parents!=snapshot.target_ids
            s.states[slot]=UInt8(2)
            return (status=:revalidate,class_id=0)
        elseif checked.unresolved
            s.states[slot]=UInt8(5)
            return (status=:unresolved,class_id=0)
        end
        id=add_class!(s,slot,bucket)
        (status=:admitted,class_id=id)
    finally
        unlock(guard)
    end
end

"""Classify a candidate, using a direct new-signature fast path when possible."""
function classify_candidate!(s::Store,slot::Integer;seconds=30.0,nodes=100_000,context=nothing)
    quick=classify_if_empty!(s,slot)
    quick.status==:requires_comparison || return quick
    snapshot=prepare_admission(s,slot)
    result=compute_admission(s,snapshot;seconds,nodes,context)
    commit_admission!(s,snapshot,result)
end

"""Export candidate snapshots lazily after all worker tasks have joined."""
candidate_rows(s::Store)=(candidate(s,i) for i in 1:s.used[])
"""Export admitted representatives lazily after all worker tasks have joined."""
class_rows(s::Store)=(class_record(s,i) for i in 1:s.classes_used[])
"""Export original comparison proofs lazily without expanding the whole store."""
comparison_rows(s::Store)=((candidate_id=candidate_identity(s,s.comparisons[i].candidate_slot).id,
    target_parent=s.comparisons[i].target_parent,status=s.comparisons[i].status,
    proof=FP._closure_thaw_proof(s.comparisons[i].proof)) for i in 1:s.comparisons_used[])

"""Read cheap capacity counters; byte accounting is conservative retained proof size."""
function stats(s::Store)
    (;candidate_count=s.used[],class_count=s.classes_used[],comparison_count=s.comparisons_used[],
        comparison_bytes=s.comparison_bytes[],candidate_capacity=length(s.ids),class_capacity=length(s.class_candidates),
        comparison_capacity=length(s.comparisons),comparison_byte_limit=s.comparison_byte_limit,
        candidate_column_bytes=length(s.luts)+sizeof(s.ids)+sizeof(s.sigmas)+sizeof(s.degrees)+sizeof(s.apn)+
            sizeof(s.class_ids)+sizeof(s.states)+sizeof(s.next)+sizeof(s.heads),
        class_column_bytes=sizeof(s.class_candidates)+sizeof(s.class_origins)+sizeof(s.class_times)+sizeof(s.class_sources),
        full_property_records_retained=0)
end
end
