"""Resolve equal-signature quadratic APN buckets using explicit bounded pair checks.

Classes refer only to the frozen candidate snapshot, never the full APN space.
Positive witnesses join components; neither sigma equality nor an inconclusive
pair is used to merge. Existing pair results are reused at exact LUT identities.
"""
const CLASSIFICATION_USAGE=nothing
isdefined(@__MODULE__,:DiscoveryEvidence) || include("evidence.jl")
using .DiscoveryEvidence,TOML,SHA,Dates

function classify_snapshot(dir;seconds=30.0,nodes=1_000_000,max_pairs=100)
    seconds>=0 && nodes>=0 && max_pairs>=0 || error("invalid classification budget")
    db=DiscoveryEvidence.SQL.DB(joinpath(dir,"run.sqlite"))
    rows(sql,args=())=[Dict(String(k)=>v for (k,v) in pairs(r)) for r in DiscoveryEvidence.DBI.execute(db,sql,args)]
    execute(sql,args=())=foreach(_->nothing,DiscoveryEvidence.DBI.execute(db,sql,args))
    try
        execute("PRAGMA busy_timeout=10000")
        execute("PRAGMA synchronous=FULL")
        execute("BEGIN")
        candidates=Dict{String,Dict{String,Any}}()
        groups=Dict{String,Vector{String}}()
        for row in rows("SELECT lut_id,lut_hex,evidence FROM candidates ORDER BY lut_id")
            old=TOML.parse(row["evidence"])
            get(old,"apn",false) && get(old,"quadratic",false) || continue
            p=properties(hex2bytes(row["lut_hex"]))
            p["apn"] && p["quadratic"] && p["lut_sha256"]==row["lut_id"] && p["sigma_hash"]==old["sigma_hash"] || error("invalid candidate evidence")
            candidates[row["lut_id"]]=p
            push!(get!(groups,p["sigma_hash"],String[]),row["lut_id"])
        end
        saved=rows("SELECT * FROM comparisons")
        execute("COMMIT")
        parent=Dict(id=>id for id in keys(candidates))
        root=function(id)
            while parent[id]!=id;id=parent[id];end
            id
        end
        function accept(proof)
            a,b=proof["candidate_sha256"],proof["target_sha256"]
            haskey(candidates,a) && haskey(candidates,b) || return
            if proof["status"]=="equivalent_with_verified_witness"
                verify_comparison(proof) || error("invalid saved positive witness")
                candidates[a]["sigma_hash"]==candidates[b]["sigma_hash"] || error("witness contradicts quadratic invariant")
                ra,rb=root(a),root(b);parent[max(ra,rb)]=min(ra,rb)
            end
        end
        for row in saved;accept(TOML.parse(row["evidence"]));end
        # A completed negative is reusable; a budget stop is eligible for a
        # later retry with larger limits. Process each initial pair at most once.
        negative=Set{Tuple{String,String}}()
        for row in saved
            proof=TOML.parse(row["evidence"])
            proof["relation"] in ("ea","ccz") || continue
            proof["status"]=="inequivalent_by_exhaustive_solver" || continue
            a,b=proof["candidate_sha256"],proof["target_sha256"]
            haskey(candidates,a) && haskey(candidates,b) && push!(negative,minmax(a,b))
        end
        attempted=0;inconclusive=0
        for hash in sort!(collect(keys(groups)))
            ids=groups[hash]
            for i in 1:length(ids),j in (i+1):length(ids)
                a,b=ids[i],ids[j]
                root(a)==root(b) && continue
                minmax(a,b) in negative && continue
                attempted>=max_pairs && continue
                proof=compare(hex2bytes(candidates[a]["lut_hex"]),hex2bytes(candidates[b]["lut_hex"]);
                    relation=:ea,timeout_seconds=seconds,max_nodes=nodes)
                execute("INSERT INTO comparisons(candidate_id,target_id,relation,evidence) VALUES(?,?,?,?)",
                    (a,b,"ea",sprint(io->TOML.print(io,proof;sorted=true))))
                attempted+=1;accept(proof)
                proof["status"]=="inequivalent_by_exhaustive_solver" && push!(negative,minmax(a,b))
                proof["status"]=="inconclusive_budget" && (inconclusive+=1)
            end
        end
        components=Dict{String,Vector{String}}()
        for id in sort!(collect(keys(candidates)));push!(get!(components,root(id),String[]),id);end
        separated=Set(minmax(root(a),root(b)) for (a,b) in negative)
        any(a==b for (a,b) in separated) && error("positive and negative equivalence evidence contradict")
        unresolved=0
        for ids in values(groups)
            reps=sort!(unique(root.(ids)))
            for i in 1:length(reps),j in (i+1):length(reps)
                minmax(reps[i],reps[j]) in separated || (unresolved+=1)
            end
        end
        result=Dict("scope"=>"frozen quadratic APN candidate snapshot only",
            "snapshot_luts"=>length(candidates),"candidate_set_sha256"=>bytes2hex(sha256(join(sort!(collect(keys(candidates))),"\n"))),
            "signature_class_lower_bound"=>length(groups),"proven_equivalence_components"=>length(components),
            "exact_snapshot_class_count_established"=>unresolved==0,"unresolved_component_pairs"=>unresolved,
            "pair_checks_this_session"=>attempted,"inconclusive_checks_this_session"=>inconclusive,
            "components"=>components,"literature_novelty"=>"unresolved",
            "negative_dependency"=>"trusted complete native EA solver; Yoshiara 2012 applies to verified quadratic APNs",
            "created_utc"=>string(Dates.now(Dates.UTC)))
        open(io->TOML.print(io,result;sorted=true),joinpath(dir,"classification.toml.tmp"),"w")
        mv(joinpath(dir,"classification.toml.tmp"),joinpath(dir,"classification.toml");force=true)
        result
    finally
        DiscoveryEvidence.SQL.intransaction(db) && execute("ROLLBACK")
        DiscoveryEvidence.SQL.close(db)
    end
end
if abspath(PROGRAM_FILE)==(@__FILE__)
    length(ARGS) in (1,7) || error("usage: classify.jl RUN_DIRECTORY [--seconds S --nodes N --max-pairs P]")
    cfg=Dict("seconds"=>"30","nodes"=>"1000000","max-pairs"=>"100")
    for i in 2:2:length(ARGS)
        key=replace(ARGS[i],r"^--"=>"");haskey(cfg,key) || error("unknown option $key");cfg[key]=ARGS[i+1]
    end
    result=classify_snapshot(ARGS[1];seconds=parse(Float64,cfg["seconds"]),nodes=parse(Int,cfg["nodes"]),max_pairs=parse(Int,cfg["max-pairs"]))
    println("$(result["proven_equivalence_components"]) proven components; $(result["unresolved_component_pairs"]) unresolved pairs; exact snapshot count: $(result["exact_snapshot_class_count_established"])")
end
