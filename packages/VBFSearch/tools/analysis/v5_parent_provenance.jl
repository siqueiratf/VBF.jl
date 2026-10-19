"""Independent parent-LUT containment checks for campaign or sampled V5 spaces."""
module V5ParentProvenance
using VBF,VBFSearch,SQLite,DBInterface,JSON3,SHA,TOML,Dates
const Q=VBF.QuadraticExtensions
filehash(path)=bytes2hex(open(SHA.sha256,path))

"Extract only the quadratic coordinate forms, using VBF's ANF and encoding."
function parent_component_space(lut)
    F=SBox{8,UInt8}(UInt8.(lut))
    algebraic_degree(F)==2 || error("parent is not quadratic")
    a=anf(F)
    c=UInt16[a[((1<<i)|(1<<j))+1] for i in 0:7 for j in i+1:7]
    first(Q.rref(Q.coord_forms(c,8)))
end
function contained_five_space(parent,forms)
    R=first(Q.rref(UInt32.(forms)))
    length(R)==5 && all(q->q<(UInt32(1)<<28),R) && Q.span_dim(vcat(parent,R))==length(parent)
end
function validate_sample(samplepath)
    raw=JSON3.read(read(samplepath,String))
    if raw isa AbstractVector || !haskey(raw,"parents_sha256")
        return Dict("parent_lut_binding_available"=>false,"scope"=>"No parent manifest supplied; coefficient-space conclusions cannot establish parent/population provenance")
    end
    parentpath=joinpath(dirname(samplepath),"parents.json")
    filehash(parentpath)==String(raw["parents_sha256"]) || error("sample parent-manifest digest mismatch")
    parents_raw=JSON3.read(read(parentpath,String));parents=parents_raw["parents"]
    bases=Dict{Int,Vector{UInt32}}();info=Dict{Int,Any}()
    for p in parents
        id=Int(p["parent_id"]);lut=hex2bytes(String(p["lut_hex"]))
        haskey(p,"candidate_id") && bytes2hex(SHA.sha256(lut))!=p["candidate_id"] && error("sample parent LUT digest mismatch")
        bases[id]=parent_component_space(lut);info[id]=p
    end
    counts=Dict{Int,Int}();G=Q.geometry(8)
    for r in raw["spaces"]
        id=Int(r["parent_id"]);haskey(bases,id) || error("sample references absent parent $id")
        forms=UInt32.(r["forms"]);R=first(Q.rref(forms))
        forms==R && contained_five_space(bases[id],R) || error("sample V5 not canonical/contained in declared parent $id")
        b5=count(q->Q.form_rank(G,q)==8,Q.comp_forms(R))
        b5==Int(r["b5"])==52-Int(r["need"]) || error("sample bent count mismatch for parent $id")
        p=info[id];ordinal=Int(r["parent_v5_index"])
        Int(r["parent_maximizing_v5_count"])==Int(p["maximizing_v5_count"]) || error("sample parent-space count mismatch")
        R==UInt32.(p["maximizing_v5_forms"][ordinal]) || error("sample ordinal does not match parent manifest")
        counts[id]=get(counts,id,0)+1
    end
    for p in parents
        id=Int(p["parent_id"])
        get(counts,id,0)==Int(p["maximizing_v5_count"]) || error("incomplete maximizing-space list for parent $id")
    end
    Dict("parent_lut_binding_available"=>true,"parents_sha256"=>filehash(parentpath),
        "checked_parents"=>length(parents),"checked_spaces"=>length(raw["spaces"]),
        "containment_failures"=>0,"bent_count_failures"=>0,"manifest_count_failures"=>0,
        "scope"=>"Every supplied space is canonical, has the declared bent count, lies in its actual parent quadratic component space, and matches the complete supplied parent list; maximality is supplied by the producer")
end

