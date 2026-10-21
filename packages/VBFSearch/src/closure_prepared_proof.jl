"""Immutable native EA evidence with worker-prepared, lossless storage text.

Only the inner constructor can bind a frozen structured proof to its encoding.
Dictionary and JSON views expose the historical proof fields. JSON transport
therefore discards the native shortcut and uses ordinary coordinator encoding.
"""
struct _ClosureFrozenProofMap
    names::Tuple
    values::Tuple
end
struct _ClosureFrozenProofVector
    values::Tuple
end
struct _ClosureFrozenProofBigInt
    decimal::String
end

"""Freeze supported TOML values without retaining caller-owned mutable objects."""
function _closure_freeze_proof(value)
    if value isa AbstractDict
        all(key->key isa AbstractString,keys(value)) || throw(ArgumentError("proof keys must be strings"))
        names=Tuple(String(key) for key in keys(value))
        return _ClosureFrozenProofMap(names,Tuple(_closure_freeze_proof(value[key]) for key in names))
    elseif value isa AbstractVector
        return _ClosureFrozenProofVector(Tuple(_closure_freeze_proof(item) for item in value))
    elseif value isa BigInt
        return _ClosureFrozenProofBigInt(string(value))
    elseif value isa AbstractString
        return String(value)
    elseif value isa Union{Bool,Int8,Int16,Int32,Int64,Int128,UInt8,UInt16,UInt32,UInt64,UInt128,
            Float16,Float32,Float64,Dates.Date,Dates.DateTime,Dates.Time}
        return value
    end
    throw(ArgumentError("unsupported mutable proof value"))
end

_closure_thaw_proof(value)=value
_closure_thaw_proof(value::_ClosureFrozenProofMap)=Dict{String,Any}(
    key=>_closure_thaw_proof(item) for (key,item) in zip(value.names,value.values))
_closure_thaw_proof(value::_ClosureFrozenProofVector)=[_closure_thaw_proof(item) for item in value.values]
_closure_thaw_proof(value::_ClosureFrozenProofBigInt)=parse(BigInt,value.decimal)

struct _ClosurePreparedProof <: AbstractDict{String,Any}
    fields::_ClosureFrozenProofMap
    evidence::String
    body::String
    slots::NTuple{9,String}
    encoded::Bool
    pair::NTuple{4,String}
    function _ClosurePreparedProof(proof::AbstractDict,pair::NTuple{4,String})
        fields=_closure_freeze_proof(proof)
        owned=_closure_thaw_proof(fields)
        evidence=_closure_text(owned)
        storage=_closure_comparison_storage(owned,evidence,pair)
        new(fields,evidence,storage.body,Tuple(storage.slots),storage.encoded,pair)
    end
end

Base.length(proof::_ClosurePreparedProof)=length(proof.fields.names)
Base.keys(proof::_ClosurePreparedProof)=proof.fields.names
Base.haskey(proof::_ClosurePreparedProof,key)=key isa AbstractString && key in keys(proof)
Base.get(proof::_ClosurePreparedProof,key,default)=haskey(proof,key) ? proof[key] : default
function Base.getindex(proof::_ClosurePreparedProof,key)
    index=findfirst(isequal(key),proof.fields.names)
    index===nothing && throw(KeyError(key))
    _closure_thaw_proof(proof.fields.values[index])
end
function Base.iterate(proof::_ClosurePreparedProof,state::Int=1)
    state>length(proof) && return nothing
    key=proof.fields.names[state]
    (Pair{String,Any}(key,_closure_thaw_proof(proof.fields.values[state])),state+1)
end
Base.copy(proof::_ClosurePreparedProof)=_closure_thaw_proof(proof.fields)
_closure_text(proof::_ClosurePreparedProof)=proof.evidence

"""Reuse constructor-bound native encoding only for the independently checked pair."""
function _closure_comparison_storage(proof::_ClosurePreparedProof,evidence,values)
    if evidence==proof.evidence && values==proof.pair
        return (body=proof.body,slots=proof.slots,encoded=proof.encoded)
    end
    invoke(_closure_comparison_storage,Tuple{Any,Any,Any},proof,evidence,values)
end

"""Prepare supported native proofs; preserve the ordinary path for future values."""
function _closure_prepare_comparison_proof(proof,pair)
    try
        _ClosurePreparedProof(proof,ntuple(i->String(pair[i]),4))
    catch error
        error isa ArgumentError || rethrow()
        proof
    end
end

"""Immutable EA packet whose digest is derived once from its frozen contents."""
struct _ClosureEquivalencePacket <: AbstractDict{String,Any}
    fields::_ClosureFrozenProofMap
    digest::String
    function _ClosureEquivalencePacket(packet::AbstractDict)
        fields=_closure_freeze_proof(packet)
        owned=_closure_thaw_proof(fields)
        get(owned,"schema",nothing)==CLOSURE_EQUIVALENCE_SCHEMA || error("unsupported native equivalence packet")
        digest=_closure_packet_digest(owned)
        if haskey(owned,"packet_sha256")
            owned["packet_sha256"]==digest || error("equivalence packet digest differs")
        else
            fields=_ClosureFrozenProofMap((fields.names...,"packet_sha256"),(fields.values...,digest))
        end
        new(fields,digest)
    end
end

Base.length(packet::_ClosureEquivalencePacket)=length(packet.fields.names)
Base.keys(packet::_ClosureEquivalencePacket)=packet.fields.names
Base.haskey(packet::_ClosureEquivalencePacket,key)=key isa AbstractString && key in keys(packet)
Base.get(packet::_ClosureEquivalencePacket,key,default)=haskey(packet,key) ? packet[key] : default
function Base.getindex(packet::_ClosureEquivalencePacket,key)
    index=findfirst(isequal(key),packet.fields.names)
    index===nothing && throw(KeyError(key))
    _closure_thaw_proof(packet.fields.values[index])
end
function Base.iterate(packet::_ClosureEquivalencePacket,state::Int=1)
    state>length(packet) && return nothing
    key=packet.fields.names[state]
    (Pair{String,Any}(key,_closure_thaw_proof(packet.fields.values[state])),state+1)
end
Base.copy(packet::_ClosureEquivalencePacket)=_closure_thaw_proof(packet.fields)
_closure_packet_digest(packet::_ClosureEquivalencePacket)=packet.digest
