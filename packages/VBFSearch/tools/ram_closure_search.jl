"""Bounded RAM construction, classification and representative expansion.

Published roots are admitted by the existing pinned audit. Every subsequent LUT
gets compact identity state before EA admission; only admitted representatives
receive mathematical plans. Immutable V5 plans live for their active ranges.
The existing worker and coverage checks supply all mathematical evidence.
Validated evidence is compressed in workers and retained in bounded RAM pages;
no SQLite operation occurs in the search or admission path.
"""
module RAMClosureSearch
using VBFSearch,TOML,Serialization
using Base.Threads
include("ram_closure_store.jl")
include("closure_refill.jl")
include("closure_operations.jl")
const FP=VBFSearch
const Q=FP.Fourier
const S=RAMClosureStore
const RAM_SCHEDULING="published audited roots first; bounded cohorts; deterministic ordered commit; admitted representatives only; shared immutable V5 range plans"
export run,run_inputs,decode_frame,job_rows,evidence_frames,stats

"""A retained scientific page; decompression has an explicit raw-byte bound."""
struct EvidenceFrame
    job_id::Int
    kind::Symbol
    raw_bytes::Int
    sha256::String
    bytes::Vector{UInt8}
end

"""A local capacity failure retaining its input for inspection/export."""
struct CapacityStop <: Exception
    kind::Symbol
    limit::Int
    required::Int
    retained::Any
end
Base.showerror(io::IO,e::CapacityStop)=print(io,"RAM ",e.kind," capacity exceeded: ",e.required," > ",e.limit)

"""Encode a lossless native payload, retaining compressed bytes even at a raw limit."""
function encode_payload(packet,kind,work,limit)
    io=IOBuffer();Serialization.serialize(io,(;packet,work));raw=take!(io)
    bytes=transcode(FP.CodecZstd.ZstdCompressor,raw)
    frame=EvidenceFrame(Int(packet["job_id"]),Symbol(kind),length(raw),bytes2hex(FP.SHA.sha256(raw)),bytes)
    length(raw)<=limit || throw(CapacityStop(:raw_frame,limit,length(raw),frame))
    frame
end

"""Encode one validated worker result without duplicating V5's per-coset ledger."""
function encode_frame(packet,result,limit)
    work=result["work"]
    retained=if packet["kind"]=="v5" && !get(work,"noop",false)
        compact=Dict{String,Any}(k=>work[k] for k in ("proof","processed_cosets","ledger",
            "commit_chunk","blocked","done","evaluations","apn_luts_checked"))
        compact["records"]=[compact_record(record) for record in work["records"]]
        compact["property_format"]=S.COMPACT_RECORD_PROPERTIES_FORMAT
        compact
    elseif packet["kind"]=="switching" && !get(work,"noop",false)
        compact=copy(work)
        compact["events"]=[event["event"]=="candidate_complete" ? compact_record(event) : event for event in work["events"]]
        compact["property_format"]=S.COMPACT_RECORD_PROPERTIES_FORMAT
        compact
    else
        work
    end
    encode_payload(packet,packet["kind"],retained,limit)
end

"""Compact validated property transport while preserving every construction field."""
function compact_record(record)
    compact=Dict{String,Any}(String(key)=>value for (key,value) in pairs(record))
    compact["properties"]=S.compact_record_properties(record["properties"])
    compact
end

"""Restore one page and check its bytes before deserializing local native objects."""
function decode_frame(frame::EvidenceFrame;max_bytes=128*1024^2)
    0<=frame.raw_bytes<=max_bytes || throw(ArgumentError("RAM frame exceeds decode budget"))
    stream=FP.CodecZstd.ZstdDecompressorStream(IOBuffer(frame.bytes))
    raw=try read(stream,frame.raw_bytes+1) finally close(stream) end
    length(raw)==frame.raw_bytes && bytes2hex(FP.SHA.sha256(raw))==frame.sha256 || error("RAM evidence page differs")
    Serialization.deserialize(IOBuffer(raw))
end

"""A logical construction job; ranges share its stable scientific key."""
Base.@kwdef mutable struct Job
    id::Int
    parent_id::Int
    kind::Symbol
    key::String
    forms::NTuple{5,UInt32}=ntuple(_->UInt32(0),5)
    need::Int=0
    b5::Int=0
    status::Symbol=:pending
    direction::Int=1
    combination::String="1"
    total::Int=0
    completed_cosets::Int=0
    pending_ranges::Int=0
    last_frame::Int=0
end

"""Materialize one small packet/export payload instead of retaining dictionaries per job."""
job_payload(job::Job)=job.kind==:v5 ? Dict{String,Any}("forms"=>Int[job.forms...],"need"=>job.need,"b5"=>job.b5) : Dict{String,Any}()

"""Only active parents retain per-direction checking state and pending children."""
Base.@kwdef mutable struct ParentProgress
    id::Int
    prepare_job::Int
    switching_job::Int
    prepared::Bool=false
    v5_remaining::Int=0
    switching_complete::Int=0
    pending_children::Set{Int}=Set{Int}()
    kernels::Dict{Int,Any}=Dict{Int,Any}()
    construction_done::Bool=false
    settled::Bool=false
end

"""One deterministic reserved unit; mathematical packets are bound at preparation."""
Base.@kwdef struct Item
    id::Int
    kind::Symbol
    parent::Int=0
    job::Int=0
    first::Int=1
    last::Int=1
    combination::String="1"
    plan::Int=0
    candidate::Int=0
    retry::Int=0
end

"""A coordinator-owned queue with bounded-prefix compaction."""
Base.@kwdef mutable struct Queue
    items::Vector{Item}=Item[]
    head::Int=1
end
available(q::Queue)=q.head<=length(q.items)
function dequeue!(q::Queue)
    item=q.items[q.head];q.head+=1
    if q.head>1024 && q.head>length(q.items)÷2
        deleteat!(q.items,1:q.head-1);q.head=1
    end
    item
end

