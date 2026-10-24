"""Bounded RAM-only candidate storage and construction experiment.

This is a single-process, multithreaded experiment, not a recursive-closure backend.
Existing VBFSearch mathematics verifies every retained APN. Pointer-free typed
slabs store compact candidate/path records; fixed result slots retain the
original managed proof/witness objects. Mathematical routines still allocate.
No SQLite API is called. EA admission, recursion, rollback, durable export,
multi-process sharing and crash recovery are deliberately outside this toy.
"""
module ArenaToy

using VBFSearch
using Base.Threads
const FP=VBFSearch
const Digest=NTuple{32,UInt8}
const ZERO_DIGEST=ntuple(_->UInt8(0),32)
export VerifiedCandidate,CandidateArena,ArenaPath,ArenaFull,ArenaRunFailure,insert_candidate!,
    record_path!,candidate_rows,path_rows,memory_stats,work_packet,packet_factory,
    make_contexts,run_packets!

"""An immutable record constructed only after the existing VBF property checks."""
struct VerifiedCandidate
    lut::NTuple{256,UInt8}
    id::Digest
    sigma::Digest
    degree::UInt8
    function VerifiedCandidate(lut;cache=nothing)
        p=FP.properties(lut;cache)
        p["apn"] || throw(ArgumentError("candidate is not APN"))
        sigma=get(p,"sigma_hash",nothing)
        new(Tuple(hex2bytes(p["lut_hex"])),Tuple(hex2bytes(p["lut_sha256"])),
            sigma===nothing ? ZERO_DIGEST : Tuple(hex2bytes(sigma)),UInt8(p["algebraic_degree"]))
    end
end

"""A bounded-pool failure; counters remain within their allocated capacities."""
struct ArenaFull <: Exception
    kind::Symbol
    capacity::Int
end
Base.showerror(io::IO,e::ArenaFull)=print(io,"arena ",e.kind," capacity exhausted (",e.capacity,")")

"""A joined-worker failure retaining its original cause and all returned proofs."""
struct ArenaRunFailure <: Exception
    cause::Any
    trace::Any
    results::Vector{Any}
    complete::Vector{UInt8}
end
function Base.showerror(io::IO,e::ArenaRunFailure)
    print(io,"RAM arena run failed; mathematical results retained: ")
    showerror(io,e.cause)
end

"""Compact edge into the retained packet result, which owns its full witness.

Method 1 is V5 and method 2 switching. Switching combinations in this toy must
fit UInt64; larger combinations require a different record layout, not truncation.
The packet/record pair identifies the original full cursor/proof/witness.
"""
struct ArenaPath
    parent::Int
    job::Int
    candidate::Int
    packet::Int
    record::Int
    cursor::Int
    combination::UInt64
    method::UInt8
end

"""Fixed-capacity slabs with one short index lock per exact-LUT digest shard.

Exact duplicates consume one candidate record. Every shard's fixed index can
hold the whole pool, so a skewed signature cannot exhaust a small partition.
This simple toy pays O(nshards*capacity) index space; memory_stats reports it.
Only insert_candidate! publishes candidate handles. Read snapshots after workers
join; arbitrary access to a counter while an insertion is underway is unsupported.
"""
struct CandidateArena
    luts::Matrix{UInt8}
    ids::Vector{Digest}
    sigmas::Vector{Digest}
    degrees::Vector{UInt8}
    index_slots::Vector{Vector{Int}}
    locks::Vector{ReentrantLock}
    used::Atomic{Int}
    paths::Vector{ArenaPath}
    paths_used::Atomic{Int}
end

"""Reserve bounded candidate, index and edge storage before any insertion."""
function CandidateArena(capacity::Integer;nshards::Integer=16,path_capacity::Integer=4capacity)
    capacity>=0 && path_capacity>=0 || throw(ArgumentError("capacities must be nonnegative"))
    nshards>0 || throw(ArgumentError("nshards must be positive"))
    n=Int(capacity);m=Int(path_capacity)
    table_size=nextpow(2,max(8,2n))
    CandidateArena(Matrix{UInt8}(undef,256,n),Vector{Digest}(undef,n),Vector{Digest}(undef,n),
        Vector{UInt8}(undef,n),[zeros(Int,table_size) for _ in 1:nshards],
        [ReentrantLock() for _ in 1:nshards],Atomic{Int}(0),Vector{ArenaPath}(undef,m),Atomic{Int}(0))
end

"""Choose a stable shard/probe from the first eight digest bytes."""
function digest_word(d::Digest)
    word=UInt64(0)
    for i in 1:8;word=(word<<8)|UInt64(d[i]);end
    word
end

"""Claim one record without incrementing beyond the pool capacity."""
function claim!(counter,capacity,kind)
    while true
        n=counter[]
        n<capacity || throw(ArenaFull(kind,capacity))
        atomic_cas!(counter,n,n+1)==n && return n+1
    end
