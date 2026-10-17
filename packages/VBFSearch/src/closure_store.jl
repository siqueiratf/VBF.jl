"""Persistence for the deterministic recursive construction frontier.

This store deliberately separates exact LUTs, verified EA classes and unresolved
equal-signature comparisons. A signature is an index, never a class identifier.
"""
const CLOSURE_SCHEMA = "vbfsearch-closure-v1"
const CLOSURE_PROGRESS_SCHEMA = "vbfsearch-closure-progress-v1"

_closure_now() = string(Dates.now(Dates.UTC))*"Z"
_closure_rows(db, sql, args=()) = DiscoveryStore.query(db, sql, args)
_closure_exec(db, sql, args=()) = DiscoveryStore.execute!(db, sql, args)
_closure_count(db, sql, args=()) = Int(only(_closure_rows(db,sql,args))["n"])
_closure_text(x) = DiscoveryStore.texttoml(x)

mutable struct ClosureStore
    db::SQLite.DB
    directory::String
    lease::IOStream
    identity::Dict{String,Any}
    session::Int
    last_report_ns::UInt64
    report_task::Union{Nothing,Task}
    report_backend::Symbol
    report_timeout_seconds::Float64
    report_reader::Any
end

ClosureStore(db,directory,lease,identity,session,last_report_ns)=
    ClosureStore(db,directory,lease,identity,session,last_report_ns,nothing,:thread,180.0,nothing)

function _closure_transaction(f, s::ClosureStore)
    SQLite.intransaction(s.db) && return f()
    _closure_exec(s.db,"BEGIN IMMEDIATE")
    try
        result=f();_closure_exec(s.db,"COMMIT");result
    catch
        _closure_exec(s.db,"ROLLBACK");rethrow()
    end
end

function _closure_lease(directory)
    lease=open(joinpath(directory,"closure.lock"),"a+")
    ccall(:flock,Cint,(Cint,Cint),fd(lease),6)==0 ||
        (close(lease);error("another process owns this closure frontier"))
    lease
end

function _closure_create_schema(db)
    for sql in (
        "CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL)",
        "CREATE TABLE candidates(id TEXT PRIMARY KEY,lut_hex TEXT NOT NULL UNIQUE,sigma TEXT,apn INTEGER NOT NULL,degree INTEGER NOT NULL,properties TEXT NOT NULL,class_id INTEGER,state TEXT NOT NULL)",
        "CREATE INDEX candidates_sigma ON candidates(sigma)",
        "CREATE INDEX candidates_counters ON candidates(apn,degree,sigma,class_id)",
        "CREATE TABLE parents(id INTEGER PRIMARY KEY,candidate_id TEXT NOT NULL UNIQUE REFERENCES candidates(id),sigma TEXT NOT NULL,origin TEXT NOT NULL,source TEXT NOT NULL,admitted_utc TEXT NOT NULL,last_dispatch INTEGER NOT NULL DEFAULT 0)",
        "CREATE INDEX parents_sigma ON parents(sigma)",
        "CREATE INDEX parents_origin ON parents(origin)",
        "CREATE TABLE jobs(id INTEGER PRIMARY KEY,parent_id INTEGER REFERENCES parents(id),kind TEXT NOT NULL,job_key TEXT NOT NULL UNIQUE,payload TEXT NOT NULL,status TEXT NOT NULL DEFAULT 'pending',direction INTEGER NOT NULL DEFAULT 1,combination TEXT NOT NULL DEFAULT '1',last_session INTEGER NOT NULL DEFAULT 0,result TEXT NOT NULL DEFAULT '',error TEXT NOT NULL DEFAULT '')",
        "CREATE INDEX jobs_frontier ON jobs(status,kind,parent_id)",
        "CREATE INDEX jobs_parent_coverage ON jobs(parent_id,kind,status)",
        "CREATE TABLE paths(id INTEGER PRIMARY KEY,parent_id INTEGER NOT NULL REFERENCES parents(id),job_id INTEGER NOT NULL REFERENCES jobs(id),method TEXT NOT NULL,cursor TEXT NOT NULL,child_id TEXT NOT NULL REFERENCES candidates(id),witness TEXT NOT NULL,UNIQUE(job_id,cursor,child_id))",
        "CREATE INDEX paths_method ON paths(method)",
        "CREATE TABLE evaluations(job_id INTEGER NOT NULL,direction INTEGER NOT NULL,combination TEXT NOT NULL,candidate_id TEXT NOT NULL REFERENCES candidates(id),apn INTEGER NOT NULL,PRIMARY KEY(job_id,direction,combination))",
        "CREATE TABLE kernels(job_id INTEGER NOT NULL,direction INTEGER NOT NULL,dimension INTEGER NOT NULL,evidence TEXT NOT NULL,PRIMARY KEY(job_id,direction))",
        "CREATE TABLE chunks(job_id INTEGER NOT NULL,first_x INTEGER NOT NULL,next_x INTEGER NOT NULL,total_x INTEGER NOT NULL,capped INTEGER NOT NULL,evidence TEXT NOT NULL,PRIMARY KEY(job_id,first_x))",
        "CREATE TABLE comparisons(id INTEGER PRIMARY KEY,candidate_id TEXT NOT NULL REFERENCES candidates(id),target_parent INTEGER NOT NULL REFERENCES parents(id),status TEXT NOT NULL,evidence TEXT NOT NULL,session_id INTEGER NOT NULL)",
        "CREATE INDEX comparisons_pair ON comparisons(candidate_id,target_parent,id)",
        "CREATE TABLE sessions(id INTEGER PRIMARY KEY,started TEXT NOT NULL,finished TEXT NOT NULL DEFAULT '',heartbeat TEXT NOT NULL,pid INTEGER NOT NULL,host TEXT NOT NULL,state TEXT NOT NULL,budgets TEXT NOT NULL,jobs INTEGER NOT NULL DEFAULT 0,evaluations INTEGER NOT NULL DEFAULT 0)",
    )
        _closure_exec(db,sql)
    end
