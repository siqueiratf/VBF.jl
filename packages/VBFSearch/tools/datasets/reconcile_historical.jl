"""Retire historical representatives only after complete positive EA graph replay.

The immutable historical archive and search checkpoints are read-only. A separate
SQLite database exposes unrecovered `classes` and retains every historical row,
positive witness, target LUT, source namespace and unsuccessful attempt. Signature
equality schedules comparisons; it never retires a class. Overlap estimates use
the conditional uniform-sample model of Beierle et al., arXiv:2508.04644, Sec. 5.
Usage: julia --project=docs/inspector --threads=4 reconcile_historical.jl CONFIG.json
"""
module HistoricalReconciliation
using VBF,VBFSearch,SQLite,JSON3,SHA,Dates,TOML
include("verify_comparisons.jl")
const SQL=SQLite.DBInterface
const COLUMNS="class_id,sigma_hash,lut_sha256,lut,source,source_member_idx,source_run"
const SCHEMA="vbfsearch-historical-reconciliation-v1"

"Read a file digest without materializing its bytes."
filehash(path)=bytes2hex(open(SHA.sha256,path))
"Read-only SQLite handles cannot write a source database."
function readonly(path)
    db=SQLite.DB("file:"*abspath(path)*"?mode=ro")
    collect(SQL.execute(db,"PRAGMA query_only=ON"));collect(SQL.execute(db,"PRAGMA busy_timeout=10000"))
    db
end
"Detach rows, including SQLite-owned blob storage, from a short read snapshot."
function rows(db,sql,args=())
    [Dict{String,Any}(String(k)=>(v isa AbstractVector{UInt8} ? copy(v) : v) for (k,v) in pairs(r)) for r in SQL.execute(db,sql,args)]
end
"Commit a complete output batch; failed witness replay rolls back the batch."
function transaction(f,db)
    SQL.execute(db,"BEGIN IMMEDIATE")
    try
        value=f();SQL.execute(db,"COMMIT");value
    catch
        SQL.execute(db,"ROLLBACK");rethrow()
    end
end
"Publish a report atomically, preserving the previous complete JSON on failure."
function atomic_json(path,value)
    write(path*".tmp",JSON3.write(value)*"\n");mv(path*".tmp",path;force=true)
