"""Transactional experiment state: exact LUT identity, work cursors and evidence, without invariant-based class merging."""
module DiscoveryStore
using ..DiscoveryEvidence, VBF, SQLite, DBInterface, SHA, TOML, Dates
const SQL=SQLite
const DBI=DBInterface
export Store, open_store, close_store, claim!, finish!, checkpoint!, register!,
       add_unit!, query, metadata, snapshot, atomic_toml, texttoml, parse_toml,
       transaction, seed!, commit_chunk!, open_progress_reporter,
       report_progress!, close_progress_reporter

texttoml(x) = sprint(io->TOML.print(io,x;sorted=true))
parse_toml(x) = TOML.parse(String(x))
function atomic_toml(path,x)
    open(io->TOML.print(io,x;sorted=true),path*".tmp","w")
    mv(path*".tmp",path;force=true)
end

"""Bounded FIFO of prepared statements, retaining late first-use hot queries.

Active statements stay pinned until their callback returns. Recursive use of
the same SQL, zero capacity, or a wholly pinned cache uses a temporary statement.
"""
mutable struct StatementCache
    db::SQL.DB
    statements::Dict{String,SQL.Stmt}
    limit::Int
    order::Vector{String}
    active::Base.IdSet{SQL.Stmt}
    hits::Int
    misses::Int
    prepares::Int
    evictions::Int
    temporary_statements::Int
    peak_entries::Int
end
function StatementCache(db;limit::Int=128)
    limit>=0 || throw(ArgumentError("statement cache limit must be nonnegative"))
    StatementCache(db,Dict{String,SQL.Stmt}(),limit,String[],Base.IdSet{SQL.Stmt}(),0,0,0,0,0,0)
end

"""Cheap connection-local cache counters; no SQL or statement traversal."""
statement_cache_stats(cache::StatementCache)=Dict{String,Any}(
    "entries"=>length(cache.statements),"peak_entries"=>cache.peak_entries,"limit"=>cache.limit,"hits"=>cache.hits,
    "misses"=>cache.misses,"prepares"=>cache.prepares,"evictions"=>cache.evictions,
    "temporary_statements"=>cache.temporary_statements,"active"=>length(cache.active),
    "policy"=>"bounded FIFO; active statements pinned; recursive SQL uses temporary statements")

function _statement(f,cache::StatementCache,sql)
    statement=get(cache.statements,sql,nothing)
    temporary=false
    if statement===nothing || statement in cache.active
        recursive=statement!==nothing
        cache.misses+=1
        # Invalid SQL must not discard a healthy cached statement.
        statement=SQL.Stmt(cache.db,sql)
        cache.prepares+=1
        if !recursive && cache.limit>0 && length(cache.statements)>=cache.limit
            victim_index=findfirst(key->!(cache.statements[key] in cache.active),cache.order)
            if victim_index!==nothing
                victim_key=cache.order[victim_index]
                victim=pop!(cache.statements,victim_key)
                deleteat!(cache.order,victim_index)
                DBI.close!(victim)
                cache.evictions+=1
            end
        end
        if !recursive && length(cache.statements)<cache.limit
            cache.statements[sql]=statement
            push!(cache.order,sql)
            cache.peak_entries=max(cache.peak_entries,length(cache.statements))
        else
            temporary=true
            cache.temporary_statements+=1
        end
    else
        cache.hits+=1
    end
    push!(cache.active,statement)
    try
        f(statement)
    finally
        # Bindings can include large evidence strings. Do not retain them until
        # this SQL happens to run again, or until the writer exits.
        try
            SQL.clear!(statement)
        finally
            delete!(cache.active,statement)
            temporary && DBI.close!(statement)
        end
    end
end

function close_statements!(cache::StatementCache)
    isempty(cache.active) || error("cannot close statement cache during active execution")
    for statement in values(cache.statements)
        DBI.close!(statement)
    end
    empty!(cache.statements)
    empty!(cache.order)
    nothing
end

struct Store
    db::SQL.DB
    guard::ReentrantLock
    lease::IOStream
    path::String
    statements::StatementCache
