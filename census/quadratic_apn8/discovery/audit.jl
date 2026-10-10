"""Audit persisted candidates, witness maps and the enumeration ledger without trusting stored verdicts."""
const AUDIT_USAGE=nothing
include("evidence.jl")
include("store.jl")
using .DiscoveryEvidence,.DiscoveryStore,TOML,Dates

function audit_run(dir;baseline=joinpath(@__DIR__,"../results/signature_rebuild"),limit=0)
    limit>=0 || error("invalid audit limit")
    db=DiscoveryStore.SQL.DB("file:"*abspath(joinpath(dir,"run.sqlite"))*"?mode=ro")
    rows(sql,args=())=[Dict(String(k)=>v for (k,v) in pairs(r)) for r in DiscoveryStore.DBI.execute(db,sql,args)]
    reference=open_reference(baseline)
    checked=0;units_checked=0
    try
        DiscoveryStore.execute!(db,"BEGIN")
        only(rows("PRAGMA integrity_check"))["integrity_check"]=="ok" || error("database integrity failure")
        identity=TOML.parse(only(rows("SELECT value FROM metadata WHERE key='run'"))["value"])["identity"]
        expected=identity["reference"]
        all(k->expected[k]==reference.metadata[k],("sha256","manifest_sha256","supplement_sha256","signatures")) || error("reference changed since this experiment")
        archive=joinpath(dir,"source")
        if isdir(archive)
            for (path,digest) in identity["code"]
                filehash(joinpath(archive,path))==digest || error("archived implementation changed: $path")
            end
        end
        for r in rows("SELECT * FROM candidates ORDER BY lut_id"*(limit==0 ? "" : " LIMIT $(limit)"))
            p=classify(hex2bytes(r["lut_hex"]),reference)
            p["lut_sha256"]==r["lut_id"] || error("candidate digest mismatch")
            old=TOML.parse(r["evidence"])
            for key in ("apn","quadratic","algebraic_degree","differential_uniformity","evidence_level")
                p[key]==old[key] || error("candidate evidence changed: $key")
            end
            get(p,"sigma_hash",nothing)==get(old,"sigma_hash",nothing) || error("candidate signature changed")
            Int(p["evidence_level"]=="inequivalent_to_documented_quadratic_corpus")==r["reference_absent"] || error("bad corpus-absence flag")
            checked+=1
        end
        for u in rows("SELECT u.*,s.lut_hex seed_lut FROM units u JOIN seeds s ON s.id=u.seed_id")
            payload=TOML.parse(u["payload"])
            if u["kind"]=="switching"
                parent=hex2bytes(payload["lut_hex"])
                verify_ccz_witness(hex2bytes(u["seed_lut"]),parent,payload["ccz_columns"],payload["ccz_constant"]) || error("invalid parent witness")
                kernels=rows("SELECT * FROM kernels WHERE unit_id=? ORDER BY direction",(u["id"],))
                total=0
                for k in kernels
                    direction=Int(k["direction"]);1<=direction<=255 || error("bad kernel direction")
                    proof=TOML.parse(k["evidence"])
                    basis=hex2bytes.(proof["basis_hex"])
                    length(basis)==k["dimension"] || error("kernel dimension mismatch")
                    all(v->length(v)==256 && all(x->x<=1,v),basis) || error("invalid Boolean kernel basis")
                    evals=rows("SELECT e.*,c.lut_hex FROM evaluations e JOIN candidates c ON c.lut_id=e.lut_id WHERE e.unit_id=? AND e.direction=?",(u["id"],direction))
                    combos=sort!([parse(BigInt,e["combination"]) for e in evals])
                    combos==collect(big(1):length(combos)) || error("noncontiguous combinations")
                    count=(big(1)<<length(basis))-1
                    length(combos)<=count || error("combination beyond kernel quotient")
                    if direction<Int(u["direction"]) || u["status"]=="done"
                        length(combos)==count || error("completed direction has missing evaluations")
                    elseif direction==Int(u["direction"])
                        length(combos)+1==parse(BigInt,u["combination"]) || error("cursor does not match committed evaluations")
                    else
                        isempty(evals) || error("evaluations lie beyond cursor")
                    end
                    for e in evals
                        combination=parse(BigInt,e["combination"]);g=copy(parent)
                        for (j,b) in enumerate(basis)
                            isodd(combination>>(j-1)) || continue
                            for x in 1:256;iszero(b[x]) || (g[x] ⊻= UInt8(direction));end
                        end
                        bytes2hex(g)==e["lut_hex"] || error("switching ledger does not reconstruct candidate")
                        if limit==0
                            properties(g)["apn"]==Bool(e["apn"]) || error("incorrect APN flag in ledger")
                        end
                    end
                    total+=length(combos)
                end
                u["status"]=="done" && (length(kernels)==255 && Int(u["direction"])==256 && parse(BigInt,u["combination"])==1 || error("incomplete completed switching unit"))
                total==only(rows("SELECT COUNT(*) c FROM evaluations WHERE unit_id=?",(u["id"],)))["c"] || error("evaluation has no kernel")
            elseif u["kind"]=="v5"
                cursor=1;total=nothing
                for chunk in rows("SELECT * FROM chunks WHERE unit_id=? ORDER BY first_x",(u["id"],))
                    chunk["first_x"]==cursor || error("extension chunks have a gap")
                    cursor=Int(chunk["next_x"])
                    cursor>chunk["first_x"] || chunk["total_x"]==0 || error("empty committed extension chunk")
                    total===nothing || total==chunk["total_x"] || error("extension space changed")
                    total=chunk["total_x"]
                    u["status"]=="done" && Bool(chunk["capped"]) && error("kernel truncation prevents exhaustion")
                    proof=TOML.parse(chunk["evidence"])
                    for id in proof["candidate_ids"]
                        isempty(rows("SELECT 1 FROM candidates WHERE lut_id=?",(id,))) && error("missing chunk candidate")
                    end
                end
                cursor==u["direction"] || error("extension cursor mismatch")
                u["status"]=="done" && !(total!==nothing && cursor>total) && error("unexhausted extension space")
            end
            units_checked+=1
        end
        for r in rows("SELECT evidence FROM comparisons")
            proof=TOML.parse(r["evidence"])
            proof["status"] in ("equivalent_with_verified_witness","inequivalent_by_quadratic_invariant") &&
                !verify_comparison(proof) && error("invalid comparison certificate")
        end
        result=Dict("candidate_luts_rechecked"=>checked,"units_ledger_checked"=>units_checked,
            "all_candidates_rechecked"=>limit==0,"database_integrity"=>"ok",
            "kernel_completeness"=>"trusted search algorithm; stored basis and coverage ledger checked, not a separate nullspace computation",
            "v5_coverage"=>"contiguous coset ledger; extension filters need algorithm replay",
            "literature_novelty"=>"unresolved","generated_utc"=>string(Dates.now(Dates.UTC)),
            "reference_sha256"=>reference.metadata["sha256"])
        atomic_toml(joinpath(dir,"audit.toml"),result);println(result);result
    finally
        DiscoveryStore.SQL.intransaction(db) && DiscoveryStore.execute!(db,"ROLLBACK")
        DiscoveryStore.SQL.close(db);close_reference(reference)
    end
end
if abspath(PROGRAM_FILE)==(@__FILE__)
    length(ARGS) in (1,3) || error("usage: audit.jl RUN_DIRECTORY [--limit N]")
    audit_run(ARGS[1];limit=length(ARGS)==3 ? parse(Int,ARGS[3]) : 0)
end