end

function _closure_add_job!(s, parent, kind, key, payload)
    _closure_exec(s.db,"INSERT OR IGNORE INTO jobs(parent_id,kind,job_key,payload) VALUES(?,?,?,?)",
        (parent,kind,key,_closure_text(payload)))
end

function _closure_add_parent!(s, candidate, sigma; origin="discovered", source="construction")
    _closure_exec(s.db,"INSERT INTO parents(candidate_id,sigma,origin,source,admitted_utc) VALUES(?,?,?,?,?)",
        (candidate,sigma,origin,source,_closure_now()))
    parent=Int(only(_closure_rows(s.db,"SELECT last_insert_rowid() id"))["id"])
    _closure_exec(s.db,"UPDATE candidates SET class_id=?,state='admitted' WHERE id=?",(parent,candidate))
    _closure_add_job!(s,parent,"prepare_v5","$parent:prepare_v5",Dict{String,Any}())
    _closure_add_job!(s,parent,"switching","$parent:switching",Dict{String,Any}())
    parent
end

function _closure_insert_candidate!(s, p; state="observed")
    _closure_exec(s.db,"INSERT OR IGNORE INTO candidates(id,lut_hex,sigma,apn,degree,properties,state) VALUES(?,?,?,?,?,?,?)",
        (p["lut_sha256"],p["lut_hex"],get(p,"sigma_hash",missing),Int(p["apn"]),p["algebraic_degree"],_closure_text(p),state))
    p["lut_sha256"]
end

"""Record a construction edge even when the exact child already exists."""
function _closure_record_candidate!(s, job, p, cursor, witness)
    child=_closure_insert_candidate!(s,p)
    _closure_exec(s.db,"INSERT OR IGNORE INTO paths(parent_id,job_id,method,cursor,child_id,witness) VALUES(?,?,?,?,?,?)",
        (job["parent_id"],job["id"],job["kind"],string(cursor),child,_closure_text(witness)))
    if p["apn"] && p["quadratic"]
        row=only(_closure_rows(s.db,"SELECT class_id FROM candidates WHERE id=?",(child,)))
        if ismissing(row["class_id"])
            _closure_exec(s.db,"UPDATE candidates SET state='awaiting_equivalence' WHERE id=?",(child,))
            _closure_add_job!(s,job["parent_id"],"deduplicate","deduplicate:$child",Dict("candidate_id"=>child))
        end
    end
    child
end