end
"Create the active collection without modifying or duplicating historical archives."
function initialize(history,output;expected_sha256=nothing)
    abspath(history)==abspath(output) && error("historical archive cannot be the output")
    ispath(output) && realpath(history)==realpath(output) && error("historical archive cannot be the output")
    digest=filehash(history)
    expected_sha256===nothing || digest==expected_sha256 || error("historical archive digest changed")
    if !isfile(output)
        mkpath(dirname(output));temporary=output*".initializing"
        ispath(temporary) && rm(temporary)
        source=readonly(history);db=SQLite.DB(temporary)
        try
            SQL.execute(db,"CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL) WITHOUT ROWID")
            SQL.execute(db,"CREATE TABLE source_classes(class_id INTEGER PRIMARY KEY,sigma_hash TEXT NOT NULL UNIQUE,lut_sha256 TEXT NOT NULL UNIQUE,lut BLOB NOT NULL CHECK(length(lut)=256),source TEXT NOT NULL,source_member_idx INTEGER NOT NULL,source_run TEXT NOT NULL)")
            SQL.execute(db,"CREATE TABLE matches(class_id INTEGER NOT NULL REFERENCES source_classes(class_id),collection TEXT NOT NULL,source_identity TEXT NOT NULL,source_path TEXT NOT NULL,target_class_id INTEGER NOT NULL,target_sha256 TEXT NOT NULL,target_lut BLOB NOT NULL CHECK(length(target_lut)=256),witness BLOB NOT NULL CHECK(length(witness)=35),method TEXT NOT NULL,verified_utc TEXT NOT NULL,details TEXT NOT NULL,PRIMARY KEY(class_id,collection,source_identity)) WITHOUT ROWID")
            SQL.execute(db,"CREATE TABLE attempts(class_id INTEGER NOT NULL REFERENCES source_classes(class_id),target_sha256 TEXT NOT NULL,solver_sha256 TEXT NOT NULL,status TEXT NOT NULL,tries INTEGER NOT NULL,next_retry REAL NOT NULL,checked_utc TEXT NOT NULL,PRIMARY KEY(class_id,target_sha256,solver_sha256)) WITHOUT ROWID")
            SQL.execute(db,"CREATE TABLE cycles(id INTEGER PRIMARY KEY,started_utc TEXT NOT NULL,finished_utc TEXT NOT NULL,report TEXT NOT NULL)")
            SQL.execute(db,"CREATE VIEW classes AS SELECT * FROM source_classes s WHERE NOT EXISTS(SELECT 1 FROM matches m WHERE m.class_id=s.class_id)")
            SQL.execute(db,"CREATE VIEW recovered_classes AS SELECT * FROM source_classes s WHERE EXISTS(SELECT 1 FROM matches m WHERE m.class_id=s.class_id)")
            SQL.execute(db,"CREATE VIEW legacy_190454 AS SELECT * FROM classes WHERE class_id<=190454")
            transaction(db) do
                statement=SQLite.Stmt(db,"INSERT INTO source_classes VALUES(?,?,?,?,?,?,?)")
                for r in SQL.execute(source,"SELECT $COLUMNS FROM classes ORDER BY class_id")
                    lut=Vector{UInt8}(r.lut)
                    length(lut)==256 && bytes2hex(SHA.sha256(lut))==r.lut_sha256 || error("historical LUT binding differs")
                    SQL.execute(statement,Tuple(getproperty(r,Symbol(k)) for k in split(COLUMNS,',')))
                end
                for (key,value) in (("schema",SCHEMA),("historical_path",abspath(history)),("historical_sha256",digest))
                    SQL.execute(db,"INSERT INTO metadata VALUES(?,?)",(key,value))
                end
            end
        finally
            close(db);close(source)
        end
        mv(temporary,output)
    end
    db=SQLite.DB(output)
    meta=Dict(r["key"]=>r["value"] for r in rows(db,"SELECT * FROM metadata"))
    meta["schema"]==SCHEMA && meta["historical_sha256"]==digest || error("active collection belongs to another historical archive")
    collect(SQL.execute(db,"PRAGMA foreign_keys=ON"));collect(SQL.execute(db,"PRAGMA journal_mode=WAL"))
    collect(SQL.execute(db,"PRAGMA synchronous=FULL"));collect(SQL.execute(db,"PRAGMA busy_timeout=10000"))
    db
end
"Encode the existing dataset verifier's 35-byte positive EA witness."
function witness(columns,constant)
    vcat(UInt8[1],collect(reinterpret(UInt8,htol.(vcat(UInt16.(columns),UInt16[constant])))))
end
"Find a budgeted EA witness using VBF; inconclusive results never imply equality."
function prove(f,g;cached=nothing,seconds=1.0,nodes=100000)
    if cached!==nothing
        APNDatasetVerification.verify_pair(f,g,cached)
        return (status="equivalent",proof=cached)
    elseif f==g
        proof=witness(UInt16[1<<i for i in 0:15],0)
    else
        result=partition_refinement_equivalence(SBox{8,UInt8}(f),SBox{8,UInt8}(g);
            relation=:ea,algorithm=:optimized,timeout_seconds=seconds,max_nodes=nodes)
        result isa Found || return (status=result isa Exhausted ? "exhausted" : "budget",proof=nothing)
        A=first(result.functions);proof=witness(A.linear.cols,A.constant)
    end
    APNDatasetVerification.verify_pair(f,g,proof)
    (status="equivalent",proof)
