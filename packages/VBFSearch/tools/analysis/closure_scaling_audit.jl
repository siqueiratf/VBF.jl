"""Bounded physical/SMT scaling audit using existing holdout work packets.

Eight, sixteen and thirty-two refer to worker slots. The host has16physical
cores and32logical CPUs; no affinity is imposed. Only a disposable fixture
is written, and no campaign coordinator or scientific ledger is started.
"""
module ClosureScalingAudit
using VBF,VBFSearch,JSON3,SHA,Dates
include("closure_worker_integration_audit.jl")
const FP=VBFSearch
const Q=VBF.QuadraticExtensions

"""CPU time of this process, including its threads, in host clock ticks."""
function cpu_seconds(ticks)
    fields=split(last(split(read("/proc/self/stat",String),')';limit=2)))
    (parse(Float64,fields[12])+parse(Float64,fields[13]))/ticks
end

"""Normalize outputs independently of repeated construction paths."""
function one(context,packet,mode)
    if mode===:worker
        r=FP._closure_compute(packet;context,seconds=120,evaluations=256)
        r["work"]["done"] || error("worker failed to exhaust scaling fixture")
        ids=sort!(unique(String(x["properties"]["lut_sha256"]) for x in r["work"]["records"]))
    else
        p=packet["payload"]
        r=Q.v5_extensions(context.geometry,UInt32.(p["forms"]),Int(p["need"]),context.work;
            beta=Q.BETA8,max_kernel=23,du7_filter=:bitsets,rank_table=context.rank_table)
        !r.capped && r.next_x==r.nX+1 || error("native job did not exhaust")
        ids=sort!([FP.DiscoveryEvidence.lut_id(UInt8.(last(Q.function_of(context.geometry,S)).lut)) for S in r.Ss])
    end
    bytes2hex(SHA.sha256(join(ids,'\n')))
end

"""One persistent scratch context per dynamically refilled compute slot."""
function pool(packets,contexts,mode,jobs,workers)
    queue=Channel{Int}(jobs)
    for i in 1:jobs;put!(queue,i);end
    close(queue)
    outputs=Vector{String}(undef,jobs)
    tasks=[Threads.@spawn begin
        context=contexts[slot]
        for i in queue
            outputs[i]=one(context,packets[mod1(i,length(packets))],mode)
        end
    end for slot in 1:workers]
    fetch.(tasks);outputs
end