end
Store(db,guard,lease,path)=Store(db,guard,lease,path,StatementCache(db))

function execute!(db::SQL.DB,sql,args=())
    statement=SQL.Stmt(db,sql;register=false)
    try
        DBI.execute(rows->foreach(_->nothing,rows),statement,args)
        nothing
    finally
        DBI.close!(statement)
    end
end
function execute!(cache::StatementCache,sql,args=())
    _statement(cache,sql) do statement
        DBI.execute(rows->foreach(_->nothing,rows),statement,args)
        nothing
    end
end
execute!(s::Store,sql,args=())=lock(()->execute!(s.statements,sql,args),s.guard)
query(s::Store,sql,args=())=lock(()->query(s.statements,sql,args),s.guard)
_copy_rows(rows)=[Dict(String(k)=>v for (k,v) in pairs(r)) for r in rows]
function query(db::SQL.DB,sql,args=())
    statement=SQL.Stmt(db,sql;register=false)
    try
        DBI.execute(_copy_rows,statement,args)
    finally
        DBI.close!(statement)
    end
end
query(cache::StatementCache,sql,args=())=_statement(statement->DBI.execute(_copy_rows,statement,args),cache,sql)

function transaction(f,s)
    lock(s.guard) do
        SQL.intransaction(s.db) && return f()
        execute!(s,"BEGIN IMMEDIATE")
        try
            value=f()
            execute!(s,"COMMIT")
            value
        catch
            execute!(s,"ROLLBACK")
            rethrow()
        end
    end
end

function metadata(s)
    lock(s.guard) do
        parse_toml(only(query(s,"SELECT value FROM metadata WHERE key='run'"))["value"])
    end
end

