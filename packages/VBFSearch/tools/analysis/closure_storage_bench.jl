"""Compare disk and RAM-backed SQLite using frozen real EA admission jobs.

Run with the search's pinned project and CPU/GC thread settings. CONFIG.json
names a small read-only fixture, disk and RAM output directories, a controller,
and a persistent summary file. Production databases are never opened here.
Only storage location changes between arms; WAL, FULL synchronization, native
packets, ordered admission, savepoints and the bounded refill pool are retained.
"""
module ClosureStorageBench
using VBFSearch, SQLite, TOML, JSON3, SHA, Serialization
const FP = VBFSearch
const ex = FP._closure_exec
const qr = FP._closure_rows

"""Read CPU, coordinator and storage counters at an untimed boundary."""
function counters()
    fields(path) = split(last(split(read(path, String), ") "; limit=2)))
    ticks = Int(ccall(:sysconf, Clong, (Cint,), 2))
    proc = fields("/proc/self/stat")
    tid = Int(ccall(:gettid, Cint, ()))
    thread = fields("/proc/self/task/$tid/stat")
    io = Dict(k => parse(Int, strip(v)) for (k, v) in
        (split(line, ':'; limit=2) for line in eachline("/proc/self/io")))
    (; cpu=(parse(Int, proc[12])+parse(Int, proc[13]))/ticks,
        coordinator=(parse(Int, thread[12])+parse(Int, thread[13]))/ticks, io)
end

"""Hash stable scientific rows, with length delimiters between values."""
function fingerprint(rows)
    context = SHA.SHA2_256_CTX()
    for row in rows, value in row
        bytes = codeunits(string(value))
        SHA.update!(context, codeunits(string(length(bytes))*":"))
        SHA.update!(context, bytes)
    end
    bytes2hex(SHA.digest!(context))
end

"""Create a disposable normalized store containing only fixture work."""
function initialize(directory, fixture, selected)
    ispath(directory) && error("benchmark directory must be new: $directory")
    mkpath(directory)
    db = SQLite.DB(joinpath(directory, "closure.sqlite"))
    s = FP.ClosureStore(db, directory, FP._closure_lease(directory), Dict{String,Any}(), 1, UInt64(0))
    s.solver_session = FP._equivalence_solver_session()
    ex(s, "PRAGMA journal_mode=WAL")
    ex(s, "PRAGMA synchronous=FULL")
    ex(s, "PRAGMA foreign_keys=ON")
    FP._closure_create_schema(db; normalized=true)
    ex(s, "CREATE INDEX jobs_pending_ea ON jobs(id,last_session) WHERE kind='deduplicate' AND status IN ('pending','paused')")
    source = SQLite.DB(fixture)
    try
        ex(source, "PRAGMA query_only=ON")
        refs = qr(source, "SELECT * FROM reference_parents ORDER BY original_id")
        work = qr(source, "SELECT * FROM work_candidates ORDER BY original_job_id")
        length(selected) <= length(work) || error("fixture is too small")
        FP._closure_transaction(s) do
            ex(s, "INSERT INTO sessions(id,started,heartbeat,pid,host,state,budgets) VALUES(1,'fixture','fixture',?,'benchmark','running','')", (getpid(),))
            for row in refs
                p = TOML.parse(row["properties"])
                p["lut_sha256"] == row["candidate_id"] || error("reference identity differs")
                id = FP._closure_insert_candidate!(s, p)
                parent = Int(row["original_id"])
                ex(s, "INSERT INTO parents(id,candidate_id,sigma,origin,source,admitted_utc) VALUES(?,?,?,'fixture_reference','frozen recent campaign','fixture')", (parent,id,row["sigma"]))
                FP._closure_candidate_state!(s, id, "admitted"; class_id=parent)
            end
            for row in work[selected]
                p = TOML.parse(row["properties"])
                p["lut_sha256"] == row["candidate_id"] || error("candidate identity differs")
                isempty(qr(s, "SELECT id FROM parents WHERE candidate_id=?", (row["candidate_id"],))) || error("pending candidate is also a reference parent")
                id = FP._closure_insert_candidate!(s, p; state="awaiting_equivalence")
                FP._closure_add_job!(s, Int(row["owner_parent"]), "deduplicate", "storage-bench:"*id, Dict("candidate_id"=>id))
            end
        end
    finally
        close(source)
    end
    n = length(selected)
    total = FP._closure_count(s, "SELECT COUNT(*) n FROM candidates")
    parents = FP._closure_count(s, "SELECT COUNT(*) n FROM parents")
    counts = Dict("total_parents"=>parents, "promoted_parents"=>0, "exact_luts"=>total,
        "quadratic_apn_luts"=>total, "nonquadratic_apn_luts"=>0,
        "unresolved_equivalence"=>n, "verified_equivalent_luts"=>0)
    (; store=s, counts)
