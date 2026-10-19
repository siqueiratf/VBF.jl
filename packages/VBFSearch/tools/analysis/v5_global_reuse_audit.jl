"""Read-only extraction and bounded indexing of every prepared V5 job.

Run with --project=docs/inspector and at most four Julia compute threads:
  v5_global_reuse_audit.jl extract SOURCE_SQLITE OUTPUT_DIRECTORY
  v5_global_reuse_audit.jl index OUTPUT_DIRECTORY [MAX_SPACES] [MAX_SECONDS]
  v5_global_reuse_audit.jl stats OUTPUT_DIRECTORY

The generated index is disposable evidence; the scientific ledger is opened
read-only. A fingerprint is only a necessary invariant. Its collisions give
upper bounds on reusable work, never permission to omit construction searches.
"""
module V5GlobalReuseAudit
using VBF, VBFSearch, SQLite, DBInterface, JSON3, SHA, TOML, Dates
const QE=VBF.QuadraticExtensions
const INDEX_NAME="prepared-v5.sqlite"
filehash(p)=bytes2hex(open(SHA.sha256,p))
function implementation()
    Dict{String,Any}("tool_sha256"=>filehash(@__FILE__),"julia_version"=>string(VERSION),
        "vbf_solver_implementation_sha256"=>VBFSearch.equivalence_solver_fingerprint())
end
function setmeta(db,key,value)
    DBInterface.execute(db,"INSERT OR REPLACE INTO metadata VALUES(?,?)",(key,JSON3.write(value)))
end
function getmeta(db,key,default=nothing)
    value=default
    for r in DBInterface.execute(db,"SELECT value FROM metadata WHERE key=?",(key,));value=JSON3.read(String(r.value));end
    value
end
function scalar(db,query,args=())
    value=0
    for r in DBInterface.execute(db,query,args);value=Int(r[1]);end
    value
end
formsblob(forms)=Vector{UInt8}(reinterpret(UInt8,htol.(UInt32.(forms))))
decodeforms(blob)=ltoh.(collect(reinterpret(UInt32,Vector{UInt8}(blob))))
function openindex(directory;readonly=false)
    path=joinpath(abspath(directory),INDEX_NAME)
    isfile(path) || error("missing prepared-space index $path")
    db=SQLite.DB(readonly ? "file:"*path*"?mode=ro" : path)
    DBInterface.execute(db,"PRAGMA cache_size=-16384")
    readonly && DBInterface.execute(db,"PRAGMA query_only=ON")
    db
end

