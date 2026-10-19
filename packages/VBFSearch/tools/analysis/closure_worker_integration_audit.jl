"""Bounded isolated audit of the real closure worker, ledger and SQLite apply.

The scientific campaign is read only through validated JSON inputs. A new tiny
fixture store receives every write. Timings separate mathematical computation,
per-coset provenance, parent validation, packet construction and durable apply.
"""
module ClosureWorkerIntegrationAudit
using VBF,VBFSearch,JSON3,SHA,SQLite,DBInterface,Dates,TOML,Statistics,Serialization
const FP=VBFSearch
const Q=VBF.QuadraticExtensions

"""One checked elapsed measurement; returned objects remain available."""
function timed(f)
    before=time_ns();value=f();((time_ns()-before)*1e-9,value)
end

"""Measure allocations and GC without changing the mathematical call."""
function detailed(f)
    t=@timed f()
    ((seconds=t.time,bytes=t.bytes,gc_seconds=t.gctime),t.value)
end

"""Create an explicitly isolated campaign fixture from existing verified parents."""
function fixture(directory,records,parents)
    mkpath(directory)
    rootfile=joinpath(directory,"fixture-inputs.tsv")
    selected=[parents[Int(record["parent_id"])] for record in records]
    write(rootfile,join([String(p["lut_hex"]) for p in selected],"\n")*"\n")
    digest=bytes2hex(open(SHA.sha256,rootfile))
    rows=[(lut_sha256=String(p["candidate_id"]),lut_hex=String(p["lut_hex"]),
        sigma_hash=String(p["sigma_hash"]),catalog_id="offline-verified-parent:"*string(p["parent_id"])) for p in selected]
    identity=Dict{String,Any}("schema"=>FP.CLOSURE_SCHEMA,"campaign"=>rootfile,"campaign_sha256"=>digest,
        "roots_sha256"=>digest,"initial_roots"=>length(rows),"qualification_complete"=>true,
        "inputs"=>Dict(rootfile=>digest),"implementation"=>FP.implementation_fingerprint(),
        "julia"=>string(VERSION),"scientific"=>Dict("n"=>8,"m"=>8,"target_b6"=>52,
            "max_kernel"=>23,"extension_cosets"=>65536,"switching_directions"=>255))
    run=joinpath(directory,"fixture-run")
    FP._closure_initialize(run,identity,rows)
    s=FP._closure_open(run)
    for (i,r) in enumerate(records)
        FP._closure_add_job!(s,i,"v5","offline-integration:$i",
            Dict("forms"=>Int.(r["forms"]),"need"=>Int(r["need"]),"b5"=>Int(r["b5"])))
    end
    jobs=FP._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='v5' ORDER BY parent_id")
    s,jobs
end

