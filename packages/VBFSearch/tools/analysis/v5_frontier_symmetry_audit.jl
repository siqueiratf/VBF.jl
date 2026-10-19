"""Probability sample of the entire stopped parent frontier, including unprepared parents.

This tool only prepares component spaces and audits their input stabilizers.
It never enumerates APN extensions or modifies a campaign database.

  julia --project=docs/inspector --threads=2 v5_frontier_symmetry_audit.jl \
    --database closure.sqlite --output evidence --parents 1024 --supplement 64

`--phase frame|prepare|validate|audit|orbits|all` supports reviewable, restartable stages.
"""
module V5FrontierSymmetryAudit
using VBF, SQLite, DBInterface, JSON3, SHA, Random, Statistics, Dates
const QE=VBF.QuadraticExtensions

function configuration(args)
    opts=Dict("parents"=>"1024","supplement"=>"64","seed"=>"20261018",
        "phase"=>"all","max-seconds"=>"900","solver-seconds"=>"1.0",
        "solver-nodes"=>"10000","solver-memory-mib"=>"512","work-proxies"=>"16",
        "orbit-spaces"=>"256")
    iseven(length(args)) || throw(ArgumentError("expected --option value pairs"))
    for i in 1:2:length(args)
        startswith(args[i],"--") || throw(ArgumentError("expected --option"))
        name=args[i][3:end]
        name in ("database","output",keys(opts)...) || throw(ArgumentError("unknown option $name"))
        opts[name]=args[i+1]
    end
    all(k->haskey(opts,k),("database","output")) || throw(ArgumentError("--database and --output are required"))
    opts["phase"] in ("frame","prepare","validate","audit","orbits","all") || throw(ArgumentError("unknown phase"))
    config=(; database=abspath(opts["database"]), output=abspath(opts["output"]),
        parents=parse(Int,opts["parents"]),supplement=parse(Int,opts["supplement"]),
        seed=parse(UInt64,opts["seed"]),phase=opts["phase"],
        max_seconds=parse(Float64,opts["max-seconds"]),
        solver_seconds=parse(Float64,opts["solver-seconds"]),solver_nodes=parse(Int,opts["solver-nodes"]),
        solver_memory=parse(Int,opts["solver-memory-mib"])*1024^2,
        work_proxies=parse(Int,opts["work-proxies"]),orbit_spaces=parse(Int,opts["orbit-spaces"]))
    config.parents>0 && config.supplement>=0 && config.max_seconds>0 &&
        config.solver_seconds>=0 && config.solver_nodes>=0 && config.solver_memory>=0 &&
        config.work_proxies>=0 && config.orbit_spaces>=0 || throw(ArgumentError("invalid sample or budget"))
    return config
end

function write_json(path,value)
    mkpath(dirname(path))
    open(path*".tmp","w") do io; JSON3.pretty(io,value); end
    mv(path*".tmp",path;force=true)
end

read_json(path)=JSON3.read(read(path,String),Dict{String,Any})
file_sha(path)=bytes2hex(open(SHA.sha256,path))

"Ordinary reservoir sampling: exactly min(capacity, seen) distinct records."
function reservoir_add!(sample,record,seen,capacity,rng)
    capacity>=0 && seen>=1 || throw(ArgumentError("invalid reservoir bounds"))
    capacity==0 && return sample
    if length(sample)<capacity
        push!(sample,record)
    else
        k=rand(rng,1:seen)
        k<=capacity && (sample[k]=record)
    end
    return sample
end

"Bind the implementation actually used by preparation and stabilizer discovery."
function implementation()
    root=joinpath(pkgdir(VBF),"src")
    paths=String[]
    for chapter in ("representations","linalg","spectra","equivalence/partition_refinement")
        append!(paths,[joinpath(dir,name) for (dir,_,names) in walkdir(joinpath(root,chapter))
            for name in names if endswith(name,".jl")])
    end
    append!(paths,[joinpath(root,"constructions",name) for name in
        ("quadratic_extensions.jl","quadratic_space_equivalence.jl","quadratic_extension_symmetry.jl")])
    files=[Dict("path"=>relpath(path,root),"sha256"=>file_sha(path)) for path in sort!(unique(paths))]
    binding=join([r["path"]*":"*r["sha256"]*"\n" for r in files])
    return Dict("sha256"=>bytes2hex(sha256(binding)),"files"=>files,
        "julia_version"=>string(VERSION),"tool_sha256"=>file_sha(@__FILE__))
end

function readonly(database)
    db=SQLite.DB("file:"*abspath(database)*"?mode=ro")
    DBInterface.execute(db,"PRAGMA query_only=ON")
    DBInterface.execute(db,"PRAGMA cache_size=-8192")
    return db