"""One plan's bytes stay charged until every dispatched/unstarted range finishes."""
Base.@kwdef mutable struct PlanLease
    job::Int
    reserved::Int
    plan::Any=nothing
    bytes::Int=0
    next::Int=1
    total::Int=0
    remaining::Int=0
    walsh_buffer::Union{Nothing,Vector{Int16}}=nothing
    walsh_bytes::Int=0
end

"""Mutable state is confined to the coordinator; workers receive frozen descriptors."""
Base.@kwdef mutable struct State
    config::Dict{String,Any}
    identity::Dict{String,Any}
    roots::Any
    store::S.Store
    geometry::Q.Geometry
    rank_table::Any
    contexts::Vector{FP.ClosureWorkContext}
    builders::Vector{Q.V5Work}
    builder_slots::Channel{Int}
    jobs::Vector{Job}=Job[]
    parents::Dict{Int,ParentProgress}=Dict{Int,ParentProgress}()
    preparation::Queue=Queue()
    mathematical::Queue=Queue()
    planning::Queue=Queue()
    admission::Queue=Queue()
    plans::Dict{Int,PlanLease}=Dict{Int,PlanLease}()
    plan_order::Vector{Int}=Int[]
    next_plan::Int=1
    plan_bytes::Int=0
    peak_plan_bytes::Int=0
    walsh_idle::Vector{Vector{Int16}}=Vector{Int16}[]
    walsh_idle_bytes::Int=0
    walsh_live_bytes::Int=0
    walsh_allocations::Int=0
    walsh_reuses::Int=0
    walsh_evictions::Int=0
    peak_walsh_bytes::Int=0
    plan_builder_count::Int=0
    cleanup_seconds::Float64=0.0
    final_property_cache::Any=nothing
    pending_admissions::Set{Int}=Set{Int}()
    waiting_parents::Dict{Int,Vector{Int}}=Dict{Int,Vector{Int}}()
    unresolved::Set{Int}=Set{Int}()
    frames::Vector{EvidenceFrame}=EvidenceFrame[]
    frame_applied::Vector{UInt8}=UInt8[]
    frame_tasks::Vector{Int}=Int[]
    evidence_bytes::Int=0
    completed_frames::Dict{Int,EvidenceFrame}=Dict{Int,EvidenceFrame}()
    completed_frames_lock::ReentrantLock=ReentrantLock()
    completed_frame_bytes::Int=0
    peak_completed_frame_bytes::Int=0
    drained_bytes::Int=0
    task_sequence::Int=0
    processed_packets::Int=0
    plan_builds::Int=0
    completed_construction::Int=0
    settled_roots::Int=0
    completed_recursive::Int=0
    started::Float64=time()
    last_report::Float64=0.0
    cpu_started::Float64=ClosureOperations.process_cpu_seconds()
    gc_started::Int=Int(Base.gc_num().total_time)
    stop::Atomic{Bool}=Atomic{Bool}(false)
    stop_reason::Symbol=:none
    pool_metrics::Any=nothing
    failure::Any=nothing
end

"""Reserve a plan and one exclusive Walsh buffer without exceeding the common budget.

Idle buffers already consume budget. Reusing one replaces its idle charge with
the build reservation; spare idle buffers are evicted until that reservation
fits. A completely idle cache therefore cannot block the next plan forever.
"""
function reserve_plan!(s,item)
    reservation=Int(get(s.config,"plan_reservation_bytes",64*1024^2))
    limit=Int(get(s.config,"plan_bytes",512*1024^2))
    reuse=get(s.config,"reuse_walsh_buffers",true)
    s.plan_bytes-s.walsh_idle_bytes+reservation<=limit || return false
    buffer=nothing;charge=0
    if reuse && !isempty(s.walsh_idle)
        buffer=pop!(s.walsh_idle);charge=Base.summarysize(buffer)
        s.walsh_idle_bytes-=charge;s.plan_bytes-=charge;s.walsh_reuses+=1
    end
    while s.plan_bytes+reservation>limit && !isempty(s.walsh_idle)
        evicted=pop!(s.walsh_idle);bytes=Base.summarysize(evicted)
        s.walsh_idle_bytes-=bytes;s.plan_bytes-=bytes;s.walsh_evictions+=1
    end
    s.plan_bytes+reservation<=limit || error("plan reservation accounting differs")
    if reuse && buffer===nothing
        # Do not first-touch the payload on this coordinator. The sole builder
        # fills it on its compute CPU before publishing the read-only plan.
        buffer=Vector{Int16}(undef,1<<(s.geometry.N-5))
        charge=Base.summarysize(buffer);s.walsh_allocations+=1
    end
    charge<=reservation || throw(ArgumentError("plan reservation is smaller than its Walsh buffer"))
    s.plans[item.job]=PlanLease(job=item.job,reserved=reservation,walsh_buffer=buffer,walsh_bytes=charge)
    push!(s.plan_order,item.job);s.plan_bytes+=reservation;s.walsh_live_bytes+=charge
    s.peak_plan_bytes=max(s.peak_plan_bytes,s.plan_bytes)
    s.peak_walsh_bytes=max(s.peak_walsh_bytes,s.walsh_idle_bytes+s.walsh_live_bytes)
    true
end

"""Recycle only after the last ordered consumer, or discard after workers join."""
function release_plan!(s,id;recycle=true,after_join=false)
    lease=s.plans[id]
    (after_join || (lease.plan!==nothing && lease.remaining==0)) ||
        throw(ArgumentError("cannot release a plan with an unfinished builder or consumer"))
    pop!(s.plans,id)
    s.plan_bytes-=lease.reserved;s.walsh_live_bytes-=lease.walsh_bytes
    if recycle && lease.walsh_buffer!==nothing
        push!(s.walsh_idle,lease.walsh_buffer)
        s.walsh_idle_bytes+=lease.walsh_bytes;s.plan_bytes+=lease.walsh_bytes
    end
    position=findfirst(==(id),s.plan_order)
    if position!==nothing
        deleteat!(s.plan_order,position)
        position<s.next_plan && (s.next_plan-=1)
    end
    nothing
end

