"""Replay fixed construction and EA work in a disposable normalized checkpoint.

Run each configuration in a fresh process. The input is a frozen SQLite fixture
with `roots` and `reference_parents` tables; production checkpoints are never
opened. Scientific digests cover paths, classes, switching kernels and coverage.
"""
module ClosureCPUReplay
using VBFSearch,SQLite,DBInterface,TOML,SHA,JSON3,Profile,Serialization
const FP=VBFSearch
const ex=FP._closure_exec
const qr=FP._closure_rows
const cfg=JSON3.read(read(only(ARGS),String),Dict{String,Any})
const run=cfg["run"]
const fixture=cfg["fixture"]
ispath(run) && error("replay output must be new")
ispath(cfg["evidence"]) && error("replay evidence must be new")
const pinned_implementation=copy(FP.code_identity())
const pinned_fixture_sha256=FP.DiscoveryEvidence.filehash(fixture)
const pinned_replay_tool_sha256=FP.DiscoveryEvidence.filehash(@__FILE__)
const controller_sources=unique!(vcat([abspath(cfg["controller"])],
    [joinpath(dirname(abspath(cfg["controller"])),name) for name in
        ("closure_baseline.jl","closure_refill.jl","closure_batches.jl","closure_operations.jl","closure_completion.jl",
         "closure_seed_progress.jl","closure_run.jl","closure_supervise.py")]))
const pinned_controller_sources=Dict(path=>(isfile(path) ? FP.DiscoveryEvidence.filehash(path) : nothing)
    for path in controller_sources)
const pinned_controller_sha256=pinned_controller_sources[abspath(cfg["controller"])]

"""Reject edited inputs instead of attributing loaded code to later file contents."""
function assert_replay_bindings()
    FP.code_identity()==pinned_implementation || error("replay implementation changed")
    FP.DiscoveryEvidence.filehash(fixture)==pinned_fixture_sha256 || error("replay fixture changed")
    FP.DiscoveryEvidence.filehash(@__FILE__)==pinned_replay_tool_sha256 || error("replay harness changed")
    for (path,digest) in pinned_controller_sources
        current=isfile(path) ? FP.DiscoveryEvidence.filehash(path) : nothing
        current==digest || error("replay controller source changed: $path")
    end
    nothing
end

assert_replay_bindings()
const sandbox=Module(:ReplayController)
Base.include(sandbox,cfg["controller"])
const CC=getfield(sandbox,:ContinuousSeedSearch)
assert_replay_bindings()