end

"""Execute the production ordered prepare/compute/admit path for fixed jobs."""
function replay(s, controller, contexts, config;on_tick=()->nothing)
    reserve(limit, excluded) = [(job=row,) for row in qr(s,
        controller._reservation_ea_sql(true), (s.session,"[]",controller._reservation_ids_json(excluded),limit))]
    function prepare(item,ticket,slot)
        job = item.job
        ex(s, "UPDATE jobs SET status='running',last_session=?,error='' WHERE id=?", (s.session,job["id"]))
        (; job,packet=FP._closure_equivalence_packet(s,job;native=true),ticket,slot)
    end
    compute(item,slot,stopped) = FP._closure_equivalence_compute(item.packet;
        seconds=1.0,nodes=100_000,context=contexts[slot],solver_session=s.solver_session)
    function apply(item,value,compute_seconds,scheduling)
        outcome = controller.closure_apply_savepoint!(s.db;execute_control=sql->ex(s,sql)) do
            FP._closure_equivalence_apply!(s,item.job,item.packet,value)
        end
        outcome == :done || error("fixture work did not complete: $outcome")
    end
    controller.run_refill_pool!(reserve,prepare,compute,apply;
        concurrency=Int(config["concurrency"]),max_pending=Int(config["reservation_horizon"]),
        reservation_refill_batch=Int(config["reservation_refill_batch"]),
        max_apply_per_step=Int(config["max_apply_per_step"]),key=item->Int(item.job["id"]),on_tick,
        coordinator_step=f->controller.closure_coordinator_step!(f,s.db;execute_control=sql->ex(s,sql)))
end

"""Run, validate and close one fresh storage arm; exclude setup from replay time."""
function trial(directory,fixture,selected,controller,config;label)
    setup = @timed initialize(directory,fixture,selected)
    s = setup.value.store
    contexts = controller.worker_contexts(Int(config["concurrency"]);
        precompute_rank_table=true,packed_rank_table=true,shared_property_cache_entries=8192).contexts
    controller.ClosureOperations.install_report_counters!(s,setup.value.counts)
    GC.gc()
    local result
    try
        before = counters()
        measured = @timed replay(s,controller,contexts,config)
        after = counters()
        jobs = qr(s,"SELECT job_key,status,result FROM jobs ORDER BY job_key")
        all(r->r["status"]=="done",jobs) || error("unfinished fixture jobs")
        candidates = qr(s,"SELECT id,class_id,state FROM candidates WHERE state!='admitted' ORDER BY id")
        length(candidates)==length(selected) || error("candidate count differs")
        all(r->r["state"]=="equivalent",candidates) || error("fixture admission differs from source")
        comparisons = qr(s,"SELECT candidate_id,target_parent,status,evidence FROM comparisons ORDER BY candidate_id,target_parent,id")
        witnesses = Any[]
        for row in comparisons
            proof = TOML.parse(row["evidence"])
            push!(witnesses,(row["candidate_id"],row["target_parent"],row["status"],
                get(proof,"graph_map_columns",nothing),get(proof,"graph_map_constant",nothing),get(proof,"rng_seed",nothing)))
        end
        isempty(qr(s,"PRAGMA foreign_key_check")) || error("foreign key check failed")
        only(qr(s,"PRAGMA quick_check"))["quick_check"]=="ok" || error("SQLite quick check failed")
        counts = controller.ClosureOperations.report_counter_snapshot(controller.ClosureOperations.ReportCounters(s))
        counts["verified_equivalent_luts"]==length(selected) || error("report counter differs")
        files = Dict(name=>filesize(joinpath(directory,name)) for name in readdir(directory) if isfile(joinpath(directory,name)))
        result = Dict{String,Any}("label"=>label,"jobs"=>length(selected),"setup_seconds"=>setup.time,
            "wall_seconds"=>measured.time,"cpu_seconds"=>after.cpu-before.cpu,
            "mean_cpu_cores"=>(after.cpu-before.cpu)/measured.time,
            "coordinator_cpu_seconds"=>after.coordinator-before.coordinator,
            "jobs_per_second"=>length(selected)/measured.time,"gc_seconds"=>measured.gctime,
            "allocated_bytes"=>measured.bytes,"compile_seconds"=>measured.compile_time,
            "peak_rss_bytes"=>Sys.maxrss(),"io_deltas"=>Dict(k=>after.io[k]-v for (k,v) in before.io),
            "scheduler"=>Dict(string(k)=>v for (k,v) in pairs(measured.value)),"files_before_close"=>files,
            "science"=>Dict("jobs"=>fingerprint((r["job_key"],r["status"],r["result"]) for r in jobs),
                "classes"=>fingerprint((r["id"],r["class_id"],r["state"]) for r in candidates),
                "witnesses"=>fingerprint(witnesses)),"comparison_rows"=>length(comparisons))
    finally
        closing=@elapsed FP._closure_close(s)
        @isdefined(result) && (result["close_seconds"]=closing)
    end
    result
