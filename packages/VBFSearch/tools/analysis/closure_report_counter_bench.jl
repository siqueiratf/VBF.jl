"""Estimate report-counter tradeoffs at production cardinality, without LUT copies.

Run under docs/inspector with one Julia compute thread and one GC thread:
    julia --project=docs/inspector --threads=1,0 --gcthreads=1,0 \
        packages/VBFSearch/tools/analysis/closure_report_counter_bench.jl CONFIG.toml

Example configuration (the eleven-million-row case is explicitly requested):
    output = "/tmp/vbf-report-counter-bench"
    historical_candidates = [1000000, 11066907]
    appended_candidates = 50000
    report_every_candidates = [0, 5000]
    candidates_per_new_parent = 3
    candidate_cycles_per_completed_parent = 50
    repetitions = 3

Each candidate cycle performs an INSERT and classification UPDATE; every third
cycle admits a parent, near the replay's candidate/admission ratio. Reporting
cadence is a separate proxy: 5,000 cycles at fifty cycles per completed work
parent represent one 100-parent fold. Admissions are not window completions;
these configurable ratios do not establish the production campaign's cadence.
The historical tables retain counter columns, 64-byte identities/signatures,
and production covering indexes. LUTs, templates, witnesses and computations
are absent. This estimates count-scan savings and marginal trigger SQL costs;
it is not a search-throughput benchmark or evidence of full-node scaling.

Trials use one outer transaction, then roll back to the identical historical
contents. Periodic savepoints exercise the same rollback mechanism as packet
applications. FULL durability is configured, but commit/fsync costs are absent
from the timed trials. All comparisons use the same physical tables, mutations
and warmed count queries. Only the production TEMP counter helper is toggled.
"""
module ClosureReportCounterBench
using VBFSearch, SQLite, TOML, Statistics
const FP=VBFSearch
include(joinpath(@__DIR__,"..","closure_operations.jl"))
const O=ClosureOperations

const MIXERS=(2654435761,2246822519,3266489917,668265263,374761393,1274126177,42595009,362437)
const COUNT_QUERIES=(
    "total_parents"=>"SELECT COUNT(*) n FROM parents",
    "promoted_parents"=>"SELECT COUNT(*) n FROM parents WHERE origin='discovered'",
    "exact_luts"=>"SELECT COUNT(*) n FROM candidates",
    "quadratic_apn_luts"=>"SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2",
    "nonquadratic_apn_luts"=>"SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree>2",
    "unresolved_equivalence"=>"SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2 AND class_id IS NULL",
    "verified_equivalent_luts"=>"SELECT COUNT(*) n FROM candidates WHERE state='equivalent'")
const TRIGGER_NAMES=("candidate_insert","candidate_delete","candidate_update","parent_insert","parent_delete","parent_update")

identity_text(i)=join(string((UInt64(i)*UInt64(m))&UInt64(0xffffffff);base=16,pad=8) for m in MIXERS)
identity_sql(expr)="printf('"*repeat("%08x",8)*"',"*join(["(($expr)*$m)&4294967295" for m in MIXERS],",")*")"
counts(s)=Dict(key=>FP._closure_count(s,sql) for (key,sql) in COUNT_QUERIES)
emit(value)=(println(FP.JSON3.write(value));flush(stdout))

function initialize!(s,n;batch_size)
    # Ratios come from the read-only 2026-10-20 production count profile.
    parents=max(1,round(Int,n*4151043/11066907))
    roots=min(parents,max(1,round(Int,n*24294/11066907)))
    unresolved=max(1,round(Int,n*364/11066907))
    for sql in (
            "CREATE TABLE candidates(id TEXT PRIMARY KEY,sigma TEXT,apn INTEGER NOT NULL,degree INTEGER NOT NULL,class_id INTEGER,state TEXT NOT NULL)",
            "CREATE TABLE parents(id INTEGER PRIMARY KEY,sigma TEXT,origin TEXT NOT NULL)")
        FP._closure_exec(s,sql)
    end
    class="CASE WHEN i<=$parents THEN i ELSE ((i-$parents-1)%$parents)+1 END"
    candidate_sql="WITH RECURSIVE seq(i) AS (SELECT ? UNION ALL SELECT i+1 FROM seq WHERE i<?) INSERT INTO candidates SELECT "*
        identity_sql("i")*","*identity_sql(class)*",1,2,CASE WHEN i>$(n-unresolved) THEN NULL ELSE $class END,"*
        "CASE WHEN i>$(n-unresolved) THEN 'awaiting_equivalence' WHEN i<=$parents THEN 'admitted' ELSE 'equivalent' END FROM seq"
    parent_sql="WITH RECURSIVE seq(i) AS (SELECT ? UNION ALL SELECT i+1 FROM seq WHERE i<?) INSERT INTO parents SELECT i,"*
        identity_sql("i")*",CASE WHEN i<=$roots THEN 'root' ELSE 'discovered' END FROM seq"
    for (name,limit,sql) in (("candidates",n,candidate_sql),("parents",parents,parent_sql))
        for first in 1:batch_size:limit
            last=min(limit,first+batch_size-1)
            FP._closure_transaction(s) do
                FP._closure_exec(s,sql,(first,last))
            end
            emit(Dict("event"=>"historical_rows","table"=>name,"rows"=>last,"target"=>limit))
        end
    end
    for sql in (
            "CREATE INDEX candidates_counters ON candidates(apn,degree,sigma,class_id)",
            "CREATE INDEX candidates_state ON candidates(state)",
            "CREATE INDEX parents_sigma ON parents(sigma)",
            "CREATE INDEX parents_origin ON parents(origin)")
        FP._closure_exec(s,sql)
    end
    (;parents,roots,unresolved)