"""Open one writer per experiment, recover interrupted work, and enforce immutable search identity."""
function open_store(dir,identity;resume=false)
    mkpath(dir)
    lease=open(joinpath(dir,"writer.lock"),"a+")
    ccall(:flock,Cint,(Cint,Cint),fd(lease),6)==0 || (close(lease);error("another writer owns this run"))
    path=joinpath(dir,"run.sqlite")
    exists=isfile(path)
    exists==resume || (close(lease);error(exists ? "existing run requires --resume true" : "cannot resume an absent run"))
    db=SQL.DB(path)
    s=Store(db,ReentrantLock(),lease,abspath(dir))
    try
        execute!(db,"PRAGMA journal_mode=WAL")
        execute!(db,"PRAGMA synchronous=FULL")
        for sql in (
            "CREATE TABLE IF NOT EXISTS metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL)",
            "CREATE TABLE IF NOT EXISTS candidates(lut_id TEXT PRIMARY KEY,lut_hex TEXT NOT NULL UNIQUE,sigma TEXT,evidence TEXT NOT NULL,reference_absent INTEGER NOT NULL,additional INTEGER NOT NULL)",
            "CREATE INDEX IF NOT EXISTS candidate_sigma ON candidates(sigma)",
            "CREATE INDEX IF NOT EXISTS candidate_absent_sigma ON candidates(sigma) WHERE reference_absent=1",
            "CREATE INDEX IF NOT EXISTS candidate_additional_sigma ON candidates(sigma) WHERE additional=1",
            "CREATE TABLE IF NOT EXISTS seeds(id INTEGER PRIMARY KEY,lut_id TEXT NOT NULL UNIQUE,lut_hex TEXT NOT NULL,sigma TEXT NOT NULL)",
            "CREATE TABLE IF NOT EXISTS units(id INTEGER PRIMARY KEY,seed_id INTEGER NOT NULL,kind TEXT NOT NULL,payload TEXT NOT NULL,status TEXT NOT NULL DEFAULT 'pending',direction INTEGER NOT NULL DEFAULT 1,combination TEXT NOT NULL DEFAULT '1',result TEXT NOT NULL DEFAULT '',UNIQUE(seed_id,kind,payload))",
            "CREATE INDEX IF NOT EXISTS unit_status ON units(status)",
            "CREATE INDEX IF NOT EXISTS runnable_units ON units(id) WHERE status IN ('pending','paused')",
            "CREATE TABLE IF NOT EXISTS kernels(unit_id INTEGER NOT NULL,direction INTEGER NOT NULL,dimension INTEGER NOT NULL,evidence TEXT NOT NULL,PRIMARY KEY(unit_id,direction))",
            "CREATE TABLE IF NOT EXISTS evaluations(unit_id INTEGER NOT NULL,direction INTEGER NOT NULL,combination TEXT NOT NULL,lut_id TEXT NOT NULL,apn INTEGER NOT NULL,PRIMARY KEY(unit_id,direction,combination))",
            "CREATE TABLE IF NOT EXISTS chunks(unit_id INTEGER NOT NULL,first_x INTEGER NOT NULL,next_x INTEGER NOT NULL,total_x INTEGER NOT NULL,capped INTEGER NOT NULL,evidence TEXT NOT NULL,PRIMARY KEY(unit_id,first_x))",
            "CREATE TABLE IF NOT EXISTS comparisons(id INTEGER PRIMARY KEY,candidate_id TEXT NOT NULL,target_id TEXT NOT NULL,relation TEXT NOT NULL,evidence TEXT NOT NULL)",
            "CREATE TABLE IF NOT EXISTS sessions(id INTEGER PRIMARY KEY,started TEXT NOT NULL,finished TEXT,seconds REAL,reason TEXT)",
        )
            execute!(db,sql)
        end
        if exists
            old=metadata(s)
            old["identity"]==identity || error("run identity changed: reference, code, seed inputs or search parameters differ")
            for unit in query(s,"SELECT * FROM units WHERE kind='switching'")
                direction=Int(unit["direction"]);combination=parse(BigInt,unit["combination"])
                1<=direction<=256 && combination>=1 || error("invalid persisted switching cursor")
                count=Int(only(query(s,"SELECT COUNT(*) c FROM evaluations WHERE unit_id=? AND direction=?",(unit["id"],direction)))["c"])
                combination==count+1 || error("cursor disagrees with committed evaluations")
                direction==256 && combination!=1 && error("invalid exhaustion cursor")
            end
            execute!(db,"UPDATE units SET status='paused' WHERE status='running'")
        else
            run=Dict("schema"=>"apn-discovery-v1","identity"=>identity,
                "created_utc"=>string(Dates.now(Dates.UTC)),"scope"=>"finite selected construction units, not all APN functions")
            execute!(db,"INSERT INTO metadata VALUES('run',?)",(texttoml(run),))
            atomic_toml(joinpath(dir,"manifest.toml"),run)
        end
        s
    catch
        close_statements!(s.statements);SQL.close(db);close(lease);rethrow()
    end
end

function close_store(s)
    try
        execute!(s,"PRAGMA wal_checkpoint(TRUNCATE)")
    finally
        close_statements!(s.statements)
        SQL.close(s.db)
        close(s.lease)
    end
end

struct ProgressReporter
    db::SQL.DB
    guard::ReentrantLock
    last_report::Threads.Atomic{UInt64}
    interval_ns::UInt64
    directory::String
    session::Int
    started::UInt64
end

"""Read committed progress independently of the search writer, at a bounded frequency."""
function open_progress_reporter(directory,session,started;interval_seconds=10.0)
    isfinite(interval_seconds) && interval_seconds>=0 || throw(ArgumentError("invalid progress interval"))
    db=SQL.DB("file:"*joinpath(abspath(directory),"run.sqlite")*"?mode=ro")
    ProgressReporter(db,ReentrantLock(),Threads.Atomic{UInt64}(0),
        round(UInt64,interval_seconds*1e9),abspath(directory),Int(session),UInt64(started))
end