function initialize_fixture()
    assert_replay_bindings()
    source=SQLite.DB(fixture);ex(source,"PRAGMA query_only=ON")
    roots=qr(source,"SELECT * FROM roots ORDER BY original_id")
    refs=qr(source,"SELECT * FROM reference_parents ORDER BY original_id")
    digest=pinned_fixture_sha256
    identity=Dict{String,Any}("schema"=>FP.CLOSURE_SCHEMA,"campaign"=>fixture,"campaign_sha256"=>digest,
        "roots_sha256"=>digest,"initial_roots"=>length(roots),"qualification_complete"=>true,
        "inputs"=>Dict(fixture=>digest),"implementation"=>copy(pinned_implementation),"julia"=>string(VERSION),
        "scope"=>"controlled performance replay; discovered APNs, not published seeds; frozen reference-only parents have no expansion jobs",
        "scientific"=>Dict("n"=>8,"m"=>8,"target_b6"=>52,"max_kernel"=>23,"extension_cosets"=>65536,"switching_directions"=>255))
    mkpath(run);lease=FP._closure_lease(run);db=SQLite.DB(joinpath(run,"closure.sqlite"));s=FP.ClosureStore(db,run,lease,identity,0,UInt64(0))
    try
        ex(db,"PRAGMA journal_mode=WAL");ex(db,"PRAGMA synchronous=FULL");ex(db,"PRAGMA foreign_keys=ON")
        FP._closure_create_schema(db;normalized=true)
        FP._closure_transaction(s) do
            ex(db,"INSERT INTO metadata VALUES('identity',?)",(FP._closure_text(identity),))
            for (key,value) in (("created_utc",FP._closure_now()),("dispatch_sequence","0"),("origin_turn","root"),("method_turn","v5"),("ledger_encoding","VBFCHN02"))
                ex(db,"INSERT INTO metadata VALUES(?,?)",(key,value))
            end
            for (index,row) in enumerate(roots)
                p=FP.properties(hex2bytes(row["lut_hex"]));@assert p["apn"] && p["quadratic"] && p["sigma_hash"]==row["sigma"]
                p["root_index"]=index;p["verification"]="fresh VBF verification of a selected campaign APN; performance fixture only"
                child=FP._closure_insert_candidate!(s,p)
                FP._closure_add_parent!(s,child,p["sigma_hash"];origin="root",source="replay:"*string(row["original_id"]))
            end
            for row in refs
                isempty(qr(db,"SELECT id FROM parents WHERE candidate_id=?",(row["candidate_id"],))) || continue
                p=TOML.parse(row["properties"])
                @assert p["lut_sha256"]==row["candidate_id"] && p["sigma_hash"]==row["sigma"]
                child=FP._closure_insert_candidate!(s,p)
                parent=10_000_000+Int(row["original_id"])
                ex(db,"INSERT INTO parents(id,candidate_id,sigma,origin,source,admitted_utc) VALUES(?,?,?,?,?,?)",
                    (parent,child,row["sigma"],"fixture_reference","frozen reference:"*string(row["original_id"]),"frozen"))
                ex(db,"UPDATE candidates SET class_id=?,state='admitted' WHERE id=?",(parent,child))
            end
        end
        FP.DiscoveryStore.atomic_toml(joinpath(run,"identity.toml"),identity)
        for (relative,digest) in identity["implementation"]
            destination=joinpath(run,"replay","workspace",relative);mkpath(dirname(destination))
            cp(joinpath(FP.DiscoveryInputs.ROOT,relative),destination)
            @assert FP.DiscoveryEvidence.filehash(destination)==digest
        end
        destination=joinpath(run,"replay","inputs","1-"*basename(fixture));mkpath(dirname(destination));cp(fixture,destination)
        ex(db,"INSERT INTO metadata VALUES('initialization_complete','true')")
        FP.DiscoveryStore.atomic_toml(joinpath(run,"progress.toml"),FP.closure_snapshot(run))
    finally
        close(source);FP._closure_close(s)
    end
    assert_replay_bindings()
end

function warmup()
    s=FP._closure_open(run)
    try
        job=only(qr(s.db,"SELECT * FROM jobs WHERE kind='prepare_v5' ORDER BY id LIMIT 1"))
        packet=FP._closure_work_packet(s,job)
        G=FP.Fourier.geometry(8);context=FP.ClosureWorkContext(;rank_table=FP.Fourier.PackedPolarRankTable(G))
        prepared=FP._closure_compute(packet;context,seconds=Inf,evaluations=256)
        spaces=prepared["work"]["spaces"]
        synthetic=copy(job);synthetic["kind"]="v5";synthetic["job_key"]="warmup"
        synthetic["payload"]=FP._closure_text(Dict("forms"=>first(spaces),"need"=>52-prepared["work"]["max_b5"],"b5"=>prepared["work"]["max_b5"]))
        work=FP._closure_compute(FP._closure_work_packet(s,synthetic);context,seconds=Inf,evaluations=256)
        if !isempty(work["work"]["records"])
            p=first(work["work"]["records"])["properties"]
            target=only(qr(s.db,"SELECT p.id parent_id,c.id candidate_id,c.lut_hex FROM parents p JOIN candidates c ON c.id=p.candidate_id WHERE p.sigma=? ORDER BY p.id LIMIT 1",(p["sigma_hash"],)))
            target["saved_exhaustive"]=false
            packet=Dict{String,Any}("schema"=>FP.CLOSURE_EQUIVALENCE_SCHEMA,"job_id"=>0,"job_key"=>"warmup-ea","candidate_id"=>p["lut_sha256"],"lut_hex"=>p["lut_hex"],"sigma"=>p["sigma_hash"],"targets"=>[target])
            packet["packet_sha256"]=FP._closure_packet_digest(packet)
            FP._closure_equivalence_compute(packet;seconds=1.0,nodes=100000)
        end
    finally
        FP._closure_close(s)
    end
    GC.gc()