end

"Sample all parents, with separately labelled rare-stratum supplements."
function sample_frame(database; parents=1024,supplement=64,seed=UInt64(20261018))
    parents>0 && supplement>=0 || throw(ArgumentError("invalid sample size"))
    before=stat(database)
    db=readonly(database)
    uniform=Dict{String,Any}[]
    supplementary=Dict("root"=>Dict{String,Any}[],"discovered_prepared"=>Dict{String,Any}[])
    rng=Xoshiro(seed)
    supplement_rng=Dict("root"=>Xoshiro(seed ⊻ 0x726f6f74),
        "discovered_prepared"=>Xoshiro(seed ⊻ 0x64697363))
    supplement_populations=Dict("root"=>0,"discovered_prepared"=>0)
    populations=Dict{String,Int}()
    ctx=SHA.SHA2_256_CTX()
    total=0;last_id=0;identity=""
    try
        for row in DBInterface.execute(db,"SELECT value FROM metadata WHERE key='identity'")
            identity=String(row.value)
        end
        query="""SELECT p.id,p.candidate_id,p.origin,
            COALESCE(v.status,'missing') AS prepare_status,
            COALESCE(s.status,'missing') AS switching_status,
            EXISTS(SELECT 1 FROM jobs x WHERE x.parent_id=p.id AND x.kind='v5' AND x.status!='done') AS unfinished_v5
            FROM parents p
            LEFT JOIN jobs v ON v.parent_id=p.id AND v.kind='prepare_v5'
            LEFT JOIN jobs s ON s.parent_id=p.id AND s.kind='switching'
            ORDER BY p.id"""
        for row in DBInterface.execute(db,query)
            id=Int(row.id);id>last_id || error("duplicate/nonordered parent frame row")
            last_id=id;total+=1
            prepared=String(row.prepare_status)=="done"
            complete=prepared && String(row.switching_status)=="done" && row.unfinished_v5==0
            state=complete ? "complete" : prepared ? "queued_prepared" : "queued_unprepared"
            record=Dict{String,Any}("parent_id"=>id,"candidate_id"=>String(row.candidate_id),
                "origin"=>String(row.origin),"prepare_status"=>String(row.prepare_status),
                "switching_status"=>String(row.switching_status),"unfinished_v5"=>row.unfinished_v5!=0,
                "prepared_parent"=>prepared,"completed_parent"=>complete,
                "queued_parent"=>!complete,"queue_state"=>state)
            SHA.update!(ctx,codeunits(JSON3.write([id,record["candidate_id"],record["origin"],
                record["prepare_status"],record["switching_status"],record["unfinished_v5"]])*"\n"))
            key=record["origin"]*"/"*state
            populations[key]=get(populations,key,0)+1
            reservoir_add!(uniform,record,total,parents,rng)
            stratum=record["origin"]=="root" ? "root" : prepared ? "discovered_prepared" : nothing
            if stratum!==nothing
                supplement_populations[stratum]+=1
                reservoir_add!(supplementary[stratum],record,supplement_populations[stratum],
                    supplement,supplement_rng[stratum])
            end
        end
        expected=Int(first(DBInterface.execute(db,"SELECT count(*) AS n FROM parents")).n)
        expected==total || error("parent frame count mismatch")
        selected=Dict{Int,Dict{String,Any}}()
        for record in uniform
            selected[record["parent_id"]]=merge(record,Dict{String,Any}(
                "sample_designs"=>["uniform_parents"],"uniform_parent_sample"=>true))
        end
        for (stratum,records) in supplementary, record in records
            value=get!(()->merge(record,Dict{String,Any}("sample_designs"=>String[],
                "uniform_parent_sample"=>false)),selected,record["parent_id"])
            push!(value["sample_designs"],"supplement_"*stratum)
        end
        chosen=sort!(collect(values(selected));by=r->r["parent_id"])
        for record in chosen
            record["uniform_parent_inclusion_probability"]=min(parents,total)/total
            record["uniform_parent_design_weight"]=total/min(parents,total)
            for stratum in keys(supplementary)
                "supplement_"*stratum in record["sample_designs"] || continue
                record["supplement_inclusion_probability"]=min(supplement,supplement_populations[stratum])/supplement_populations[stratum]
            end
            rows=DBInterface.execute(db,"SELECT lut_hex,sigma,apn,degree,class_id FROM candidates WHERE id=?",
                (record["candidate_id"],))
            # SQLite.Row is a cursor view. Detach values before advancing to
            # SQLITE_DONE, rather than retaining an invalidated row object.
            row=only([(lut_hex=String(r.lut_hex),sigma=String(r.sigma),
                apn=Int(r.apn),degree=Int(r.degree),class_id=Int(r.class_id)) for r in rows])
            row.apn==1 && row.degree==2 && row.class_id==record["parent_id"] || error("invalid parent record")
            lut_hex=String(row.lut_hex)
            bytes2hex(sha256(hex2bytes(lut_hex)))==record["candidate_id"] || error("parent LUT digest mismatch")
            record["lut_hex"]=lut_hex;record["sigma_hash"]=String(row.sigma)
        end
        after=stat(database)
        before.size==after.size && before.mtime==after.mtime || error("campaign database changed during frame scan")
        frame=Dict{String,Any}("schema"=>"vbfsearch-parent-probability-frame-v1",
            "database"=>abspath(database),"database_bytes"=>after.size,"database_mtime_unix"=>after.mtime,
            "campaign_identity_sha256"=>bytes2hex(sha256(identity)),
            "ordered_parent_roster_sha256"=>bytes2hex(SHA.digest!(ctx)),
            "roster_digest_scope"=>"All parents ordered by id; JSON arrays[id,candidate_id,origin,prepare_status,switching_status,unfinished_v5] with newline",
            "population_parents"=>total,"population_strata"=>populations,
            "supplement_populations"=>supplement_populations,"seed"=>seed,
            "uniform_sample_size"=>length(uniform),"supplement_per_stratum"=>supplement,
            "selected_unique_parents"=>length(chosen),
            "sampling"=>"Seeded Xoshiro reservoir SRS without replacement over every admitted parent, independent of preparation; separate labelled SRS rare-stratum supplements",
            "supplement_estimator_rule"=>"Supplements are descriptive only and excluded from the uniform-parent population estimates")
        return frame,chosen
    finally
        close(db)
    end