end
"Persist only a positive certificate independently replayed on all 256 points."
function record!(db,old,target,proof,collection,identity,path,method,details)
    f=Vector{UInt8}(old["lut"]);g=Vector{UInt8}(target["lut"])
    bytes2hex(SHA.sha256(f))==old["lut_sha256"] || error("historical LUT changed")
    bytes2hex(SHA.sha256(g))==target["sha"] || error("target LUT changed")
    APNDatasetVerification.verify_pair(f,g,proof)
    SQL.execute(db,"INSERT OR IGNORE INTO matches VALUES(?,?,?,?,?,?,?,?,?,?,?)",
        (old["class_id"],collection,identity,abspath(path),target["id"],target["sha"],g,proof,method,string(now(UTC))*"Z",JSON3.write(details)))
end
"Replay the completed published-root comparison in its original ID namespace."
function frozen!(db,freeze,expected_roots;deadline=Inf,expected_sha256=nothing,progress=(_...)->nothing)
    path=joinpath(freeze,"classes.sqlite");digest=filehash(path)
    expected_sha256===nothing || digest==expected_sha256 || error("published-root freeze digest changed")
    report=JSON3.read(read(joinpath(freeze,"comparison.json"),String))
    report.complete && report.all_positive_witnesses_replayed && report.roots_sha256==expected_roots || error("published-root evidence differs")
    source=readonly(path);proofs=readonly(joinpath(freeze,"comparisons.sqlite"))
    proof_digest=filehash(joinpath(freeze,"comparisons.sqlite"))
    try
        positives=rows(proofs,"SELECT * FROM historical WHERE status='equivalent_witness_replayed' ORDER BY historical_class_id")
        for batch in Iterators.partition(positives,256)
            time()>=deadline && break
            transaction(db) do
                for item in batch
                    id=item["historical_class_id"]
                    isempty(rows(db,"SELECT 1 FROM matches WHERE class_id=? AND collection='published_roots' AND source_identity=?",(id,digest))) || continue
                    old=only(rows(db,"SELECT * FROM source_classes WHERE class_id=?",(id,)))
                    target=only(rows(source,"SELECT class_id id,lut_sha256 sha,lut,sigma_hash,observed_output FROM classes WHERE class_id=?",(item["class_id"],)))
                    target["observed_output"]==1 && old["sigma_hash"]==target["sigma_hash"]==item["sigma_hash"] || error("published-root pair binding differs")
                    columns=ltoh.(reinterpret(UInt16,Vector{UInt8}(item["witness_columns"])))
                    proof=witness(columns,item["witness_constant"])
                    record!(db,old,target,proof,"published_roots",digest,path,"cached_ea_replayed",
                        Dict("comparison_sha256"=>proof_digest,"roots_sha256"=>expected_roots,"worker_sha256"=>filehash(@__FILE__)))
                end
            end
            progress("published_root_witnesses")
        end
    finally
        close(source);close(proofs)
    end
    digest
end
"Materialize admitted targets in bounded read queries; never retain a live cursor."
function targets(source,key,value,cutoff)
    key in ("sigma","candidate_id") || error("unsupported target key")
    result=rows(source,"SELECT p.id,c.id sha,c.lut_hex,c.sigma,c.apn,c.degree FROM parents p JOIN candidates c ON c.id=p.candidate_id WHERE p.$key=? AND p.id<=? AND p.origin='discovered' ORDER BY p.id",(value,cutoff))
    for r in result
        r["apn"]==1 && r["degree"]==2 || error("target is not admitted quadratic APN")
        r["lut"]=hex2bytes(r["lut_hex"])
    end
    result
