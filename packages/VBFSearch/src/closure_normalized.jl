"""Lossless normalization of repeated LUTs and proof text.

The public SQL views retain the original columns and exact TOML bytes. Digests
index templates; an exact body comparison guards against hash collisions. This
is serialization only and confers no mathematical equivalence on candidates.
"""
const _CLOSURE_NORMALIZED = WeakKeyDict{SQLite.DB,Bool}()
const _CLOSURE_PROOF_SLOTS = ("graph_map_columns","graph_map_constant","nodes","seconds","timeout_seconds","max_nodes","stop","evidence","rng_seed")
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
    row=only(_closure_rows(db,"SELECT id,body FROM closure_templates WHERE digest=?",(digest,)))
    row["body"]==body || error("proof-template SHA-256 collision")
    row["id"]
end
_closure_binary_hex(value) = value isa String && iseven(sizeof(value)) && occursin(r"^[0-9a-f]*$",value)
function _closure_normalized_candidate(db,p;state="observed")
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
    binary=_closure_binary_hex(lut)
    _closure_exec(db,"INSERT OR IGNORE INTO closure_candidates(id,lut,lut_text,sigma,apn,degree,template_id,ortho,encoding,state) SELECT ?,?,?,?,?,?,?,?,?,? WHERE NOT EXISTS(SELECT 1 FROM closure_candidates WHERE lut_text=?)",
        (id,binary ? hex2bytes(lut) : missing,binary ? missing : lut,sigma,Int(p["apn"]),p["algebraic_degree"],
         _closure_template!(db,body),hex2bytes(ortho),Int(encoded),state,lut))
    id
end
function _closure_insert_comparison!(s,candidate_id,target_parent,proof)
    evidence=_closure_text(proof);status=proof["status"]
    if !_closure_normalized(s.db)
        _closure_exec(s.db,"INSERT INTO comparisons(candidate_id,target_parent,status,evidence,session_id) VALUES(?,?,?,?,?)",(candidate_id,target_parent,status,evidence,s.session))
        return
    end
    body=evidence;slots=fill("",9);encoded=false
    if !occursin(_CLOSURE_TOKEN_PREFIX,evidence)
        row=only(_closure_rows(s.db,"SELECT a.lut_hex,b.lut_hex AS target_lut,b.id AS target_id FROM candidates a,parents p JOIN candidates b ON b.id=p.candidate_id WHERE a.id=? AND p.id=?",(candidate_id,target_parent)))
        values=(row["lut_hex"],row["target_lut"],candidate_id,row["target_id"])
        fields=("candidate_lut_hex","target_lut_hex","candidate_sha256","target_sha256")
        encoded=all(get(proof,k,nothing)==v for (k,v) in zip(fields,values))
        if encoded
            for (key,value) in zip(("c:lut","t:lut","c:id","t:id"),values)
                isempty(value) || (body=replace(body,value=>_closure_token(key)))
            end
            for (i,key) in enumerate(_CLOSURE_PROOF_SLOTS)
                pattern=Regex("(?m)^"*key*" = ([^\\n]*)\n")
                matches=collect(eachmatch(pattern,body))
                if length(matches)==1
                    slots[i]=String(only(matches).captures[1])
                    body=replace(body,pattern=>(key*" = "*_closure_token("v$(i-1)")*"\n"))
                end
            end
        end
    end
    _closure_exec(s.db,"INSERT INTO closure_comparisons(candidate_id,target_parent,status,template_id,session_id,encoding,v0,v1,v2,v3,v4,v5,v6,v7,v8) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (candidate_id,target_parent,status,_closure_template!(s.db,body),s.session,Int(encoded),slots...))
    nothing
end