end

function remove_counters!(s)
    for name in TRIGGER_NAMES
        FP._closure_exec(s,"DROP TRIGGER temp.closure_runtime_$name")
    end
    FP._closure_exec(s,"DROP TABLE temp.closure_runtime_counts")
end

function append_cycles!(s,mutations;report_every,counters,savepoint_every)
    refreshes=0;report_seconds=0.0
    for (i,item) in enumerate(mutations)
        savepoint_every>0 && (i-1)%savepoint_every==0 && FP._closure_exec(s,"SAVEPOINT counter_bench_packet")
        FP._closure_exec(s,"INSERT INTO candidates(id,sigma,apn,degree,class_id,state) VALUES(?,?,1,2,NULL,'awaiting_equivalence')",(item.id,item.sigma))
        item.admitted && FP._closure_exec(s,"INSERT INTO parents(id,sigma,origin) VALUES(?,?,'discovered')",(item.parent,item.sigma))
        FP._closure_exec(s,"UPDATE candidates SET class_id=?,state=? WHERE id=?",(item.parent,item.admitted ? "admitted" : "equivalent",item.id))
        if savepoint_every>0 && (i%savepoint_every==0 || i==length(mutations))
            FP._closure_exec(s,"RELEASE counter_bench_packet")
        end
        if report_every>0 && i%report_every==0
            t=time_ns()
            counters===nothing ? counts(s) : O.report_counter_snapshot(counters)
            report_seconds+=(time_ns()-t)*1e-9;refreshes+=1
        end
    end
    (;refreshes,report_seconds)
end

function trial!(s,mutations;use_counters,report_every,savepoint_every,warmup_candidates)
    counts(s) # Prime all count indexes equally before timing the warm refresh.
    warm=@timed counts(s)
    initial=warm.value
    setup=@timed(use_counters ? O.install_report_counters!(s,initial) : nothing)
    counters=setup.value
    # Compile the loop and warm the write paths before measuring either arm.
    FP._closure_exec(s,"BEGIN IMMEDIATE")
    try
        append_cycles!(s,view(mutations,1:min(warmup_candidates,length(mutations)));
            report_every=0,counters,savepoint_every)
    finally
        FP._closure_exec(s,"ROLLBACK")
    end
    FP._closure_exec(s,"BEGIN IMMEDIATE")
    local measured,final
    try
        measured=@timed append_cycles!(s,mutations;report_every,counters,savepoint_every)
        final=counts(s) # Untimed exact validation, including in the no-report arm.
        counters===nothing || O.report_counter_snapshot(counters)==final || error("transactional counter parity failed")
        final["exact_luts"]==initial["exact_luts"]+length(mutations) || error("candidate append count differs")
        final["total_parents"]==initial["total_parents"]+count(m->m.admitted,mutations) || error("parent append count differs")
    finally
        FP._closure_exec(s,"ROLLBACK")
    end
    counts(s)==initial || error("trial rollback did not restore historical counts")
    counters===nothing || O.report_counter_snapshot(counters)==initial || error("counter rollback differs")
    use_counters && remove_counters!(s)
    Dict{String,Any}("use_counters"=>use_counters,"report_every_candidates"=>report_every,
        "candidate_cycles"=>length(mutations),"sql_row_mutations"=>2length(mutations)+count(m->m.admitted,mutations),
        "wall_seconds"=>measured.time,"gc_seconds"=>measured.gctime,"allocated_bytes"=>measured.bytes,
        "report_seconds"=>measured.value.report_seconds,"refreshes"=>measured.value.refreshes,
        "warm_count_seconds"=>warm.time,"counter_setup_seconds"=>setup.time,
        "initial_counts"=>initial,"final_counts"=>final)
end