end

function rows_fingerprint(db,sql)
    hash=SHA.SHA2_256_CTX();n=0
    for row in DBInterface.execute(db,sql)
        for k in propertynames(row)
            v=getproperty(row,k);bytes=ismissing(v) ? UInt8[] : v isa Vector{UInt8} ? v : Vector{UInt8}(codeunits(string(v)))
            SHA.update!(hash,codeunits(string(length(bytes))*":"));SHA.update!(hash,bytes)
        end
        n+=1
    end
    Dict("rows"=>n,"sha256"=>bytes2hex(SHA.digest!(hash)))
end

function science_fingerprints()
    db=SQLite.DB(joinpath(run,"closure.sqlite"));ex(db,"PRAGMA query_only=ON")
    try
        specs=(
            "paths"=>"SELECT p.parent_id,p.method,p.cursor,p.child_id,p.witness FROM paths p ORDER BY p.parent_id,p.method,p.cursor,p.child_id",
            "classes"=>"SELECT c.id,p.candidate_id FROM candidates c LEFT JOIN parents p ON p.id=c.class_id ORDER BY c.id",
            "kernels"=>"SELECT j.job_key,k.direction,k.dimension,k.evidence FROM kernels k JOIN jobs j ON j.id=k.job_id ORDER BY j.job_key,k.direction",
            "coverage"=>"SELECT j.job_key,c.first_x,c.next_x,c.total_x,c.capped,c.evidence FROM chunks c JOIN jobs j ON j.id=c.job_id ORDER BY j.job_key,c.first_x")
        Dict{String,Any}(name=>rows_fingerprint(db,sql) for (name,sql) in specs)
    finally
        close(db)
    end
end

"""Audit logical EA outcomes separately from the four upgrade-gate digests.

Solver deadlines may change outcomes between cold and warm runs. These fields
are reported without asserting equality or hashing source-bound proof bytes.
"""
function admission_job_audit()
    db=SQLite.DB(joinpath(run,"closure.sqlite"));ex(db,"PRAGMA query_only=ON")
    try
        comparisons=FP._closure_normalized(db) ? "closure_comparisons" : "comparisons"
        Dict{String,Any}(
            "job_status_histogram"=>qr(db,"SELECT kind,status,COUNT(*) rows FROM jobs GROUP BY kind,status ORDER BY kind,status"),
            "candidate_state_histogram"=>qr(db,"SELECT state,COUNT(*) rows FROM candidates GROUP BY state ORDER BY state"),
            "comparison_status_histogram"=>qr(db,"SELECT status,COUNT(*) rows FROM $comparisons GROUP BY status ORDER BY status"),
            "unresolved_equivalence_candidates"=>FP._closure_count(db,"SELECT COUNT(*) n FROM candidates WHERE state='unresolved_equivalence'"),
            "unclassified_quadratic_apn_candidates"=>FP._closure_count(db,"SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2 AND class_id IS NULL"),
            "unfinished_equivalence_jobs"=>FP._closure_count(db,"SELECT COUNT(*) n FROM jobs WHERE kind='deduplicate' AND status!='done'"),
            "comparison_outcomes"=>rows_fingerprint(db,
                "SELECT e.candidate_id,p.candidate_id AS target_candidate_id,e.status FROM $comparisons e JOIN parents p ON p.id=e.target_parent ORDER BY e.candidate_id,p.candidate_id,e.status"),
            "scope"=>"logical EA status and job audit; excludes source-bound proof bytes, witnesses, node counts and timing; seconds-bounded cold/warm outcomes are not required to match")
    finally
        close(db)
    end
end

function cpu_seconds()
    fields=split(last(split(read("/proc/self/stat",String),") ";limit=2)))
    (parse(Int,fields[12])+parse(Int,fields[13]))/ccall(:sysconf,Clong,(Cint,),2)
