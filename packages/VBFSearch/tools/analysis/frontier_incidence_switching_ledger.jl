"""Read-only switching-ledger census and historical packet timing audit.

All mathematical dimensions come from the saved complete Boolean kernels or a
separately produced quadratic certificate artifact; this tool implements no
switching mathematics and never opens a campaign for writing.
"""
module FrontierIncidenceSwitchingLedger
using SQLite, DBInterface, JSON3, SHA, TOML, Dates
file_sha(path)=bytes2hex(open(SHA.sha256,path))
read_json(path)=JSON3.read(read(path,String),Dict{String,Any})
function write_json(path,value)
    mkpath(dirname(path));open(io->JSON3.pretty(io,value),path,"w")
end

function check_evidence(direction,dimension,text)
    e=TOML.parse(text)
    e["complete_constraints"]===true || error("incomplete Boolean constraints")
    e["direction"]==direction && e["quotient_dimension"]==dimension || error("dimension/cursor mismatch")
    length(e["basis_hex"])==dimension || error("basis dimension mismatch")
    e["raw_dimension"]==16+dimension || error("unexpected affine/component quotient")
    return e
end

function packet_timings(path)
    started=time();before=stat(path)
    kinds=Dict{String,Any}();count=0
    for line in eachline(path)
        isempty(strip(line)) && continue
        r=JSON3.read(line,Dict{String,Any});kind=r["kind"]
        group=get!(kinds,kind) do
            Dict("packets"=>0,"compute_wall_seconds"=>0.0,
                "application_wall_seconds"=>0.0,"processed_cosets"=>0)
        end
        group["packets"]+=1;count+=1
        for key in ("compute_wall_seconds","application_wall_seconds")
            value=Float64(r[key]);value>=0 && isfinite(value) || error("invalid timing")
            group[key]+=value
        end
        group["processed_cosets"]+=get(r,"processed_cosets",0)
    end
    before.size==stat(path).size && before.mtime==stat(path).mtime || error("timing source changed")
    total=sum(g["compute_wall_seconds"] for g in values(kinds))
    switching=get(kinds,"switching",Dict("compute_wall_seconds"=>0.0))["compute_wall_seconds"]
    return Dict("path"=>abspath(path),"sha256"=>file_sha(path),"bytes"=>before.size,
        "packets"=>count,"kinds"=>kinds,"total_compute_wall_seconds"=>total,
        "switching_fraction_of_compute_wall"=>switching/total,
        "v5_fraction_of_compute_wall"=>get(kinds,"v5",Dict("compute_wall_seconds"=>0.0))["compute_wall_seconds"]/total,
        "elapsed_seconds"=>time()-started,
        "interpretation"=>"Sum of measured packet wall durations; parallel waiting and GC may be included. These are not CPU seconds or elapsed campaign wall time.")
end

