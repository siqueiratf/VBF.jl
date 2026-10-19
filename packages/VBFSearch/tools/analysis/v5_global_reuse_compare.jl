isdefined(@__MODULE__,:V5GlobalReuseAudit) || include(joinpath(@__DIR__,"v5_global_reuse_audit.jl"))
isdefined(@__MODULE__,:V5ParentProvenance) || include(joinpath(@__DIR__,"v5_parent_provenance.jl"))

"""Certified classification and frontier lookups against the complete V5 index.

  julia --project=docs/inspector v5_global_reuse_compare.jl classify INDEX_DIR [MAX_PAIRS] [MAX_SECONDS]
  julia --project=docs/inspector v5_global_reuse_compare.jl lookup INDEX_DIR SPACES_JSON OUTPUT_JSON [MAX_SECONDS]

Fingerprint equality is only a filter. Positive decisions replay input maps;
negative decisions require exhaustive transporter searches. Budgets remain
unknown. Neither command modifies the scientific campaign or restarts jobs.
"""
module V5GlobalReuseCompare
using ..V5GlobalReuseAudit
using ..V5ParentProvenance
using VBF,VBFSearch,SQLite,DBInterface,JSON3,SHA,Dates
const A=V5GlobalReuseAudit
const QE=VBF.QuadraticExtensions
columnsblob(v)=Vector{UInt8}(reinterpret(UInt8,htol.(UInt16.(v))))
decodecolumns(v)=ltoh.(collect(reinterpret(UInt16,Vector{UInt8}(v))))

function pair_decision(G,V,W;seconds=0.5,nodes=10000)
    before=time()
    outcome=quadratic_space_transporter(G,V,W;timeout_seconds=seconds,max_nodes=nodes,max_memory_bytes=128*1024^2)
    result=Dict{String,Any}("status"=>outcome isa Found ? "equivalent_witness_replayed" :
        outcome isa Exhausted ? "inequivalent_exhaustive" : "unknown_budget_hit",
        "seconds"=>time()-before,"nodes"=>VBF.nodes_visited(outcome))
    if outcome isa Found
        cols=only(search_solutions(outcome))
        verify_quadratic_space_transporter(G,V,W,cols) || error("transporter certificate failed replay")
        result["columns"]=Int.(cols)
    end
    result
end

function require_complete(db)
    A.getmeta(db,"extraction_complete",false)===true || error("incomplete job extraction")
    A.scalar(db,"SELECT COUNT(*) FROM spaces WHERE fingerprint IS NULL")==0 || error("fingerprinting is incomplete")
    parameters=A.getmeta(db,"fingerprint_parameters")
    parameters["implementation_sha256"]==VBFSearch.equivalence_solver_fingerprint() || error("solver source differs from fingerprint index")
    parameters
end

