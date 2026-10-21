"""Bounded replay of real output-heavy V5 packets in fresh normalized stores.

Usage: julia --project=<selected implementation> closure_v5_application_replay.jl CONFIG.json
No production database is opened. Compute, application, and validation are timed
separately; all scientific paths and complete per-coset coverage are fingerprinted.
"""
module ClosureV5ApplicationReplay
using VBFSearch, SQLite, DBInterface, TOML, SHA, JSON3, Serialization, Profile
const VS=VBFSearch
const cfg=JSON3.read(read(only(ARGS),String),Dict{String,Any})
const root=abspath(cfg["output"])
ispath(root) && error("output must be new")
mkpath(root)
const fixture=SQLite.DB(cfg["fixture"])
VS._closure_exec(fixture,"PRAGMA query_only=ON")
const roots=VS._closure_rows(fixture,"SELECT * FROM roots ORDER BY original_id")
const references=VS._closure_rows(fixture,"SELECT * FROM reference_parents ORDER BY original_id")
const jobs=VS._closure_rows(fixture,"SELECT * FROM work_jobs ORDER BY id")
const implementation=VS.code_identity()
const completion=if haskey(cfg,"completion_helper")
    Base.include(@__MODULE__,cfg["completion_helper"])
else
    nothing
end
"""Materialize the public wire schema without retaining native encoding views."""
wire(value::AbstractDict)=Dict{String,Any}(String(k)=>wire(v) for (k,v) in value)
wire(value::Vector{UInt8})=copy(value)
wire(value::AbstractVector)=map(wire,value)
wire(value::Tuple)=map(wire,value)
wire(value)=value
"""Reject incompatible native Julia objects before entering Serialization."""
function artifact_binding()
    layouts=Dict{String,Any}()
    for name in (:_ClosureCosetProof,:_ClosureCosetChunk,:_ClosurePreparedCandidate,:_ClosurePreparedWitness,
            :_ClosureV5ValidationScope,:_ClosurePreparedV5Record,:_ClosurePreparedV5Records,:_ClosurePreparedV5Chunk)
        isdefined(VS,name) || continue
        type=getfield(VS,name)
        layouts[string(name)]=Dict("names"=>collect(string.(fieldnames(type))),"types"=>collect(string.(fieldtypes(type))))
    end
    Dict{String,Any}("schema"=>"vbfsearch-native-replay-artifact-v1","implementation"=>implementation,
        "julia"=>string(VERSION),"julia_commit"=>string(Base.GIT_VERSION_INFO.commit),
        "julia_executable_sha256"=>VS.DiscoveryEvidence.filehash(first(Base.julia_cmd().exec)),
        "machine"=>Sys.MACHINE,"word_size"=>Sys.WORD_SIZE,"result_schema"=>VS.CLOSURE_RESULT_SCHEMA,
        "fixture_sha256"=>VS.DiscoveryEvidence.filehash(cfg["fixture"]),"layouts"=>layouts,
        "tool_sha256"=>VS.DiscoveryEvidence.filehash(@__FILE__))
end
function read_results(path)
    manifest=path*".json"
    isfile(manifest) || error("native replay artifact lacks version binding; recompute it")
    record=JSON3.read(read(manifest,String),Dict{String,Any})
    record["binding"]==artifact_binding() || error("native replay artifact implementation/toolchain/layout differs; recompute it")
    record["sha256"]==VS.DiscoveryEvidence.filehash(path) || error("native replay artifact digest differs")
    deserialize(path)
end
function save_results(path,results)
    serialize(path,results)
    open(path*".json","w") do io
        JSON3.pretty(io,Dict("binding"=>artifact_binding(),"sha256"=>VS.DiscoveryEvidence.filehash(path)))
    end
end
cpu_seconds()=begin
    fields=split(last(split(read("/proc/self/stat",String),") ";limit=2)))
    (parse(Int,fields[12])+parse(Int,fields[13]))/ccall(:sysconf,Clong,(Cint,),2)