"""Count each shared, locked property cache once without reading it during mutation."""
function property_cache_stats(s)
    s.final_property_cache===nothing || return copy(s.final_property_cache)
    seen=Base.IdSet{FP.DiscoveryEvidence.PropertyCache}()
    totals=Dict("caches"=>0,"capacity"=>0,"entries"=>0,"hits"=>0,"misses"=>0)
    for context in s.contexts
        cache=context.property_cache
        cache in seen && continue
        push!(seen,cache);lock(cache.guard)
        try
            totals["caches"]+=1;totals["capacity"]+=cache.max_entries
            totals["entries"]+=length(cache.values);totals["hits"]+=cache.hits;totals["misses"]+=cache.misses
        finally
            unlock(cache.guard)
        end
    end
    totals
end

"""Drop mathematical caches after joined workers, before streaming final export."""
function cleanup_work!(s)
    started=time_ns();s.final_property_cache=property_cache_stats(s)
    seen=Base.IdSet{FP.DiscoveryEvidence.PropertyCache}()
    for context in s.contexts
        context.v5_plan=nothing
        work=context.work
        if work!==nothing
            work.cnt=zeros(Int32,1);work.g5=zeros(Int16,1)
            work.flat_histogram=Int[];work.bitmap=UInt64[]
            work.du7.zeroes=Matrix{UInt64}(undef,0,0);work.du7.signatures=Matrix{UInt64}(undef,0,0)
            work.du7.bad=UInt64[]
        end
        cache=context.property_cache
        cache in seen && continue
        push!(seen,cache);lock(cache.guard)
        try
            cache.values=Dict{Tuple{String,Bool},Dict{String,Any}}()
            cache.order=Tuple{String,Bool}[]
        finally
            unlock(cache.guard)
        end
    end
    for id in collect(keys(s.plans));release_plan!(s,id;recycle=false,after_join=true);end
    empty!(s.walsh_idle);s.walsh_idle_bytes=0;s.walsh_live_bytes=0
    empty!(s.plan_order);s.plan_bytes=0
    empty!(s.builders)
    # The large, mostly pointer-free buffers may be old-generation objects.
    # Collect after dropping references so native SQLite export cannot overlap
    # its peak with dead mathematical workspaces.
    GC.gc()
    s.cleanup_seconds+=(time_ns()-started)*1e-9
    nothing
end

"""Retain one worker completion before its pool event can be dropped on an error.

Only a reference to already-compressed bytes is added. The pool horizon bounds
the number of entries. Ordered application transfers ownership to the main
evidence vector before removing this journal entry.
"""
function journal_frame!(s,item,frame)
    lock(s.completed_frames_lock)
    try
        haskey(s.completed_frames,item.id) && error("worker completion was journaled twice")
        s.completed_frames[item.id]=frame
        s.completed_frame_bytes+=length(frame.bytes)+80
        s.peak_completed_frame_bytes=max(s.peak_completed_frame_bytes,s.completed_frame_bytes)
        length(s.completed_frames)<=Int(get(s.config,"reservation_horizon",max(2length(s.contexts),32))) ||
            error("completion journal exceeded the reservation horizon")
    finally
        unlock(s.completed_frames_lock)
    end
    frame
end

"""Forget a completion only after its scientific bytes have another retained owner."""
function forget_frame!(s,item_id)
    lock(s.completed_frames_lock)
    try
        frame=pop!(s.completed_frames,item_id,nothing)
        frame===nothing || (s.completed_frame_bytes-=length(frame.bytes)+80)
    finally
        unlock(s.completed_frames_lock)
    end
    nothing
end

"""Keep all completed pages after joined workers stop, including unapplied suffixes.

This transfers existing compressed references rather than copying pages. A
separate drain allowance covers at most the reservation horizon's completions;
normal evidence capacity never silently discards a successfully returned page.
"""
function drain_frames!(s)
    lock(s.completed_frames_lock)
    try
        for task in sort!(collect(keys(s.completed_frames)))
            frame=s.completed_frames[task];charge=length(frame.bytes)+80
            push!(s.frames,frame);push!(s.frame_applied,0);push!(s.frame_tasks,task)
            s.evidence_bytes+=charge;s.drained_bytes+=charge
        end
        empty!(s.completed_frames);s.completed_frame_bytes=0
    finally
        unlock(s.completed_frames_lock)
    end
    nothing
end

"""Create uniquely keyed work without any worker mutation of the frontier."""
function enqueue!(s,q,kind;kwargs...)
    s.task_sequence+=1;item=Item(;id=s.task_sequence,kind,kwargs...)
    push!(q.items,item);item
end

"""Create mathematical jobs only for a published or verified admitted class."""
function register_parent!(s,parent)
    haskey(s.parents,parent) && return s.parents[parent]
    S.class_record(s.store,parent)
    prepare=Job(id=length(s.jobs)+1,parent_id=parent,kind=:prepare_v5,key="$parent:prepare_v5")
    push!(s.jobs,prepare)
    switching=Job(id=length(s.jobs)+1,parent_id=parent,kind=:switching,key="$parent:switching")
    push!(s.jobs,switching)
    progress=ParentProgress(id=parent,prepare_job=prepare.id,switching_job=switching.id)
    s.parents[parent]=progress
    progress
end

"""Activate one bounded cohort; all descendants remain unexpanded until admitted."""
function activate!(s,parents)
    stride=Int(get(s.config,"switching_directions",32))
    for parent in parents
        progress=register_parent!(s,parent)
        enqueue!(s,s.preparation,:math;parent,job=progress.prepare_job)
        for first in 1:stride:255
            enqueue!(s,s.mathematical,:math;parent,job=progress.switching_job,first,last=min(255,first+stride-1))
        end
    end
end

"""Bind the existing immutable mathematical protocol to a RAM representative."""
function work_packet(s,item)
    job=s.jobs[item.job];parent=S.class_record(s.store,item.parent)
    packet=Dict{String,Any}("schema"=>FP.CLOSURE_WORK_SCHEMA,"job_id"=>job.id,"parent_id"=>item.parent,
        "job_key"=>job.key,"kind"=>String(job.kind),"direction"=>item.first,"combination"=>item.combination,
        "payload"=>job_payload(job),"target_b6"=>52,"max_kernel"=>23,
        "extension_cosets"=>max(1,item.last-item.first+1),
        "switching_directions"=>job.kind==:switching ? item.last-item.first+1 : 1,
        "parent"=>Dict("lut_sha256"=>parent.candidate_id,"lut_hex"=>parent.lut_hex,"sigma"=>parent.sigma))
    packet["packet_sha256"]=FP._closure_packet_digest(packet)
    packet