"""Publish one consistent snapshot; competing workers skip rather than wait for reporting."""
function report_progress!(reporter::ProgressReporter;force=false)
    now=time_ns()
    !force && now-reporter.last_report[]<reporter.interval_ns && return false
    trylock(reporter.guard) || return false
    try
        now=time_ns()
        !force && now-reporter.last_report[]<reporter.interval_ns && return false
        execute!(reporter.db,"BEGIN")
        progress=try
            snapshot(reporter.db)
        finally
            execute!(reporter.db,"ROLLBACK")
        end
        progress["session"]=reporter.session
        progress["elapsed_seconds"]=(now-reporter.started)*1e-9
        atomic_toml(joinpath(reporter.directory,"progress.toml"),progress)
        reporter.last_report[]=time_ns()
        true
    finally
        unlock(reporter.guard)
    end
end

"""Close the independent progress reader after all search workers have joined."""
close_progress_reporter(reporter::ProgressReporter)=SQL.close(reporter.db)

function register_unlocked!(s,p)
    id=p["lut_sha256"]
    existing=query(s,"SELECT lut_hex FROM candidates WHERE lut_id=?",(id,))
    isempty(existing) || only(existing)["lut_hex"]==p["lut_hex"] || error("LUT digest collision")
    isempty(existing) || return id
    execute!(s,"INSERT OR IGNORE INTO candidates VALUES(?,?,?,?,?,?)",
        (id,p["lut_hex"],get(p,"sigma_hash",nothing),texttoml(p),
         Int(get(p,"evidence_level","")=="inequivalent_to_documented_quadratic_corpus"),
         Int(get(p,"additional_signature",false))))
    id
end
register!(s,p)=transaction(s) do
    register_unlocked!(s,p)
end

function seed!(s,lut,sigma,kind)
    transaction(s) do
        hex=bytes2hex(UInt8.(lut));id=lut_id(lut)
        execute!(s,"INSERT OR IGNORE INTO seeds(lut_id,lut_hex,sigma) VALUES(?,?,?)",(id,hex,sigma))
        row=only(query(s,"SELECT id,lut_hex FROM seeds WHERE lut_id=?",(id,)))
        row["lut_hex"]==hex || error("seed digest collision")
        execute!(s,"INSERT OR IGNORE INTO units(seed_id,kind,payload) VALUES(?,?,?)",
            (row["id"],kind,texttoml(Dict("lut_hex"=>hex,"ccz_columns"=>[1<<i for i in 0:15],"ccz_constant"=>0))))
    end
end

function commit_chunk!(s,unit,proof,records;done=false)
    proof=Dict{String,Any}(proof)
    transaction(s) do
        current=only(query(s,"SELECT direction FROM units WHERE id=?",(unit["id"],)))["direction"]
        current==proof["first_x"] || error("noncontiguous extension chunk")
        ids=String[]
        for p in records
            push!(ids,register_unlocked!(s,p))
        end
        proof["candidate_ids"]=ids
        execute!(s,"INSERT INTO chunks VALUES(?,?,?,?,?,?)",
            (unit["id"],proof["first_x"],proof["next_x"],proof["total_x"],Int(proof["capped"]),texttoml(proof)))
        execute!(s,"UPDATE units SET direction=?,status=?,result=? WHERE id=?",
            (proof["next_x"],done ? "done" : "paused",texttoml(proof),unit["id"]))
    end
end

function add_unit!(s,seed_id,kind,payload)
    transaction(s) do
        execute!(s,"INSERT OR IGNORE INTO units(seed_id,kind,payload) VALUES(?,?,?)",
            (seed_id,kind,texttoml(payload)))
    end
end

function claim!(s)
    transaction(s) do
        rows=query(s,"SELECT u.*,s.lut_hex,s.sigma FROM units u JOIN seeds s ON s.id=u.seed_id WHERE u.status IN ('pending','paused') ORDER BY u.id LIMIT 1")
        isempty(rows) && return nothing
        row=only(rows)
        execute!(s,"UPDATE units SET status='running' WHERE id=?",(row["id"],))
        row
    end
end