end
"Compare one fixed catalog-audited recursive snapshot, exact matches first."
function current!(db,run;snapshot,deadline=Inf,pair_seconds=1.0,pair_nodes=100000,progress=(_...)->nothing)
    identity=filehash(joinpath(run,"identity.toml"));source=readonly(joinpath(run,"closure.sqlite"))
    cache=readonly(joinpath(run,"reports","classes.sqlite"));solver=VBFSearch.DiscoveryEvidence.solver_fingerprint()
    cutoff=Int(snapshot["parent_cutoff"])
    details=Dict("catalog_parent_cutoff"=>cutoff,"catalog_generated_utc"=>snapshot["generated_utc"],
        "catalog_reference"=>snapshot["reference"],"solver_sha256"=>solver,"worker_sha256"=>filehash(@__FILE__))
    pending()=rows(db,"SELECT s.* FROM source_classes s WHERE NOT EXISTS(SELECT 1 FROM matches m WHERE m.class_id=s.class_id AND m.collection='recursive' AND m.source_identity=?) ORDER BY s.class_id",(identity,))
    function eligible(old,target)
        cached=only(rows(cache,"SELECT sha,sigma,absent FROM classes WHERE id=?",(target["id"],)))
        cached["sha"]==target["sha"] && cached["sigma"]==target["sigma"]==old["sigma_hash"] || error("recursive snapshot pair binding differs")
        cached["absent"]==1
    end
    try
        reused=rows(db,"SELECT m.class_id,m.target_sha256,m.witness FROM matches m WHERE m.collection='published_roots' AND NOT EXISTS(SELECT 1 FROM matches x WHERE x.class_id=m.class_id AND x.collection='recursive' AND x.source_identity=?) ORDER BY m.class_id",(identity,))
        for batch in Iterators.partition(reused,256)
            transaction(db) do
                for prior in batch
                    old=only(rows(db,"SELECT * FROM source_classes WHERE class_id=?",(prior["class_id"],)))
                    found=targets(source,"candidate_id",prior["target_sha256"],cutoff)
                    isempty(found) && continue
                    target=only(found);eligible(old,target) || continue
                    record!(db,old,target,prior["witness"],"recursive",identity,joinpath(run,"closure.sqlite"),"published_root_witness_replayed",details)
                end
            end
            progress("recursive_cached_witnesses")
        end
        for batch in Iterators.partition(pending(),256)
            transaction(db) do
                for old in batch
                    found=targets(source,"candidate_id",old["lut_sha256"],cutoff)
                    isempty(found) && continue
                    target=only(found);eligible(old,target) || continue
                    proof=prove(Vector{UInt8}(old["lut"]),target["lut"]).proof
                    record!(db,old,target,proof,"recursive",identity,joinpath(run,"closure.sqlite"),"exact_lut",details)
                end
            end
            progress("exact_representatives")
        end
        plans=Any[]
        for old in pending()
            candidates=filter(t->eligible(old,t),targets(source,"sigma",old["sigma_hash"],cutoff))
            isempty(candidates) || push!(plans,(old=old,targets=candidates))
            progress("signature_candidates")
        end
        println(JSON3.write(Dict("event"=>"recursive_candidates_prepared","pending_signature_classes"=>length(plans),"parent_cutoff"=>cutoff)));flush(stdout)
        for batch in Iterators.partition(plans,128)
            time()>=deadline && break
            work=Any[]
            for plan in batch
                old=plan.old
                for target in plan.targets
                    prior=rows(db,"SELECT * FROM attempts WHERE class_id=? AND target_sha256=? AND solver_sha256=?",(old["class_id"],target["sha"],solver))
                    tries=isempty(prior) ? 0 : Int(only(prior)["tries"])
                    if !isempty(prior)
                        p=only(prior);(p["status"]=="exhausted" || p["next_retry"]>time()) && continue
                    end
                    push!(work,(old=old,target=target,tries=tries))
                end
            end
            results=Vector{Any}(undef,length(work))
            Threads.@threads for i in eachindex(work)
                item=work[i];remaining=deadline-time()
                results[i]=remaining<=0 ? nothing : prove(Vector{UInt8}(item.old["lut"]),item.target["lut"];
                    seconds=min(pair_seconds*2.0^min(item.tries,5),30.0,remaining),nodes=min(pair_nodes*2^min(item.tries,4),1000000))
            end
            transaction(db) do
                for (item,result) in zip(work,results)
                    result===nothing && continue
                    if result.status=="equivalent"
                        record!(db,item.old,item.target,result.proof,"recursive",identity,joinpath(run,"closure.sqlite"),"ea_witness_replayed",details)
                    end
                    retry=time()+min(1800.0*2.0^min(item.tries,6),86400.0)
                    SQL.execute(db,"INSERT OR REPLACE INTO attempts VALUES(?,?,?,?,?,?,?)",
                        (item.old["class_id"],item.target["sha"],solver,result.status,item.tries+1,retry,string(now(UTC))*"Z"))
                end
            end
            progress("recursive_ea_witnesses")
        end
        unresolved=inequivalent=0;prefix_unresolved=0
        for plan in plans
            id=plan.old["class_id"]
            isempty(rows(db,"SELECT 1 FROM matches WHERE class_id=? AND collection='recursive' AND source_identity=?",(id,identity))) || continue
            exhausted=all(plan.targets) do target
                found=rows(db,"SELECT status FROM attempts WHERE class_id=? AND target_sha256=? AND solver_sha256=?",(id,target["sha"],solver))
                !isempty(found) && only(found)["status"]=="exhausted"
            end
            if exhausted
                inequivalent+=1
            else
                unresolved+=1;prefix_unresolved+=id<=190454
            end
        end
        status=Dict("source_identity"=>identity,"parent_cutoff"=>cutoff,"unresolved"=>unresolved,
            "prefix_unresolved"=>prefix_unresolved,"inequivalent_signature_matches"=>inequivalent,"complete"=>unresolved==0)
        SQL.execute(db,"INSERT OR REPLACE INTO metadata VALUES('current_comparison',?)",(JSON3.write(status),))
    finally
        close(source);close(cache)
    end
    identity
