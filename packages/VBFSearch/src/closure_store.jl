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
    statements::DiscoveryStore.StatementCache
    solver_session::Any
end

ClosureStore(db,directory,lease,identity,session,last_report_ns)=
    ClosureStore(db,directory,lease,identity,session,last_report_ns,nothing,:thread,180.0,nothing,
        DiscoveryStore.StatementCache(db),nothing)

_closure_rows(s::ClosureStore,sql,args=())=DiscoveryStore.query(s.statements,sql,args)
_closure_exec(s::ClosureStore,sql,args=())=DiscoveryStore.execute!(s.statements,sql,args)
_closure_rows(s::NamedTuple,sql,args=())=_closure_rows(s.db,sql,args)
_closure_exec(s::NamedTuple,sql,args=())=_closure_exec(s.db,sql,args)
_closure_solver_session(s)=hasproperty(s,:solver_session) ? s.solver_session : nothing

function _closure_transaction(f, s::ClosureStore)
    SQLite.intransaction(s.db) && return f()
    _closure_exec(s,"BEGIN IMMEDIATE")
    try
        result=f();_closure_exec(s,"COMMIT");result
    catch
        _closure_exec(s,"ROLLBACK");rethrow()
    end
end

function _closure_lease(directory)
    lease=open(joinpath(directory,"closure.lock"),"a+")
    ccall(:flock,Cint,(Cint,Cint),fd(lease),6)==0 ||
        (close(lease);error("another process owns this closure frontier"))
    lease
end