end

"""Read process RSS and available host RAM without treating virtual pages as resident."""
function memory_bytes()
    rss=try parse(Int,split(read("/proc/self/statm",String))[2])*Int(ccall(:sysconf,Clong,(Cint,),30)) catch;0 end
    available=try
        line=only(filter(l->startswith(l,"MemAvailable:"),readlines("/proc/meminfo")))
        parse(Int,split(line)[2])*1024
    catch
        typemax(Int)
    end
    (;rss,available)
end

"""Latch external, deadline and memory stops outside the per-coset hot path."""
function maintain!(s,external)
    s.stop[] && return
    reason=if external()
        :external
    elseif time()-s.started>=Float64(get(s.config,"duration_seconds",Inf))
        :deadline
    else
        mem=memory_bytes()
        mem.rss>Int(get(s.config,"rss_limit_bytes",8*1024^3)) ? :rss_limit :
            mem.available<Int(get(s.config,"minimum_available_bytes",4*1024^3)) ? :host_memory : :none
    end
    reason==:none || (s.stop_reason=reason;s.stop[]=true)
end

"""Incrementally settle roots when both construction and every child admission finish."""
function settle!(s,parent)
    p=s.parents[parent]
    if !p.construction_done && p.prepared && p.v5_remaining==0 && p.switching_complete==255
        p.construction_done=true;p.kernels=Dict{Int,Any}();s.completed_construction+=1
    end
    if !p.settled && p.construction_done && isempty(p.pending_children)
        p.settled=true
        parent<=length(s.roots) ? (s.settled_roots+=1) : (s.completed_recursive+=1)
    end
end

"""Resolve every root dependency without rescanning historical candidate/path rows."""
function resolve_candidate!(s,slot)
    delete!(s.unresolved,slot);delete!(s.pending_admissions,slot)
    for parent in pop!(s.waiting_parents,slot,Int[])
        delete!(s.parents[parent].pending_children,slot);settle!(s,parent)
    end
end

"""Store a fully validated observation, taking the empty-signature fast path first."""
function observe!(s,parent,p)
    slot,_=S.observe_candidate!(s.store,p;trusted=true)
    p["apn"] && p["quadratic"] || return slot
    outcome=S.classify_if_empty!(s.store,slot)
    if outcome.status in (:admitted,:already_classified,:equivalent)
        resolve_candidate!(s,slot)
    elseif outcome.status==:requires_comparison
        progress=s.parents[parent]
        if !(slot in progress.pending_children)
            push!(progress.pending_children,slot)
            push!(get!(s.waiting_parents,slot,Int[]),parent)
        end
        if !(slot in s.pending_admissions)
            push!(s.pending_admissions,slot)
            enqueue!(s,s.admission,:admission;candidate=slot)
        end
    elseif outcome.status==:unresolved
        push!(s.unresolved,slot)
    end
    slot
end

"""Validate every original native V5 chunk before dropping raw per-coset objects."""
function validate_v5(packet,work)
    proof=work["proof"];first=Int(packet["direction"]);processed=Int(work["processed_cosets"])
    proof["first_x"]==first && 0<=processed<=packet["extension_cosets"] && proof["next_x"]==first+processed || error("V5 cursor differs")
    proof["V5_forms"]==packet["payload"]["forms"] && proof["heuristic_pruning"]===false || error("V5 scientific scope differs")
    chunks=work["chunks"];records=FP._closure_v5_record_buffer(chunks)
    work["commit_chunk"]==!isempty(chunks) || error("V5 commit flag differs")
    length(chunks)==processed || (processed==0 && proof["total_x"]==0 && length(chunks)==1) || error("V5 coverage lost cosets")
    cursor,n,candidates,du,completions,capped=FP._closure_apply_v5_cosets!(nothing,nothing,packet,proof,chunks,first,records)
    cursor==proof["next_x"] && n==processed && records==work["records"] &&
        length(records)==proof["candidate_spaces"] && candidates==proof["linear_system_candidates"] &&
        du==proof["du_reject"] && completions==proof["completion_spaces"] && capped==proof["capped"] || error("V5 aggregate differs")
    work["evaluations"]==candidates+length(records) || error("V5 evaluation count differs")
    if haskey(proof,"distinct_candidate_spaces")
        proof["distinct_candidate_spaces"]==length(unique(r["properties"]["lut_sha256"] for r in records)) || error("V5 distinct candidate count differs")
    end
    work["done"]==(cursor>proof["total_x"] && !capped) && work["blocked"]==capped || error("V5 completion differs")
    nothing
end

"""Prepare immutable descriptors on the coordinator; no dictionary is read by a worker during mutation."""
function prepare_item(s,item,ticket,slot)
    if item.kind==:admission
        (;item,snapshot=S.prepare_admission(s.store,item.candidate),slot)
    elseif item.kind==:plan
        job=s.jobs[item.job]
        (;item,forms=UInt32[job.forms...],need=job.need,walsh_buffer=s.plans[item.job].walsh_buffer,slot)
    else
        (;item,packet=work_packet(s,item),plan=item.plan==0 ? nothing : s.plans[item.plan].plan,slot)
    end
end