end

"One VBF subspace pass retains every eventual maximum, then drops earlier records."
function maximizing_component_spaces(G,F;k=G.n-3)
    a=anf(F)
    coefficients=UInt16[a[((1<<i)|(1<<j))+1] for i in 0:G.n-1 for j in i+1:G.n-1]
    components=QE.comp_forms(QE.coord_forms(coefficients,G.n))
    QE.span_dim(QE.coord_forms(coefficients,G.n))==G.n || error("dependent component coordinates")
    bent=QE.bent_mask(G,components)
    best=Ref(-1)
    records=QE.subspaces_of_comp(components,bent,k;keep=nb->begin
        best[]=max(best[],nb)
        nb==best[]
    end)
    spaces=sort!([first(QE.rref(record.forms)) for record in records if record.nbent==best[]];by=Tuple)
    isempty(spaces) && error("no maximizing component space")
    return best[],spaces
end

"Mandatory provenance check before a prepared parent may be marked complete."
function validate_prepared_parent(G,parent)
    F=SBox{G.n,UInt8}(hex2bytes(parent["lut_hex"]))
    a=anf(F)
    coefficients=UInt16[a[((1<<i)|(1<<j))+1] for i in 0:G.n-1 for j in i+1:G.n-1]
    S=first(QE.rref(QE.coord_forms(coefficients,G.n)))
    forms=parent["maximizing_v5_forms"]
    length(forms)==parent["maximizing_v5_count"]>0 || error("maximizing-space count mismatch")
    seen=Set{Tuple}()
    for V in forms
        canonical=first(QE.rref(UInt32.(V)))
        length(canonical)==G.n-3 && Int.(canonical)==V || error("noncanonical maximizing space")
        first(QE.rref(vcat(S,canonical)))==S || error("maximizing space is not contained in its declared parent")
        nbent=count(q->QE.form_rank(G,q)==G.n,QE.comp_forms(canonical))
        nbent==parent["b5"] || error("maximizing-space bent count mismatch")
        Tuple(canonical) in seen && error("duplicate maximizing space")
        push!(seen,Tuple(canonical))
    end
    return true
end