function _closure_create_schema(db;normalized=false)
    for sql in (
        "CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL)",
        "CREATE TABLE candidates(id TEXT PRIMARY KEY,lut_hex TEXT NOT NULL UNIQUE,sigma TEXT,apn INTEGER NOT NULL,degree INTEGER NOT NULL,properties TEXT NOT NULL,class_id INTEGER,state TEXT NOT NULL)",
        "CREATE INDEX candidates_sigma ON candidates(sigma)",
        "CREATE INDEX candidates_counters ON candidates(apn,degree,sigma,class_id)",
        "CREATE INDEX candidates_state ON candidates(state)",
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
        if normalized
            (startswith(sql,"CREATE TABLE candidates(") || startswith(sql,"CREATE TABLE comparisons(") ||
             occursin(r"^CREATE INDEX (candidates_|comparisons_)",sql)) && continue
            sql=replace(sql,"REFERENCES candidates(id)"=>"REFERENCES closure_candidates(id)")
        end
        _closure_exec(db,sql)
    end
    normalized && _closure_create_normalized_schema(db)
end

function _closure_add_job!(s, parent, kind, key, payload)
    _closure_exec(s,"INSERT OR IGNORE INTO jobs(parent_id,kind,job_key,payload) VALUES(?,?,?,?)",
        (parent,kind,key,_closure_text(payload)))
end

function _closure_add_parent!(s, candidate, sigma; origin="discovered", source="construction")
    _closure_exec(s,"INSERT INTO parents(candidate_id,sigma,origin,source,admitted_utc) VALUES(?,?,?,?,?)",
        (candidate,sigma,origin,source,_closure_now()))
    parent=Int(SQLite.last_insert_rowid(s.db))
    _closure_candidate_state!(s,candidate,"admitted";class_id=parent)
    _closure_exec(s,"INSERT OR IGNORE INTO jobs(parent_id,kind,job_key,payload) VALUES(?,'prepare_v5',?,''),(?,'switching',?,'')",
        (parent,"$parent:prepare_v5",parent,"$parent:switching"))
    parent
end

"""Update mutable admission fields without expanding the normalized proof view."""
function _closure_candidate_state!(s,id,state;class_id=nothing)
    table=_closure_normalized(s.db) ? "closure_candidates" : "candidates"
    if class_id===nothing
        _closure_exec(s,"UPDATE $table SET state=? WHERE id=?",(state,id))
    else
        _closure_exec(s,"UPDATE $table SET class_id=?,state=? WHERE id=?",(class_id,state,id))
    end
    nothing
end

function _closure_insert_candidate!(s, p; state="observed")
    existing=_closure_rows(s,"SELECT lut_hex FROM candidates WHERE id=?",(p["lut_sha256"],))
    if !isempty(existing)
        only(existing)["lut_hex"]==p["lut_hex"] || error("LUT digest collision")
        return p["lut_sha256"]
    end
    _closure_normalized(s.db) && return _closure_normalized_candidate(s,p;state)
    _closure_exec(s,"INSERT OR IGNORE INTO candidates(id,lut_hex,sigma,apn,degree,properties,state) VALUES(?,?,?,?,?,?,?)",
        (p["lut_sha256"],p["lut_hex"],get(p,"sigma_hash",missing),Int(p["apn"]),p["algebraic_degree"],_closure_text(p),state))
    p["lut_sha256"]
end

"""Record a construction edge even when the exact child already exists."""
function _closure_record_candidate!(s, job, p, cursor, witness)
    child=_closure_insert_candidate!(s,p)
    _closure_exec(s,"INSERT OR IGNORE INTO paths(parent_id,job_id,method,cursor,child_id,witness) VALUES(?,?,?,?,?,?)",
        (job["parent_id"],job["id"],job["kind"],string(cursor),child,_closure_text(witness)))
    if p["apn"] && p["quadratic"]
        row=only(_closure_rows(s,"SELECT class_id FROM candidates WHERE id=?",(child,)))
        if ismissing(row["class_id"])
            _closure_candidate_state!(s,child,"awaiting_equivalence")
            _closure_add_job!(s,job["parent_id"],"deduplicate","deduplicate:$child",Dict("candidate_id"=>child))
        end
    end
    child
end

const _CLOSURE_PATH_INSERT_SQL="INSERT OR IGNORE INTO paths(parent_id,job_id,method,cursor,child_id,witness) VALUES(?,?,?,?,?,?)"
const _CLOSURE_PATH_BATCH_ROWS=32
const _CLOSURE_PATH_BATCH_SQL="INSERT OR IGNORE INTO paths(parent_id,job_id,method,cursor,child_id,witness) VALUES"*
    join(fill("(?,?,?,?,?,?)",_CLOSURE_PATH_BATCH_ROWS),",")
const _CLOSURE_DEDUP_JOB_INSERT_SQL="INSERT OR IGNORE INTO jobs(parent_id,kind,job_key,payload) VALUES(?,?,?,?)"
const _CLOSURE_DEDUP_JOB_BATCH_SQL="INSERT OR IGNORE INTO jobs(parent_id,kind,job_key,payload) VALUES"*
    join(fill("(?,?,?,?)",_CLOSURE_PATH_BATCH_ROWS),",")

"""The canonical one-field payload, with generic escaping for future IDs."""
function _closure_deduplication_payload(id)
    if id isa String && sizeof(id)==64 && all(c->UInt8('0')<=c<=UInt8('9') || UInt8('a')<=c<=UInt8('f'),codeunits(id))
        return "candidate_id = \""*id*"\"\n"
    end
    _closure_text(Dict("candidate_id"=>id))
end
_closure_unique_properties_buffer(records)=Any[]

"""Persist a validated V5 packet with one admission check per exact child.

All coset paths retain their original order and exact witness bytes. Lookup and
template reuse are scoped to this call, so rollback never leaves an admission
cache ahead of the database. Ordinary physical writes also retain per-row SQLite
triggers, foreign keys and the caller's transaction/savepoint semantics.
"""
function _closure_record_v5_candidates!(s,job,records)
    isempty(records) && return nothing
    unique_properties=_closure_unique_properties_buffer(records);seen=Dict{String,String}()
    for record in records
        p=record["properties"];id=String(p["lut_sha256"]);lut=String(p["lut_hex"])
        p["apn"] && p["quadratic"] || error("V5 application requires quadratic APN outputs")
        if haskey(seen,id)
            seen[id]==lut || error("LUT digest collision")
        else
            seen[id]=lut;push!(unique_properties,p)
        end
    end
    existing=Dict{String,Any}()
    for start in 1:128:length(unique_properties)
        part=@view unique_properties[start:min(start+127,end)]
        placeholders=join(fill("?",length(part)),",")
        for row in _closure_rows(s,"SELECT id,lut_hex,class_id FROM candidates WHERE id IN ($placeholders)",
                [p["lut_sha256"] for p in part])
            existing[row["id"]]=row
        end
    end
    normalized=_closure_normalized(s.db);templates=Dict{String,Int}();dedup_arguments=Any[]
    sizehint!(dedup_arguments,4*_CLOSURE_PATH_BATCH_ROWS)
    for p in unique_properties
        id=p["lut_sha256"];row=get(existing,id,nothing)
        if row===nothing
            if normalized
                _closure_normalized_candidate(s,p;state="awaiting_equivalence",templates)
            else
                _closure_exec(s,"INSERT OR IGNORE INTO candidates(id,lut_hex,sigma,apn,degree,properties,state) VALUES(?,?,?,?,?,?,?)",
                    (id,p["lut_hex"],get(p,"sigma_hash",missing),Int(p["apn"]),p["algebraic_degree"],_closure_text(p),"awaiting_equivalence"))
            end
        else
            row["lut_hex"]==p["lut_hex"] || error("LUT digest collision")
        end
        if row===nothing || ismissing(row["class_id"])
            row===nothing || _closure_candidate_state!(s,id,"awaiting_equivalence")
            append!(dedup_arguments,(job["parent_id"],"deduplicate","deduplicate:$id",_closure_deduplication_payload(id)))
            if length(dedup_arguments)==4*_CLOSURE_PATH_BATCH_ROWS
                _closure_exec(s,_CLOSURE_DEDUP_JOB_BATCH_SQL,dedup_arguments);empty!(dedup_arguments)
            end
        end
    end
    for start in 1:4:length(dedup_arguments)
        _closure_exec(s,_CLOSURE_DEDUP_JOB_INSERT_SQL,@view dedup_arguments[start:start+3])
    end
    # Reuse only two statement shapes. A bounded full batch amortizes binding
    # and stepping without filling the statement cache with every tail length.
    arguments=Any[];sizehint!(arguments,6*_CLOSURE_PATH_BATCH_ROWS)
    for record in records
        append!(arguments,(job["parent_id"],job["id"],job["kind"],string(record["cursor"]),
            record["properties"]["lut_sha256"],_closure_text(record["witness"])))
        if length(arguments)==6*_CLOSURE_PATH_BATCH_ROWS
            _closure_exec(s,_CLOSURE_PATH_BATCH_SQL,arguments);empty!(arguments)
        end
    end
    for start in 1:6:length(arguments)
        _closure_exec(s,_CLOSURE_PATH_INSERT_SQL,@view arguments[start:start+5])
    end
    nothing
end

"""Poll STOP files at most once in `interval_ns`; a seen request stays set.

Search callbacks run millions of times. A filesystem check on each call made one
complete switching job about 17 times slower. This is the throttled poll of the
discovery search driver.
"""
function _closure_stop_poller(paths...;interval_ns=250_000_000)
    seen=Threads.Atomic{Bool}(false);last=Threads.Atomic{UInt64}(0)
    function()
        seen[] && return true
        now=time_ns();previous=last[]
        if now>=previous && now-previous>=interval_ns && Threads.atomic_cas!(last,previous,now)==previous
            any(isfile,paths) && (seen[]=true)
        end
        seen[]
    end
end

function _closure_open(directory)
    dir=abspath(directory);isfile(joinpath(dir,"closure.sqlite")) || error("closure frontier is not initialized")
    lease=_closure_lease(dir)
    db=SQLite.DB(joinpath(dir,"closure.sqlite"))
    s=nothing
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
        _closure_validate_execution_inputs(dir,identity)
        _closure_validate_active_runtime_environment(dir,identity)
        for (relative,digest) in identity["implementation"]
            archived=joinpath(dir,"replay","workspace",relative)
            isfile(archived) && DiscoveryEvidence.filehash(archived)==digest || error("closure implementation archive changed: $relative")
        end
        for (i,(source,digest)) in enumerate(sort!(collect(identity["inputs"]);by=first))
            archived=joinpath(dir,"replay","inputs",string(i)*"-"*basename(source))
            isfile(archived) && DiscoveryEvidence.filehash(archived)==digest || error("closure input archive changed: $source")
        end
        isdefined(@__MODULE__,:closure_verify_segments) && closure_verify_segments(db,dir)
        s=ClosureStore(db,dir,lease,identity,0,UInt64(0))
        _closure_transaction(s) do
            _closure_exec(db,"UPDATE jobs SET status='paused' WHERE status='running'")
            _closure_exec(db,"UPDATE sessions SET state='interrupted',finished=? WHERE finished=''",(_closure_now(),))
        end
        _closure_validate_cursors(s)
        # This optional covering index changes no scientific rows or identity.
        # Add it under the exclusive lease only after all normal identity,
        # input/archive and committed-coverage guards have succeeded.
        _closure_exec(db,"CREATE INDEX IF NOT EXISTS candidates_state ON "*(_closure_normalized(db) ? "closure_candidates" : "candidates")*"(state)")
        s.solver_session=_equivalence_solver_session()
        s
    catch
        s===nothing || DiscoveryStore.close_statements!(s.statements)
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
                _closure_exec(s,"PRAGMA wal_checkpoint(PASSIVE)")
            finally
                DiscoveryStore.close_statements!(s.statements)
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