function run(config)
    Threads.nthreads(:default)==1 || error("use one Julia compute thread for this coordinator-only experiment")
    output=abspath(String(config["output"]));ispath(output) && error("output must be a new directory")
    sizes=Int.(get(config,"historical_candidates",[1_000_000]))
    appended=Int(get(config,"appended_candidates",50_000))
    periods=Int.(get(config,"report_every_candidates",[0,5000]))
    per_parent=Int(get(config,"candidates_per_new_parent",3))
    per_completed=Int(get(config,"candidate_cycles_per_completed_parent",50))
    repetitions=Int(get(config,"repetitions",3))
    batch=Int(get(config,"build_batch_size",100_000))
    savepoint_every=Int(get(config,"savepoint_every_candidates",50))
    warmup=Int(get(config,"warmup_candidates",500))
    cache_kib=Int(get(config,"sqlite_cache_kib",2000))
    build_cache_kib=Int(get(config,"build_cache_kib",262144))
    largest_id=min(Int(typemax(UInt32)),typemax(Int)÷maximum(MIXERS))
    !isempty(sizes) && all(n->1<=n && n+appended<=largest_id,sizes) || error("invalid historical cardinalities")
    1<=appended<=1_000_000 && per_parent>0 && per_completed>0 && repetitions>0 && batch>0 && savepoint_every>=0 && warmup>=0 || error("invalid workload bounds")
    !isempty(periods) && all(>=(0),periods) || error("invalid reporting periods")
    cache_kib>0 && build_cache_kib>0 || error("page cache sizes must be positive")
    mkpath(output)
    FP.DiscoveryStore.atomic_toml(joinpath(output,"config.toml"),config)
    results=Dict{String,Any}[]
    for n in sizes
        directory=joinpath(output,"rows-$n");mkpath(directory)
        # Allow about 700 bytes/row for tables, indexes, journal and index builds.
        reserve=Int(get(config,"reserve_free_bytes",2*1024^3))
        reserve>=0 || error("reserve_free_bytes must be nonnegative")
        available=Base.Filesystem.diskstat(directory).available
        available>=700n+reserve || error("insufficient disk space for bounded synthetic tables")
        db=SQLite.DB(joinpath(directory,"counts.sqlite"));lease=FP._closure_lease(directory)
        s=FP.ClosureStore(db,directory,lease,Dict{String,Any}(),0,UInt64(0))
        try
            FP._closure_exec(s,"PRAGMA journal_mode=WAL");FP._closure_exec(s,"PRAGMA synchronous=FULL")
            FP._closure_exec(s,"PRAGMA cache_size=-$build_cache_kib")
            built=@timed initialize!(s,n;batch_size=batch)
            FP._closure_exec(s,"PRAGMA cache_size=-$cache_kib")
            FP._closure_exec(s,"PRAGMA shrink_memory")
            base=built.value
            mutations=[begin
                admitted=i%per_parent==0
                parent=admitted ? base.parents+i÷per_parent : 1+(i-1)%base.parents
                (;id=identity_text(n+i),sigma=identity_text(parent),parent,admitted)
            end for i in 1:appended]
            plans=Dict(key=>FP._closure_rows(s,"EXPLAIN QUERY PLAN "*sql) for (key,sql) in COUNT_QUERIES)
            for period in periods,repeat in 1:repetitions
                for enabled in (isodd(repeat) ? (false,true) : (true,false))
                    record=trial!(s,mutations;use_counters=enabled,report_every=period,savepoint_every,warmup_candidates=warmup)
                    merge!(record,Dict("historical_candidates"=>n,"historical_parents"=>base.parents,"repetition"=>repeat,
                        "historical_build_seconds"=>built.time,"sqlite_cache_kib"=>cache_kib,"build_cache_kib"=>build_cache_kib,
                        "new_parents_per_report"=>period==0 ? 0.0 : period/per_parent,
                        "completed_parent_proxy_per_report"=>period==0 ? 0.0 : period/per_completed,"query_plans"=>plans))
                    push!(results,record)
                    emit(merge(Dict("event"=>"counter_trial"),record))
                    open(joinpath(output,"results.json"),"w") do io
                        FP.JSON3.pretty(io,results)
                    end
                end
            end
        finally
            FP.DiscoveryStore.close_statements!(s.statements);close(db);close(lease)
        end
    end
    comparisons=Dict{String,Any}[]
    for n in sizes,period in periods
        selected=[r for r in results if r["historical_candidates"]==n && r["report_every_candidates"]==period]
        before=median([r["wall_seconds"] for r in selected if !r["use_counters"]])
        after=median([r["wall_seconds"] for r in selected if r["use_counters"]])
        push!(comparisons,Dict("historical_candidates"=>n,"report_every_candidates"=>period,
            "median_without_counters_seconds"=>before,"median_with_counters_seconds"=>after,
            "counter_minus_scan_seconds"=>after-before,"throughput_ratio"=>before/after))
    end
    summary=Dict("comparisons"=>comparisons,"julia"=>string(VERSION),
        "operations_sha256"=>FP.DiscoveryEvidence.filehash(joinpath(@__DIR__,"..","closure_operations.jl")),
        "tool_sha256"=>FP.DiscoveryEvidence.filehash(@__FILE__),
        "scope"=>"Synthetic counter columns and covering indexes; no LUT/proof/math cost; rolled-back single-thread trials exclude durable commit/fsync and initial backfill/setup cost",
        "interpretation"=>"Use period=0 to estimate marginal trigger apply cost; compare matched reporting periods for count-scan savings. Cold production scans, page-cache competition, full-row layout and real window frequency can differ.")
    open(joinpath(output,"summary.json"),"w") do io
        FP.JSON3.pretty(io,summary)
    end
    summary
end
end

if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==1 || error("usage: closure_report_counter_bench.jl CONFIG.toml")
    ClosureReportCounterBench.run(ClosureReportCounterBench.TOML.parsefile(only(ARGS)))
end
