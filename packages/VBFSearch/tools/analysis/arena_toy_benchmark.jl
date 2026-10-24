"""Measure the isolated RAM arena toy with real verified APNs and construction work.

The compact-ingest experiment compares identical candidate/edge fields with a
best-case in-memory SQLite transaction. It excludes mathematical verification,
EA admission, full witnesses and durability from BOTH storage timings. A separate
construction experiment retains complete production proof objects and compares
one versus multiple workers on exactly the same nonrecursive work ranges.
"""
module ArenaToyBenchmark
using VBFSearch, SQLite, JSON3, SHA, Random, Statistics
include(joinpath(@__DIR__,"..","arena_toy.jl"))
include(joinpath(@__DIR__,"..","closure_operations.jl"))
const A=ArenaToy
const FP=VBFSearch
const DB=FP.DBInterface

"""Measure computation after explicit setup, including residual managed allocations."""
function measure(f)
    GC.gc()
    before=ClosureOperations.process_cpu_seconds()
    measured=@timed f()
    cpu=ClosureOperations.process_cpu_seconds()-before
    (;value=measured.value,metrics=Dict("seconds"=>measured.time,"cpu_seconds"=>cpu,
        "mean_busy_cores"=>cpu/measured.time,"allocated_bytes"=>measured.bytes,
        "gc_seconds"=>measured.gctime,"compile_seconds"=>measured.compile_time))
end

"""Hash complete canonical rows independently of allocation or arrival order."""
digest(rows)=bytes2hex(SHA.sha256(JSON3.write(rows)))

"""Verify the common real APN fixture before either storage backend is timed."""
function inputs(path)
    rows=JSON3.read(read(path,String),Vector{Dict{String,Any}})
    records=A.VerifiedCandidate[]
    for row in rows
        verified=A.VerifiedCandidate(hex2bytes(row["lut_hex"]))
        bytes2hex(collect(verified.id))==row["id"] || error("fixture LUT identity differs")
        bytes2hex(collect(verified.sigma))==row["sigma"] || error("fixture signature differs")
        push!(records,verified)
    end
    records
end

"""Append the same synthetic edge descriptor for each verified input observation."""
function ingest_ram!(arena,records,observations,concurrency)
    @sync for worker in 1:concurrency
        Threads.@spawn for i in worker:concurrency:length(observations)
            slot,_=A.insert_candidate!(arena,records[observations[i]])
            A.record_path!(arena,A.ArenaPath(mod1(i,32),mod1(i,1024),slot,i,1,i,UInt64(0),UInt8(1)))
        end
    end
    nothing
end

"""Snapshot compact state after workers join, binding edge handles to exact LUT IDs."""
function ram_snapshot(arena)
    paths=sort!(A.path_rows(arena);by=p->p.packet)
    edges=[(p.parent,p.job,bytes2hex(collect(arena.ids[p.candidate])),p.packet,p.record,
        p.cursor,Int(p.combination),Int(p.method)) for p in paths]
    (;candidates=A.candidate_rows(arena),edges)
end

"""Initialize an intentionally compact, memory-only SQLite baseline with prepared SQL."""
function sqlite_store()
    db=SQLite.DB()
    SQLite.execute(db,"PRAGMA foreign_keys=ON")
    SQLite.execute(db,"CREATE TABLE candidates(slot INTEGER PRIMARY KEY,id BLOB UNIQUE NOT NULL,lut BLOB NOT NULL,sigma BLOB NOT NULL,degree INTEGER NOT NULL)")
    SQLite.execute(db,"CREATE TABLE paths(parent INTEGER,job INTEGER,candidate INTEGER REFERENCES candidates(slot),packet INTEGER UNIQUE,record INTEGER,cursor INTEGER,combination INTEGER,method INTEGER)")
    (;db,lookup=SQLite.Stmt(db,"SELECT slot,lut,sigma,degree FROM candidates WHERE id=?"),
        insert=SQLite.Stmt(db,"INSERT INTO candidates(id,lut,sigma,degree) VALUES(?,?,?,?)"),
        path=SQLite.Stmt(db,"INSERT INTO paths VALUES(?,?,?,?,?,?,?,?)"))