"""Workers prepare plans, compare EA snapshots, or compute/validate/compress mathematics."""
function compute_item(s,prepared,slot,stopped)
    item=prepared.item;context=s.contexts[slot]
    if item.kind==:plan
        builder=take!(s.builder_slots)
        try
            return Q.prepare_v5_plan(s.geometry,UInt32.(prepared.forms),prepared.need;
                beta=Q.BETA8,rank_table=s.rank_table,work=s.builders[builder],walsh_buffer=prepared.walsh_buffer)
        finally
            put!(s.builder_slots,builder)
        end
    end
    try
        if item.kind==:admission
            result=S.compute_admission(s.store,prepared.snapshot;context,
                seconds=min(300.0,Float64(get(s.config,"equivalence_seconds",30.0))*4.0^item.retry),
                nodes=min(1_000_000,Int(get(s.config,"equivalence_nodes",100_000))*4^item.retry))
            if result!==nothing
                snapshot=prepared.snapshot
                binding=(;slot=snapshot.slot,sigma=snapshot.sigma,version=snapshot.version,
                    target_ids=snapshot.target_ids,packet=snapshot.packet,status=snapshot.status,class_id=snapshot.class_id)
                frame=encode_payload(prepared.snapshot.packet,:deduplicate,
                    (;snapshot=binding,result),Int(get(s.config,"max_frame_bytes",128*1024^2)))
                journal_frame!(s,item,frame)
            end
            return result
        else
            context.v5_plan=prepared.plan
            result=try
                FP._closure_compute(prepared.packet;context,seconds=Inf,evaluations=256,stop_requested=stopped)
            finally
                context.v5_plan=nothing
            end
            get(result["work"],"noop",false) || prepared.packet["kind"]!="v5" || validate_v5(prepared.packet,result["work"])
            frame=encode_frame(prepared.packet,result,Int(get(s.config,"max_frame_bytes",128*1024^2)))
            journal_frame!(s,item,frame)
            return (;result,frame)
        end
    catch error
        if error isa CapacityStop && error.retained isa EvidenceFrame
            journal_frame!(s,item,error.retained)
        elseif error isa FP._ClosureWorkCapacity
            frame=encode_payload(prepared.packet,:worker_failure,
                Dict("worker_failure"=>string(typeof(error)),"kind"=>String(error.kind),
                    "limit"=>error.limit,"retained"=>error.retained),typemax(Int))
            journal_frame!(s,item,frame)
        elseif error isa Q.V5OutputLimit
            frame=encode_payload(prepared.packet,:worker_failure,
                Dict("worker_failure"=>string(typeof(error)),"limit"=>error.limit,
                    "coset"=>error.coset_index,"output_spaces"=>error.output_spaces),typemax(Int))
            journal_frame!(s,item,frame)
        end
        rethrow()
    end
end

"""Append the scientific page before mutating candidate metadata, retaining failure inputs."""
function retain!(s,frame,task_id)
    required=s.evidence_bytes+length(frame.bytes)+80
    required<=Int(get(s.config,"evidence_bytes",3*1024^3)) || throw(CapacityStop(:evidence,
        Int(get(s.config,"evidence_bytes",3*1024^3)),required,frame))
    push!(s.frames,frame);push!(s.frame_applied,0);push!(s.frame_tasks,task_id);s.evidence_bytes=required
    forget_frame!(s,task_id)
    length(s.frames)
end

"""Check exact switching kernel/candidate sequence and retain all observations, including non-APNs."""
function apply_switching!(s,item,packet,work)
    p=s.parents[item.parent];direction=Int(packet["direction"]);combination=parse(BigInt,packet["combination"])
    count=0;completed=0
    for event in work["events"]
        Int(event["direction"])==direction || error("switching event cursor differs")
        kind=event["event"]
        if kind=="kernel"
            evidence=event["evidence"]
            evidence["complete_constraints"]===true && length(evidence["basis_hex"])==event["dimension"] || error("incomplete switching kernel")
            digest=bytes2hex(FP.SHA.sha256(FP._closure_text(evidence)))
            previous=get(p.kernels,direction,nothing)
            previous===nothing || previous.digest==digest || error("resumed kernel changed")
            previous===nothing && (p.kernels[direction]=(;digest,dimension=Int(event["dimension"]),evaluations=0,done=false))
        elseif kind=="candidate_complete"
            parse(BigInt,event["combination"])==combination && event["next_direction"]==direction &&
                parse(BigInt,event["next_combination"])==combination+1 || error("switching candidate sequence differs")
            FP._closure_check_result_properties(event["properties"])
            event["cursor"]==string(direction)*":"*string(combination) || error("switching path cursor differs")
            observe!(s,item.parent,event["properties"])
            previous=p.kernels[direction]
            previous.evaluations+1==combination || error("switching evaluation coverage has a gap")
            p.kernels[direction]=merge(previous,(evaluations=previous.evaluations+1,))
            combination+=1;count+=1
        elseif kind=="direction_complete"
            event["next_direction"]==direction+1 && event["next_combination"]=="1" || error("switching transition differs")
            previous=p.kernels[direction]
            previous.done && error("switching direction repeated")
            total=(big(1)<<previous.dimension)-1
            combination==total+1 && previous.evaluations==total || error("switching direction lacks candidate coverage")
            p.kernels[direction]=merge(previous,(done=true,));p.switching_complete+=1
            direction+=1;combination=big(1);completed+=1
        else
            error("unknown switching checkpoint")
        end
    end
    proof=work["proof"]
    count==work["evaluations"]==proof["evaluations"] && count<=256 && completed<=packet["switching_directions"] || error("switching packet exceeded scope")
    proof["next_direction"]==direction && parse(BigInt,proof["next_combination"])==combination || error("switching final cursor differs")
    work["done"]==(direction==256 && combination==1) || error("switching exhaustion differs")
    if direction<=item.last && !s.stop[]
        enqueue!(s,s.mathematical,:math;parent=item.parent,job=item.job,first=direction,last=item.last,combination=string(combination))
    end
    job=s.jobs[item.job]
    while job.direction<=255 && haskey(p.kernels,job.direction) && p.kernels[job.direction].done
        job.direction+=1;job.combination="1"
    end
    job.direction<=255 && haskey(p.kernels,job.direction) && (job.combination=string(p.kernels[job.direction].evaluations+1))
    p.switching_complete==255 && (job.status=:done;job.direction=256;job.combination="1")
end