end

"""Read Linux accounting outside the timed controller; retain partial availability."""
function linux_runtime_snapshot()
    threads=Dict{Int,Tuple{UInt64,UInt64}}();io=Dict{String,UInt64}()
    coordinator=nothing;ticks=0;cpu_error="";io_error="";unreadable=Int[]
    if !Sys.islinux()
        return (;available=false,threads,io,coordinator,ticks,cpu_error="Linux /proc unavailable",
            io_error="Linux /proc unavailable",unreadable)
    end
    try
        coordinator=Int(ccall(:gettid,Cint,()))
    catch error
        cpu_error="gettid unavailable: "*sprint(showerror,error)
    end
    try
        ticks=Int(ccall(:sysconf,Clong,(Cint,),2))
        ticks>0 || error("invalid _SC_CLK_TCK")
        for name in readdir("/proc/self/task")
            tid=tryparse(Int,name);tid===nothing && continue
            try
                fields=split(last(split(read("/proc/self/task/$tid/stat",String),") ";limit=2)))
                threads[tid]=(parse(UInt64,fields[12]),parse(UInt64,fields[13]))
            catch
                # A helper may exit between listing /proc and reading its stat.
                push!(unreadable,tid)
            end
        end
    catch error
        cpu_error=isempty(cpu_error) ? sprint(showerror,error) : cpu_error*"; "*sprint(showerror,error)
        empty!(threads)
    end
    try
        for line in eachline("/proc/self/io")
            key,value=split(line,':';limit=2)
            io[key]=parse(UInt64,strip(value))
        end
    catch error
        io_error=sprint(showerror,error);empty!(io)
    end
    (;available=!isempty(threads)||!isempty(io),threads,io,coordinator,ticks,cpu_error,io_error,unreadable)
end

"""Separate OS-thread CPU consumption from inclusive coordinator wall timers."""
function linux_runtime_deltas(before,after,wall_seconds,process_cpu_seconds)
    available=before.available && after.available
    cpu_available=!isempty(before.threads) && !isempty(after.threads) && before.ticks>0 && before.ticks==after.ticks
    records=Dict{String,Any}[];counter_resets=Int[]
    if cpu_available
        for tid in intersect(keys(before.threads),keys(after.threads))
            u0,s0=before.threads[tid];u1,s1=after.threads[tid]
            if u1<u0 || s1<s0
                push!(counter_resets,tid);continue
            end
            user=Float64(u1-u0)/before.ticks;system=Float64(s1-s0)/before.ticks
            seconds=user+system
            push!(records,Dict("tid"=>tid,"user_cpu_seconds"=>user,"system_cpu_seconds"=>system,
                "cpu_seconds"=>seconds,"mean_cpu_cores"=>wall_seconds>0 ? seconds/wall_seconds : 0.0,
                "process_cpu_share"=>process_cpu_seconds>0 ? seconds/process_cpu_seconds : 0.0))
        end
    end
    sort!(records;by=row->(-row["cpu_seconds"],row["tid"]))
    coordinator=before.coordinator===nothing ? nothing :
        findfirst(row->row["tid"]==before.coordinator,records)
    coordinator_record=coordinator===nothing ? nothing : records[coordinator]
    others=[row for row in records if row["tid"]!=before.coordinator]
    appeared=sort!(collect(setdiff(keys(after.threads),keys(before.threads))))
    disappeared=sort!(collect(setdiff(keys(before.threads),keys(after.threads))))
    io_available=!isempty(before.io) && !isempty(after.io) && keys(before.io)==keys(after.io)
    io=io_available ? Dict(key=>Int128(after.io[key])-Int128(value) for (key,value) in before.io) : Dict{String,Int128}()
    Dict{String,Any}(
        "available"=>available,
        "thread_cpu"=>Dict("available"=>cpu_available,"ticks_per_second"=>before.ticks,
            "coordinator_tid_before"=>before.coordinator,"coordinator_tid_after"=>after.coordinator,
            "coordinator"=>coordinator_record,"worker_helper_threads"=>others,
            "observed_cpu_seconds"=>sum(row["cpu_seconds"] for row in records;init=0.0),
            "appeared_tids"=>appeared,"disappeared_tids"=>disappeared,"counter_reset_tids"=>sort!(counter_resets),
            "unreadable_tids_before"=>before.unreadable,"unreadable_tids_after"=>after.unreadable,
            "errors"=>[before.cpu_error,after.cpu_error],
            "scope"=>"Linux OS-thread user+system CPU deltas for TIDs readable at both boundaries; other TIDs are worker/helper threads without Julia-pool attribution; mean_cpu_cores is CPU seconds / measured wall seconds, process_cpu_share is fraction of measured process CPU; jiffy quantization and outside-timed snapshots cause small boundary differences"),
        "process_io"=>Dict("available"=>io_available,"deltas"=>io,
            "errors"=>[before.io_error,after.io_error],
            "scope"=>"Linux /proc/self/io counter deltas outside timed boundaries; rchar/wchar include cached I/O, read_bytes/write_bytes count storage I/O, syscr/syscw count calls, cancelled_write_bytes counts cancelled writes"))