"""Measure integrated work on up to six holdout V5 jobs with a180s bound."""
function run(holdout_input,parents_input,out;limit=6,max_seconds=180.0)
    mkpath(out);started=time();solver_start=FP.equivalence_solver_fingerprint()
    holdout=JSON3.read(read(holdout_input,String));holdout["complete"] || error("incomplete holdout")
    rawparents=JSON3.read(read(parents_input,String))
    parents=Dict(Int(p["parent_id"])=>p for p in rawparents["parents"])
    records=holdout["records"][1:min(limit,length(holdout["records"]))]
    table_seconds,table=timed(()->Q.PolarRankTable(Q.geometry(8)))
    s,jobs=fixture(joinpath(out,"isolated-fixture"),records,parents)
    context=FP.ClosureWorkContext(;rank_table=table)
    diagnostics=Any[]
    try
        # Compile the real worker and per-coset provenance using an8-coset packet.
        warm=FP._closure_work_packet(s,jobs[1]);warm["extension_cosets"]=8
        warm["packet_sha256"]=FP._closure_packet_digest(warm)
        FP._closure_compute(warm;context,seconds=60,evaluations=256)
        warmup_complete=time()
        for (i,job) in enumerate(jobs)
            time()-started<max_seconds || break
            packet_seconds,packet=timed(()->FP._closure_work_packet(s,job))
            parent_times=Float64[]
            for _ in 1:20
                seconds,_=timed(()->FP._closure_compute_parent(packet));push!(parent_times,seconds)
            end
            raw_timing,raw=detailed(()->Q.v5_extensions(context.geometry,UInt32.(records[i]["forms"]),
                Int(records[i]["need"]),context.work;beta=Q.BETA8,max_kernel=23,
                rank_table=table,du7_filter=:bitsets))
            full_timing,result=detailed(()->FP._closure_compute(packet;context,seconds=60,evaluations=256))
            raw_seconds=raw_timing.seconds;full_seconds=full_timing.seconds
            work=result["work"]
            work["done"] && work["processed_cosets"]==raw.nX || error("fixture packet did not finish")
            expected=Set(bytes2hex(UInt8.(last(Q.function_of(context.geometry,S)).lut)) for S in raw.Ss)
            actual=Set(String(r["properties"]["lut_hex"]) for r in work["records"])
            expected==actual || error("real worker differs from mathematical result")
            json_seconds,wire=timed(()->JSON3.write(result))
            serialization_seconds,serialized=timed() do
                io=IOBuffer();serialize(io,result);take!(io)
            end
            apply_seconds,_=timed(()->FP._closure_apply!(s,job,result))
            push!(diagnostics,Dict("parent_id"=>Int(records[i]["parent_id"]),"fixture_job_id"=>job["id"],
                "packet_build_seconds"=>packet_seconds,"parent_validation_median_seconds"=>median(parent_times),
                "raw_native_seconds"=>raw_seconds,"real_worker_seconds"=>full_seconds,
                "raw_allocated_bytes"=>raw_timing.bytes,"raw_gc_seconds"=>raw_timing.gc_seconds,
                "worker_allocated_bytes"=>full_timing.bytes,"worker_gc_seconds"=>full_timing.gc_seconds,
                "worker_over_raw_ratio"=>full_seconds/raw_seconds,"apply_seconds"=>apply_seconds,
                "processed_cosets"=>work["processed_cosets"],"raw_candidates"=>raw.ncand,
                "worker_candidates"=>work["proof"]["linear_system_candidates"],
                "candidate_records"=>length(work["records"]),"distinct_output_luts"=>length(actual),
                "json_encode_seconds"=>json_seconds,"json_result_bytes"=>sizeof(wire),
                "serialization_seconds"=>serialization_seconds,"serialized_result_bytes"=>length(serialized),
                "compressed_ledger_bytes"=>sizeof(work["ledger"].evidence),"output_parity"=>true))
            println(JSON3.write(last(diagnostics)));flush(stdout)
        end
        report=Dict("schema"=>"vbfsearch-closure-worker-integration-audit-v1",
            "created_utc"=>string(now(UTC))*"Z","tool_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),
            "holdout_input_sha256"=>bytes2hex(open(SHA.sha256,holdout_input)),
            "parents_input_sha256"=>bytes2hex(open(SHA.sha256,parents_input)),
            "solver_sha256"=>solver_start,"solver_sources_unchanged"=>solver_start==FP.equivalence_solver_fingerprint(),
            "threads"=>Threads.nthreads(),
            "rank_table_build_seconds"=>table_seconds,"rank_table_bytes"=>length(table.ranks),
            "setup_including_compile_seconds"=>warmup_complete-started,
            "elapsed_seconds"=>time()-started,"complete"=>length(diagnostics)==length(jobs),
            "jobs"=>diagnostics,
            "fixture_counts"=>Dict("parents"=>FP._closure_count(s.db,"SELECT COUNT(*) n FROM parents"),
                "candidates"=>FP._closure_count(s.db,"SELECT COUNT(*) n FROM candidates"),
                "paths"=>FP._closure_count(s.db,"SELECT COUNT(*) n FROM paths"),
                "pending_ea"=>FP._closure_count(s.db,"SELECT COUNT(*) n FROM jobs WHERE kind='deduplicate'")),
            "scope"=>"Six existing uniform-parent holdout jobs; isolated SQLite fixture only; excludes full-campaign large-index effects and EA execution; no scientific DB mutation or campaign restart")
        write(joinpath(out,"report.json"),JSON3.write(report));report
    finally
        FP._closure_close(s)
    end
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==3 || error("usage: closure_worker_integration_audit HOLDOUT_JSON PARENTS_JSON NEW_OUTPUT_DIRECTORY")
    run(ARGS[1],ARGS[2],ARGS[3])
end
end
