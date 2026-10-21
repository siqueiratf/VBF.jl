"""Compare exact native Dict V5 application with a completed SQLite replay.

Usage: julia --project=<same frozen package> closure_v5_native_replay.jl CONFIG.json
SQLite is used only for the explicitly separate common fixture/export phase.
Native setup, application, state saving and round-trip loading call no SQLite.
"""
module NativeV5Replay
using VBFSearch, SQLite, TOML, JSON3, SHA, Serialization
include("closure_v5_native.jl")
const FP=VBFSearch
const N=NativeV5Application
const cfg=JSON3.read(read(only(ARGS),String),Dict{String,Any})
const output=abspath(cfg["output"])
ispath(output) && error("native replay output must be new")
mkpath(output)
const implementation=FP.code_identity()

function result_binding()
    layouts=Dict{String,Any}()
    for name in (:_ClosureCosetProof,:_ClosureCosetChunk,:_ClosurePreparedCandidate,:_ClosurePreparedWitness,
            :_ClosureV5ValidationScope,:_ClosurePreparedV5Record,:_ClosurePreparedV5Records,:_ClosurePreparedV5Chunk)
        isdefined(FP,name) || continue
        type=getfield(FP,name)
        layouts[string(name)]=Dict("names"=>collect(string.(fieldnames(type))),"types"=>collect(string.(fieldtypes(type))))
    end
    Dict{String,Any}("schema"=>"vbfsearch-native-replay-artifact-v1","implementation"=>implementation,
        "julia"=>string(VERSION),"julia_commit"=>string(Base.GIT_VERSION_INFO.commit),
        "julia_executable_sha256"=>FP.DiscoveryEvidence.filehash(first(Base.julia_cmd().exec)),
        "machine"=>Sys.MACHINE,"word_size"=>Sys.WORD_SIZE,"result_schema"=>FP.CLOSURE_RESULT_SCHEMA,
        "fixture_sha256"=>FP.DiscoveryEvidence.filehash(cfg["fixture"]),"layouts"=>layouts,
        "tool_sha256"=>FP.DiscoveryEvidence.filehash(cfg["result_producer_tool"]))
end

function checked_results()
    path=cfg["results_path"];record=JSON3.read(read(path*".json",String),Dict{String,Any})
    record["binding"]==result_binding() || error("native input source/toolchain/layout binding differs")
    record["sha256"]==FP.DiscoveryEvidence.filehash(path) || error("native result digest differs")
    deserialize(path)
end

"""Common input export, strictly outside every native-arm timer."""
function export_input()
    db=SQLite.DB(cfg["fixture"]);FP._closure_exec(db,"PRAGMA query_only=ON")
    parents=Any[];jobs=Any[];seen=Set{Int}()
    try
        for table in ("roots","reference_parents")
            for r in FP._closure_rows(db,"SELECT * FROM $table ORDER BY original_id")
                id=Int(r["original_id"]);id in seen && continue;push!(seen,id)
                push!(parents,Dict("id"=>id,"candidate_id"=>r["candidate_id"],"lut_hex"=>r["lut_hex"],
                    "sigma"=>r["sigma"],"properties"=>TOML.parse(r["properties"])))
            end
        end
        for r in FP._closure_rows(db,"SELECT * FROM work_jobs ORDER BY id")
            push!(jobs,Dict("id"=>r["id"],"parent_id"=>r["parent_id"],"kind"=>r["kind"],
                "job_key"=>r["job_key"],"payload"=>TOML.parse(r["payload"]),"expected_result"=>TOML.parse(r["expected_result"])))
        end
    finally
        close(db)
    end
    expected_db=SQLite.DB(cfg["sqlite_trial_db"]);FP._closure_exec(expected_db,"PRAGMA query_only=ON")
    order=try
        N.fingerprint(Tuple(r[k] for k in ("parent_id","job_id","method","cursor","child_id","witness"))
            for r in FP._closure_rows(expected_db,"SELECT parent_id,job_id,method,cursor,child_id,witness FROM paths ORDER BY id"))
    finally
        close(expected_db)
    end
    input=Dict("parents"=>parents,"jobs"=>jobs,"scientific"=>Dict("target_b6"=>52,"extension_cosets"=>65536,"switching_directions"=>255),
        "fixture_sha256"=>FP.DiscoveryEvidence.filehash(cfg["fixture"]),"expected_path_order"=>order)
    path=joinpath(output,"native-input.json")
    open(path,"w") do io;JSON3.write(io,input);end
    input,path
end

cpu_seconds()=begin
    fields=split(last(split(read("/proc/self/stat",String),") ";limit=2)))
    (parse(Int,fields[12])+parse(Int,fields[13]))/ccall(:sysconf,Clong,(Cint,),2)
