"""Independent sampled mathematics check of newly admitted closure parents.

Run only after the measured campaign session stops. The mathematical package
must load from the supplied archived workspace; this script never imports the
search controller or calls its candidate-properties helper. Its only database
connection is read-only/query-only and reads a fixed transaction snapshot.

Usage:
  julia --project=ARCHIVE/docs/inspector new_parent_math_audit.jl \
      DATABASE OUTPUT ARCHIVE BASELINE_MAX_PARENT SAMPLE_SIZE SEED

Sampling is uniform without replacement over every admitted parent ID above
the supplied historical cutoff, ordered before applying a fixed-seed Xoshiro
permutation. This is an integration sample, not a novelty or equivalence audit.
"""
module NewParentMathAudit
using VBF,SQLite,DBInterface,JSON3,SHA,TOML,Dates,Random

"Hash actual archived VBF Julia source files, independently of search metadata."
function mathematical_sources(workspace)
    source=joinpath(workspace,"packages","VBF","src")
    paths=sort!([joinpath(root,file) for (root,_,files) in walkdir(source) for file in files if endswith(file,".jl")])
    Dict(relpath(path,workspace)=>bytes2hex(open(sha256,path)) for path in paths)
end

"Require the active project and the loaded mathematical implementation archived."
function check_archive(workspace)
    workspace=realpath(workspace)
    expected=realpath(joinpath(workspace,"docs","inspector","Project.toml"))
    realpath(Base.active_project())==expected || error("run with --project=$expected")
    realpath(dirname(dirname(pathof(VBF))))==realpath(joinpath(workspace,"packages","VBF")) ||
        error("VBF loaded from outside the supplied archive")
    workspace
end

"Copy SQLite row values before advancing the lazy query iterator."
copyrow(row)=Dict(String(key)=>getproperty(row,key) for key in propertynames(row))

"Read all new IDs, draw the sample, then fetch only its candidate evidence rows."
function sampled_rows(database,cutoff,sample_size,seed)
    db=SQLite.DB("file:"*abspath(database)*"?mode=ro")
    population=Dict{String,Any}[];selected=Dict{String,Any}[];indices=Int[]
    try
        DBInterface.execute(db,"PRAGMA query_only=ON")
        DBInterface.execute(db,"PRAGMA busy_timeout=5000")
        DBInterface.execute(db,"BEGIN")
        for row in DBInterface.execute(db,"SELECT id,candidate_id,origin,admitted_utc FROM parents WHERE id>? ORDER BY id",(cutoff,))
            push!(population,copyrow(row))
        end
        isempty(population) && error("no newly admitted parents above supplied cutoff")
        sample_size<=length(population) || error("requested sample exceeds eligible population")
        indices=sort!(randperm(Xoshiro(seed),length(population))[1:sample_size])
        for index in indices
            parent=population[index]
            sql="""SELECT p.id parent_id,p.candidate_id,p.sigma parent_sigma,p.origin,
                p.source,p.admitted_utc,c.lut_hex,c.sigma candidate_sigma,c.apn,c.degree,
                c.properties,c.class_id,c.state
                FROM parents p JOIN candidates c ON c.id=p.candidate_id WHERE p.id=?"""
            row=only([copyrow(row) for row in DBInterface.execute(db,sql,(parent["id"],))])
            row["population_index"]=index;push!(selected,row)
        end
        DBInterface.execute(db,"ROLLBACK")
    finally
        close(db)
    end
    digest=bytes2hex(sha256(join((string(row["id"],':',row["candidate_id"]) for row in population),'\n')))
    (;rows=selected,population_count=length(population),population_sha256=digest,
        population_minimum=Int(first(population)["id"]),population_maximum=Int(last(population)["id"]),
        sampled_population_indices=indices)
end