end
function create_store(label)
    directory=joinpath(root,label);mkpath(directory)
    identity=Dict{String,Any}("schema"=>VS.CLOSURE_SCHEMA,"implementation"=>copy(implementation),
        "scientific"=>Dict{String,Any}("target_b6"=>52,"extension_cosets"=>65536,"switching_directions"=>255))
    s=VS.ClosureStore(SQLite.DB(joinpath(directory,"closure.sqlite")),directory,VS._closure_lease(directory),identity,1,UInt64(0))
    VS._closure_exec(s,"PRAGMA journal_mode=WAL");VS._closure_exec(s,"PRAGMA synchronous=FULL");VS._closure_exec(s,"PRAGMA foreign_keys=ON")
    VS._closure_create_schema(s.db;normalized=true)
    VS._closure_transaction(s) do
        VS._closure_exec(s,"INSERT INTO metadata VALUES('identity',?)",(VS._closure_text(identity),))
        VS._closure_exec(s,"INSERT INTO metadata VALUES('ledger_encoding','VBFCHN02')")
        seen=Set{Int}()
        for r in vcat(roots,references)
            id=Int(r["original_id"]);id in seen && continue;push!(seen,id)
            p=TOML.parse(r["properties"]);@assert p["lut_sha256"]==r["candidate_id"] && p["sigma_hash"]==r["sigma"]
            VS._closure_insert_candidate!(s,p)
            VS._closure_exec(s,"INSERT INTO parents(id,candidate_id,sigma,origin,source,admitted_utc) VALUES(?,?,?,?,?,?)",
                (id,r["candidate_id"],r["sigma"],"fixture_reference","bounded real V5 replay","frozen"))
            VS._closure_exec(s,"UPDATE candidates SET class_id=?,state='admitted' WHERE id=?",(id,r["candidate_id"]))
        end
        for j in jobs
            VS._closure_exec(s,"INSERT INTO jobs(id,parent_id,kind,job_key,payload) VALUES(?,?,?,?,?)",
                (j["id"],j["parent_id"],j["kind"],j["job_key"],j["payload"]))
        end
    end
    s
end
function fingerprint(db,sql)
    h=SHA.SHA2_256_CTX();n=0
    for r in DBInterface.execute(db,sql)
        for k in propertynames(r)
            v=getproperty(r,k);b=ismissing(v) ? UInt8[] : v isa Vector{UInt8} ? v : Vector{UInt8}(codeunits(string(v)))
            SHA.update!(h,codeunits(string(length(b))*":"));SHA.update!(h,b)
        end
        n+=1
    end
    Dict("rows"=>n,"sha256"=>bytes2hex(SHA.digest!(h)))
end
function science(s)
    Dict("paths"=>fingerprint(s.db,"SELECT parent_id,job_id,method,cursor,child_id,witness FROM paths ORDER BY parent_id,job_id,cursor,child_id"),
        "candidates"=>fingerprint(s.db,"SELECT id,lut_hex,sigma,apn,degree,properties,class_id,state FROM candidates ORDER BY id"),
        "jobs"=>fingerprint(s.db,"SELECT id,parent_id,kind,job_key,payload,status,direction,combination,result FROM jobs ORDER BY id"),
        "coverage"=>fingerprint(s.db,"SELECT job_id,first_x,next_x,total_x,capped,evidence FROM chunks ORDER BY job_id,first_x"))
end
function validate(s)
    @assert isempty(VS._closure_rows(s,"PRAGMA foreign_key_check"))
    @assert only(VS._closure_rows(s,"PRAGMA quick_check"))["quick_check"]=="ok"
    expected=fingerprint(fixture,"SELECT parent_id,job_id,method,cursor,child_id,witness FROM expected_paths ORDER BY parent_id,job_id,cursor,child_id")
    @assert science(s)["paths"]==expected
    for j in jobs
        actual=only(VS._closure_rows(s,"SELECT result,status,direction FROM jobs WHERE id=?",(j["id"],)))
        @assert actual["status"]=="done"
        @assert TOML.parse(actual["result"])==TOML.parse(j["expected_result"])
    end
    science(s)
end
store=create_store("compute")
contexts=VS.ClosureWorkContext()
println(JSON3.write(Dict("event"=>"computing","jobs"=>length(jobs),"output"=>root)));flush(stdout)
compute_rows=Dict{String,Any}[];results=Any[];native_jobs=Any[]
saved_results=haskey(cfg,"results_path") ? read_results(cfg["results_path"]) : nothing
saved_results===nothing || @assert length(saved_results)==length(jobs)
for (index,j) in enumerate(jobs)
    job=only(VS._closure_rows(store,"SELECT * FROM jobs WHERE id=?",(j["id"],)));push!(native_jobs,job)
    packet=VS._closure_work_packet(store,job)
    if saved_results===nothing
        startcpu=cpu_seconds();timed=@timed VS._closure_compute(packet;context=contexts,seconds=Inf,evaluations=256)
        result=timed.value;push!(results,result)
        entry=Dict("job_id"=>j["id"],"wall_seconds"=>timed.time,"cpu_seconds"=>cpu_seconds()-startcpu,
            "gc_seconds"=>timed.gctime,"compile_seconds"=>timed.compile_time,"allocated_bytes"=>timed.bytes,
            "records"=>length(result["work"]["records"]),"cosets"=>result["work"]["processed_cosets"])
        push!(compute_rows,entry);println(JSON3.write(entry));flush(stdout)
    else
        result=saved_results[index]
        @assert result["packet_sha256"]==packet["packet_sha256"]
        push!(results,result)
    end