function validate_global(source,indexpath,output)
    started=time();before=stat(source);db=SQLite.DB("file:"*abspath(source)*"?mode=ro")
    idx=SQLite.DB("file:"*abspath(indexpath)*"?mode=ro")
    DBInterface.execute(db,"PRAGMA query_only=ON");DBInterface.execute(idx,"PRAGMA query_only=ON")
    ids=[Int(r.parent_id) for r in DBInterface.execute(idx,"SELECT DISTINCT parent_id FROM jobs ORDER BY parent_id")]
    bases=Dict{Int,Vector{UInt32}}();invalid_parents=Int[];bad=Dict{String,Int}()
    failures=Dict{String,Any}[];G=Q.geometry(8);ctx=SHA.SHA2_256_CTX();checked=0
    function fail(reason,id,parent)
        bad[reason]=get(bad,reason,0)+1
        length(failures)<20 && push!(failures,Dict("reason"=>reason,"job_id"=>id,"parent_id"=>parent))
    end
    try
        for first_id in 1:512:length(ids)
            wanted=ids[first_id:min(length(ids),first_id+511)]
            query="SELECT p.id,p.candidate_id,c.lut_hex FROM parents p JOIN candidates c ON c.id=p.candidate_id WHERE p.id IN ("*join(fill("?",length(wanted)),',')*")"
            for p in DBInterface.execute(db,query,Tuple(wanted))
                id=Int(p.id);lut=hex2bytes(String(p.lut_hex))
                if bytes2hex(SHA.sha256(lut))!=String(p.candidate_id)
                    push!(invalid_parents,id);continue
                end
                try
                    bases[id]=parent_component_space(lut)
                catch e
                    e isa InterruptException && rethrow()
                    push!(invalid_parents,id)
                end
            end
        end
        original=DBInterface.execute(db,"SELECT j.id,j.parent_id,p.origin,j.payload,j.status,j.result FROM jobs j JOIN parents p ON p.id=j.parent_id WHERE j.kind='v5' ORDER BY j.id")
        derived=DBInterface.execute(idx,"SELECT j.job_id,j.parent_id,j.origin,j.status,s.forms,s.need,s.b5 FROM jobs j JOIN spaces s USING(space_id) ORDER BY j.job_id")
        for (s,r) in zip(original,derived)
            id=Int(s.id);parent=Int(s.parent_id);payload=String(s.payload);origin=String(s.origin);status=String(s.status);result=String(s.result)
            SHA.update!(ctx,codeunits(JSON3.write([id,parent,origin,payload,status,result])*"\n"))
            checked+=1;p=TOML.parse(payload);R=first(Q.rref(UInt32.(p["forms"])))
            canonical=ltoh.(collect(reinterpret(UInt32,Vector{UInt8}(r.forms))))
            id==Int(r.job_id) && parent==Int(r.parent_id) && origin==String(r.origin) && status==String(r.status) &&
                R==canonical && Int(p["need"])==Int(r.need) && Int(p["b5"])==Int(r.b5) || fail("extracted_job_mismatch",id,parent)
            if !haskey(bases,parent) || !contained_five_space(bases[parent],R)
                fail("not_contained_in_actual_parent",id,parent)
            end
            b5=count(q->Q.form_rank(G,q)==8,Q.comp_forms(R))
            b5==Int(p["b5"])==52-Int(p["need"]) || fail("wrong_bent_count",id,parent)
        end
        digest=bytes2hex(SHA.digest!(ctx));expected=""
        for r in DBInterface.execute(idx,"SELECT value FROM metadata WHERE key='ordered_v5_job_roster_sha256'");expected=String(JSON3.read(String(r.value)));end
        after=stat(source);unchanged=before.size==after.size && before.mtime==after.mtime
        report=Dict{String,Any}("schema"=>"vbfsearch-global-v5-parent-provenance-v1","created_utc"=>string(now(UTC))*"Z",
            "source_database"=>abspath(source),"source_bytes"=>before.size,"source_mtime_unix"=>before.mtime,
            "source_unchanged"=>unchanged,"parent_luts_checked"=>length(bases),"prepared_parents"=>length(ids),
            "jobs_checked"=>checked,"invalid_parent_ids"=>invalid_parents,"failures_by_reason"=>bad,"first_failures"=>failures,
            "ordered_v5_job_roster_sha256"=>digest,"expected_roster_sha256"=>expected,"roster_matches"=>digest==expected,
            "implementation_sha256"=>filehash(@__FILE__),"vbf_solver_implementation_sha256"=>VBFSearch.equivalence_solver_fingerprint(),
            "valid"=>isempty(bad) && isempty(invalid_parents) && checked>0 && digest==expected && unchanged,
            "elapsed_seconds"=>time()-started,"scope"=>"Every indexed original V5 job: exact source payload/parent identity, actual parent-LUT component-space containment, exact bent count. Does not re-prove maximality of the chosen spaces or completion coverage.")
        open(io->JSON3.pretty(io,report),output,"w");println(JSON3.write(report));flush(stdout);report
    finally
        close(idx);close(db)
    end
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && V5ParentProvenance.validate_global(ARGS...)