end

"""Use preverified byte buffers and one transaction; retain the exact collision guard."""
function ingest_sqlite!(store,wires,observations)
    SQLite.execute(store.db,"BEGIN")
    try
        for i in eachindex(observations)
            wire=wires[observations[i]];slot=0
            for row in DB.execute(store.lookup,(wire.id,))
                row.lut==wire.lut && row.sigma==wire.sigma && row.degree==wire.degree || error("SQLite identity collision")
                slot=Int(row.slot)
            end
            if slot==0
                DB.execute(store.insert,(wire.id,wire.lut,wire.sigma,wire.degree))
                slot=Int(SQLite.last_insert_rowid(store.db))
            end
            DB.execute(store.path,(mod1(i,32),mod1(i,1024),slot,i,1,i,0,1))
        end
        SQLite.execute(store.db,"COMMIT")
    catch
        SQLite.execute(store.db,"ROLLBACK");rethrow()
    end
    nothing
end

"""Read equivalent compact fields with foreign-key and SQLite integrity checks."""
function sqlite_snapshot(store)
    isempty(collect(DB.execute(store.db,"PRAGMA foreign_key_check"))) || error("SQLite foreign key mismatch")
    only([row[1] for row in DB.execute(store.db,"PRAGMA quick_check")])=="ok" || error("SQLite integrity mismatch")
    candidates=[(id=bytes2hex(row.id),lut_hex=bytes2hex(row.lut),sigma=bytes2hex(row.sigma),degree=Int(row.degree))
        for row in DB.execute(store.db,"SELECT id,lut,sigma,degree FROM candidates ORDER BY id")]
    edges=[(Int(row.parent),Int(row.job),bytes2hex(row.id),Int(row.packet),Int(row.record),
        Int(row.cursor),Int(row.combination),Int(row.method)) for row in DB.execute(store.db,
        "SELECT p.*,c.id FROM paths p JOIN candidates c ON c.slot=p.candidate ORDER BY p.packet")]
    (;candidates,edges)
end

"""Close every prepared statement before discarding the disposable database."""
function close_store(store)
    for statement in (store.lookup,store.insert,store.path);DB.close!(statement);end
    close(store.db)
end

"""Measure both storage modes after warmup; setup and parity checks are separate."""
function storage_trials(records;concurrency=8,repeats=32,trials=3)
    observations=repeat(collect(eachindex(records)),repeats)
    shuffle!(Random.Xoshiro(0x1a2b3c),observations)
    wires=[(;id=collect(r.id),lut=collect(r.lut),sigma=collect(r.sigma),degree=Int(r.degree)) for r in records]
    warm_records=records[1:min(16,length(records))];warm_observations=repeat(collect(eachindex(warm_records)),4)
    for n in unique((1,concurrency))
        ingest_ram!(A.CandidateArena(length(warm_records);path_capacity=length(warm_observations)),warm_records,warm_observations,n)
    end
    warm_store=sqlite_store()
    try ingest_sqlite!(warm_store,wires,warm_observations) finally close_store(warm_store) end
    output=Dict{String,Any}[];reference=nothing
    for trial in 1:trials, mode in ("sqlite-memory","arena-1","arena-$concurrency")
        println("STORAGE ",mode," trial ",trial);flush(stdout)
        local measured,snapshot,memory
        if mode=="sqlite-memory"
            store=sqlite_store()
            try
                measured=measure(()->ingest_sqlite!(store,wires,observations))
                snapshot=sqlite_snapshot(store)
                pages=Int(only([row[1] for row in DB.execute(store.db,"PRAGMA page_count")]))
                page_bytes=Int(only([row[1] for row in DB.execute(store.db,"PRAGMA page_size")]))
                memory=Dict("sqlite_page_bytes"=>pages*page_bytes)
            finally
                close_store(store)
            end
        else
            workers=mode=="arena-1" ? 1 : concurrency
            arena=A.CandidateArena(length(records);path_capacity=length(observations))
            measured=measure(()->ingest_ram!(arena,records,observations,workers))
            snapshot=ram_snapshot(arena)
            memory=Dict(string(k)=>v for (k,v) in pairs(A.memory_stats(arena)))
        end
        fingerprints=(candidates=digest(snapshot.candidates),edges=digest(snapshot.edges))
        reference===nothing && (reference=fingerprints)
        fingerprints==reference || error("compact storage parity differs")
        push!(output,merge(measured.metrics,Dict("mode"=>mode,"trial"=>trial,
            "observations"=>length(observations),"distinct_candidates"=>length(snapshot.candidates),
            "observations_per_second"=>length(observations)/measured.metrics["seconds"],
            "parity"=>fingerprints,"memory"=>memory)))
    end
    output