function extract(source,directory)
    source=abspath(source);directory=abspath(directory);mkpath(directory)
    destination=joinpath(directory,INDEX_NAME)
    isfile(destination) && error("output index already exists; retain it or choose another output directory")
    source==destination && error("input and output paths coincide")
    before=stat(source);started=time();impl=implementation()
    input=SQLite.DB("file:"*source*"?mode=ro")
    DBInterface.execute(input,"PRAGMA query_only=ON")
    DBInterface.execute(input,"PRAGMA cache_size=-8192")
    output=SQLite.DB(destination)
    collect(DBInterface.execute(output,"PRAGMA journal_mode=WAL"))
    DBInterface.execute(output,"PRAGMA synchronous=NORMAL")
    DBInterface.execute(output,"CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL) WITHOUT ROWID")
    DBInterface.execute(output,"""CREATE TABLE spaces(space_id INTEGER PRIMARY KEY,forms BLOB NOT NULL CHECK(length(forms)=20),
        need INTEGER NOT NULL,b5 INTEGER NOT NULL,multiplicity INTEGER NOT NULL DEFAULT 1,
        completed_multiplicity INTEGER NOT NULL DEFAULT 0,fingerprint TEXT,UNIQUE(forms,need))""")
    DBInterface.execute(output,"""CREATE TABLE jobs(job_id INTEGER PRIMARY KEY,space_id INTEGER NOT NULL REFERENCES spaces(space_id),
        parent_id INTEGER NOT NULL,origin TEXT NOT NULL,status TEXT NOT NULL,total_x INTEGER,
        linear_system_candidates INTEGER,candidate_spaces INTEGER,completion_spaces INTEGER,capped INTEGER)""")
    DBInterface.execute(output,"CREATE INDEX jobs_parent ON jobs(parent_id,space_id)")
    DBInterface.execute(output,"CREATE INDEX jobs_space ON jobs(space_id)")
    setmeta(output,"schema","vbfsearch-global-v5-reuse-v1")
    setmeta(output,"extraction_complete",false)
    setmeta(output,"source",Dict("path"=>source,"bytes"=>before.size,"mtime_unix"=>before.mtime))
    setmeta(output,"extraction_implementation",impl)
    for r in DBInterface.execute(input,"SELECT value FROM metadata WHERE key='identity'")
        setmeta(output,"campaign_identity",String(r.value))
        setmeta(output,"campaign_identity_sha256",bytes2hex(SHA.sha256(String(r.value))))
    end
    upsert=DBInterface.prepare(output,"""INSERT INTO spaces(forms,need,b5,completed_multiplicity) VALUES(?,?,?,?)
        ON CONFLICT(forms,need) DO UPDATE SET multiplicity=multiplicity+1,
        completed_multiplicity=completed_multiplicity+excluded.completed_multiplicity RETURNING space_id""")
    insertjob=DBInterface.prepare(output,"INSERT INTO jobs VALUES(?,?,?,?,?,?,?,?,?,?)")
    ctx=SHA.SHA2_256_CTX();count=0
    try
        DBInterface.execute(output,"BEGIN IMMEDIATE")
        query="""SELECT j.id,j.parent_id,p.origin,j.payload,j.status,j.result
            FROM jobs j JOIN parents p ON p.id=j.parent_id WHERE j.kind='v5' ORDER BY j.id"""
        for r in DBInterface.execute(input,query)
            id=Int(r.id);parent=Int(r.parent_id);origin=String(r.origin)
            payload=String(r.payload);status=String(r.status);result=String(r.result)
            SHA.update!(ctx,codeunits(JSON3.write([id,parent,origin,payload,status,result])*"\n"))
            p=TOML.parse(payload);R=QE.rref(UInt32.(p["forms"]))[1]
            length(R)==5 && Int(p["need"])+Int(p["b5"])==52 || error("unsupported V5 job parameters")
            proof=TOML.parse(result)
            complete=status=="done" && get(proof,"capped",nothing)===false &&
                haskey(proof,"next_x") && haskey(proof,"total_x") && proof["next_x"]>proof["total_x"]
            space=0
            for s in DBInterface.execute(upsert,(formsblob(R),Int(p["need"]),Int(p["b5"]),Int(complete)));space=Int(s.space_id);end
            metric(name)=get(proof,name,missing)
            DBInterface.execute(insertjob,(id,space,parent,origin,status,metric("total_x"),metric("linear_system_candidates"),
                metric("candidate_spaces"),metric("completion_spaces"),haskey(proof,"capped") ? Int(proof["capped"]) : missing))
            count+=1
            if count%8192==0
                DBInterface.execute(output,"COMMIT");DBInterface.execute(output,"BEGIN IMMEDIATE")
            end
        end
        DBInterface.execute(output,"COMMIT")
        after=stat(source)
        before.size==after.size && before.mtime==after.mtime || error("scientific input changed during extraction")
        setmeta(output,"ordered_v5_job_roster_sha256",bytes2hex(SHA.digest!(ctx)))
        setmeta(output,"input_digest_scope","Ordered JSON arrays [id,parent_id,origin,payload,status,result], newline-delimited; every V5 job, not unrelated campaign database bytes")
        setmeta(output,"cost_proxy_scope","Fields from the last stored job result; not necessarily cumulative and never a historical elapsed-time measurement")
        setmeta(output,"extraction_seconds",time()-started)
        setmeta(output,"extraction_complete",true)
        DBInterface.execute(output,"CREATE INDEX spaces_fingerprint ON spaces(fingerprint,need,space_id)")
        DBInterface.execute(output,"CREATE INDEX spaces_fingerprint_ordered ON spaces(fingerprint,space_id,forms)")
        collect(DBInterface.execute(output,"PRAGMA wal_checkpoint(TRUNCATE)"))
    finally
        DBInterface.close!(upsert);DBInterface.close!(insertjob);close(input);close(output)
    end
    stats(directory)
end