function audit(database,certificates,timing_path,output)
    started=time();before=stat(database)
    certificate=read_json(certificates)
    certificate["complete"]===true || error("incomplete quadratic certificate sample")
    parent_source=certificate["input"]
    certificate["input_sha256"]==file_sha(parent_source) || error("certificate parent source changed")
    db=SQLite.DB("file:"*abspath(database)*"?mode=ro")
    DBInterface.execute(db,"PRAGMA query_only=ON");DBInterface.execute(db,"PRAGMA cache_size=-8192")
    try
        jobs=Dict{Int,Any}();by_parent=Dict{Int,Int}()
        for row in DBInterface.execute(db,"SELECT j.id,j.parent_id,j.status,p.origin FROM jobs j JOIN parents p ON p.id=j.parent_id WHERE j.kind='switching'")
            j=(;parent_id=Int(row.parent_id),status=String(row.status),origin=String(row.origin))
            jobs[Int(row.id)]=j;by_parent[j.parent_id]=Int(row.id)
        end
        strata=Dict{String,Dict{String,Int}}();global_hist=Dict{String,Int}();job_counts=Dict{Int,Int}()
        for row in DBInterface.execute(db,"SELECT job_id,dimension,COUNT(*) n FROM kernels GROUP BY job_id,dimension")
            job=jobs[Int(row.job_id)];dim=string(row.dimension);n=Int(row.n)
            stratum=get!(strata,job.origin,Dict{String,Int}())
            stratum[dim]=get(stratum,dim,0)+n
            global_hist[dim]=get(global_hist,dim,0)+n
            job_counts[Int(row.job_id)]=get(job_counts,Int(row.job_id),0)+n
        end
        count_parent_incomplete=0
        for (id,count) in job_counts
            0<=count<=255 || error("invalid direction coverage")
            jobs[id].status=="done" && count!=255 && error("completed switching job lacks all directions")
            count<255 && (count_parent_incomplete+=1)
        end
        rare=Dict{String,Any}[]
        for row in DBInterface.execute(db,"SELECT job_id,direction,dimension,evidence FROM kernels WHERE dimension>0")
            job=jobs[Int(row.job_id)];e=check_evidence(Int(row.direction),Int(row.dimension),String(row.evidence))
            push!(rare,Dict("job_id"=>Int(row.job_id),"parent_id"=>job.parent_id,
                "origin"=>job.origin,"direction"=>Int(row.direction),"quotient_dimension"=>Int(row.dimension),
                "raw_dimension"=>e["raw_dimension"],"evidence_sha256"=>bytes2hex(sha256(String(row.evidence)))))
        end
        comparisons=Dict{String,Any}[];matched=0;uncertified=0;total_directions=0
        for parent in certificate["parents"]
            id=Int(parent["parent_id"]);haskey(by_parent,id) || continue
            jobid=by_parent[id];directions=0
            for row in DBInterface.execute(db,"SELECT direction,dimension,evidence FROM kernels WHERE job_id=? ORDER BY direction",(jobid,))
                u=Int(row.direction);dimension=Int(row.dimension)
                e=check_evidence(u,dimension,String(row.evidence));directions+=1;total_directions+=1
                qdim=parent["quadratic_dimensions"][u]
                e["raw_dimension"]>=9+qdim || error("Boolean kernel lost quadratic solutions")
                if parent["certificates"][u]!="unknown"
                    e["raw_dimension"]==9+qdim || error("quadratic certificate contradicted by stored Boolean ledger")
                    matched+=1
                else
                    uncertified+=1
                end
            end
            directions>0 && push!(comparisons,Dict("parent_id"=>id,"job_id"=>jobid,"directions_checked"=>directions,
                "origin"=>jobs[jobid].origin,"uniform_parent_sample"=>parent["uniform_parent_sample"]))
        end
        timings=packet_timings(timing_path)
        after=stat(database)
        before.size==after.size && before.mtime==after.mtime || error("campaign database changed")
        result=Dict("schema"=>"vbfsearch-switching-ledger-audit-v1","created_utc"=>string(now(UTC)),
            "database"=>abspath(database),"database_bytes"=>before.size,"database_mtime"=>before.mtime,
            "tool_sha256"=>file_sha(@__FILE__),"certificate_path"=>abspath(certificates),
            "certificate_sha256"=>file_sha(certificates),"parent_source_sha256"=>certificate["input_sha256"],
            "kernel_directions"=>sum(values(global_hist)),"kernel_quotient_dimension_histogram"=>global_hist,
            "kernel_quotient_dimensions_by_origin"=>strata,"parents_with_kernel_records"=>length(job_counts),
            "parents_with_partial_direction_coverage"=>count_parent_incomplete,"nontrivial_directions"=>rare,
            "sample_parent_comparisons"=>comparisons,"stored_sample_directions_checked"=>total_directions,
            "certified_sample_directions_matching_full_boolean"=>matched,"uncertified_sample_directions"=>uncertified,
            "all_checked_evidence_complete_and_dimension_consistent"=>true,"timings"=>timings,
            "elapsed_seconds"=>time()-started,
            "scope"=>"Saved complete Boolean kernel census; cross-checks only sampled prepared parents. No APN search or campaign write.")
        write_json(output,result)
        println(JSON3.write(Dict(k=>result[k] for k in ("kernel_quotient_dimension_histogram","stored_sample_directions_checked","elapsed_seconds"))))
        return result
    finally
        close(db)
    end
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==4 || error("expected DATABASE CERTIFICATES PACKET_TIMINGS OUTPUT")
    audit(ARGS...)
end
end