end

"""Build every nonrecursive construction range for a known bounded sparse parent."""
function construction_packets(root_hex;parents=4,cosets_per_packet=2048)
    luts=[hex2bytes(root_hex) .⊻ UInt8(i) for i in 0:parents-1]
    packets=A.packet_factory(luts;directions_per_packet=32,prepare_v5=true)
    planning=A.make_contexts(1;preallocate_v5=true)[1]
    coverage=Dict{String,Any}[]
    for (parent,lut) in enumerate(luts)
        p=FP.properties(lut)
        prep=FP._closure_compute(A.work_packet(p;job_id=1,parent_id=parent,kind="prepare_v5");context=planning,seconds=Inf,evaluations=256)["work"]
        for (space,forms) in enumerate(prep["spaces"])
            payload=Dict("forms"=>forms,"need"=>52-prep["max_b5"],"b5"=>prep["max_b5"])
            probe=A.work_packet(p;job_id=1,parent_id=parent,kind="v5",payload,extension_cosets=1)
            proof=FP._closure_compute(probe;context=planning,seconds=Inf,evaluations=256)["work"]["proof"]
            total=Int(proof["total_x"])
            for first in 1:cosets_per_packet:max(1,total)
                count=min(cosets_per_packet,max(1,total-first+1))
                push!(packets,A.work_packet(p;job_id=length(packets)+1,parent_id=parent,kind="v5",payload,
                    direction=first,extension_cosets=count))
            end
            push!(coverage,Dict("parent"=>parent,"space"=>space,"forms"=>forms,"total_cosets"=>total))
        end
    end
    (;packets,luts,coverage)
end

"""Check complete union of every requested V5 space; worker validation checks each slice."""
function check_coverage(plan,run)
    all(==(1),run.complete) || error("unfinished construction call")
    for parent in eachindex(plan.luts)
        directions=Int[]
        for (packet,result) in zip(plan.packets,run.results)
            packet["kind"]=="switching" && packet["parent_id"]==parent || continue
            append!(directions,[Int(e["direction"]) for e in result["work"]["events"] if e["event"]=="direction_complete"])
        end
        sort!(directions)==collect(1:255) || error("switching union contains a gap or overlap")
    end
    for item in plan.coverage
        intervals=Tuple{Int,Int}[]
        for (packet,result) in zip(plan.packets,run.results)
            packet["kind"]=="v5" && packet["parent_id"]==item["parent"] && packet["payload"]["forms"]==item["forms"] || continue
            proof=result["work"]["proof"]
            push!(intervals,(Int(proof["first_x"]),Int(proof["next_x"])))
        end
        sort!(intervals);cursor=1
        for (first,next) in intervals
            first==cursor || error("V5 union contains a gap or overlap")
            cursor=next
        end
        cursor==item["total_cosets"]+1 || error("V5 union is incomplete")
    end
    true
end