end

"""Publish a complete candidate under its shard lock, with exact-byte dedup."""
function insert_candidate!(arena::CandidateArena,candidate::VerifiedCandidate)
    shard=Int(mod(digest_word(candidate.id),UInt64(length(arena.locks))))+1
    table=arena.index_slots[shard]
    guard=arena.locks[shard]
    lock(guard)
    try
        probe=Int(mod(digest_word(candidate.id),UInt64(length(table))))+1
        while true
            slot=table[probe]
            if slot==0
                slot=claim!(arena.used,length(arena.ids),:candidates)
                @inbounds for x in 1:256;arena.luts[x,slot]=candidate.lut[x];end
                arena.ids[slot]=candidate.id;arena.sigmas[slot]=candidate.sigma
                arena.degrees[slot]=candidate.degree
                table[probe]=slot
                return (slot,true)
            elseif arena.ids[slot]==candidate.id
                @inbounds for x in 1:256
                    arena.luts[x,slot]==candidate.lut[x] || error("LUT digest collision")
                end
                arena.sigmas[slot]==candidate.sigma && arena.degrees[slot]==candidate.degree ||
                    error("verified properties changed for an exact LUT")
                return (slot,false)
            end
            probe=probe==length(table) ? 1 : probe+1
        end
    finally
        unlock(guard)
    end
end
insert_candidate!(arena::CandidateArena,lut)=insert_candidate!(arena,VerifiedCandidate(lut))

"""Append one complete pointer-free path into an exclusively claimed record."""
function record_path!(arena::CandidateArena,path::ArenaPath)
    1<=path.candidate<=arena.used[] || throw(ArgumentError("unknown candidate slot"))
    index=claim!(arena.paths_used,length(arena.paths),:paths)
    arena.paths[index]=path
    index
end

"""Take canonical compact candidate rows; no insertion may outlive this snapshot."""
function candidate_rows(arena::CandidateArena)
    for guard in arena.locks;lock(guard);end
    try
        sort!([(id=bytes2hex(collect(arena.ids[i])),lut_hex=bytes2hex(@view arena.luts[:,i]),
            sigma=arena.sigmas[i]==ZERO_DIGEST ? nothing : bytes2hex(collect(arena.sigmas[i])),
            degree=Int(arena.degrees[i])) for i in 1:arena.used[]];by=x->x.id)
    finally
        for guard in reverse(arena.locks);unlock(guard);end
    end
end

"""Read edges after all path-writing workers have joined."""
path_rows(arena::CandidateArena)=copy(@view arena.paths[1:arena.paths_used[]])

"""Report actual reserved typed storage separately from managed result memory."""
function memory_stats(arena::CandidateArena)
    (capacity=length(arena.ids),candidates=arena.used[],path_capacity=length(arena.paths),
        paths=arena.paths_used[],candidate_slab_bytes=length(arena.luts)+
            sizeof(Digest)*(length(arena.ids)+length(arena.sigmas))+length(arena.degrees),
        index_bytes=sum(sizeof,arena.index_slots),path_slab_bytes=sizeof(arena.paths),
        arena_owned_bytes=Base.summarysize(arena),nshards=length(arena.locks))
end

"""Make the existing production compute protocol directly from verified inputs."""
function work_packet(properties;job_id::Integer,parent_id::Integer=1,kind="switching",
    direction::Integer=1,combination="1",payload=Dict{String,Any}(),
    directions_per_packet::Integer=32,extension_cosets::Integer=32)
    packet=Dict{String,Any}("schema"=>FP.CLOSURE_WORK_SCHEMA,"job_id"=>Int(job_id),
        "parent_id"=>Int(parent_id),"job_key"=>"arena:$parent_id:$job_id:$kind","kind"=>String(kind),
        "direction"=>Int(direction),"combination"=>String(combination),"payload"=>payload,
        "target_b6"=>52,"max_kernel"=>23,"extension_cosets"=>Int(extension_cosets),
        "switching_directions"=>Int(directions_per_packet),
        "parent"=>Dict("lut_sha256"=>properties["lut_sha256"],"lut_hex"=>properties["lut_hex"],
            "sigma"=>properties["sigma_hash"]))
    packet["packet_sha256"]=FP._closure_packet_digest(packet)
    packet
end