function classify(directory;max_pairs=100000,max_seconds=600,pair_seconds=0.5)
    tool_start_sha=A.filehash(@__FILE__)
    index=A.openindex(directory;readonly=true);parameters=require_complete(index)
    db=SQLite.DB(joinpath(directory,"equivalence-pairs.sqlite"))
    collect(DBInterface.execute(db,"PRAGMA journal_mode=WAL"))
    DBInterface.execute(db,"CREATE TABLE IF NOT EXISTS metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL) WITHOUT ROWID")
    DBInterface.execute(db,"""CREATE TABLE IF NOT EXISTS pairs(left_id INTEGER,right_id INTEGER,status TEXT NOT NULL,
        columns BLOB,seconds REAL,nodes INTEGER,PRIMARY KEY(left_id,right_id)) WITHOUT ROWID""")
    DBInterface.execute(db,"""CREATE TABLE IF NOT EXISTS buckets(fingerprint TEXT,need INTEGER,spaces INTEGER,
        groups_upper INTEGER,groups_lower INTEGER,complete INTEGER,unknown_pairs INTEGER,
        PRIMARY KEY(fingerprint,need)) WITHOUT ROWID""")
    DBInterface.execute(db,"CREATE TABLE IF NOT EXISTS assignments(space_id INTEGER PRIMARY KEY,representative_id INTEGER NOT NULL)")
    solver=VBFSearch.equivalence_solver_fingerprint()
    previous=A.getmeta(db,"solver_sha256",solver)
    previous==solver || error("cached equivalence decisions use different solver sources")
    previous_parameters=A.getmeta(db,"fingerprint_parameters",parameters)
    all(get(previous_parameters,k,nothing)==parameters[k] for k in keys(parameters)) || error("cached equivalence decisions use different fingerprint parameters")
    roster=A.getmeta(index,"ordered_v5_job_roster_sha256")
    A.getmeta(db,"input_roster_sha256",roster)==roster || error("cached equivalence decisions belong to another input roster")
    A.setmeta(db,"solver_sha256",solver)
    A.setmeta(db,"input_roster_sha256",A.getmeta(index,"ordered_v5_job_roster_sha256"))
    A.setmeta(db,"comparison_tool_sha256",tool_start_sha)
    A.setmeta(db,"fingerprint_parameters",parameters)
    buckets=[(fp=String(r.fingerprint),need=Int(r.need),n=Int(r.n)) for r in DBInterface.execute(index,
        "SELECT fingerprint,need,COUNT(*) n FROM spaces GROUP BY fingerprint,need HAVING COUNT(*)>1 ORDER BY n,fingerprint,need")]
    started=time();attempted=0;G=QE.geometry(8);replayed=0
    try
        for witness in DBInterface.execute(db,"SELECT left_id,right_id,columns FROM pairs WHERE status='equivalent_witness_replayed'")
            V=UInt32[];W=UInt32[]
            for r in DBInterface.execute(index,"SELECT space_id,forms FROM spaces WHERE space_id IN (?,?)",(Int(witness.left_id),Int(witness.right_id)))
                Int(r.space_id)==Int(witness.left_id) ? (V=A.decodeforms(r.forms)) : (W=A.decodeforms(r.forms))
            end
            length(V)==5 && length(W)==5 && verify_quadratic_space_transporter(G,V,W,decodecolumns(witness.columns)) ||
                error("stored positive transporter failed replay")
            replayed+=1
        end
        for bucket in buckets
            time()-started>=max_seconds && break
            A.scalar(db,"SELECT COUNT(*) FROM buckets WHERE fingerprint=? AND need=? AND complete=1",(bucket.fp,bucket.need))>0 && continue
            rows=[(id=Int(r.space_id),forms=A.decodeforms(r.forms)) for r in DBInterface.execute(index,
                "SELECT space_id,forms FROM spaces WHERE fingerprint=? AND need=? ORDER BY space_id",(bucket.fp,bucket.need))]
            representatives=typeof(first(rows))[];matches=0;unknown=0;processed=0;stopped=false
            DBInterface.execute(db,"BEGIN IMMEDIATE")
            for row in rows
                matched=false;representative=row.id
                for rep in representatives
                    cached=nothing
                    for c in DBInterface.execute(db,"SELECT status,columns,seconds,nodes FROM pairs WHERE left_id=? AND right_id=?",(rep.id,row.id))
                        cached=Dict{String,Any}("status"=>String(c.status),"seconds"=>Float64(c.seconds),"nodes"=>Int(c.nodes))
                        !ismissing(c.columns) && (cached["columns"]=Int.(decodecolumns(c.columns)))
                    end
                    if cached===nothing || cached["status"]=="unknown_budget_hit"
                        if attempted>=max_pairs || time()-started>=max_seconds;stopped=true;break;end
                        cached=pair_decision(G,rep.forms,row.forms;seconds=min(pair_seconds,max(0,max_seconds-(time()-started))))
                        attempted+=1
                        DBInterface.execute(db,"INSERT OR REPLACE INTO pairs VALUES(?,?,?,?,?,?)",(rep.id,row.id,cached["status"],
                            haskey(cached,"columns") ? columnsblob(cached["columns"]) : missing,cached["seconds"],cached["nodes"]))
                    end
                    if cached["status"]=="equivalent_witness_replayed"
                        verify_quadratic_space_transporter(G,rep.forms,row.forms,cached["columns"]) || error("cached transporter failed replay")
                        matches+=1;matched=true;representative=rep.id;break
                    elseif cached["status"]=="unknown_budget_hit"
                        unknown+=1
                    end
                end
                stopped && break
                matched || push!(representatives,row)
                DBInterface.execute(db,"INSERT OR REPLACE INTO assignments VALUES(?,?)",(row.id,representative))
                processed+=1
            end
            complete=!stopped && unknown==0 && processed==length(rows)
            upper=length(rows)-matches
            lower=complete ? length(representatives) : 1
            DBInterface.execute(db,"INSERT OR REPLACE INTO buckets VALUES(?,?,?,?,?,?,?)",(bucket.fp,bucket.need,length(rows),upper,lower,Int(complete),unknown))
            DBInterface.execute(db,"COMMIT")
            stopped && break
        end
        jobs=A.scalar(index,"SELECT COUNT(*) FROM jobs");spaces=A.scalar(index,"SELECT COUNT(*) FROM spaces")
        nbuckets=A.scalar(index,"SELECT COUNT(*) FROM (SELECT fingerprint,need FROM spaces GROUP BY fingerprint,need)")
        merged=A.scalar(db,"SELECT COALESCE(SUM(spaces-groups_upper),0) FROM buckets")
        extra_lower=A.scalar(db,"SELECT COALESCE(SUM(groups_lower-1),0) FROM buckets")
        upper=spaces-merged;lower=nbuckets+extra_lower
        report=Dict{String,Any}("schema"=>"vbfsearch-global-v5-equivalence-report-v1","created_utc"=>string(now(UTC))*"Z",
            "ordered_v5_job_roster_sha256"=>A.getmeta(index,"ordered_v5_job_roster_sha256"),
            "comparison_tool_sha256"=>tool_start_sha,"solver_implementation_sha256"=>solver,
            "sources_unchanged_during_classification"=>solver==VBFSearch.equivalence_solver_fingerprint() && tool_start_sha==A.filehash(@__FILE__),
            "fingerprint_parameters"=>parameters,"prepared_jobs"=>jobs,"exact_spaces"=>spaces,
            "necessary_invariant_buckets"=>nbuckets,"collision_buckets"=>length(buckets),
            "collision_buckets_complete"=>A.scalar(db,"SELECT COUNT(*) FROM buckets WHERE complete=1"),
            "unresolved_collision_buckets"=>length(buckets)-A.scalar(db,"SELECT COUNT(*) FROM buckets WHERE complete=1"),
            "new_pair_attempts"=>attempted,"positive_pairs"=>A.scalar(db,"SELECT COUNT(*) FROM pairs WHERE status='equivalent_witness_replayed'"),
            "cached_positive_witnesses_replayed"=>replayed,
            "negative_pairs"=>A.scalar(db,"SELECT COUNT(*) FROM pairs WHERE status='inequivalent_exhaustive'"),
            "unknown_pairs"=>A.scalar(db,"SELECT COUNT(*) FROM pairs WHERE status='unknown_budget_hit'"),
            "distinct_orbits_lower_bound"=>lower,"distinct_orbits_upper_bound"=>upper,
            "reusable_jobs_lower_bound"=>jobs-upper,"reusable_jobs_upper_bound"=>jobs-lower,
            "complete"=>lower==upper,"elapsed_seconds"=>time()-started,
            "scope"=>A.getmeta(index,"population_scope","Input-GL orbits of prepared quadratic five-spaces with matching need, not CCZ classes of parent APNs"),
            "limits"=>Dict("max_pairs"=>max_pairs,"max_seconds"=>max_seconds,"pair_seconds"=>pair_seconds),
            "limitations"=>["Unknown comparisons preserve an interval, never an inequivalence conclusion.",
                "These counts describe prepared V5 jobs, not the unprepared frontier or switching searches.",
                "This audit never marks construction jobs covered or modifies scientific ledgers."])
        open(io->JSON3.pretty(io,report),joinpath(directory,"equivalence-report.json"),"w")
        collect(DBInterface.execute(db,"PRAGMA wal_checkpoint(TRUNCATE)"))
        println(JSON3.write(report));flush(stdout);report
    finally
        close(db);close(index)
    end