function _closure_open(directory)
    dir=abspath(directory);isfile(joinpath(dir,"closure.sqlite")) || error("closure frontier is not initialized")
    lease=_closure_lease(dir)
    db=SQLite.DB(joinpath(dir,"closure.sqlite"))
    try
        _closure_exec(db,"PRAGMA busy_timeout=10000")
        _closure_exec(db,"PRAGMA foreign_keys=ON")
        _closure_exec(db,"PRAGMA journal_mode=WAL")
        _closure_exec(db,"PRAGMA synchronous=FULL")
        identity=TOML.parse(only(_closure_rows(db,"SELECT value FROM metadata WHERE key='identity'"))["value"])
        identity==TOML.parsefile(joinpath(dir,"identity.toml")) || error("closure identity manifest differs from the database")
        identity["schema"]==CLOSURE_SCHEMA || error("unsupported closure schema")
        identity["implementation"]==implementation_fingerprint() || error("closure source or environment identity changed; use the archived implementation")
        identity["julia"]==string(VERSION) || error("closure Julia version changed")
        _closure_count(db,"SELECT COUNT(*) n FROM metadata WHERE key='initialization_complete' AND value='true'")==1 || error("closure initialization did not complete")
        for (path,digest) in identity["inputs"]
            isfile(path) && DiscoveryEvidence.filehash(path)==digest || error("closure input changed: $path")
        end
        for (relative,digest) in identity["implementation"]
            archived=joinpath(dir,"replay","workspace",relative)
            isfile(archived) && DiscoveryEvidence.filehash(archived)==digest || error("closure implementation archive changed: $relative")
        end
        for (i,(source,digest)) in enumerate(sort!(collect(identity["inputs"]);by=first))
            archived=joinpath(dir,"replay","inputs",string(i)*"-"*basename(source))
            isfile(archived) && DiscoveryEvidence.filehash(archived)==digest || error("closure input archive changed: $source")
        end
        s=ClosureStore(db,dir,lease,identity,0,UInt64(0))
        _closure_transaction(s) do
            _closure_exec(db,"UPDATE jobs SET status='paused' WHERE status='running'")
            _closure_exec(db,"UPDATE sessions SET state='interrupted',finished=? WHERE finished=''",(_closure_now(),))
        end
        _closure_validate_cursors(s)
        s
    catch
        close(db);close(lease);rethrow()
    end
end

function _closure_close(s)
    try
        _closure_wait_report!(s)
    finally
        try
            _closure_shutdown_reporter!(s)
        finally
            try
                _closure_exec(s.db,"PRAGMA wal_checkpoint(PASSIVE)")
            finally
                close(s.db);close(s.lease)
            end
        end
    end
end

# Each query follows an existing primary-key order. Keep its current SQLite row
# alive only until advancing that query: SQLite rows are forward-only views.
const _CLOSURE_CURSOR_JOBS_SQL = "SELECT id,kind,direction,combination,status FROM jobs WHERE kind IN ('v5','switching') ORDER BY id"
const _CLOSURE_CURSOR_KERNELS_SQL = "SELECT job_id,direction,dimension FROM kernels ORDER BY job_id,direction"
const _CLOSURE_CURSOR_EVALUATIONS_SQL = "SELECT job_id,direction,COUNT(*) n FROM evaluations GROUP BY job_id,direction ORDER BY job_id,direction"
const _CLOSURE_CURSOR_CHUNKS_SQL = "SELECT first_x,next_x,capped FROM chunks WHERE job_id=? ORDER BY first_x"
const _CLOSURE_CURSOR_TOTAL_SQL = "SELECT total_x FROM chunks WHERE job_id=? ORDER BY first_x DESC LIMIT 1"

mutable struct _ClosureCoverageRows
    query::SQLite.Query{false}
    next_rownumber::Int
end

function _closure_coverage_rows!(opened,db,sql)
    query=DBInterface.execute(db,sql)
    push!(opened,query)
    first=iterate(query)
    _ClosureCoverageRows(query,first===nothing ? 0 : first[2])
end

_closure_coverage_empty(rows)=rows.next_rownumber==0
_closure_coverage_row(rows)=SQLite.Row(rows.query,rows.next_rownumber-1)
function _closure_coverage_advance!(rows)
    next=iterate(rows.query,rows.next_rownumber)
    rows.next_rownumber=next===nothing ? 0 : next[2]
    nothing
end

# SQLite INTEGER affinity puts nonnumeric TEXT/BLOB after numeric values. Such
# corrupt/orphan keys cannot match an integer job/direction in the old WHERE
# queries either; do not convert them or introduce new validation failures.
_closure_coverage_before(value,key)=ismissing(value) || (value isa Real && value<key)
_closure_coverage_equal(value,key)=value isa Real && value==key
function _closure_coverage_seek_job!(rows,id)
    while !_closure_coverage_empty(rows) && _closure_coverage_before(_closure_coverage_row(rows).job_id,id)
        _closure_coverage_advance!(rows)
    end
    nothing