"""Commit candidate evidence and the next cursor in the same transaction."""
function checkpoint!(s,unit,event,value,properties=nothing)
    id=unit["id"]
    transaction(s) do
        if event===:kernel
            proof=Dict("basis_hex"=>[bytes2hex(UInt8.(v)) for v in value.basis],
                "raw_dimension"=>value.raw_dimension,"dimension"=>value.quotient_dimension)
            old=query(s,"SELECT evidence FROM kernels WHERE unit_id=? AND direction=?",(id,value.direction))
            isempty(old) || only(old)["evidence"]==texttoml(proof) || error("resumed kernel changed")
            execute!(s,"INSERT OR IGNORE INTO kernels VALUES(?,?,?,?)",
                (id,value.direction,value.quotient_dimension,texttoml(proof)))
        else
            current=only(query(s,"SELECT direction,combination FROM units WHERE id=?",(id,)))
            Int(current["direction"])==value.direction || error("checkpoint direction is not current")
            if event===:candidate_complete
                properties===nothing && error("candidate evidence missing")
                parse(BigInt,current["combination"])==value.combination || error("checkpoint combination is not current")
                value.next_direction==value.direction && value.next_combination==value.combination+1 || error("invalid candidate cursor transition")
                properties["apn"]==value.apn || error("candidate evidence disagrees with APN flag")
                cid=register_unlocked!(s,properties)
                execute!(s,"INSERT INTO evaluations VALUES(?,?,?,?,?)",
                    (id,value.direction,string(value.combination),cid,Int(value.apn)))
            elseif event===:direction_complete
                dimension=Int(only(query(s,"SELECT dimension FROM kernels WHERE unit_id=? AND direction=?",(id,value.direction)))["dimension"])
                expected=(big(1)<<dimension)-1
                parse(BigInt,current["combination"])==expected+1 || error("direction completed before all combinations")
                value.next_direction==value.direction+1 && value.next_combination==1 || error("invalid direction cursor transition")
            else
                error("unknown checkpoint event")
            end
            execute!(s,"UPDATE units SET direction=?,combination=? WHERE id=?",
                (value.next_direction,string(value.next_combination),id))
        end
    end
end

function finish!(s,unit,result;done=false)
    transaction(s) do
        if done && unit["kind"]=="switching"
            kernels=query(s,"SELECT direction,dimension FROM kernels WHERE unit_id=? ORDER BY direction",(unit["id"],))
            expected=sum((big(1)<<Int(r["dimension"]))-1 for r in kernels;init=big(0))
            actual=Int(only(query(s,"SELECT COUNT(*) c FROM evaluations WHERE unit_id=?",(unit["id"],)))["c"])
            length(kernels)==255 && expected==actual || error("incomplete switching prefix; cannot certify exhaustion")
            [Int(r["direction"]) for r in kernels]==collect(1:255) || error("invalid completed kernel directions")
            current=only(query(s,"SELECT direction,combination FROM units WHERE id=?",(unit["id"],)))
            current["direction"]==256 && current["combination"]=="1" || error("nonterminal switching cursor")
        end
        execute!(s,"UPDATE units SET status=?,result=? WHERE id=?",
            (done ? "done" : "paused",texttoml(result),unit["id"]))
    end
end

snapshot(s::Store) = lock(() -> snapshot(s.db), s.guard)
function snapshot(s::SQL.DB)
    statuses=Dict(String(r["status"])=>Int(r["count"]) for r in query(s,"SELECT status,COUNT(*) count FROM units GROUP BY status"))
    count=Int(only(query(s,"SELECT COUNT(*) c FROM candidates"))["c"])
    absent=Int(only(query(s,"SELECT COUNT(DISTINCT sigma) c FROM candidates WHERE reference_absent=1"))["c"])
    additional=Int(only(query(s,"SELECT COUNT(DISTINCT sigma) c FROM candidates WHERE additional=1"))["c"])
    Dict("units"=>statuses,"exact_luts"=>count,"corpus_absent_signature_buckets"=>absent,
        "additional_signature_buckets"=>additional,
        "finite_plan_exhausted"=>!isempty(query(s,"SELECT value FROM metadata WHERE key='plan_complete'")) && !isempty(statuses) && get(statuses,"done",0)==sum(values(statuses)),
        "all_apn_classification"=>false,"literature_novelty"=>"unresolved")
end
end