"""Commit completed work in reservation order, independent of worker finish order."""
function apply_item!(s,prepared,value,seconds,scheduling)
    item=prepared.item
    if item.kind==:plan
        lease=s.plans[item.job];bytes=Q.v5_plan_bytes(value)
        lease.walsh_buffer===nothing || value.walsh===lease.walsh_buffer || error("plan changed its leased Walsh buffer")
        required=s.plan_bytes+bytes-lease.reserved
        required<=Int(get(s.config,"plan_bytes",512*1024^2)) || throw(CapacityStop(:plans,
            Int(get(s.config,"plan_bytes",512*1024^2)),required,value))
        s.plan_bytes=required
        lease.plan=value;lease.bytes=bytes;lease.reserved=bytes;lease.total=length(value.eligible_cosets)
        lease.remaining=cld(max(1,lease.total),Int(get(s.config,"extension_cosets",4096)))
        job=s.jobs[item.job];job.total=lease.total;job.pending_ranges=lease.remaining
        s.plan_builds+=1;s.peak_plan_bytes=max(s.peak_plan_bytes,s.plan_bytes)
        return
    elseif item.kind==:admission
        outcome=S.commit_admission!(s.store,prepared.snapshot,value);s.processed_packets+=1
        forget_frame!(s,item.id)
        if outcome.status in (:admitted,:equivalent,:already_classified,:ineligible)
            resolve_candidate!(s,item.candidate)
        elseif outcome.status==:revalidate
            enqueue!(s,s.admission,:admission;candidate=item.candidate,retry=item.retry)
        elseif outcome.status==:unresolved
            if item.retry<Int(get(s.config,"equivalence_retries",2)) && !s.stop[]
                enqueue!(s,s.admission,:admission;candidate=item.candidate,retry=item.retry+1)
            else
                push!(s.unresolved,item.candidate)
            end
        end
        return
    end
    result=value.result;packet=prepared.packet
    result["schema"]==FP.CLOSURE_RESULT_SCHEMA && result["job_id"]==packet["job_id"] &&
        result["packet_sha256"]==packet["packet_sha256"] && FP._closure_packet_digest(result["packet"])==packet["packet_sha256"] || error("RAM result transport differs")
    index=retain!(s,value.frame,item.id);work=result["work"];s.processed_packets+=1
    if get(work,"noop",false)
        return
    elseif packet["kind"]=="prepare_v5"
        work["done"]===true && length(work["spaces"])==work["proof"]["five_spaces"] && work["proof"]["all_maximizers"]===true || error("incomplete maximizer preparation")
        p=s.parents[item.parent];p.prepared=true
        s.jobs[item.job].status=:done
        for forms in work["spaces"]
            length(forms)==5 || error("invalid five-space basis")
            job=Job(id=length(s.jobs)+1,parent_id=item.parent,kind=:v5,key=string(item.parent)*":v5:"*join(forms,","),
                forms=Tuple(UInt32.(forms)),need=52-work["max_b5"],b5=Int(work["max_b5"]))
            push!(s.jobs,job);p.v5_remaining+=1
            enqueue!(s,s.planning,:plan;parent=item.parent,job=job.id)
        end
    elseif packet["kind"]=="v5"
        for record in work["records"];observe!(s,item.parent,record["properties"]);end
        job=s.jobs[item.job];job.completed_cosets+=Int(work["processed_cosets"])
        next=Int(work["proof"]["next_x"])
        item.first==job.direction && (job.direction=next)
        if work["blocked"]
            job.status=:blocked;s.stop_reason=:blocked;s.stop[]=true
        elseif next>item.last
            lease=s.plans[item.plan];lease.remaining-=1;job.pending_ranges-=1
            if lease.remaining==0
                job.completed_cosets==job.total || error("V5 complete ranges lost coverage")
                job.status=:done;job.direction=job.total+1;s.parents[item.parent].v5_remaining-=1
                release_plan!(s,item.plan)
            end
        elseif !s.stop[]
            enqueue!(s,s.mathematical,:math;parent=item.parent,job=item.job,first=next,last=item.last,plan=item.plan)
        end
    else
        apply_switching!(s,item,packet,work)
    end
    s.jobs[item.job].last_frame=index;s.frame_applied[index]=1;settle!(s,item.parent)
end

"""Select one unreserved coset range while retaining the plan until ordered application."""
function range_item!(s)
    n=length(s.plan_order);n==0 && return nothing
    for _ in 1:n
        s.next_plan>length(s.plan_order) && (s.next_plan=1)
        id=s.plan_order[s.next_plan];s.next_plan+=1
        lease=get(s.plans,id,nothing)
        lease===nothing && continue
        lease.plan===nothing && continue
        lease.next>max(1,lease.total) && continue
        first=lease.next;last=lease.total==0 ? 0 : min(lease.total,first+Int(get(s.config,"extension_cosets",4096))-1)
        lease.next=max(first+1,last+1);s.task_sequence+=1
        return Item(id=s.task_sequence,kind=:math,parent=s.jobs[id].parent_id,job=id,first=first,last=last,plan=id)
    end
    nothing
end

"""Reserve bounded work; no mathematical preparation executes on this coordinator."""
function reserve_items(s,limit,excluded)
    items=Item[]
    for _ in 1:limit
        item=if available(s.admission)
            dequeue!(s.admission)
        elseif (range=range_item!(s))!==nothing
            range
        elseif available(s.planning) && reserve_plan!(s,s.planning.items[s.planning.head])
            dequeue!(s.planning)
        elseif available(s.preparation)
            dequeue!(s.preparation)
        elseif available(s.mathematical)
            dequeue!(s.mathematical)
        else
            nothing
        end
        item===nothing && break
        item.id in excluded && error("RAM work reserved twice")
        push!(items,item)
    end
    items
end