"Recompute DDT spectrum, ANF degree, LUT identity and quadratic signatures using VBF."
function verify_candidate(row)
    start=time_ns();stored=TOML.parse(String(row["properties"]))
    lut=hex2bytes(String(row["lut_hex"]));length(lut)==256 || error("LUT length differs from n8")
    F=SBox{8}(lut);degree=algebraic_degree(F)
    spectrum=differential_spectrum(F);uniformity=maximum(first,spectrum)
    digest=bytes2hex(sha256(lut));signature=VBF.sigma_hash(F)
    ortho=bytes2hex(UInt8.(ortho_derivative(F).lut))
    histogram=[Dict("value"=>Int(v),"count"=>Int(c)) for (v,c) in VBF.sorted_pairs(spectrum)]
    fresh=Dict{String,Any}("lut_sha256"=>digest,"lut_hex"=>bytes2hex(lut),
        "n"=>8,"m"=>8,"apn"=>uniformity==2,"quadratic"=>degree==2,
        "algebraic_degree"=>degree,"differential_uniformity"=>uniformity,
        "sigma_hash"=>signature,"ortho_lut_hex"=>ortho,"ddt_histogram"=>histogram)
    checks=Dict{String,Bool}(
        "fresh_apn"=>uniformity==2,"fresh_quadratic"=>degree==2,
        "candidate_id"=>String(row["candidate_id"])==digest,
        "candidate_apn_column"=>row["apn"]==1,
        "candidate_degree_column"=>row["degree"]==2,
        "parent_sigma"=>String(row["parent_sigma"])==signature,
        "candidate_sigma"=>String(row["candidate_sigma"])==signature,
        "class_binding"=>row["class_id"]==row["parent_id"],
        "admitted_state"=>row["state"]=="admitted",
        "discovered_origin"=>row["origin"]=="discovered")
    for (key,value) in fresh
        checks["properties.$key"]=haskey(stored,key)&&stored[key]==value
    end
    (;parent_id=Int(row["parent_id"]),population_index=Int(row["population_index"]),
        candidate_id=String(row["candidate_id"]),origin=String(row["origin"]),
        source=String(row["source"]),admitted_utc=String(row["admitted_utc"]),
        stored_properties_sha256=bytes2hex(sha256(String(row["properties"]))),
        passed=all(values(checks)),checks,fresh,seconds=(time_ns()-start)*1e-9)
end

"Run the explicitly sampled independent audit; write its complete receipt before failing."
function audit(database,output,workspace,cutoff,sample_size,seed)
    workspace=check_archive(workspace);cutoff=parse(Int,cutoff)
    sample_size=parse(Int,sample_size);seed=parse(UInt64,seed)
    sample_size>0&&cutoff>=0 || throw(ArgumentError("invalid sample size or cutoff"))
    database=realpath(database);before=stat(database);started=time_ns()
    sources=mathematical_sources(workspace)
    sample=sampled_rows(database,cutoff,sample_size,seed)
    records=Any[]
    for row in sample.rows
        result=try
            verify_candidate(row)
        catch err
            (;parent_id=Int(row["parent_id"]),candidate_id=String(row["candidate_id"]),
                passed=false,error=sprint(showerror,err))
        end
        push!(records,result)
    end
    after=stat(database)
    result=(;schema="vbfsearch-new-parent-mathematics-sample-v1",created_utc=string(now(UTC)),
        scope="Uniform sampled integration check of newly admitted parents; not a corpus novelty/equivalence audit",
        database,cutoff_parent_id=cutoff,population_count=sample.population_count,
        population_minimum_parent=sample.population_minimum,population_maximum_parent=sample.population_maximum,
        population_sha256=sample.population_sha256,seed,sample_size,
        sampling="Xoshiro fixed-seed uniform permutation of all parent IDs above cutoff; without replacement",
        sampled_population_indices=sample.sampled_population_indices,
        archive_workspace=workspace,active_project=Base.active_project(),loaded_vbf_path=pathof(VBF),
        archive_project_sha256=bytes2hex(open(sha256,Base.active_project())),
        archive_manifest_sha256=bytes2hex(open(sha256,joinpath(dirname(Base.active_project()),"Manifest.toml"))),
        mathematical_source_sha256=sources,script_sha256=bytes2hex(open(sha256,@__FILE__)),
        julia_version=string(VERSION),threads=Threads.nthreads(),
        database_stat_before=(;bytes=before.size,mtime=before.mtime),
        database_stat_after=(;bytes=after.size,mtime=after.mtime),
        all_passed=all(r->r.passed,records),verified=length(records),
        seconds=(time_ns()-started)*1e-9,records)
    mkpath(dirname(abspath(output)));write(output,JSON3.write(result))
    println(JSON3.write((;output=abspath(output),population=result.population_count,
        sample=result.sample_size,passed=count(r->r.passed,records),all_passed=result.all_passed,
        seconds=result.seconds)))
    result.all_passed || error("sample verification failed; see retained receipt")
    result
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && NewParentMathAudit.audit(ARGS...)