end

function lookup(directory,samplepath,output;max_seconds=600,max_pairs=100000,pair_seconds=0.5,sample_index_directory=nothing)
    tool_start_sha=A.filehash(@__FILE__)
    provenance=V5ParentProvenance.validate_sample(samplepath)
    index=A.openindex(directory;readonly=true);parameters=require_complete(index)
    samplebytes=read(samplepath)
    sample_digest=bytes2hex(SHA.sha256(samplebytes))
    raw=JSON3.read(String(samplebytes));spaces=raw isa AbstractVector ? raw : raw["spaces"]
    precomputed=Dict{Int,String}()
    if sample_index_directory!==nothing
        local_index=A.openindex(sample_index_directory;readonly=true)
        try
            local_parameters=require_complete(local_index)
            A.getmeta(local_index,"sample_artifact_sha256")==sample_digest || error("sample fingerprint cache belongs to another artifact")
            all(parameters[k]==local_parameters[k] for k in ("max_rounds","min_active_hyperplanes","implementation_sha256")) ||
                error("sample fingerprint parameters differ")
            for r in DBInterface.execute(local_index,"SELECT j.job_id,s.forms,s.need,s.fingerprint FROM jobs j JOIN spaces s USING(space_id)")
                ordinal=Int(r.job_id);record=spaces[ordinal]
                QE.rref(UInt32.(record["forms"]))[1]==A.decodeforms(r.forms) && Int(record["need"])==Int(r.need) || error("sample cache coefficient mismatch")
                precomputed[ordinal]=String(r.fingerprint)
            end
        finally
            close(local_index)
        end
    end
    G=QE.geometry(8);started=time();attempts=0;results=Dict{String,Any}[]
    try
        for (position,record) in enumerate(spaces)
            forms=QE.rref(UInt32.(record["forms"]))[1];need=Int(record["need"])
            base=Dict{String,Any}(String(k)=>v for (k,v) in pairs(record))
            merge!(base,Dict("sample_index"=>position,"parent_id"=>Int(record["parent_id"]),"need"=>need,
                "forms"=>Int.(forms),"status"=>"unknown_global_budget","candidate_spaces"=>0,"pair_attempts"=>0,
                "complete_expansion_coverage_status"=>"unknown_global_budget"))
            if time()-started<max_seconds
                fp=haskey(precomputed,position) ? precomputed[position] :
                    quadratic_space_fingerprint(G,forms;max_rounds=Int(parameters["max_rounds"]),min_active_hyperplanes=Int(parameters["min_active_hyperplanes"]))
                candidates=[(id=Int(r.space_id),forms=A.decodeforms(r.forms),completed=Int(r.completed_multiplicity)) for r in DBInterface.execute(index,
                    "SELECT space_id,forms,completed_multiplicity FROM spaces WHERE fingerprint=? AND need=? ORDER BY (completed_multiplicity=0),space_id",(fp,need))]
                base["fingerprint"]=fp;base["candidate_spaces"]=length(candidates)
                base["completed_candidate_spaces"]=count(c->c.completed>0,candidates)
                base["status"]=isempty(candidates) ? "absent_by_necessary_invariant" : "inequivalent_exhaustive"
                unknown=false;unknown_completed=false
                for candidate in candidates
                    if forms==candidate.forms
                        base["status"]="exact_prepared_space";base["target_space_id"]=candidate.id
                        base["target_has_complete_expansion"]=candidate.completed>0;break
                    end
                    if attempts>=max_pairs || time()-started>=max_seconds
                        unknown=true;unknown_completed|=candidate.completed>0;continue
                    end
                    decision=pair_decision(G,forms,candidate.forms;seconds=min(pair_seconds,max(0,max_seconds-(time()-started))))
                    attempts+=1;base["pair_attempts"]+=1
                    if decision["status"]=="equivalent_witness_replayed"
                        base["status"]=decision["status"];base["input_columns"]=decision["columns"]
                        base["target_space_id"]=candidate.id;base["target_has_complete_expansion"]=candidate.completed>0;break
                    elseif decision["status"]=="unknown_budget_hit"
                        unknown=true;unknown_completed|=candidate.completed>0
                    end
                end
                unknown && base["status"]=="inequivalent_exhaustive" && (base["status"]="unknown_candidate_comparisons")
                base["complete_expansion_coverage_status"]=get(base,"target_has_complete_expansion",false) ? "covered_by_verified_space" :
                    unknown_completed ? "unknown_completed_candidate_comparisons" :
                    base["completed_candidate_spaces"]==0 ? "not_covered_by_necessary_invariant" : "not_covered_by_exhaustive_comparison"
            end
            push!(results,base)
            position%256==0 && (println(JSON3.write(Dict("event"=>"lookup_progress","spaces"=>position,"pairs"=>attempts,"seconds"=>time()-started)));flush(stdout))
        end
        counts=Dict{String,Int}();coverage=Dict{String,Int}()
        for r in results
            counts[r["status"]]=get(counts,r["status"],0)+1
            c=r["complete_expansion_coverage_status"];coverage[c]=get(coverage,c,0)+1
        end
        report=Dict{String,Any}("schema"=>"vbfsearch-frontier-v5-lookup-v1","created_utc"=>string(now(UTC))*"Z",
            "sample_file"=>abspath(samplepath),"sample_sha256"=>sample_digest,"sample_file_unchanged"=>A.filehash(samplepath)==sample_digest,
            "sampled_spaces"=>length(results),
            "precomputed_sample_fingerprints"=>length(precomputed),
            "input_roster_sha256"=>A.getmeta(index,"ordered_v5_job_roster_sha256"),"comparison_tool_sha256"=>tool_start_sha,
            "comparison_source_unchanged"=>tool_start_sha==A.filehash(@__FILE__),"parent_provenance"=>provenance,
            "solver_implementation_sha256"=>VBFSearch.equivalence_solver_fingerprint(),"fingerprint_parameters"=>parameters,
            "statuses"=>counts,"coverage_statuses"=>coverage,"pair_attempts"=>attempts,"elapsed_seconds"=>time()-started,"results"=>results,
            "limitations"=>["Matching fingerprints are never counted as reuse without exact coefficients or a verified input map.",
                "A matched space from an already-prepared sampled parent is self-coverage, not a forecast for queued parents; stratify by preparation state.",
                "Sample weights and all maximizing spaces per sampled parent must be used for population estimates.",
                "Only matches to a space with a complete expansion can cover future construction work."])
        open(io->JSON3.pretty(io,report),output,"w");report
    finally
        close(index)
    end
