"""Read-only views of the existing complete-coset worker result schema.

The fixed proof fields are stored as native scalars and an immutable tuple of
forms. Dictionary access and JSON transport retain the historical field names
and values. No construction, coverage criterion or persistent encoding changes.
"""
const _CLOSURE_COSET_PROOF_KEYS=("first_x","next_x","total_x","capped","candidate_spaces",
    "linear_system_candidates","du_reject","completion_spaces","heuristic_pruning",
    "V5_forms","coset_order","coset_representative")
const _CLOSURE_COSET_CHUNK_KEYS=("proof","records","processed_cosets")
const _CLOSURE_COSET_ORDER="increasing nonzero quotient integer with exact bent count"

"""Immutable completed-coset proof; mutable form arrays are never cached."""
struct _ClosureCosetProof <: AbstractDict{String,Any}
    forms::NTuple{5,Int}
    first_x::Int
    next_x::Int
    total_x::Int
    candidate_spaces::Int
    linear_system_candidates::Int
    du_reject::Int
    completion_spaces::Int
    coset_representative::Int
    capped::Bool
end

Base.length(::_ClosureCosetProof)=12
Base.keys(::_ClosureCosetProof)=_CLOSURE_COSET_PROOF_KEYS
Base.haskey(::_ClosureCosetProof,key)=key isa AbstractString && key in _CLOSURE_COSET_PROOF_KEYS
Base.get(p::_ClosureCosetProof,key,default)=haskey(p,key) ? p[key] : default
Base.getindex(::_ClosureCosetProof,key)=throw(KeyError(key))

"""Expose historical dictionary fields, copying the forms at the boundary."""
@inline function Base.getindex(p::_ClosureCosetProof,key::AbstractString)
    key=="first_x" && return p.first_x
    key=="next_x" && return p.next_x
    key=="total_x" && return p.total_x
    key=="capped" && return p.capped
    key=="candidate_spaces" && return p.candidate_spaces
    key=="linear_system_candidates" && return p.linear_system_candidates
    key=="du_reject" && return p.du_reject
    key=="completion_spaces" && return p.completion_spaces
    key=="heuristic_pruning" && return false
    key=="V5_forms" && return collect(p.forms)
    key=="coset_order" && return _CLOSURE_COSET_ORDER
    key=="coset_representative" && return p.coset_representative
    throw(KeyError(key))
end

"""Materialize a mutable legacy dictionary for aggregation or explicit edits."""
Base.copy(p::_ClosureCosetProof)=Dict{String,Any}(key=>p[key] for key in keys(p))
function Base.iterate(p::_ClosureCosetProof,state::Int=1)
    state>length(p) && return nothing
    key=_CLOSURE_COSET_PROOF_KEYS[state]
    (Pair{String,Any}(key,p[key]),state+1)
end

"""An immutable empty candidate vector; sharing it exposes no mutable state."""
struct _ClosureEmptyRecords <: AbstractVector{Dict{String,Any}} end
Base.size(::_ClosureEmptyRecords)=(0,)
Base.IndexStyle(::Type{_ClosureEmptyRecords})=IndexLinear()
Base.getindex(v::_ClosureEmptyRecords,i::Int)=throw(BoundsError(v,i))
Base.iterate(::_ClosureEmptyRecords)=nothing
Base.copy(::_ClosureEmptyRecords)=Dict{String,Any}[]
const _CLOSURE_EMPTY_RECORDS=_ClosureEmptyRecords()

"""Read-only chunk envelope, with an owned vector only when candidates exist."""
struct _ClosureCosetChunk <: AbstractDict{String,Any}
    proof::_ClosureCosetProof
    records::Union{Nothing,Vector{Dict{String,Any}}}
end

Base.length(::_ClosureCosetChunk)=3
Base.keys(::_ClosureCosetChunk)=_CLOSURE_COSET_CHUNK_KEYS
Base.haskey(::_ClosureCosetChunk,key)=key isa AbstractString && key in _CLOSURE_COSET_CHUNK_KEYS
Base.get(c::_ClosureCosetChunk,key,default)=haskey(c,key) ? c[key] : default
Base.getindex(::_ClosureCosetChunk,key)=throw(KeyError(key))
@inline function Base.getindex(c::_ClosureCosetChunk,key::AbstractString)
    key=="proof" && return c.proof
    key=="records" && return c.records===nothing ? _CLOSURE_EMPTY_RECORDS : c.records
    key=="processed_cosets" && return 1
    throw(KeyError(key))
end
Base.copy(c::_ClosureCosetChunk)=Dict{String,Any}("proof"=>copy(c.proof),
    "records"=>copy(c["records"]),"processed_cosets"=>1)
function Base.iterate(c::_ClosureCosetChunk,state::Int=1)
    state>length(c) && return nothing
    key=_CLOSURE_COSET_CHUNK_KEYS[state]
    (Pair{String,Any}(key,c[key]),state+1)
end