end
"Report fixed-snapshot verified overlap and the explicitly conditional estimator."
function summary(db,snapshot,identity)
    scalar(sql,args=())=Int(only(rows(db,sql,args))["n"])
    total=scalar("SELECT COUNT(*) n FROM source_classes")
    remaining=scalar("SELECT COUNT(*) n FROM classes")
    prefix=scalar("SELECT COUNT(*) n FROM source_classes WHERE class_id<=190454")
    hits=scalar("SELECT COUNT(*) n FROM matches WHERE collection='recursive' AND source_identity=?",(identity,))
    prefixhits=scalar("SELECT COUNT(*) n FROM matches WHERE collection='recursive' AND source_identity=? AND class_id<=190454",(identity,))
    status=JSON3.read(only(rows(db,"SELECT value FROM metadata WHERE key='current_comparison'"))["value"],Dict{String,Any})
    status["source_identity"]==identity && status["parent_cutoff"]==snapshot["parent_cutoff"] || error("comparison coverage differs from snapshot")
    groups=rows(db,"SELECT s.source,COUNT(*) total,SUM(m.class_id IS NOT NULL) overlap FROM source_classes s LEFT JOIN matches m ON m.class_id=s.class_id AND m.collection='recursive' AND m.source_identity=? GROUP BY s.source",(identity,))
    for group in groups
        group["conditional_outside_catalog_estimate"]=group["overlap"]==0 ? nothing : group["total"]*snapshot["confirmed_absent_classes"]/group["overlap"]
    end
    Dict("schema"=>SCHEMA,"status"=>"complete" ,"generated_utc"=>string(now(UTC))*"Z","original_classes"=>total,
        "active_remaining_classes"=>remaining,"recovered_classes"=>total-remaining,
        "published_root_verified_overlap"=>scalar("SELECT COUNT(DISTINCT class_id) n FROM matches WHERE collection='published_roots'"),
        "recursive_verified_overlap"=>hits,"recursive_190454_prefix_overlap"=>prefixhits,
        "recursive_unresolved_classes"=>status["unresolved"],"recursive_comparison_complete"=>status["complete"],
        "recursive_inequivalent_signature_matches"=>status["inequivalent_signature_matches"],
        "recursive_maximum_possible_overlap"=>hits+status["unresolved"],
        "current_snapshot"=>snapshot,"current_identity_sha256"=>identity,
        "overlap_by_source"=>groups,
        "conditional_outside_catalog_estimate"=>(hits==0 ? nothing : total*snapshot["confirmed_absent_classes"]/hits),
        "conditional_prefix_estimate"=>(prefixhits==0 ? nothing : prefix*snapshot["confirmed_absent_classes"]/prefixhits),
        "conditional_total_estimate"=>(prefixhits==0 || !haskey(snapshot,"reference_classes") ? nothing : snapshot["reference_classes"]+prefix*snapshot["confirmed_absent_classes"]/prefixhits),
        "estimate_status"=>"Exploratory uniform-independent-sample model; unfinished witness comparisons make the verified overlap a lower bound. Random seeds do not establish uniform class sampling.",
        "signature_matches_are_not_equivalence"=>true,"original_archive_unchanged"=>true)