"""Partition each parent's complete switching directions into disjoint packets.

Optional prepare_v5 packets retain all maximizing five-spaces; callers may use
work_packet for subsequent disjoint V5 coset slices. This factory does not
silently expand the recursive frontier or claim completion of V5 extensions.
"""
function packet_factory(luts;directions_per_packet::Integer=32,prepare_v5::Bool=false)
    1<=directions_per_packet<=255 || throw(ArgumentError("invalid switching slice"))
    packets=Dict{String,Any}[]
    for (parent,lut) in enumerate(luts)
        p=FP.properties(lut)
        p["apn"] && p["quadratic"] || throw(ArgumentError("parent must be quadratic APN"))
        if prepare_v5
            push!(packets,work_packet(p;job_id=length(packets)+1,parent_id=parent,kind="prepare_v5"))
        end
        for first in 1:directions_per_packet:255
            push!(packets,work_packet(p;job_id=length(packets)+1,parent_id=parent,direction=first,
                directions_per_packet=min(directions_per_packet,256-first)))
        end
    end
    packets
end

"""Allocate per-slot mutable contexts while sharing only caller-owned read-only tables."""
function make_contexts(concurrency::Integer;geometry=FP.Fourier.geometry(8),rank_table=nothing,
    preallocate_v5::Bool=false,property_cache_entries::Integer=64)
    concurrency>0 || throw(ArgumentError("concurrency must be positive"))
    contexts=[FP.ClosureWorkContext(;rank_table,property_cache_entries) for _ in 1:concurrency]
    for context in contexts
        context.geometry=geometry
        preallocate_v5 && (context.work=FP.Fourier.V5Work(23))
    end
    contexts
end

"""Reject overlapping requested mathematics before reserving worker scratch."""
function validate_packets(packets)
    ranges=Dict{Any,Vector{Tuple{Int,Int}}}()
    for packet in packets
        kind=packet["kind"];parent=packet["parent"]["lut_sha256"]
        if kind=="prepare_v5"
            key=(parent,kind);first=last=0
        elseif kind=="switching"
            first=Int(packet["direction"]);count=Int(packet["switching_directions"])
            1<=first<=255 && 1<=count<=255 && packet["combination"]=="1" ||
                throw(ArgumentError("switching slices require whole directions"))
            last=min(255,first+count-1);key=(parent,kind)
        elseif kind=="v5"
            first=Int(packet["direction"]);count=Int(packet["extension_cosets"])
            first>=1 && count>0 && count<=typemax(Int)-first+1 ||
                throw(ArgumentError("invalid V5 range"))
            last=first+count-1
            forms=Tuple(FP.Fourier.rref(UInt32.(packet["payload"]["forms"]))[1])
            key=(parent,kind,forms)
        else
            throw(ArgumentError("unsupported packet kind"))
        end
        push!(get!(ranges,key,Tuple{Int,Int}[]),(first,last))
    end
    for intervals in values(ranges)
        sort!(intervals)
        for i in 2:length(intervals)
            intervals[i][1]>intervals[i-1][2] || throw(ArgumentError("requested packet ranges overlap"))
        end
    end
    nothing
end

"""Reject aliased mutable buffers, including distinct wrappers sharing arrays."""
function validate_contexts(contexts)
    owned=Any[]
    function add!(slot,field,value)
        for previous in owned
            aliases=value===previous.value || (value isa AbstractArray && previous.value isa AbstractArray &&
                Base.mightalias(value,previous.value))
            aliases && throw(ArgumentError("mutable $field in slot $slot aliases $(previous.field) in slot $(previous.slot)"))
        end
        push!(owned,(;slot,field,value))
    end
    for (slot,context) in enumerate(contexts)
        add!(slot,:context,context);add!(slot,:context_guard,context.guard)
        cache=context.property_cache
        add!(slot,:property_cache,cache);add!(slot,:cache_guard,cache.guard)
        add!(slot,:cache_values,cache.values);add!(slot,:cache_order,cache.order)
        work=context.work
        if work!==nothing
            work isa FP.Fourier.V5Work || throw(ArgumentError("unsupported scratch type"))
            add!(slot,:work,work)
            for field in (:cnt,:g5,:pts,:flat_histogram,:bitmap)
                add!(slot,field,getproperty(work,field))
            end
            add!(slot,:du7,work.du7)
            for field in (:zeroes,:signatures,:bad)
                add!(slot,field,getproperty(work.du7,field))
            end
        end
    end
    nothing
end

"""Require the entire requested slice; bounded compute may otherwise stop early."""
function validate_scope(packet,result)
    work=result["work"];kind=packet["kind"]
    get(work,"noop",false) && error("packet returned no completed work")
    if kind=="prepare_v5"
        work["done"]===true || error("incomplete five-space preparation")
    elseif kind=="switching"
        expected=min(256,Int(packet["direction"])+Int(packet["switching_directions"]))
        proof=work["proof"]
        proof["next_direction"]==expected && proof["next_combination"]=="1" ||
            error("incomplete switching slice; use smaller slices or explicit continuations")
    elseif kind=="v5"
        proof=work["proof"];first=Int(packet["direction"]);total=Int(proof["total_x"])
        expected=min(first+Int(packet["extension_cosets"]),total+1)
        proof["next_x"]==expected && !proof["capped"] || error("incomplete V5 slice")
        records=FP._closure_v5_record_buffer(work["chunks"])
        cursor,count,candidates,du,completions,capped=FP._closure_apply_v5_cosets!(
            nothing,nothing,packet,proof,work["chunks"],first,records)
        cursor==expected && count==work["processed_cosets"] && records==work["records"] &&
            candidates==proof["linear_system_candidates"] && du==proof["du_reject"] &&
            completions==proof["completion_spaces"] && capped==proof["capped"] ||
            error("V5 coverage differs from original evidence")
    else
        error("unsupported packet kind")
    end
    nothing