end
_closure_coverage_job(rows,id)=!_closure_coverage_empty(rows) &&
    _closure_coverage_equal(_closure_coverage_row(rows).job_id,id)

function _closure_coverage_evaluations!(rows,id,direction)
    _closure_coverage_seek_job!(rows,id)
    while _closure_coverage_job(rows,id) && _closure_coverage_before(_closure_coverage_row(rows).direction,direction)
        _closure_coverage_advance!(rows)
    end
    _closure_coverage_job(rows,id) && _closure_coverage_equal(_closure_coverage_row(rows).direction,direction) ?
        Int(_closure_coverage_row(rows).n) : 0
end

function _closure_validate_extension_prepared!(chunk_stmt,total_stmt,id,d,status)
    next=1
    query=DBInterface.execute(chunk_stmt,(id,))
    try
        for row in query
            row.first_x==next || error("gap in extension coset coverage")
            row.capped==0 || error("capped extension coverage requires explicit recovery")
            next=Int(row.next_x)
        end
    finally
        DBInterface.close!(query)
    end
    d==next || error("extension cursor disagrees with chunk ledger")
    if status=="done"
        query=DBInterface.execute(total_stmt,(id,))
        try
            row=iterate(query)
            row!==nothing && d==row[1].total_x+1 || error("extension job marked complete without exhaustive coverage")
        finally
            DBInterface.close!(query)
        end
    end
end
"""Validate every committed coverage row with bounded memory before resuming.

Jobs, kernels and grouped evaluation counts are ordered streams retaining one
row each. Extension scans reuse two local prepared statements and their original
three-column decoder, so empty jobs require no new SQL preparation and populated
jobs avoid decoding an extra job id per coset. Payload/evidence text is omitted.
Checks within a job retain their original order; jobs have an explicit id order
instead of an unspecified one. Timestamps never certify coverage.
"""
function _closure_validate_cursors(s)
    opened=SQLite.Query{false}[]
    prepared=SQLite.Stmt[]
    try
        jobs=_closure_coverage_rows!(opened,s.db,_CLOSURE_CURSOR_JOBS_SQL)
        kernels=nothing;evaluations=nothing;chunk_stmt=nothing;total_stmt=nothing
        while !_closure_coverage_empty(jobs)
            job=_closure_coverage_row(jobs)
            id=job.id;d=Int(job.direction);c=parse(BigInt,job.combination)
            d>=1 && c>=1 || error("invalid closure cursor")
            if job.kind=="switching"
                d<=256 && (d!=256 || c==1) || error("invalid switching exhaustion cursor")
                if kernels===nothing
                    kernels=_closure_coverage_rows!(opened,s.db,_CLOSURE_CURSOR_KERNELS_SQL)
                    evaluations=_closure_coverage_rows!(opened,s.db,_CLOSURE_CURSOR_EVALUATIONS_SQL)
                end
                _closure_coverage_seek_job!(kernels,id)
                earlier=0
                while _closure_coverage_job(kernels,id)
                    row=_closure_coverage_row(kernels)
                    u=Int(row.direction);u>d && error("switching kernel ahead of committed cursor")
                    if u<d
                        total=(big(1)<<Int(row.dimension))-1
                        _closure_coverage_evaluations!(evaluations,id,u)==total || error("incomplete earlier switching direction")
                        earlier+=1
                    end
                    _closure_coverage_advance!(kernels)
                end
                earlier==d-1 || error("missing switching kernel coverage")
                n=_closure_coverage_evaluations!(evaluations,id,d)
                n==c-1 || error("switching cursor disagrees with evaluations")
                job.status=="done" && d!=256 && error("switching job marked complete before direction 255")
            else
                if chunk_stmt===nothing
                    chunk_stmt=DBInterface.prepare(s.db,_CLOSURE_CURSOR_CHUNKS_SQL);push!(prepared,chunk_stmt)
                    total_stmt=DBInterface.prepare(s.db,_CLOSURE_CURSOR_TOTAL_SQL);push!(prepared,total_stmt)
                end
                _closure_validate_extension_prepared!(chunk_stmt,total_stmt,id,d,job.status)
            end
            _closure_coverage_advance!(jobs)
        end
    finally
        for query in opened DBInterface.close!(query) end
        for stmt in prepared DBInterface.close!(stmt) end
    end
    nothing
end