end
save_results(joinpath(root,"computed-results.jls"),results)
get(cfg,"transport","native")=="wire" && (results=wire(results))
VS._closure_close(store)
trials=Dict{String,Any}[]
for trial in 0:Int(get(cfg,"trials",3))
    store=create_store(trial==0 ? "warmup" : "trial-$trial")
    tracker=completion===nothing ? nothing : completion.install!(store)
    tracker===nothing || completion.track!(tracker,Int[r["original_id"] for r in roots])
    GC.gc()
    startcpu=cpu_seconds()
    timed=if get(cfg,"profile",false) && trial==1
        Profile.init(n=2_000_000,delay=0.001);Profile.clear()
        @timed Profile.@profile for (job,result) in zip(native_jobs,results);VS._closure_apply!(store,job,result);end
    else
        @timed for (job,result) in zip(native_jobs,results);VS._closure_apply!(store,job,result);end
    end
    measured_cpu=cpu_seconds()-startcpu
    digests=validate(store)
    tracker_metrics=tracker===nothing ? nothing : completion.snapshot(tracker)
    if tracker!==nothing
        for r in roots
            parent=r["original_id"]
            expected=VS._closure_count(store,"SELECT COUNT(*) n FROM paths p JOIN candidates c ON c.id=p.child_id WHERE p.job_id IN (SELECT id FROM jobs WHERE parent_id=? AND kind IN ('prepare_v5','v5','switching')) AND c.apn=1 AND c.degree=2 AND c.class_id IS NULL",(parent,))
            actual=only(VS._closure_rows(store,"SELECT unresolved_paths FROM temp.closure_completion_parents WHERE parent_id=?",(parent,)))["unresolved_paths"]
            @assert actual==expected
        end
    end
    entry=Dict("trial"=>trial,"wall_seconds"=>timed.time,"cpu_seconds"=>measured_cpu,
        "mean_cpu_cores"=>measured_cpu/timed.time,"gc_seconds"=>timed.gctime,
        "compile_seconds"=>timed.compile_time,"allocated_bytes"=>timed.bytes,"science"=>digests,
        "completion_tracker"=>tracker_metrics)
    push!(trials,entry);println(JSON3.write(Dict(k=>v for (k,v) in entry if k!="science")));flush(stdout)
    if get(cfg,"profile",false) && trial==1
        serialize(joinpath(root,"apply-profile.jls"),Profile.retrieve())
        for format in (:flat,:tree)
            open(joinpath(root,"apply-profile-$format.txt"),"w") do io
                Profile.print(IOContext(io,:displaysize=>(10000,240));format,sortedby=:count,mincount=5,C=true)
            end
        end
    end
    VS._closure_close(store)
end
@assert all(t["science"]==first(trials)["science"] for t in trials)
summary=Dict("config"=>cfg,"compute"=>compute_rows,"trials"=>trials,"implementation"=>implementation,
    "fixture_sha256"=>VS.DiscoveryEvidence.filehash(cfg["fixture"]),"tool_sha256"=>VS.DiscoveryEvidence.filehash(@__FILE__),
    "result_input_sha256"=>haskey(cfg,"results_path") ? VS.DiscoveryEvidence.filehash(cfg["results_path"]) : nothing,
    "julia"=>string(VERSION),"threads"=>Threads.nthreads(),"peak_rss_bytes"=>Sys.maxrss(),
    "scope"=>"Real bounded V5 packets, complete final same-signature references; mathematical compute separate from repeated application; trial zero warms compilation; fresh WAL/FULL normalized database each trial; paths and final V5 result proofs compared exactly to stopped production")
open(joinpath(root,"summary.json"),"w") do io;JSON3.pretty(io,summary);end
close(fixture)
end