function fingerprint_index(directory;max_spaces=typemax(Int),max_seconds=Inf,batch_size=256,max_rounds=4)
    max_spaces>=0 && max_seconds>=0 && batch_size>0 || throw(ArgumentError("invalid index limits"))
    Threads.nthreads()<=4 || error("offline audit must use at most four Julia compute threads")
    db=openindex(directory);started=time();done=0;impl=implementation()
    try
        getmeta(db,"extraction_complete",false)===true || error("incomplete extraction")
        previous=getmeta(db,"fingerprint_parameters",nothing)
        parameters=Dict("max_rounds"=>max_rounds,"min_active_hyperplanes"=>0,
            "implementation_sha256"=>impl["vbf_solver_implementation_sha256"])
        if previous!==nothing
            all(get(previous,k,nothing)==v for (k,v) in parameters) || error("index fingerprint parameters/implementation differ; build a separate index")
        end
        setmeta(db,"fingerprint_parameters",parameters)
        G=QE.geometry(8)
        update=DBInterface.prepare(db,"UPDATE spaces SET fingerprint=? WHERE space_id=?")
        try
            while done<max_spaces && time()-started<max_seconds
                rows=[(id=Int(r.space_id),forms=decodeforms(r.forms)) for r in DBInterface.execute(db,
                    "SELECT space_id,forms FROM spaces WHERE fingerprint IS NULL ORDER BY space_id LIMIT ?",(min(batch_size,max_spaces-done),))]
                isempty(rows) && break
                hashes=Vector{String}(undef,length(rows))
                Threads.@threads for i in eachindex(rows)
                    hashes[i]=VBF.quadratic_space_fingerprint(G,rows[i].forms;max_rounds,min_active_hyperplanes=0)
                end
                DBInterface.execute(db,"BEGIN IMMEDIATE")
                for i in eachindex(rows);DBInterface.execute(update,(hashes[i],rows[i].id));end
                DBInterface.execute(db,"COMMIT")
                done+=length(rows)
                done%4096==0 && (println(JSON3.write(Dict("event"=>"fingerprint_progress","new_spaces"=>done,"seconds"=>time()-started)));flush(stdout))
            end
        finally
            DBInterface.close!(update)
        end
        impl["sources_unchanged_during_index"]=(impl["vbf_solver_implementation_sha256"]==VBFSearch.equivalence_solver_fingerprint())
        impl["sources_unchanged_during_index"] || error("solver sources changed while fingerprinting")
        setmeta(db,"last_index_pass",Dict("spaces"=>done,"elapsed_seconds"=>time()-started,"implementation"=>impl,
            "max_spaces"=>max_spaces==typemax(Int) ? "unbounded" : max_spaces,
            "max_seconds"=>isfinite(max_seconds) ? max_seconds : "Inf","threads"=>Threads.nthreads()))
        collect(DBInterface.execute(db,"PRAGMA wal_checkpoint(TRUNCATE)"))
    finally
        close(db)
    end
    stats(directory)
end