end

initialize_fixture();warmup()
config=Dict{String,Any}("run"=>run,"evidence"=>cfg["evidence"],"concurrency"=>Int(get(cfg,"concurrency",Threads.nthreads(:default))),"window_size"=>2,
    "max_windows"=>1,"duration_seconds"=>Float64(get(cfg,"duration_seconds",600.0)),"equivalence_seconds"=>1.0,"equivalence_nodes"=>100000,
    "precompute_rank_table"=>true,"packed_rank_table"=>true,"parent_scope"=>"all","baseline_policy"=>"summary")
for key in ("reservation_horizon","reservation_refill_batch","window_size","max_windows","report_interval_seconds",
        "global_count_interval_seconds","rolling_windows","measure_result_bytes","shared_property_cache_entries",
        "cached_global_counts","max_apply_per_step","precompute_rank_table","packed_rank_table")
    haskey(cfg,key) && (config[key]=cfg[key])
end
cold_controller=nothing
if get(cfg,"warm_controller",false)
    assert_replay_bindings()
    cold_cpu=cpu_seconds()
    cold=@timed CC.run(config)
    cold_cpu=cpu_seconds()-cold_cpu
    assert_replay_bindings()
    @assert cold.value["state"]=="paused_window_limit"
    cold_controller=Dict("wall_seconds"=>cold.time,"cpu_seconds"=>cold_cpu,
        "mean_cpu_cores"=>cold_cpu/cold.time,"gc_seconds"=>cold.gctime,
        "allocated_bytes"=>cold.bytes,"compile_seconds"=>cold.compile_time,
        "result"=>cold.value,"science"=>science_fingerprints(),"admission_job_audit"=>admission_job_audit(),
        "implementation"=>pinned_implementation,"fixture_sha256"=>pinned_fixture_sha256,
        "controller_sha256"=>pinned_controller_sha256,"controller_sources_sha256"=>pinned_controller_sources,
        "replay_tool_sha256"=>pinned_replay_tool_sha256,
        "runtime_metrics"=>JSON3.read(read(joinpath(cfg["evidence"],"progress.json"),String))["runtime_metrics"])
    open(cfg["summary"]*".cold-controller.json","w") do io;JSON3.pretty(io,cold_controller);end
    rm(run;recursive=true)
    rm(cfg["evidence"];recursive=true)
    initialize_fixture()
    GC.gc()
end
assert_replay_bindings()
function measured_run()
    if get(cfg,"profile_cpu",false)
        Profile.init(n=20_000_000,delay=0.003)
        Profile.clear()
        return @timed Profile.@profile CC.run(config)
    elseif get(cfg,"profile_allocations",false)
        Profile.Allocs.clear()
        return @timed Profile.Allocs.@profile sample_rate=Float64(get(cfg,"allocation_sample_rate",0.00001)) CC.run(config)
    end
    @timed CC.run(config)