end

"Build a separately labelled partial-space index; ordinals are not campaign job IDs."
function sample_index(samplepath,directory;max_seconds=600,max_pairs=100000)
    provenance=V5ParentProvenance.validate_sample(samplepath)
    started=time();mkpath(directory);digest=A.filehash(samplepath)
    raw=JSON3.read(read(samplepath,String));records=raw isa AbstractVector ? raw : raw["spaces"]
    source=joinpath(directory,"sample-maximizer-input.sqlite")
    if !isfile(joinpath(directory,A.INDEX_NAME))
        isfile(source) && error("partial sample staging database exists; choose a fresh directory")
        db=SQLite.DB(source)
        DBInterface.execute(db,"CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT)")
        DBInterface.execute(db,"INSERT INTO metadata VALUES('identity',?)",("derived_data_not_campaign_jobs=true\nsample_sha256=\"$digest\"",))
        DBInterface.execute(db,"CREATE TABLE parents(id INTEGER PRIMARY KEY,origin TEXT)")
        DBInterface.execute(db,"CREATE TABLE jobs(id INTEGER PRIMARY KEY,parent_id INTEGER,kind TEXT,payload TEXT,status TEXT,result TEXT)")
        DBInterface.execute(db,"BEGIN IMMEDIATE")
        for (ordinal,r) in enumerate(records)
            DBInterface.execute(db,"INSERT OR IGNORE INTO parents VALUES(?,?)",(Int(r["parent_id"]),String(r["origin"])))
            forms=QE.rref(UInt32.(r["forms"]))[1];need=Int(r["need"])
            payload="b5=$(52-need)\nneed=$need\nforms=[$(join(Int.(forms),','))]\n"
            DBInterface.execute(db,"INSERT INTO jobs VALUES(?,?,'v5',?,'sampled_unexpanded_space','')",(ordinal,Int(r["parent_id"]),payload))
        end
        DBInterface.execute(db,"COMMIT");close(db)
        A.extract(source,directory)
        local_index=A.openindex(directory)
        A.setmeta(local_index,"sample_artifact_sha256",digest)
        A.setmeta(local_index,"population_scope","Input-GL orbits among every maximizing V5 space of the sampled parents; synthetic ordinals are not campaign job IDs and confer no completed-work coverage")
        close(local_index)
    end
    check=A.openindex(directory;readonly=true)
    try
        A.getmeta(check,"sample_artifact_sha256")==digest || error("local sample index belongs to another sample artifact")
    finally
        close(check)
    end
    A.fingerprint_index(directory;max_seconds=max(0,max_seconds-(time()-started)),batch_size=512)
    local_report_path=joinpath(directory,"index-report.json")
    local_report=JSON3.read(read(local_report_path,String),Dict{String,Any})
    local_report["scope"]="Every maximizing five-space of the sampled parents; synthetic ordinals are not campaign job IDs or completed searches"
    local_report["source_kind"]="sample_maximizing_five_spaces"
    open(io->JSON3.pretty(io,local_report),local_report_path,"w")
    report=classify(directory;max_seconds=max(0,max_seconds-(time()-started)),max_pairs)
    index=A.openindex(directory;readonly=true);pairdb=SQLite.DB("file:"*joinpath(abspath(directory),"equivalence-pairs.sqlite")*"?mode=ro")
    try
        assignments=Dict(Int(r.space_id)=>Int(r.representative_id) for r in DBInterface.execute(pairdb,"SELECT * FROM assignments"))
        complete_buckets=Set((String(r.fingerprint),Int(r.need)) for r in DBInterface.execute(pairdb,"SELECT fingerprint,need FROM buckets WHERE complete=1"))
        parents=Dict{Int,Vector{NamedTuple}}()
        for r in DBInterface.execute(index,"SELECT j.parent_id,s.space_id,s.fingerprint,s.need FROM jobs j JOIN spaces s USING(space_id) ORDER BY j.job_id")
            id=Int(r.space_id)
            push!(get!(()->NamedTuple[],parents,Int(r.parent_id)),(id=id,representative=get(assignments,id,id),fp=String(r.fingerprint),need=Int(r.need)))
        end
        parent_reports=Dict{String,Any}[]
        for parent in sort!(collect(keys(parents)))
            rows=parents[parent];keys=unique((r.fp,r.need) for r in rows)
            upper=length(unique(r.representative for r in rows));lower=length(keys)
            for key in keys
                key in complete_buckets || continue
                lower+=length(unique(r.representative for r in rows if (r.fp,r.need)==key))-1
            end
            push!(parent_reports,Dict("parent_id"=>parent,"maximizing_spaces"=>length(rows),"distinct_orbits_lower_bound"=>lower,
                "distinct_orbits_upper_bound"=>upper,"reusable_spaces_lower_bound"=>length(rows)-upper,
                "reusable_spaces_upper_bound"=>length(rows)-lower,"complete"=>lower==upper))
        end
        summary=Dict("schema"=>"vbfsearch-sampled-parent-v5-orbits-v1","sample_sha256"=>digest,"parents"=>parent_reports,
            "parent_provenance"=>provenance,
            "sample_space_orbits"=>report,"elapsed_seconds"=>time()-started,
            "scope"=>"Within-parent redundancy bounds use every maximizing space of each sampled parent; cross-parent sample collisions are descriptive and not a population-wide reuse estimate")
        open(io->JSON3.pretty(io,summary),joinpath(directory,"parent-orbits.json"),"w")
        summary
    finally
        close(pairdb);close(index)
    end
end
function main(args=ARGS)
    args[1]=="classify" && return classify(args[2];max_pairs=length(args)>=3 ? parse(Int,args[3]) : 100000,max_seconds=length(args)>=4 ? parse(Float64,args[4]) : 600)
    args[1]=="lookup" && return lookup(args[2],args[3],args[4];max_seconds=length(args)>=5 ? parse(Float64,args[5]) : 600,
        sample_index_directory=length(args)>=6 ? args[6] : nothing)
    args[1]=="sample" && return sample_index(args[2],args[3];max_seconds=length(args)>=4 ? parse(Float64,args[4]) : 600)
    error("expected classify, lookup, or sample")
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && V5GlobalReuseCompare.main()