function prepare_parents!(config,frame,parents;geometry=QE.geometry(8))
    G=geometry
    results=Vector{Any}(undef,length(parents))
    for first_index in 1:32:length(parents)
        last_index=min(length(parents),first_index+31)
        Threads.@threads :dynamic for i in first_index:last_index
            record=copy(parents[i]);started=time_ns()
            F=SBox{G.n,UInt8}(hex2bytes(record["lut_hex"]))
            differential_uniformity(F)==2 && algebraic_degree(F)==2 || error("sampled parent is not quadratic APN")
            # This name must not alias the aggregate `spaces` binding below.
            # A binding shared with the surrounding function is boxed and
            # can be overwritten by another @threads task.
            b5,parent_spaces=maximizing_component_spaces(G,F)
            record["b5"]=b5;record["need"]=52-b5
            record["maximizing_v5_count"]=length(parent_spaces)
            record["maximizing_v5_forms"]=[Int.(V) for V in parent_spaces]
            validate_prepared_parent(G,record)
            record["preparation_seconds"]=(time_ns()-started)*1e-9
            record["preparation_complete"]=true
            results[i]=record
        end
        println(JSON3.write(Dict("event"=>"parents_prepared","completed"=>last_index,"total"=>length(parents))))
        flush(stdout)
    end
    spaces=Dict{String,Any}[]
    for record in results
        M=record["maximizing_v5_count"]
        for (i,forms) in enumerate(record["maximizing_v5_forms"])
            push!(spaces,Dict{String,Any}("parent_id"=>record["parent_id"],"origin"=>record["origin"],
                "prepared_parent"=>record["prepared_parent"],"completed_parent"=>record["completed_parent"],
                "queue_state"=>record["queue_state"],"uniform_parent_sample"=>record["uniform_parent_sample"],
                "sample_designs"=>record["sample_designs"],"parent_v5_index"=>i,
                "parent_maximizing_v5_count"=>M,"b5"=>record["b5"],"need"=>record["need"],
                "forms"=>forms,"exact_key"=>join(forms,',')*":"*string(record["need"]),
                "parent_inclusion_probability"=>record["uniform_parent_inclusion_probability"],
                "second_stage_space_inclusion_probability"=>1.0,
                "uniform_cluster_design_weight"=>record["uniform_parent_design_weight"]))
        end
    end
    write_json(joinpath(config.output,"parents.json"),Dict("schema"=>"vbfsearch-prepared-parent-sample-v1",
        "frame_sha256"=>file_sha(joinpath(config.output,"frame.json")),"complete"=>true,"parents"=>results))
    write_json(joinpath(config.output,"spaces.json"),Dict("schema"=>"vbfsearch-frontier-v5-sample-v1",
        "frame_sha256"=>file_sha(joinpath(config.output,"frame.json")),
        "parents_sha256"=>file_sha(joinpath(config.output,"parents.json")),
        "complete"=>true,"spaces"=>spaces))
    return results,spaces
end

"Independent artifact check after preparation, before downstream classifiers."
function validate_artifacts(config)
    frame=read_json(joinpath(config.output,"frame.json"))
    original=read_json(joinpath(config.output,"parents-frame.json"))["parents"]
    parents=read_json(joinpath(config.output,"parents.json"))["parents"]
    spaces=read_json(joinpath(config.output,"spaces.json"))["spaces"]
    original_by_id=Dict(Int(p["parent_id"])=>p for p in original)
    by_id=Dict(Int(p["parent_id"])=>p for p in parents)
    length(by_id)==length(original_by_id)==length(parents)==length(original) || error("parent roster changed")
    G=QE.geometry(8)
    for p in parents
        source=original_by_id[p["parent_id"]]
        for field in ("candidate_id","lut_hex","sigma_hash","origin","queue_state",
                "uniform_parent_sample","sample_designs")
            p[field]==source[field] || error("sampled parent field changed: $field")
        end
        bytes2hex(sha256(hex2bytes(p["lut_hex"])))==p["candidate_id"] || error("LUT digest changed")
        validate_prepared_parent(G,p)
    end
    seen=Set{Tuple{Int,Int}}()
    for s in spaces
        p=by_id[s["parent_id"]];i=Int(s["parent_v5_index"])
        s["forms"]==p["maximizing_v5_forms"][i] || error("space artifact differs from validated parent")
        s["b5"]==p["b5"] && s["need"]==52-p["b5"] || error("space parameters changed")
        s["parent_maximizing_v5_count"]==p["maximizing_v5_count"] || error("space design count changed")
        s["uniform_parent_sample"]==p["uniform_parent_sample"] || error("space sampling label changed")
        key=(Int(s["parent_id"]),i)
        key in seen && error("duplicate parent/space index")
        push!(seen,key)
    end
    length(spaces)==sum(p["maximizing_v5_count"] for p in parents) || error("space artifact incomplete")
    report=Dict("schema"=>"vbfsearch-frontier-provenance-validation-v1","complete"=>true,
        "implementation"=>implementation(),"validated_parents"=>length(parents),
        "validated_v5_spaces"=>length(spaces),"evaluated_form_ranks_per_v5"=>32,
        "all_parent_LUT_digests_and_sampling_labels_match_original_frame"=>true,
        "all_v5_bases_canonical_distinct_and_exactly_contained_in_declared_parent"=>true,
        "all_v5_rank_bent_profiles_match_declared_b5"=>true,
        "all_serialized_space_rows_match_validated_parent_lists"=>true,
        "bindings"=>Dict(name=>file_sha(joinpath(config.output,name)) for name in
            ("frame.json","parents-frame.json","parents.json","spaces.json")),
        "limitation"=>"Maximum-space enumeration completeness comes from the declared exhaustive VBF subspaces_of_comp pass; this receipt independently checks provenance, ranks and serialization without repeating that enumeration.")
    write_json(joinpath(config.output,"provenance-validation.json"),report)
    return report