function stats(directory)
    db=openindex(directory;readonly=true)
    try
        jobs=scalar(db,"SELECT COUNT(*) FROM jobs");spaces=scalar(db,"SELECT COUNT(*) FROM spaces")
        indexed=scalar(db,"SELECT COUNT(*) FROM spaces WHERE fingerprint IS NOT NULL")
        buckets=scalar(db,"SELECT COUNT(*) FROM (SELECT fingerprint,need FROM spaces WHERE fingerprint IS NOT NULL GROUP BY fingerprint,need)")
        largest=scalar(db,"SELECT COALESCE(MAX(n),0) FROM (SELECT COUNT(*) n FROM spaces WHERE fingerprint IS NOT NULL GROUP BY fingerprint,need)")
        cost_bounds=Dict{String,Any}()
        for metric in ("total_x","linear_system_candidates","candidate_spaces","completion_spaces")
            total=scalar(db,"SELECT COALESCE(SUM($metric),0) FROM jobs")
            exact_min=scalar(db,"SELECT COALESCE(SUM(v),0) FROM (SELECT MIN(COALESCE($metric,0)) v FROM jobs GROUP BY space_id)")
            grouping=indexed==spaces ? "s.fingerprint,s.need" : "s.need"
            invariant_min=scalar(db,"""SELECT COALESCE(SUM(v),0) FROM (SELECT MIN(COALESCE(j.$metric,0)) v
                FROM jobs j JOIN spaces s USING(space_id) GROUP BY $grouping)""")
            cost_bounds[metric]=Dict("retained_metric_sum"=>total,"missing_job_values"=>scalar(db,"SELECT COUNT(*) FROM jobs WHERE $metric IS NULL"),
                "exact_duplicate_retain_one_savings"=>total-exact_min,"invariant_bucket_retain_one_savings_upper_bound"=>total-invariant_min,
                "meaning"=>"Bounds on deleting observed metric records while retaining one record per orbit, not measured saved CPU time; last results may be noncumulative")
        end
        report=Dict{String,Any}("schema"=>"vbfsearch-global-v5-reuse-report-v1","created_utc"=>string(now(UTC))*"Z",
            "source"=>getmeta(db,"source"),"ordered_v5_job_roster_sha256"=>getmeta(db,"ordered_v5_job_roster_sha256"),
            "extraction_complete"=>getmeta(db,"extraction_complete",false),"extraction_seconds"=>getmeta(db,"extraction_seconds"),
            "extraction_implementation"=>getmeta(db,"extraction_implementation"),
            "prepared_jobs"=>jobs,"exact_spaces"=>spaces,"exact_repeated_jobs"=>jobs-spaces,
            "fingerprinted_spaces"=>indexed,"fingerprint_complete"=>indexed==spaces,"necessary_invariant_buckets"=>buckets,
            "largest_fingerprint_bucket"=>largest,"distinct_orbits_lower_bound"=>max(buckets,Int(spaces>0)),
            "spaces_with_verified_completion_cursor"=>scalar(db,"SELECT COUNT(*) FROM spaces WHERE completed_multiplicity>0"),
            "eligible_coset_count_buckets"=>scalar(db,"SELECT COUNT(*) FROM (SELECT s.need,j.total_x FROM jobs j JOIN spaces s USING(space_id) WHERE j.total_x IS NOT NULL GROUP BY s.need,j.total_x)"),
            "retained_cost_proxy_bounds"=>cost_bounds,
            "distinct_orbits_upper_bound"=>spaces,"reusable_jobs_lower_bound"=>jobs-spaces,
            "reusable_jobs_upper_bound"=>jobs-max(buckets,Int(spaces>0)),
            "last_index_pass"=>getmeta(db,"last_index_pass"),"fingerprint_parameters"=>getmeta(db,"fingerprint_parameters"),
            "scope"=>"All prepared V5 jobs in the stopped campaign. Unprepared parents are a separate population.",
            "limitations"=>["Invariant collisions are potential equivalences, not certificates.",
                "Partial indexing gives a valid but weak global lower bound from the observed disjoint invariant buckets.",
                "Prepared-job duplicate counts do not measure the unprepared frontier or switching coverage.",
                "Last-result cost proxies are not cumulative historical runtime or a completion forecast."])
        report["strata"]=[Dict("origin"=>String(r.origin),"b5"=>Int(r.b5),"jobs"=>Int(r.n),"parents"=>Int(r.parents))
            for r in DBInterface.execute(db,"SELECT j.origin,s.b5,COUNT(*) n,COUNT(DISTINCT j.parent_id) parents FROM jobs j JOIN spaces s USING(space_id) GROUP BY j.origin,s.b5 ORDER BY j.origin,s.b5")]
        open(io->JSON3.pretty(io,report),joinpath(directory,"index-report.json"),"w")
        println(JSON3.write(report));flush(stdout)
        return report
    finally
        close(db)
    end
end

function main(args=ARGS)
    isempty(args) && error("expected extract, index, or stats")
    if args[1]=="extract"
        length(args)==3 || error("extract SOURCE_SQLITE OUTPUT_DIRECTORY")
        extract(args[2],args[3])
    elseif args[1]=="index"
        2<=length(args)<=4 || error("index OUTPUT_DIRECTORY [MAX_SPACES] [MAX_SECONDS]")
        fingerprint_index(args[2];max_spaces=length(args)>=3 ? parse(Int,args[3]) : typemax(Int),
            max_seconds=length(args)>=4 ? parse(Float64,args[4]) : Inf)
    elseif args[1]=="stats"
        stats(args[2])
    else
        error("unknown command $(args[1])")
    end
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && V5GlobalReuseAudit.main()
