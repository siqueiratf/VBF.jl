"""Constructor-bound native construction text, discarded by ordinary JSON transport.

The worker owns the frozen fields and exact storage bytes together. Callers can
read historical dictionary fields, but receive fresh copies of nested arrays or
maps. Arbitrary transported dictionaries always use ordinary encoding instead.
"""
abstract type _ClosurePreparedConstructionMap <: AbstractDict{String,Any} end

struct _ClosurePreparedCandidate <: _ClosurePreparedConstructionMap
    fields::_ClosureFrozenProofMap
    storage::NamedTuple{(:original,:body,:ortho,:encoded),Tuple{String,String,String,Bool}}
    reflexive::Bool
    function _ClosurePreparedCandidate(properties::AbstractDict)
        fields=_closure_freeze_proof(properties)
        owned=_closure_thaw_proof(fields)
        # Bind the existing transport checks to owned immutable fields. Native
        # application can reuse this check; a JSON dictionary is checked anew.
        _closure_check_result_properties(owned)
        new(fields,_closure_candidate_storage(owned),(owned==owned)===true)
    end
end

struct _ClosurePreparedWitness <: _ClosurePreparedConstructionMap
    fields::_ClosureFrozenProofMap
    evidence::String
    reflexive::Bool
    function _ClosurePreparedWitness(witness::AbstractDict)
        fields=_closure_freeze_proof(witness)
        owned=_closure_thaw_proof(fields)
        new(fields,_closure_text(owned),(owned==owned)===true)
    end
end

Base.length(value::_ClosurePreparedConstructionMap)=length(value.fields.names)
Base.keys(value::_ClosurePreparedConstructionMap)=value.fields.names
Base.haskey(value::_ClosurePreparedConstructionMap,key)=key isa AbstractString && key in keys(value)
Base.get(value::_ClosurePreparedConstructionMap,key,default)=haskey(value,key) ? value[key] : default
function Base.getindex(value::_ClosurePreparedConstructionMap,key)
    index=findfirst(isequal(key),value.fields.names)
    index===nothing && throw(KeyError(key))
    _closure_thaw_proof(value.fields.values[index])
end
function Base.iterate(value::_ClosurePreparedConstructionMap,state::Int=1)
    state>length(value) && return nothing
    key=value.fields.names[state]
    (Pair{String,Any}(key,_closure_thaw_proof(value.fields.values[state])),state+1)
end
Base.copy(value::_ClosurePreparedConstructionMap)=_closure_thaw_proof(value.fields)
function Base.:(==)(a::_ClosurePreparedConstructionMap,b::_ClosurePreparedConstructionMap)
    # Immutable fields cannot change after the constructor checked reflexivity.
    # Preserve generic comparison for distinct maps and non-reflexive NaN data.
    a===b ? a.reflexive : invoke(==,Tuple{AbstractDict,AbstractDict},a,b)
end
_closure_text(value::_ClosurePreparedCandidate)=value.storage.original
_closure_text(value::_ClosurePreparedWitness)=value.evidence
_closure_candidate_storage(value::_ClosurePreparedCandidate)=value.storage
_closure_check_result_properties(::_ClosurePreparedCandidate)=true

"""Keep future unsupported proof types on the ordinary, fully encoded path."""
function _closure_prepare_construction(::Type{T},value) where {T<:_ClosurePreparedConstructionMap}
    try
        T(value)
    catch failure
        failure isa ArgumentError || rethrow()
        value
    end
end