end
linux_before=linux_runtime_snapshot()
startcpu=cpu_seconds();before=Base.gc_num();timed=measured_run();after=Base.gc_num();result=timed.value
measured_cpu=cpu_seconds()-startcpu
linux_after=linux_runtime_snapshot()
if get(cfg,"profile_cpu",false)
    prefix=cfg["summary"]*".cpu-profile"
    serialize(prefix*".jls",Profile.retrieve())
    for (format,label,threads) in ((:flat,"flat",1:typemax(Int)),(:tree,"tree",1:typemax(Int)),(:flat,"main",1))
        open(prefix*"."*label*".txt","w") do io
            output=IOContext(io,:displaysize=>(10000,240))
            Profile.print(output;format,sortedby=:count,mincount=20,C=label!="main",threads)
        end
    end
elseif get(cfg,"profile_allocations",false)
    allocations=Profile.Allocs.fetch()
    serialize(cfg["summary"]*".allocations.jls",allocations)
    portable=[Dict("bytes"=>a.size,"type"=>string(a.type),
        "stack"=>[Dict("file"=>string(f.file),"line"=>f.line,"function"=>string(f.func)) for f in a.stacktrace])
        for a in allocations.allocs]
    open(cfg["summary"]*".allocations.json","w") do io
        JSON3.write(io,Dict("sample_rate"=>get(cfg,"allocation_sample_rate",0.00001),"allocations"=>portable))
    end
end
@assert result["state"]=="paused_window_limit"
science=science_fingerprints()
cold_controller===nothing || @assert science==cold_controller["science"]
audit=admission_job_audit()
assert_replay_bindings()
summary=Dict{String,Any}("arm"=>cfg["arm"],"wall_seconds"=>timed.time,"cpu_seconds"=>measured_cpu,
    "mean_cpu_cores"=>measured_cpu/timed.time,"gc_seconds"=>timed.gctime,"gc_fraction"=>timed.gctime/timed.time,
    "allocated_bytes"=>timed.bytes,"compile_seconds"=>timed.compile_time,"peak_rss_bytes"=>Sys.maxrss(),
    "peak_rss_scope"=>"process lifetime high-water mark, including initialization, mathematical warmup and any excluded cold-controller replay; not a measured-run-only peak",
    "gc_pause_count"=>after.pause-before.pause,"gc_safepoint_seconds"=>(after.total_time_to_safepoint-before.total_time_to_safepoint)/1e9,
    "linux_runtime_accounting"=>linux_runtime_deltas(linux_before,linux_after,timed.time,measured_cpu),
    "result"=>result,"science"=>science,"admission_job_audit"=>audit,"config"=>cfg,"controller_warmed"=>cold_controller!==nothing,
    "cold_controller_run"=>cold_controller,
    "implementation"=>pinned_implementation,"julia"=>string(VERSION),
    "fixture_sha256"=>pinned_fixture_sha256,
    "controller_sha256"=>pinned_controller_sha256,"controller_sources_sha256"=>pinned_controller_sources,
    "replay_tool_sha256"=>pinned_replay_tool_sha256,
    "julia_compute_threads"=>Threads.nthreads(:default),"julia_gc_threads"=>Threads.ngcthreads(),
    "heap_size_hint_bytes"=>Int(Base.JLOptions().heap_size_hint),
    "runtime_metrics"=>JSON3.read(read(joinpath(cfg["evidence"],"progress.json"),String))["runtime_metrics"],
    "scope"=>cold_controller===nothing ?
        "Bounded fixed fixture replay in a new checkpoint; initialization and mathematical warmup excluded; controller compilation and rank-table construction included; no production database access" :
        "Bounded fixed fixture replay after a full identical cold-controller replay; new checkpoint and caches, same process/compiler; rank-table construction included; initialization and warmup excluded; cold and warm scientific digests identical; no production database access")
open(cfg["summary"],"w") do io;JSON3.pretty(io,summary);end
println(JSON3.write(Dict("event"=>"benchmark_complete","arm"=>cfg["arm"],"wall_seconds"=>summary["wall_seconds"],"mean_cpu_cores"=>summary["mean_cpu_cores"],"gc_fraction"=>summary["gc_fraction"])))
end