end

"Refuse a missing or stale provenance receipt before downstream analysis."
function require_provenance_validation(config)
    path=joinpath(config.output,"provenance-validation.json")
    isfile(path) || error("missing provenance validation; run --phase validate")
    receipt=read_json(path)
    receipt["complete"]===true || error("incomplete provenance validation")
    for (name,digest) in receipt["bindings"]
        file_sha(joinpath(config.output,name))==digest || error("stale provenance validation for $name")
    end
    return true
end

function log_choose(n::Int,k::Int)
    0<=k<=n || return -Inf
    k=min(k,n-k)
    return sum((log(n-k+i)-log(i) for i in 1:k);init=0.0)
end

"Exact finite-population hypergeometric CDF, evaluated with logarithmic sums."
function hypergeometric_cdf(x::Int,N::Int,K::Int,n::Int)
    0<=K<=N && 0<=n<=N || throw(ArgumentError("invalid finite population"))
    lo=max(0,n+K-N);hi=min(x,n,K)
    hi<lo && return 0.0
    lp=log_choose(K,lo)+log_choose(N-K,n-lo)-log_choose(N,n)
    acc=lp
    for j in lo:hi-1
        lp+=log(K-j)-log(j+1)+log(n-j)-log(N-K-n+j+1)
        high=max(acc,lp)
        acc=high+log1p(exp(min(acc,lp)-high))
    end
    return min(1.0,exp(acc))
end

"Largest compatible finite-population success count; one-sided error alpha."
function population_success_upper(N::Int,n::Int,x::Int;alpha=0.05)
    0<=x<=n<=N && 0<alpha<1 || throw(ArgumentError("invalid confidence bounds"))
    n==0 && return N
    lo=x;hi=N+1
    while hi-lo>1
        mid=lo+(hi-lo)÷2
        if hypergeometric_cdf(x,N,mid,n)>=alpha
            lo=mid
        else
            hi=mid
        end
    end
    return lo
end

function rate_summary(frame,parents,spaces)
    base=[p for p in parents if p["uniform_parent_sample"]]
    N=Int(frame["population_parents"]);n=length(base)
    parent_results=Dict{Int,Tuple{Int,Int,Int}}()
    for p in base
        records=[s for s in spaces if s["parent_id"]==p["parent_id"]]
        positive=count(s->get(s,"generator_count",0)>0,records)
        unknown=count(s->!get(s,"audit_complete",false),records)
        parent_results[p["parent_id"]]=(positive,unknown,length(records))
    end
    known_positive=count(r->r[1]>0,values(parent_results))
    unknown_parents=count(r->r[1]==0 && r[2]>0,values(parent_results))
    upper_count=population_success_upper(N,n,known_positive+unknown_parents;alpha=0.05)
    upper95=upper_count/N
    upper975=population_success_upper(N,n,known_positive+unknown_parents;alpha=0.025)
    lower025=N-population_success_upper(N,n,n-known_positive;alpha=0.025)
    total_spaces=sum(r[3] for r in values(parent_results))
    positive_spaces=sum(r[1] for r in values(parent_results))
    unknown_spaces=sum(r[2] for r in values(parent_results))
    max_per_parent=Int(QE.gauss_binom(8,5))
    # Without a PPS frame, zero sampled successes do not justify a binomial
    # 3/number-of-spaces bound: the sampled spaces form parent clusters.
    # Universal deterministic bound: each positive parent has <=97155 V5s;
    # each negative parent has at least one. Combine with the exact parent CI.
    job_upper=upper_count==0 ? 0.0 :
        upper_count*Float64(max_per_parent)/(upper_count*Float64(max_per_parent)+N-upper_count)
    return Dict("population_parents"=>N,"uniform_sampled_parents"=>n,
        "sampled_parents_with_nontrivial_stabilizer"=>known_positive,
        "sampled_parents_with_unknown_stabilizers"=>unknown_parents,
        "parent_prevalence_identified_estimate"=>[known_positive/n,(known_positive+unknown_parents)/n],
        "parent_prevalence_exact_finite_population_95pct_interval"=>[lower025/N,upper975/N],
        "parent_prevalence_exact_finite_population_one_sided_95pct_upper"=>upper95,
        "parent_positive_population_one_sided_95pct_upper_count"=>upper_count,
        "parent_weighted_mean_v5_positive_fraction_identified_estimate"=>[
            mean(r[1]/r[3] for r in values(parent_results)),
            mean((r[1]+r[2])/r[3] for r in values(parent_results))],
        "parent_weighted_mean_v5_fraction_one_sided_95pct_upper"=>upper95,
        "uniform_parent_sample_total_v5_spaces"=>total_spaces,
        "sampled_v5_spaces_with_nonidentity_generators"=>positive_spaces,
        "sampled_v5_spaces_with_unknown_stabilizers"=>unknown_spaces,
        "v5_job_weighted_hajek_ratio_identified_estimate"=>[
            positive_spaces/total_spaces,(positive_spaces+unknown_spaces)/total_spaces],
        "estimated_population_maximizing_v5_jobs_horvitz_thompson"=>total_spaces*N/n,
        "v5_job_weighted_conservative_one_sided_95pct_upper"=>job_upper,
        "universal_max_v5_spaces_per_parent"=>max_per_parent,
        "confidence_method"=>"SRS parent hypergeometric tail inversion; unknown parents conservatively positive. V5 job bound uses universal97155-per-parent cap, not independent-space binomial assumptions.",
        "v5_job_confidence_limitation"=>"The job-weighted ratio is a cluster-sample estimate. Its distribution-free upper bound is loose because maximizing-space counts of unprepared population parents are unknown; sibling spaces are not independent samples.")