"""Publish cheap counters; process CPU is measured rather than inferred from task count."""
function stats(s::State)
    wall=time()-s.started;cpu=ClosureOperations.process_cpu_seconds()-s.cpu_started
    mem=memory_bytes();store=S.stats(s.store)
    lock(s.completed_frames_lock)
    journal=try
        (;bytes=s.completed_frame_bytes,peak=s.peak_completed_frame_bytes,count=length(s.completed_frames))
    finally
        unlock(s.completed_frames_lock)
    end
    (;wall_seconds=wall,process_cpu_seconds=cpu,average_cpu_cores=wall>0 ? cpu/wall : 0.0,
        gc_pause_seconds=(Int(Base.gc_num().total_time)-s.gc_started)*1e-9,
        initial_roots=length(s.roots),construction_completed=s.completed_construction,
        admission_settled=s.settled_roots,recursive_settled=s.completed_recursive,
        processed_packets=s.processed_packets,plan_builds=s.plan_builds,live_plan_bytes=s.plan_bytes,
        peak_plan_bytes=s.peak_plan_bytes,evidence_frames=length(s.frames),evidence_bytes=s.evidence_bytes,
        walsh_idle_bytes=s.walsh_idle_bytes,walsh_live_bytes=s.walsh_live_bytes,
        walsh_allocations=s.walsh_allocations,walsh_reuses=s.walsh_reuses,walsh_evictions=s.walsh_evictions,
        peak_walsh_bytes=s.peak_walsh_bytes,plan_builder_count=s.plan_builder_count,
        cleanup_seconds=s.cleanup_seconds,property_cache=property_cache_stats(s),
        property_cache_released=s.final_property_cache!==nothing,walsh_pool_enabled=get(s.config,"reuse_walsh_buffers",true),
        drained_evidence_bytes=s.drained_bytes,pending_frame_bytes=journal.bytes,pending_frame_count=journal.count,
        peak_pending_frame_bytes=journal.peak,
        evidence_drain_budget=Int(get(s.config,"drain_bytes",0)),
        evidence_drain_exceeded=s.drained_bytes>Int(get(s.config,"drain_bytes",0)),
        pending_admissions=length(s.pending_admissions),unresolved_equivalence=length(s.unresolved),
        rss_bytes=mem.rss,host_available_bytes=mem.available,store,pool=s.pool_metrics,pool_metric_scope="most recent cohort")
end

"""Expose logical construction metadata without allocating a second job database."""
job_rows(s::State)=((id=j.id,parent_id=j.parent_id,kind=String(j.kind),job_key=j.key,payload=job_payload(j),
    status=String(j.status),direction=j.direction,combination=j.combination,result=nothing,last_frame=j.last_frame) for j in s.jobs)
"""Pages are immutable after a successful search; decode them one at a time for export."""
evidence_frames(s::State)=((frame=s.frames[i],applied=s.frame_applied[i]==1,task_id=s.frame_tasks[i]) for i in eachindex(s.frames))

"""Pin the actual RAM controller sources before mathematical work begins."""
function controller_sources()
    root=normpath(joinpath(@__DIR__,"..","..",".."))
    paths=["packages/VBFSearch/tools/"*name for name in
        ("ram_closure_store.jl","ram_closure_search.jl","ram_closure_output.jl","closure_refill.jl","closure_operations.jl")]
    Dict(path=>FP.DiscoveryEvidence.filehash(joinpath(root,path)) for path in paths)
end

"""Size the default builder pool to both CPU slots and live plan reservations."""
function default_plan_builders(concurrency,plan_bytes,reservation_bytes)
    concurrency>0 && reservation_bytes>0 && plan_bytes>=reservation_bytes ||
        throw(ArgumentError("plan budget must cover one positive reservation"))
    min(concurrency,max(1,plan_bytes÷reservation_bytes))
end

"""Keep audited mathematics/input pins while describing this executor truthfully."""
function ram_identity(identity,config,n)
    owned=copy(identity)
    scientific=Dict{String,Any}(get(identity,"scientific",Dict{String,Any}()))
    scientific["execution_backend"]="ram";scientific["scheduling"]=RAM_SCHEDULING
    owned["scientific"]=scientific
    owned["execution"]=Dict{String,Any}("backend"=>"ram","scheduling"=>RAM_SCHEDULING,
        "initial_only"=>get(config,"initial_only",true),"root_limit"=>Int(get(config,"root_limit",n)))
    owned
end

"""Initialize compact candidates from previously audited input identities."""
function initialize(inputs,config)
    config=Dict{String,Any}(config)
    haskey(config,"ram_controller_sources") || (config["ram_controller_sources"]=controller_sources())
    roots=inputs.roots;n=length(roots);concurrency=Int(get(config,"concurrency",8))
    1<=concurrency<=Threads.nthreads(:default) || throw(ArgumentError("invalid RAM worker count"))
    horizon=Int(get(config,"reservation_horizon",max(2concurrency,32)))
    horizon>=concurrency || throw(ArgumentError("reservation horizon must cover RAM workers"))
    frame_limit=Int(get(config,"max_frame_bytes",128*1024^2));frame_limit>0 || throw(ArgumentError("invalid frame byte limit"))
    get!(config,"drain_bytes",horizon*(2frame_limit+1024))
    stride=Int(get(config,"switching_directions",32));1<=stride<=255 || throw(ArgumentError("invalid switching range"))
    Int(get(config,"extension_cosets",4096))>0 || throw(ArgumentError("invalid V5 range"))
    builders_default=default_plan_builders(concurrency,Int(get(config,"plan_bytes",512*1024^2)),
        Int(get(config,"plan_reservation_bytes",64*1024^2)))
    get(config,"reuse_walsh_buffers",true) isa Bool || throw(ArgumentError("reuse_walsh_buffers must be boolean"))
    walsh_bytes=2*(1<<23)+Base.summarysize(Int16[])
    !get(config,"reuse_walsh_buffers",true) || Int(get(config,"plan_reservation_bytes",64*1024^2))>=walsh_bytes ||
        throw(ArgumentError("plan reservation cannot hold an eight-bit Walsh buffer"))
    store=S.Store(;candidate_capacity=Int(get(config,"candidate_capacity",max(n,1_000_000))),
        class_capacity=Int(get(config,"class_capacity",max(n,1_000_000))),
        comparison_capacity=Int(get(config,"comparison_capacity",100_000)),
        comparison_bytes=Int(get(config,"comparison_bytes",256*1024^2)))
    pinned=[(;id=i,source=String(row.catalog_id),properties=Dict{String,Any}("lut_sha256"=>String(row.lut_sha256),
        "lut_hex"=>String(row.lut_hex),"sigma_hash"=>String(row.sigma_hash),"apn"=>true,"quadratic"=>true,
        "algebraic_degree"=>2,"differential_uniformity"=>2)) for (i,row) in enumerate(roots)]
    S.initialize_roots!(store,pinned;audited=true)
    geometry=Q.geometry(8)
    table=get(config,"precompute_rank_table",true) ? Q.PackedPolarRankTable(geometry) : nothing
    shared_entries=Int(get(config,"shared_property_cache_entries",8192))
    shared_entries>=0 || throw(ArgumentError("shared property cache capacity must be nonnegative"))
    shared_cache=shared_entries==0 ? nothing : FP.DiscoveryEvidence.PropertyCache(;max_entries=shared_entries)
    contexts=[FP.ClosureWorkContext(;rank_table=table,property_cache=shared_cache,property_cache_entries=64) for _ in 1:concurrency]
    record_limit=Int(get(config,"max_packet_records",16384));record_limit>=0 || throw(ArgumentError("invalid packet record limit"))
    for context in contexts
        context.geometry=geometry;context.work=Q.V5Work(0,8);context.record_limit=record_limit
    end
    count=Int(get(config,"plan_builders",builders_default))
    1<=count<=concurrency || throw(ArgumentError("invalid plan builder count"))
    builders=[Q.V5Work(0,8) for _ in 1:count];slots=Channel{Int}(count)
    for i in 1:count;put!(slots,i);end
    config["plan_builders"]=count
    s=State(;config,identity=ram_identity(inputs.identity,config,n),roots,store,geometry,rank_table=table,contexts,builders,
        builder_slots=slots,plan_builder_count=count)
    for parent in 1:n;register_parent!(s,parent);end
    s