"""Measure native and real-worker pools within an explicit300CPU-second cap."""
function run(holdout_input,parents_input,out;max_cpu_seconds=300.0,native_jobs=64,worker_jobs=32,
        modes=(:native,:worker),worker_counts=(8,16,32),table_kind::Symbol=:byte)
    Threads.nthreads()>=32 || error("launch this bounded scaling audit with32 Julia compute threads")
    mkpath(out);started=time();ticks=parse(Float64,read(`getconf CLK_TCK`,String));initial_cpu=cpu_seconds(ticks)
    solver_start=FP.equivalence_solver_fingerprint()
    worker_sources=Dict(name=>joinpath(dirname(pathof(FP)),name) for name in
        ("closure_algorithms.jl","closure_coset_proofs.jl","closure_ledger.jl"))
    worker_hashes=Dict(k=>bytes2hex(open(SHA.sha256,p)) for (k,p) in worker_sources)
    h=JSON3.read(read(holdout_input,String));h["complete"] || error("incomplete holdout")
    raw=JSON3.read(read(parents_input,String));parents=Dict(Int(p["parent_id"])=>p for p in raw["parents"])
    s,jobs=ClosureWorkerIntegrationAudit.fixture(joinpath(out,"isolated-fixture"),h["records"],parents)
    packets=try [FP._closure_work_packet(s,j) for j in jobs] finally FP._closure_close(s) end
    G=Q.geometry(8)
    table=table_kind===:byte ? Q.PolarRankTable(G) : table_kind===:packed ? Q.PackedPolarRankTable(G) :
        throw(ArgumentError("unknown rank-table representation"))
    contexts=[FP.ClosureWorkContext(G,Q.V5Work(23),ReentrantLock(),table) for _ in 1:32]
    # Preallocate and touch scratch outside the measured phases.
    for context in contexts;fill!(context.work.cnt,0);fill!(context.work.g5,0);end
    one(contexts[1],packets[1],:native);one(contexts[1],packets[1],:worker)
    records=Any[];expected=Dict{Int,String}()
    # Isolated worker-only continuations retain an independent native oracle,
    # rather than treating their first repeated worker output as the reference.
    if modes==(:worker,)
        for i in eachindex(packets)
            expected[i]=one(contexts[1],packets[i],:native)
        end
    end
    for mode in modes,workers in worker_counts
        used=cpu_seconds(ticks)-initial_cpu
        used>=max_cpu_seconds-20 && break
        count=mode===:native ? native_jobs : worker_jobs
        GC.gc();before_cpu=cpu_seconds(ticks)
        measured=@timed pool(packets,contexts,mode,count,workers)
        cpu=cpu_seconds(ticks)-before_cpu
        outputs=measured.value
        for i in eachindex(outputs)
            index=mod1(i,length(packets))
            get!(expected,index,outputs[i])==outputs[i] || error("pool output digest mismatch")
        end
        memory=Dict{String,Any}()
        for line in eachline("/proc/self/status")
            pieces=split(line,':';limit=2)
            pieces[1] in ("VmRSS","VmHWM","RssAnon","RssFile") || continue
            memory[pieces[1]*"_KiB"]=parse(Int,first(split(pieces[2])))
        end
        row=Dict("mode"=>String(mode),"worker_slots"=>workers,"jobs"=>count,
            "wall_seconds"=>measured.time,"process_cpu_seconds"=>cpu,
            "average_active_logical_CPUs"=>cpu/measured.time,"jobs_per_second"=>count/measured.time,
            "allocated_bytes"=>measured.bytes,"gc_seconds"=>measured.gctime,
            "process_memory"=>memory,
            "output_digests"=>outputs,
            "exact_output_digests_match"=>true)
        push!(records,row);println(JSON3.write(row));flush(stdout)
        write(joinpath(out,"partial-report.json"),JSON3.write(Dict("complete"=>false,
            "solver_sha256"=>solver_start,"records"=>records,
            "total_process_cpu_seconds"=>cpu_seconds(ticks)-initial_cpu)))
    end
    report=Dict("schema"=>"vbfsearch-closure-physical-smt-scaling-audit-v1",
        "created_utc"=>string(now(UTC))*"Z","holdout_sha256"=>bytes2hex(open(SHA.sha256,holdout_input)),
        "tool_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),"solver_sha256"=>solver_start,
        "solver_sources_unchanged"=>solver_start==FP.equivalence_solver_fingerprint(),
        "worker_source_sha256"=>worker_hashes,
        "worker_sources_unchanged"=>worker_hashes==Dict(k=>bytes2hex(open(SHA.sha256,p)) for (k,p) in worker_sources),
        "launch_argv"=>filter(!isempty,split(read("/proc/self/cmdline",String),'\0')),
        "physical_cores"=>16,"logical_CPUs"=>32,"Julia_compute_threads"=>Threads.nthreads(),
        "affinity"=>"OS scheduling; worker slots are not pinned to distinct physical cores",
        "contexts"=>32,"scratch_bytes"=>32*(sizeof(contexts[1].work.cnt)+sizeof(contexts[1].work.g5)),
        "rank_table_kind"=>String(table_kind),
        "shared_rank_table_bytes"=>sizeof(table_kind===:byte ? table.ranks : table.codes),"max_cpu_seconds"=>max_cpu_seconds,
        "expected_native_digests"=>Dict(string(k)=>v for (k,v) in expected),
        "total_process_cpu_seconds"=>cpu_seconds(ticks)-initial_cpu,"elapsed_seconds"=>time()-started,
        "complete"=>length(records)==length(modes)*length(worker_counts),"records"=>records,
        "scope"=>"Repeated existing holdout jobs, dynamic FIFO compute pool; worker mode includes real parent validation and per-coset provenance, but excludes durable SQL apply/EA admission and network transport. No campaign restarted; only disposable fixture writes.")
    write(joinpath(out,"report.json"),JSON3.write(report));report
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS) in (3,4) || error("usage: closure_scaling_audit HOLDOUT_JSON PARENTS_JSON NEW_OUTPUT_DIRECTORY [worker32|worker32both]")
    if length(ARGS)==4
        if ARGS[4]=="worker32both"
            for kind in (:byte,:packed)
                GC.gc()
                run(ARGS[1],ARGS[2],joinpath(ARGS[3],String(kind));max_cpu_seconds=90.0,
                    modes=(:worker,),worker_counts=(32,),table_kind=kind)
            end
        else
            ARGS[4]=="worker32" || error("unknown bounded phase")
            run(ARGS[1],ARGS[2],ARGS[3];max_cpu_seconds=115.0,modes=(:worker,),worker_counts=(32,))
        end
    else
        run(ARGS[1],ARGS[2],ARGS[3])
    end
end
end