end

"Conditional SRS over the remaining queue; supplements remain excluded."
function queue_rate_summary(frame,parents,spaces)
    queued=[p for p in parents if p["queued_parent"]]
    qspaces=[s for s in spaces if s["queue_state"]!="complete"]
    qframe=copy(frame)
    qframe["population_parents"]=sum(Int(v) for (k,v) in frame["population_strata"]
        if endswith(k,"/queued_unprepared") || endswith(k,"/queued_prepared"))
    return rate_summary(qframe,queued,qspaces)
end

function audit_stabilizers!(config,frame,parents,spaces)
    G=QE.geometry(8)
    # Warm backend including n=8 specialization on the first supplied space.
    first_space=first(spaces)
    quadratic_space_stabilizers(G,UInt32.(first_space["forms"]);
        max_nodes=config.solver_nodes,timeout_seconds=config.solver_seconds,
        max_memory_bytes=config.solver_memory)
    started=time()
    for first_index in 1:128:length(spaces)
        time()-started>=config.max_seconds && break
        last_index=min(length(spaces),first_index+127)
        Threads.@threads :dynamic for i in first_index:last_index
            record=spaces[i];before=time_ns()
            result=quadratic_space_stabilizers(G,UInt32.(record["forms"]);
                max_nodes=config.solver_nodes,timeout_seconds=config.solver_seconds,
                max_memory_bytes=config.solver_memory)
            record["generator_count"]=length(result.generators)
            record["generators"]=[Int.(A) for A in result.generators]
            record["audit_complete"]=result.complete
            record["stop_reason"]=String(result.stop_reason)
            record["nodes_visited"]=result.nodes_visited
            record["discarded_identity_actions"]=result.discarded_identity_actions
            record["discovery_seconds"]=(time_ns()-before)*1e-9
        end
        println(JSON3.write(Dict("event"=>"spaces_audited","completed"=>last_index,
            "total"=>length(spaces),"elapsed_seconds"=>time()-started)))
        flush(stdout)
    end
    return spaces
end

function work_proxies!(config,parents,spaces)
    config.work_proxies==0 && return Dict{String,Any}[]
    base=[p for p in parents if p["uniform_parent_sample"]]
    rng=Xoshiro(config.seed ⊻ 0x776f726b)
    chosen=randperm(rng,length(base))[1:min(config.work_proxies,length(base))]
    proxy=Dict{String,Any}[]
    G=QE.geometry(8);work=QE.V5Work(23,8)
    for pi in chosen
        parent=base[pi]
        siblings=[s for s in spaces if s["parent_id"]==parent["parent_id"]]
        record=siblings[rand(rng,1:length(siblings))]
        started=time_ns()
        counts=QE.coset_bent_counts!(work.cnt,G,UInt32.(record["forms"]),QE.BETA8)
        X=UInt32[j-1 for j in 2:length(work.cnt) if work.cnt[j]==record["need"]*counts.scale]
        plan=quadratic_extension_orbits(G,UInt32.(record["forms"]),X,
            [UInt16.(A) for A in get(record,"generators",Any[])])
        push!(proxy,Dict("parent_id"=>record["parent_id"],"parent_v5_index"=>record["parent_v5_index"],
            "b5"=>record["b5"],"need"=>record["need"],"eligible_cosets"=>length(X),
            "verified_subgroup_coset_orbits"=>length(plan.representatives),
            "coset_savings"=>length(X)-length(plan.representatives),
            "parent_subsample_probability"=>length(chosen)/length(base),
            "space_probability_within_parent"=>1/length(siblings),
            "elapsed_seconds"=>(time_ns()-started)*1e-9))
    end
    return proxy