end
"Run one resumable pass with a nonblocking Linux process lock."
function main(config_path)
    config=JSON3.read(read(config_path,String),Dict{String,Any});output=abspath(config["output"])
    mkpath(dirname(output));lock=open(output*".lock","w")
    ccall(:flock,Cint,(Cint,Cint),Base.fd(lock),2|4)==0 || (close(lock);return)
    db=nothing;started=string(now(UTC))*"Z"
    try
        current=JSON3.read(read(config["current_pointer"],String),Dict{String,Any})
        run=dirname(current["current_recursive_checkpoint"])
        manifest=TOML.parsefile(joinpath(run,"identity.toml"))
        snapshot=JSON3.read(read(joinpath(run,"reports","catalog.json"),String),Dict{String,Any})
        snapshot["current_run"]==abspath(run) && snapshot["catalog_snapshot_validated"] || error("catalog snapshot is not bound to current campaign")
        db=initialize(config["historical"],output;expected_sha256=config["historical_sha256"])
        last_progress=Ref(0.0)
        function progress(stage)
            time()-last_progress[]<15 && return
            value=Dict("schema"=>SCHEMA,"status"=>"running","stage"=>stage,"generated_utc"=>string(now(UTC))*"Z",
                "original_classes"=>only(rows(db,"SELECT COUNT(*) n FROM source_classes"))["n"],
                "active_remaining_classes"=>only(rows(db,"SELECT COUNT(*) n FROM classes"))["n"],
                "matches_by_collection"=>rows(db,"SELECT collection,COUNT(*) n FROM matches GROUP BY collection"),"current_snapshot"=>snapshot,"active_database"=>output)
            atomic_json(config["report"],value);println(JSON3.write(value));flush(stdout);last_progress[]=time()
        end
        deadline=time()+get(config,"seconds",600.0)
        frozen!(db,config["published_roots"],manifest["roots_sha256"];deadline,expected_sha256=config["published_roots_sha256"],progress)
        identity=current!(db,run;snapshot,deadline,pair_seconds=get(config,"pair_seconds",1.0),pair_nodes=get(config,"pair_nodes",100000),progress)
        report=summary(db,snapshot,identity)
        report["active_database"]=output;report["historical_archive"]=config["historical"]
        SQL.execute(db,"INSERT INTO cycles(started_utc,finished_utc,report) VALUES(?,?,?)",(started,string(now(UTC))*"Z",JSON3.write(report)))
        atomic_json(config["report"],report);println(JSON3.write(report));flush(stdout)
        collect(SQL.execute(db,"PRAGMA wal_checkpoint(TRUNCATE)"))
    finally
        db===nothing || close(db)
        ccall(:flock,Cint,(Cint,Cint),Base.fd(lock),8);close(lock)
    end
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && HistoricalReconciliation.main(only(ARGS))
