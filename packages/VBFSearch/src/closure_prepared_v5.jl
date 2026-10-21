"""Native V5 validation bound to frozen work and immutable complete cosets.

Only inner constructors create these views. JSON exposes historical dictionary
fields, drops this native type, and therefore uses the full coordinator checks.
"""
struct _ClosureV5ValidationScope
    packet_sha256::String
    forms::NTuple{5,Int}
    need::Int
    target_b6::Int
    function _ClosureV5ValidationScope(packet::AbstractDict)
        owned=_closure_thaw_proof(_closure_freeze_proof(packet))
        owned["schema"]==CLOSURE_WORK_SCHEMA && owned["kind"]=="v5" || error("invalid native V5 validation scope")
        digest=_closure_packet_digest(owned)
        owned["packet_sha256"]==digest || error("native V5 work digest mismatch")
        forms=owned["payload"]["forms"]
        length(forms)==5 || error("invalid native V5 forms")
        new(digest,Tuple(Int.(forms)),Int(owned["payload"]["need"]),Int(owned["target_b6"]))
    end
end

struct _ClosurePreparedV5Record <: AbstractDict{String,Any}
    properties::_ClosurePreparedCandidate
    cursor::String
    witness::_ClosurePreparedWitness
    function _ClosurePreparedV5Record(record::AbstractDict)
        length(record)==3 && all(haskey(record,key) for key in ("properties","cursor","witness")) || throw(ArgumentError("future V5 record schema"))
        p=record["properties"];w=record["witness"];cursor=record["cursor"]
        p isa _ClosurePreparedCandidate && w isa _ClosurePreparedWitness && cursor isa String || throw(ArgumentError("ordinary V5 record requires coordinator validation"))
        new(p,cursor,w)
    end
end
const _CLOSURE_V5_RECORD_KEYS=("properties","cursor","witness")
Base.length(::_ClosurePreparedV5Record)=3
Base.keys(::_ClosurePreparedV5Record)=_CLOSURE_V5_RECORD_KEYS
Base.haskey(::_ClosurePreparedV5Record,key)=key isa AbstractString && key in _CLOSURE_V5_RECORD_KEYS
Base.get(r::_ClosurePreparedV5Record,key,default)=haskey(r,key) ? r[key] : default
@inline function Base.getindex(r::_ClosurePreparedV5Record,key)
    key=="properties" && return r.properties
    key=="cursor" && return r.cursor
    key=="witness" && return r.witness
    throw(KeyError(key))
end
function Base.iterate(r::_ClosurePreparedV5Record,state::Int=1)
    state>3 && return nothing
    key=_CLOSURE_V5_RECORD_KEYS[state]
    (Pair{String,Any}(key,r[key]),state+1)
end
Base.copy(r::_ClosurePreparedV5Record)=Dict{String,Any}("properties"=>copy(r.properties),"cursor"=>r.cursor,"witness"=>copy(r.witness))
function Base.:(==)(a::_ClosurePreparedV5Record,b::_ClosurePreparedV5Record)
    a.properties==b.properties && a.cursor==b.cursor && a.witness==b.witness
end

struct _ClosurePreparedV5Records <: AbstractVector{_ClosurePreparedV5Record}
    values::Tuple
    function _ClosurePreparedV5Records(records)
        new(Tuple(_ClosurePreparedV5Record(record) for record in records))
    end
end
Base.size(records::_ClosurePreparedV5Records)=(length(records.values),)
Base.IndexStyle(::Type{_ClosurePreparedV5Records})=IndexLinear()
Base.getindex(records::_ClosurePreparedV5Records,index::Int)=records.values[index]::_ClosurePreparedV5Record
Base.copy(records::_ClosurePreparedV5Records)=[copy(r) for r in records]
_closure_unique_properties_buffer(::AbstractVector{_ClosurePreparedV5Record})=_ClosurePreparedCandidate[]

struct _ClosurePreparedV5Chunk <: AbstractDict{String,Any}
    proof::_ClosureCosetProof
    records::_ClosurePreparedV5Records
    scope::_ClosureV5ValidationScope
    function _ClosurePreparedV5Chunk(chunk::_ClosureCosetChunk,scope::_ClosureV5ValidationScope)
        p=chunk.proof;records=_ClosurePreparedV5Records(chunk["records"])
        p.forms==scope.forms || error("extension coset scientific scope mismatch")
        p.next_x==p.first_x+1 && 1<=p.first_x<=p.total_x || error("invalid extension coset coverage step")
        0<=p.du_reject<=1 && p.linear_system_candidates>=0 && p.completion_spaces>=0 || error("invalid extension coset counters")
        length(records)==p.candidate_spaces || error("extension coset lost candidate records")
        0<p.coset_representative<(1<<28) || error("invalid eligible extension coset")
        cursor=string(p.first_x)
        for record in records
            properties=record.properties;w=record.witness
            properties["apn"] && properties["quadratic"] || error("worker returned an invalid APN completion")
            record.cursor==cursor || error("extension record cursor mismatch")
            w["eligible_coset_index"]==p.first_x && w["coset_representative"]==p.coset_representative &&
                w["V5_forms"]==collect(p.forms) && w["need"]==scope.need && w["target_b6"]==scope.target_b6 &&
                length(w["output_forms"])==8 || error("extension construction witness mismatch")
        end
        new(p,records,scope)
    end
end
Base.length(::_ClosurePreparedV5Chunk)=3
Base.keys(::_ClosurePreparedV5Chunk)=_CLOSURE_COSET_CHUNK_KEYS
Base.haskey(::_ClosurePreparedV5Chunk,key)=key isa AbstractString && key in _CLOSURE_COSET_CHUNK_KEYS
Base.get(c::_ClosurePreparedV5Chunk,key,default)=haskey(c,key) ? c[key] : default
@inline function Base.getindex(c::_ClosurePreparedV5Chunk,key)
    key=="proof" && return c.proof
    key=="records" && return c.records
    key=="processed_cosets" && return 1
    throw(KeyError(key))
end
Base.copy(c::_ClosurePreparedV5Chunk)=Dict{String,Any}("proof"=>copy(c.proof),"records"=>copy(c.records),"processed_cosets"=>1)
function Base.iterate(c::_ClosurePreparedV5Chunk,state::Int=1)
    state>3 && return nothing
    key=_CLOSURE_COSET_CHUNK_KEYS[state]
    (Pair{String,Any}(key,c[key]),state+1)
end
function _closure_prepare_v5_chunk(chunk,scope)
    try
        _ClosurePreparedV5Chunk(chunk,scope)
    catch failure
        failure isa ArgumentError || rethrow()
        chunk
    end
end

"""Keep the hot native coordinator loops concrete; retain mixed future fallback."""
function _closure_native_v5_chunks(chunks)
    all(chunk->chunk isa _ClosurePreparedV5Chunk,chunks) || return chunks
    _ClosurePreparedV5Chunk[chunk for chunk in chunks]
end
_closure_v5_record_buffer(chunks)=Any[]
_closure_v5_record_buffer(::AbstractVector{_ClosurePreparedV5Chunk})=_ClosurePreparedV5Record[]
