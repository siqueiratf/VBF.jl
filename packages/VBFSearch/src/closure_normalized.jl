"""Lossless normalization of repeated LUTs and proof text.

The public SQL views retain the original columns and exact TOML bytes. Digests
index templates; an exact body comparison guards against hash collisions. This
is serialization only and confers no mathematical equivalence on candidates.
"""
const _CLOSURE_NORMALIZED = WeakKeyDict{SQLite.DB,Bool}()
const _CLOSURE_PROOF_SLOTS = ("graph_map_columns","graph_map_constant","nodes","seconds","timeout_seconds","max_nodes","stop","evidence","rng_seed")
const _CLOSURE_PROOF_SLOT_PATTERN = Regex("(?m)^("*join(_CLOSURE_PROOF_SLOTS,"|")*") = ([^\\n]*)\n")
const _CLOSURE_PROOF_SLOT_INDEX = Dict(key=>i for (i,key) in enumerate(_CLOSURE_PROOF_SLOTS))
const _CLOSURE_TOKEN_PREFIX = "!!vbf:"
_closure_token(key) = _CLOSURE_TOKEN_PREFIX*key*"!!"
function _closure_normalized(db)
    get!(_CLOSURE_NORMALIZED,db) do
        _closure_count(db,"SELECT COUNT(*) n FROM sqlite_master WHERE type='table' AND name='closure_candidates'")==1
    end
end
function _closure_create_normalized_schema(db)
    for statement in split(read(joinpath(@__DIR__,"closure_normalized.sql"),String),"--@statement")
        _closure_exec(db,statement)
    end
    _CLOSURE_NORMALIZED[db]=true
end
function _closure_template!(db,body)
    digest=SHA.sha256(body)
    _closure_exec(db,"INSERT OR IGNORE INTO closure_templates(digest,body) VALUES(?,?)",(digest,body))
    rows=_closure_rows(db,"SELECT id FROM closure_templates WHERE digest=? AND body=? COLLATE BINARY",(digest,body))
    isempty(rows) && error("proof-template SHA-256 collision")
    only(rows)["id"]
end
_closure_binary_hex(value) = value isa String && iseven(sizeof(value)) && occursin(r"^[0-9a-f]*$",value)
"""Prepare only lossless candidate text; mutable admission state stays in SQLite."""
function _closure_candidate_storage(p)
    id=p["lut_sha256"];lut=p["lut_hex"];sigma=get(p,"sigma_hash",missing)
    original=_closure_text(p);body=original;ortho=get(p,"ortho_lut_hex","")
    encoded=!occursin(_CLOSURE_TOKEN_PREFIX,original) && _closure_binary_hex(ortho)
    if encoded
        for (key,value) in (("c:lut",lut),("c:id",id),("c:sigma",sigma),("c:ortho",ortho))
            ismissing(value) || isempty(value) || (body=replace(body,value=>_closure_token(key)))
        end
    else
        ortho=""
    end
    (;original,body,ortho,encoded)
end

function _closure_normalized_candidate(db,p;state="observed",templates=nothing)
    id=p["lut_sha256"];lut=p["lut_hex"];sigma=get(p,"sigma_hash",missing)
    storage=_closure_candidate_storage(p);binary=_closure_binary_hex(lut)
    template=if templates===nothing
        _closure_template!(db,storage.body)
    else
        get!(templates,storage.body) do
            _closure_template!(db,storage.body)
        end
    end
    _closure_exec(db,"INSERT OR IGNORE INTO closure_candidates(id,lut,lut_text,sigma,apn,degree,template_id,ortho,encoding,state) SELECT ?,?,?,?,?,?,?,?,?,? WHERE NOT EXISTS(SELECT 1 FROM closure_candidates WHERE lut_text=?)",
        (id,binary ? hex2bytes(lut) : missing,binary ? missing : lut,sigma,Int(p["apn"]),p["algebraic_degree"],
         template,hex2bytes(storage.ortho),Int(storage.encoded),state,lut))
    id
end
"""Normalize proof slots in one scan, preserving opaque and repeated-key payloads."""
function _closure_comparison_storage(proof,evidence,values)
    body=evidence;slots=fill("",9);encoded=false
    if values!==nothing && !occursin(_CLOSURE_TOKEN_PREFIX,evidence)
        fields=("candidate_lut_hex","target_lut_hex","candidate_sha256","target_sha256")
        encoded=all(get(proof,k,nothing)==v for (k,v) in zip(fields,values))
        if encoded
            for (key,value) in zip(("c:lut","t:lut","c:id","t:id"),values)
                isempty(value) || (body=replace(body,value=>_closure_token(key)))
            end
            counts=zeros(Int,9)
            for matched in eachmatch(_CLOSURE_PROOF_SLOT_PATTERN,body)
                i=_CLOSURE_PROOF_SLOT_INDEX[matched.captures[1]]
                counts[i]+=1;slots[i]=String(matched.captures[2])
            end
            for i in eachindex(slots)
                counts[i]==1 || (slots[i]="")
            end
            body=replace(body,_CLOSURE_PROOF_SLOT_PATTERN=>matched->begin
                key=SubString(matched,1,findfirst(' ',matched)-1)
                i=_CLOSURE_PROOF_SLOT_INDEX[key]
                counts[i]==1 ? key*" = "*_closure_token("v$(i-1)")*"\n" : matched
            end)
        end
    end
    (;body,slots,encoded)
end

include("closure_prepared_proof.jl")
include("closure_prepared_construction.jl")

"""Insert evidence, optionally reusing the pair already checked by admission."""
function _closure_insert_comparison!(s,candidate_id,target_parent,proof;bound_pair=nothing)
    evidence=_closure_text(proof);status=proof["status"]
    if !_closure_normalized(s.db)
        _closure_exec(s,"INSERT INTO comparisons(candidate_id,target_parent,status,evidence,session_id) VALUES(?,?,?,?,?)",(candidate_id,target_parent,status,evidence,s.session))
        return
    end
    values=bound_pair
    if values===nothing && !occursin(_CLOSURE_TOKEN_PREFIX,evidence)
        row=only(_closure_rows(s,"SELECT a.lut_hex,b.lut_hex AS target_lut,b.id AS target_id FROM candidates a,parents p JOIN candidates b ON b.id=p.candidate_id WHERE a.id=? AND p.id=?",(candidate_id,target_parent)))
        values=(row["lut_hex"],row["target_lut"],candidate_id,row["target_id"])
    end
    body,slots,encoded=_closure_comparison_storage(proof,evidence,values)
    _closure_exec(s,"INSERT INTO closure_comparisons(candidate_id,target_parent,status,template_id,session_id,encoding,v0,v1,v2,v3,v4,v5,v6,v7,v8) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (candidate_id,target_parent,status,_closure_template!(s,body),s.session,Int(encoded),slots...))
    nothing
end