end

function generator_order(columns;limit=1024)
    A=F2LinearMap{8,UInt16}(UInt16.(columns))
    identity=identity_linear_map(8,UInt16).cols
    power=copy(identity)
    for exponent in 1:limit
        power=UInt16[A(c) for c in power]
        power==identity && return exponent
    end
    return nothing
end

"Actual eligible-coset orbit counts for a bounded SRS of nontrivial spaces."
function positive_orbits(config,frame,spaces)
    impl=implementation()
    input_sha=file_sha(joinpath(config.output,"stabilizers.json"))
    positive=[s for s in spaces if get(s,"generator_count",0)>0]
    rng=Xoshiro(config.seed ⊻ 0x6f72626974)
    indices=sort!(randperm(rng,length(positive))[1:min(config.orbit_spaces,length(positive))])
    selected=positive[indices]
    records=Vector{Any}(undef,length(selected))
    G=QE.geometry(8);started=time()
    slots=min(2,Threads.nthreads(),length(selected))
    @sync for slot in 1:slots
        Threads.@spawn begin
            # Buffers belong to this task, not to a thread that it may leave.
            work=QE.V5Work(23,8)
            for i in slot:slots:length(selected)
                source=selected[i]
                record=Dict{String,Any}("parent_id"=>source["parent_id"],
                    "parent_v5_index"=>source["parent_v5_index"],"b5"=>source["b5"],
                    "need"=>source["need"],"forms"=>source["forms"],
                    "generators"=>source["generators"],"generator_count"=>source["generator_count"],
                    "uniform_parent_sample"=>source["uniform_parent_sample"],
                    "positive_space_subsample_probability"=>length(selected)/length(positive))
                if time()-started>=config.max_seconds
                    record["complete"]=false;record["stop_reason"]="time"
                    records[i]=record;continue
                end
                before=time_ns()
                counts=QE.coset_bent_counts!(work.cnt,G,UInt32.(source["forms"]),QE.BETA8)
                X=UInt32[j-1 for j in 2:length(work.cnt) if work.cnt[j]==source["need"]*counts.scale]
                plan=quadratic_extension_orbits(G,UInt32.(source["forms"]),X,
                    [UInt16.(A) for A in source["generators"]])
                orbit_sizes=Dict{Int,Int}()
                for root in plan.representative_of
                    orbit_sizes[root]=get(orbit_sizes,root,0)+1
                end
                histogram=Dict{Int,Int}()
                for size in values(orbit_sizes)
                    histogram[size]=get(histogram,size,0)+1
                end
                record["eligible_cosets"]=length(X)
                record["orbit_representatives"]=length(plan.representatives)
                record["saved_cosets"]=length(X)-length(plan.representatives)
                record["coset_saving_fraction"]=isempty(X) ? 0.0 :
                    (length(X)-length(plan.representatives))/length(X)
                record["orbit_size_histogram"]=[[size,count] for (size,count) in sort!(collect(histogram))]
                record["generator_orders"]=[generator_order(A) for A in source["generators"]]
                record["elapsed_seconds"]=(time_ns()-before)*1e-9
                record["complete"]=true
                records[i]=record
            end
        end
    end
    completed=[r for r in records if r["complete"]]
    report=Dict("schema"=>"vbfsearch-frontier-positive-symmetry-orbits-v1",
        "implementation"=>impl,"stabilizers_sha256"=>input_sha,
        "input_positive_spaces"=>length(positive),"selected_positive_spaces"=>length(selected),
        "selection"=>"Uniform SRS without replacement among verified nontrivial spaces, seed xor 0x6f72626974; all if below cap",
        "seed"=>config.seed,"space_cap"=>config.orbit_spaces,
        "all_positive_spaces_covered"=>length(selected)==length(positive) && length(completed)==length(positive),
        "complete"=>length(completed)==length(selected),
        "eligible_cosets"=>sum((r["eligible_cosets"] for r in completed);init=0),
        "orbit_representatives"=>sum((r["orbit_representatives"] for r in completed);init=0),
        "saved_cosets"=>sum((r["saved_cosets"] for r in completed);init=0),
        "elapsed_seconds"=>time()-started,"records"=>records,
        "limitation"=>"These are exact quotient-domain orbit counts, not APN completions or wall-clock extension-search speedups. The positive-space subset is not a uniform sample of all V5 jobs.")
    file_sha(joinpath(config.output,"stabilizers.json"))==input_sha || error("stabilizer input changed")
    implementation()["sha256"]==impl["sha256"] || error("mathematical implementation changed")
    write_json(joinpath(config.output,"positive-orbits.json"),report)
    return report