end
function measured(f)
    before=cpu_seconds();t=@timed f()
    (;t.value,wall_seconds=t.time,cpu_seconds=cpu_seconds()-before,gc_seconds=t.gctime,
        allocated_bytes=t.bytes,compile_seconds=t.compile_time)
end
metrics(t)=Dict(String(k)=>v for (k,v) in pairs(t) if k!=:value)

common=measured(export_input)
input,input_path=common.value
results=checked_results()
length(results)==length(input["jobs"])==8 || error("bounded V5 fixture size differs")
reference=JSON3.read(read(cfg["sqlite_summary"],String),Dict{String,Any})
reference["implementation"]==implementation || error("SQLite comparison uses another implementation")
expected=first(reference["trials"])["science"]
binding=Dict("schema"=>"vbfsearch-native-v5-save-v1","implementation"=>implementation,
    "julia"=>string(VERSION),"julia_commit"=>string(Base.GIT_VERSION_INFO.commit),
    "julia_executable_sha256"=>FP.DiscoveryEvidence.filehash(first(Base.julia_cmd().exec)),
    "input_sha256"=>FP.DiscoveryEvidence.filehash(input_path),"results_sha256"=>FP.DiscoveryEvidence.filehash(cfg["results_path"]),
    "native_tool_sha256"=>FP.DiscoveryEvidence.filehash(joinpath(@__DIR__,"closure_v5_native.jl")),
    "replay_tool_sha256"=>FP.DiscoveryEvidence.filehash(@__FILE__))
function validate(store)
    actual=N.science(store)
    actual==expected || error("native V5 logical candidate/job/path/coverage fingerprints differ: "*JSON3.write(actual))
    N.path_order(store)==input["expected_path_order"] || error("native path insertion order differs")
    for j in input["jobs"]
        current=store.state.jobs[Int(j["id"])]
        current.status=="done" && FP._closure_thaw_proof(current.result)==j["expected_result"] || error("native final V5 result differs")
    end
    actual
end

# Reject malformed late aggregate data and a failure after complete staging.
sanity=N.initialize(input);job=input["jobs"][1];before=sanity.state
before_science=N.science(sanity)
bad=copy(first(results));badwork=copy(bad["work"]);badwork["done"]=!badwork["done"];bad["work"]=badwork
function rejected_unchanged(f,store,before,before_science)
    rejected=try
        f();false
    catch
        true
    end
    rejected && store.state===before && N.science(store)==before_science
end
rejected_unchanged(()->N.apply!(sanity,Int(job["id"]),bad),sanity,before,before_science) || error("rejected native packet partially applied")
rejected_unchanged(()->N.apply!(sanity,Int(job["id"]),first(results);fail_before_commit=true),sanity,before,before_science) || error("late native staging failure partially applied")

trials=Any[]
for trial in 0:Int(get(cfg,"trials",4))
    setup=measured(()->N.initialize(JSON3.read(read(input_path,String),Dict{String,Any})))
    store=setup.value;GC.gc()
    apply=measured() do
        for (job,result) in zip(input["jobs"],results)
            N.apply!(store,Int(job["id"]),result)
        end
    end
    validation=measured(()->validate(store))
    state_bytes=Base.summarysize(store)
    destination=joinpath(output,"trial-$trial.jls")
    saving=measured(()->N.save(store,destination,binding))
    restored=measured(()->N.restore(destination,binding))
    roundtrip=measured(()->validate(restored.value))
    entry=Dict("trial"=>trial,"setup"=>metrics(setup),"apply"=>metrics(apply),"validation"=>metrics(validation),
        "save"=>metrics(saving),"reload"=>metrics(restored),"roundtrip_validation"=>metrics(roundtrip),
        "native_state_bytes"=>state_bytes,"saved_bytes"=>filesize(destination),"science"=>validation.value)
    push!(trials,entry);println(JSON3.write(entry));flush(stdout)
end
summary=Dict("config"=>cfg,"binding"=>binding,"common_export"=>metrics(common),"trials"=>trials,
    "threads"=>Threads.nthreads(),"peak_rss_bytes"=>Sys.maxrss(),"rollback_sanity_checks"=>2,
    "scope"=>"Eight real V5 packets / 9774 paths; exact native dictionaries with production pure validation; atomic copy-on-write commit; structured candidate/witness/coverage evidence; no SQLite operations in native setup/application/save/reload. Common SQLite fixture export and canonical comparison validation are outside native processing. No recursive scheduling, EA admission, checkpoints, reporting, or completion-tracker maintenance.",
    "durability"=>"Native state serialized and fsynced after processing; SQLite WAL/FULL commits each packet during processing; semantics intentionally differ and save cost is separate.")
open(joinpath(output,"summary.json"),"w") do io;JSON3.pretty(io,summary);end
end