end

"""Store APN edges while retaining complete original proof objects in result slots."""
function store_result!(arena,packet,result,packet_index,context)
    result["schema"]==FP.CLOSURE_RESULT_SCHEMA && result["job_id"]==packet["job_id"] &&
        result["kind"]==packet["kind"] && result["packet_sha256"]==packet["packet_sha256"] &&
        FP._closure_packet_digest(result["packet"])==packet["packet_sha256"] || error("mismatched result")
    validate_scope(packet,result)
    kind=packet["kind"];work=result["work"]
    records=kind=="v5" ? work["records"] : kind=="switching" ? work["events"] : ()
    for (record_index,record) in enumerate(records)
        kind=="switching" && record["event"]!="candidate_complete" && continue
        p=record["properties"]
        FP._closure_check_result_properties(p)
        p["apn"] || continue
        candidate=VerifiedCandidate(hex2bytes(p["lut_hex"]);cache=context.property_cache)
        bytes2hex(collect(candidate.id))==p["lut_sha256"] || error("candidate identity differs")
        Int(candidate.degree)==p["algebraic_degree"] || error("candidate degree differs")
        (candidate.sigma==ZERO_DIGEST ? nothing : bytes2hex(collect(candidate.sigma)))==get(p,"sigma_hash",nothing) ||
            error("candidate signature differs")
        slot,_=insert_candidate!(arena,candidate)
        cursor=kind=="v5" ? parse(Int,record["cursor"]) : Int(record["direction"])
        combination=kind=="v5" ? UInt64(0) : parse(UInt64,record["combination"])
        record_path!(arena,ArenaPath(Int(packet["parent_id"]),Int(packet["job_id"]),slot,
            packet_index,record_index,cursor,combination,kind=="v5" ? UInt8(1) : UInt8(2)))
    end
    nothing
end

"""Compute fixed packets with private scratch and direct sharded RAM application.

Workers claim disjoint result positions. Full result objects are retained before
compact application, so capacity failures cannot erase returned mathematical
evidence. All workers join before errors propagate. Capacity failure may retain
a candidate whose edge could not be appended; this toy promises bounded storage
and explicit failure, not production transaction rollback. Caller packets and
shared tables must remain read-only for the entire invocation.

Use one packet invocation per arena: edge packet indices refer to this run's
returned result vector. Reuse contexts across arenas, not one arena's path slab
across unrelated result vectors.
"""
function run_packets!(arena::CandidateArena,packets;concurrency::Integer=1,contexts=nothing)
    concurrency>0 || throw(ArgumentError("concurrency must be positive"))
    validate_packets(packets)
    contexts===nothing && (contexts=make_contexts(concurrency;
        preallocate_v5=any(p->p["kind"]=="v5",packets)))
    length(contexts)==concurrency || throw(ArgumentError("one context per slot required"))
    validate_contexts(contexts)
    n=length(packets);results=Any[nothing for _ in 1:n]
    compute_seconds=zeros(Float64,n);apply_seconds=zeros(Float64,n);complete=zeros(UInt8,n)
    next=Atomic{Int}(0);cancelled=Atomic{Bool}(false);failure=Channel{Any}(concurrency)
    started=time_ns()
    @sync for slot in 1:concurrency
        Threads.@spawn begin
            try
                while !cancelled[]
                    index=atomic_add!(next,1)+1
                    index>n && break
                    packet=packets[index];t=time_ns()
                    result=FP._closure_compute(packet;context=contexts[slot],seconds=Inf,evaluations=256)
                    compute_seconds[index]=(time_ns()-t)*1e-9;results[index]=result
                    t=time_ns();store_result!(arena,packet,result,index,contexts[slot])
                    apply_seconds[index]=(time_ns()-t)*1e-9;complete[index]=1
                end
            catch error
                cancelled[]=true;put!(failure,(;error,backtrace=catch_backtrace()))
            end
        end
    end
    if isready(failure)
        problem=take!(failure)
        throw(ArenaRunFailure(problem.error,problem.backtrace,results,complete))
    end
    (;results,complete,contexts,compute_seconds,apply_seconds,wall_seconds=(time_ns()-started)*1e-9,
        memory=memory_stats(arena),retained_result_bytes=Base.summarysize(results))
end

end