end

include("closure_storage_native.jl")

"""Run alternating paired trials and persist each result before the next arm."""
function main(config)
    fixture=abspath(config["fixture"])
    fixture_sha=FP.DiscoveryEvidence.filehash(fixture)
    native_fixture_sha=haskey(config,"native_fixture") ? FP.DiscoveryEvidence.filehash(config["native_fixture"]) : nothing
    implementation=FP.code_identity()
    owner=Module(:StorageBenchmarkController)
    Base.include(owner,config["controller"])
    controller=Base.invokelatest(getfield,owner,:ContinuousSeedSearch)
    source=SQLite.DB(fixture)
    n=try FP._closure_count(source,"SELECT COUNT(*) n FROM work_candidates") finally close(source) end
    warm=Base.invokelatest(trial,joinpath(config["ram_root"],"warmup"),fixture,1:min(64,n),controller,config;label="warmup")
    native_warm=if "native" in config["order"]
        Base.invokelatest(native_trial,config["native_fixture"],1:min(64,n),controller,config;label="native-warmup")
    else
        nothing
    end
    results=Dict{String,Any}[]
    for (i,arm) in enumerate(String.(config["order"]))
        result=if arm=="native"
            Base.invokelatest(native_trial,config["native_fixture"],1:n,controller,config;label="$i-$arm")
        else
            root=arm=="disk" ? config["disk_root"] : arm=="ram" ? config["ram_root"] : error("invalid storage arm")
            result=Base.invokelatest(trial,joinpath(root,"trial-$i"),fixture,1:n,controller,config;label="$i-$arm")
            if arm=="ram"
                destination=joinpath(get(config,"native_output",joinpath(dirname(config["summary"]),"saved-results")),"$i-ram.sqlite");mkpath(dirname(destination))
                result["durable_save_seconds"]=@elapsed begin
                    cp(joinpath(root,"trial-$i","closure.sqlite"),destination)
                    open(destination,"r+") do io
                        ccall(:fsync,Cint,(Cint,),fd(io))==0 || error("RAM SQLite save fsync failed")
                    end
                end
                result["saved_bytes"]=filesize(destination)
            end
            result
        end
        result["storage"]=arm;push!(results,result)
        FP.code_identity()==implementation || error("implementation changed during measurement")
        FP.DiscoveryEvidence.filehash(fixture)==fixture_sha || error("fixture changed")
        native_fixture_sha===nothing || FP.DiscoveryEvidence.filehash(config["native_fixture"])==native_fixture_sha || error("native fixture changed")
        summary=Dict("schema"=>"vbfsearch-storage-comparison-v1","julia"=>string(VERSION),
            "fixture_sha256"=>fixture_sha,"implementation"=>implementation,"config"=>config,
            "native_fixture_sha256"=>native_fixture_sha,
            "warmup"=>warm,"native_warmup"=>native_warm,"results"=>results,
            "scope"=>"bounded replay of recent positive EA admission jobs; complete same-signature reference buckets and production ordered refill; SQLite WAL/FULL versus native dictionary candidates, buckets, jobs and evidence; identical VBF math and full witness verification; native omits database-oriented text preparation and saves at end; excludes construction, full campaign cardinality, reporting, cold segments and portable exports")
        open(config["summary"],"w") do io; JSON3.pretty(io,summary); end
        println(JSON3.write(Dict("event"=>"storage_trial_complete","label"=>result["label"],
            "seconds"=>result["wall_seconds"],"cores"=>result["mean_cpu_cores"],"jobs_per_second"=>result["jobs_per_second"])));flush(stdout)
    end
    all(r->r["science"]==first(results)["science"],results) || error("storage arms disagree scientifically")
end

if abspath(PROGRAM_FILE)==@__FILE__
    main(JSON3.read(read(only(ARGS),String),Dict{String,Any}))
end
end