end

function main(args=ARGS)
    config=configuration(args);mkpath(config.output)
    impl=implementation();started=time()
    mkpath(joinpath(config.output,"used-code"))
    cp(@__FILE__,joinpath(config.output,"used-code","source-"*impl["tool_sha256"]*".jl");force=true)
    if config.phase in ("all","frame")
        frame,parents=sample_frame(config.database;parents=config.parents,
            supplement=config.supplement,seed=config.seed)
        frame["implementation"]=impl
        write_json(joinpath(config.output,"frame.json"),frame)
        write_json(joinpath(config.output,"parents-frame.json"),Dict("parents"=>parents))
        println(JSON3.write(Dict("event"=>"frame_ready","population"=>frame["population_parents"],
            "sampled"=>length(parents),"uniform_sample"=>frame["uniform_sample_size"])));flush(stdout)
        config.phase=="frame" && return
    else
        frame=read_json(joinpath(config.output,"frame.json"))
        parents=read_json(joinpath(config.output,"parents-frame.json"))["parents"]
    end
    config.phase=="validate" && return validate_artifacts(config)
    if config.phase in ("all","prepare")
        parents,spaces=prepare_parents!(config,frame,parents)
        validate_artifacts(config)
        config.phase=="prepare" && return
    else
        parents=read_json(joinpath(config.output,"parents.json"))["parents"]
        spaces=read_json(joinpath(config.output,"spaces.json"))["spaces"]
    end
    require_provenance_validation(config)
    if config.phase=="orbits"
        spaces=read_json(joinpath(config.output,"stabilizers.json"))["spaces"]
        return positive_orbits(config,frame,spaces)
    end
    spaces=audit_stabilizers!(config,frame,parents,spaces)
    proxies=work_proxies!(config,parents,spaces)
    report=Dict{String,Any}("schema"=>"vbfsearch-frontier-symmetry-audit-v1",
        "created_utc"=>string(now(UTC))*"Z","implementation"=>impl,
        "frame_sha256"=>file_sha(joinpath(config.output,"frame.json")),
        "parents_sha256"=>file_sha(joinpath(config.output,"parents.json")),
        "spaces_sha256"=>file_sha(joinpath(config.output,"spaces.json")),
        "population_rates"=>rate_summary(frame,parents,spaces),
        "remaining_queue_rates"=>queue_rate_summary(frame,parents,spaces),
        "audited_v5_spaces"=>count(s->haskey(s,"audit_complete"),spaces),
        "exhausted_v5_stabilizers"=>count(s->get(s,"audit_complete",false),spaces),
        "nontrivial_v5_stabilizers"=>count(s->get(s,"generator_count",0)>0,spaces),
        "unknown_v5_stabilizers"=>count(s->!get(s,"audit_complete",false),spaces),
        "work_proxies"=>proxies,"elapsed_seconds"=>time()-started,
        "limitations"=>[
            "The randomization seed and selected parent frame are fixed before preparing or inspecting sampled parents.",
            "All admitted parents are in the frame, including those without prepared V5 jobs.",
            "Supplemental root/prepared-parent samples are not pooled into uniform-parent estimates.",
            "A useful stabilizer is an input-linear action modulo affine terms; quadratic translations with identity input action are excluded.",
            "A timeout or memory/node cap is unknown, never evidence of a trivial stabilizer.",
            "No APN extension enumeration or campaign restart is performed.",
            "Potential symmetry coverage is measured; actual wall-clock campaign speedup is not extrapolated."])
    source=stat(config.database)
    source.size==frame["database_bytes"] && source.mtime==frame["database_mtime_unix"] ||
        error("campaign database changed during audit")
    implementation()["sha256"]==impl["sha256"] || error("mathematical implementation changed during audit")
    report["complete"]=report["unknown_v5_stabilizers"]==0
    write_json(joinpath(config.output,"stabilizers.json"),Dict("spaces"=>spaces))
    report["stabilizers_sha256"]=file_sha(joinpath(config.output,"stabilizers.json"))
    write_json(joinpath(config.output,"report.json"),report)
    println(JSON3.write(Dict("event"=>"complete","report"=>joinpath(config.output,"report.json"),
        "population_rates"=>report["population_rates"])));flush(stdout)
    return report
end
end

abspath(PROGRAM_FILE)==(@__FILE__) && V5FrontierSymmetryAudit.main()