end

"""Run verified inputs without SQLite; initial_only stops before descendant expansion."""
function run_inputs(inputs,config=Dict{String,Any}();on_progress=_->nothing,stop_requested=()->false)
    s=initialize(inputs,config);concurrency=length(s.contexts)
    window=Int(get(config,"window_size",max(16,2concurrency)));window>0 || throw(ArgumentError("invalid RAM window"))
    n=length(s.roots);limit=Int(get(config,"root_limit",n));1<=limit<=n || throw(ArgumentError("invalid published root limit"))
    get(config,"initial_only",true) || limit==n || throw(ArgumentError("recursive search requires all selected published roots"))
    next_parent=1;state="running"
    maintenance=()->maintain!(s,stop_requested)
    function progress(;force=false)
        maintenance()
        if force || time()-s.last_report>=Float64(get(config,"report_interval_seconds",15.0))
            on_progress(stats(s));s.last_report=time()
        end
    end
    progress(;force=true)
    try
        while !s.stop[]
            last_allowed=get(config,"initial_only",true) ? limit : S.stats(s.store).class_count
            next_parent>last_allowed && break
            selected=collect(next_parent:min(last_allowed,next_parent+window-1));next_parent=last(selected)+1
            activate!(s,selected)
            pool=run_refill_pool!((limit,excluded)->reserve_items(s,limit,excluded),
                (item,ticket,slot)->prepare_item(s,item,ticket,slot),
                (prepared,slot,stopped)->compute_item(s,prepared,slot,stopped),
                (prepared,value,seconds,meta)->apply_item!(s,prepared,value,seconds,meta);
                concurrency,max_pending=Int(get(config,"reservation_horizon",max(2concurrency,32))),
                reservation_refill_batch=1,max_apply_per_step=32,key=item->item.id,
                lane=item->item.kind==:plan ? :plan : :default,
                lane_limits=Dict(:plan=>length(s.builders)),stop_requested=()->s.stop[],
                on_tick=()->progress(),on_wait=maintenance,
                on_state=x->(s.pool_metrics=x))
            s.pool_metrics=pool
            if !s.stop[] && (available(s.planning) || available(s.preparation) || available(s.mathematical) || available(s.admission))
                error("RAM frontier drained while eligible work remained")
            end
            progress(;force=true)
        end
        state=s.stop[] ? "paused_"*String(s.stop_reason) : !isempty(s.unresolved) ? "paused_unresolved_equivalence" :
            get(config,"initial_only",true) ? "initial_complete" : "exhausted"
        state=="initial_complete" && (s.settled_roots==limit || error("initial roots finished without complete admission dependencies"))
    catch error
        s.failure=(;error,backtrace=catch_backtrace());s.stop[]=true
        state=error isa Union{CapacityStop,S.StoreFull,FP._ClosureWorkCapacity,Q.V5OutputLimit} ? "paused_capacity" : "failed"
    finally
        drain_frames!(s)
        cleanup_work!(s)
    end
    progress(;force=true)
    report=Dict{String,Any}("state"=>state,"processed_packets"=>s.processed_packets,
        "seed_statistics"=>Dict("published_selected"=>limit,"published_registry"=>n,"published_completed_this_session"=>s.settled_roots,
            "completed_this_session"=>s.settled_roots,"construction_completed"=>s.completed_construction),
        "runtime_metrics"=>Dict(string(k)=>v for (k,v) in pairs(stats(s))),
        "identity"=>s.identity,"initial_only"=>get(config,"initial_only",true),
        "execution_scheduling"=>RAM_SCHEDULING,
        "v5_filter"=>"exact DU7 bitsets",
        "pool_metric_scope"=>"most recent cohort",
        "scope"=>"RAM candidates and EA admission before representative expansion; compressed native evidence")
    (;report,store=s.store,state=s,evidence=s)
end

"""Reuse the exact audited campaign-input gate without creating an intermediate database."""
function run(config;on_progress=_->nothing,stop_requested=()->false)
    config=Dict{String,Any}(config);config["ram_controller_sources"]=controller_sources()
    inputs=FP.closure_seed_inputs(config["campaign"];root_first=Int(get(config,"root_first",1)),
        root_last=Int(get(config,"root_last",0)),extension_cosets=Int(get(config,"extension_cosets",4096)),
        switching_directions=Int(get(config,"switching_directions",32)))
    run_inputs(inputs,config;on_progress,stop_requested)
end
end