"""Compare real complete fixed nonrecursive math and all proofs, with no SQLite calls."""
function math_trials(root_hex;concurrency=8,trials=2)
    plan=construction_packets(root_hex)
    output=Dict{String,Any}[];reference=nothing;reference_rows=nothing;first_emitting=nothing
    geometry=FP.Fourier.geometry(8)
    for workers in unique((1,concurrency))
        contexts=A.make_contexts(workers;geometry,preallocate_v5=true)
        # Warm every mathematical kind; residual first-touch/compilation remains
        # visible in the per-trial metrics rather than hidden in a speed claim.
        warm_indices=[findfirst(p->p["kind"]==kind,plan.packets) for kind in ("prepare_v5","switching","v5")]
        warm_packets=plan.packets[Int[i for i in warm_indices if i!==nothing]]
        for context in contexts,packet in warm_packets
            FP._closure_compute(packet;context,seconds=Inf,evaluations=256)
        end
        A.run_packets!(A.CandidateArena(65536;path_capacity=262144),warm_packets;concurrency=workers,contexts)
        for trial in 1:trials
            println("MATH workers ",workers," trial ",trial);flush(stdout)
            arena=A.CandidateArena(65536;path_capacity=262144)
            for lut in plan.luts;A.insert_candidate!(arena,lut);end
            measured=measure(()->A.run_packets!(arena,plan.packets;concurrency=workers,contexts))
            run=measured.value;check_coverage(plan,run)
            work=[r["work"] for r in run.results]
            if first_emitting===nothing
                for result in run.results
                    result["kind"]=="v5" || continue
                    records=result["work"]["records"]
                    isempty(records) && continue
                    first_emitting=Dict("packet"=>result["packet"],"cursor"=>first(records)["cursor"],
                        "candidate_id"=>first(records)["properties"]["lut_sha256"])
                    break
                end
            end
            rows=ram_snapshot(arena)
            if reference===nothing
                reference=work;reference_rows=rows
            else
                work==reference || error("mathematical work/proof parity differs")
                rows==reference_rows || error("mathematical compact-state parity differs")
            end
            push!(output,merge(measured.metrics,Dict("workers"=>workers,"trial"=>trial,
                "packets"=>length(plan.packets),"input_parents"=>length(plan.luts),
                "v5_cosets"=>sum(c["total_cosets"] for c in plan.coverage),
                "switching_directions"=>255length(plan.luts),"complete_coverage"=>true,
                "exact_work_and_proof_parity"=>true,"retained_result_bytes"=>run.retained_result_bytes,
                "first_emitting_v5"=>first_emitting,
                "memory"=>Dict(string(k)=>v for (k,v) in pairs(run.memory)))))
        end
    end
    output
end

"""Run explicitly bounded experiments; all output is an analysis artifact."""
function main(args=ARGS)
    length(args)==1 || error("usage: arena_toy_benchmark.jl CONFIG.json")
    cfg=JSON3.read(read(only(args),String),Dict{String,Any})
    concurrency=Int(get(cfg,"concurrency",8));0<concurrency<=Threads.nthreads(:default) || error("invalid Julia worker count")
    output=Dict{String,Any}("schema"=>"vbfsearch-arena-toy-benchmark-v1","julia"=>string(VERSION),
        "scope"=>"compact ingest versus memory SQLite; separate fixed nonrecursive math; no EA/recursion/durability guarantee",
        "math_inputs"=>"four output-translated LUTs of one sparse parent; EA-equivalent controlled workload",
        "memory_scope"=>"SQLite page bytes exclude native allocator/cache overhead; arena owned bytes exclude full result/worker/context memory; neither is peak RSS",
        "concurrency"=>concurrency)
    if haskey(cfg,"fixture")
        setup=@timed inputs(cfg["fixture"])
        output["fixture_verification_seconds"]=setup.time
        output["storage"]=storage_trials(setup.value;concurrency,repeats=Int(get(cfg,"repeats",32)),trials=Int(get(cfg,"storage_trials",3)))
    end
    if haskey(cfg,"root_hex")
        output["math"]=math_trials(cfg["root_hex"];concurrency,trials=Int(get(cfg,"math_trials",2)))
    end
    open(io->JSON3.pretty(io,output),cfg["output"],"w")
    println("ARENA_TOY_BENCHMARK_COMPLETE ",cfg["output"])
end
abspath(PROGRAM_FILE)==(@__FILE__) && main()
end
