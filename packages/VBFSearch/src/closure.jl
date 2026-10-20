"""
    closure_init(campaign; output=joinpath(dirname(campaign), "run"),
        root_first=1, root_last=0, root_order=:forward)

Freeze the qualified, EA-deduplicated published roots and initialize a recursive
frontier. Initialization performs no construction search. Historical recovery
targets are comparison artifacts and are never loaded here. The entire audited
root file is verified before selecting the inclusive, one-based row interval.
`root_last=0` includes the last qualified root; `root_order=:reverse` reverses
admission order. Descendants are promoted without any interval or profile filter.
Independent root partitions can reach overlapping descendant EA classes.
"""
function closure_init(campaign; output=joinpath(dirname(abspath(campaign)),"run"),
    root_first=1,root_last=0,root_order=:forward,execution_backend=:serial,extension_cosets=1,switching_directions=1,compact_storage=true)
    compact_storage isa Bool || throw(ArgumentError("compact_storage must be boolean"))
    path=abspath(campaign);plan=TOML.parsefile(path);base=dirname(path)
    startswith(plan["schema"],"vbfsearch-literature-closure-plan-") || error("unsupported campaign plan")
    rootspec=plan["roots"];methods=plan["methods"]
    rootspec["n"]==rootspec["m"]==8 || error("closure supports eight-bit square functions")
    rootspec["profile_order"]=="bminK" && rootspec["profile_b6"]==52 || error("expected published P6 bminK roots at b6=52")
    rootspec["historical_discoveries_as_roots"]===false || error("historical discoveries cannot seed this campaign")
    methods["v5"]["target_b6"]==52 && methods["v5"]["bent"]=="max" || error("expected maximal-five-space extensions at exact b6=52")
    methods["v5"]["heuristic_histogram_pruning"]===false || error("histogram pruning is not valid closure coverage")
    plan["promotion"]["global_b6_filter"]==plan["promotion"]["p6_profile_filter"]=="none" || error("descendants must not be profile-filtered")
    rootpath=joinpath(base,rootspec["qualified_root_file"])
    proofpath=joinpath(base,rootspec["equivalence_evidence"])
    qualification=joinpath(base,rootspec["qualification_evidence"])
    proof=TOML.parsefile(proofpath)
    qualified=TOML.parsefile(qualification)
    qualified["complete"]===true && qualified["inconclusive"]==0 && qualified["processed"]==qualified["total"] || error("published-pool profile qualification is incomplete")
    proof["complete"]===true && proof["all_encoded_positive_witnesses_replayed"]===true || error("root equivalence audit is incomplete")
    digest=DiscoveryEvidence.filehash(rootpath)
    proof["verified_roots_sha256"]==digest || error("qualified root digest mismatch")
    expected=Int(rootspec["qualified_root_count"])
    proof["verified_seed_classes"]==expected || error("qualified root count disagrees with its audit")
    inputs=Dict(path=>DiscoveryEvidence.filehash(path),rootpath=>digest,proofpath=>DiscoveryEvidence.filehash(proofpath),
        qualification=>DiscoveryEvidence.filehash(qualification))
    certificates=joinpath(dirname(proofpath),"EA_certificates.tsv")
    isfile(certificates) && DiscoveryEvidence.filehash(certificates)==proof["certificate_sha256"] || error("published-root EA certificate file differs from its audit")
    inputs[certificates]=DiscoveryEvidence.filehash(certificates)
    selected=joinpath(dirname(rootpath),"selected_roots.tsv")
    isfile(selected) && DiscoveryEvidence.filehash(selected)==qualified["selected_roots_sha256"] || error("qualified pre-equivalence root file differs from its audit")
    inputs[selected]=DiscoveryEvidence.filehash(selected)
    pool=joinpath(base,rootspec["source_inventory"])
    isfile(pool) && (inputs[pool]=DiscoveryEvidence.filehash(pool))
    rows=collect(CSV.File(rootpath;delim='\t',types=String))
    length(rows)==expected || error("qualified root list is incomplete")
    length(unique(String(row.sigma_hash) for row in rows))==expected || error("root list requires further verified EA deduplication")
    for row in rows
        first(split(String(row.catalog_id),':')) in rootspec["sources"] || error("root is outside the published source pool")
        first(split(last(split(String(row.P6_bminK),':')),','))=="52" || error("root profile annotation does not end at b6=52")
        lut=hex2bytes(String(row.lut_hex))
        length(lut)==256 && DiscoveryEvidence.lut_id(lut)==String(row.lut_sha256) || error("root LUT digest mismatch")
    end
    root_first isa Integer && root_last isa Integer || throw(ArgumentError("root interval endpoints must be integers"))
    first_index=Int(root_first);last_index=root_last==0 ? expected : Int(root_last)
    1<=first_index<=last_index<=expected || throw(ArgumentError("root interval must satisfy 1 <= first <= last <= $expected"))
    order=Symbol(root_order)
    order in (:forward,:reverse) || throw(ArgumentError("root_order must be forward or reverse"))
    backend=Symbol(execution_backend)
    backend==:serial || throw(ArgumentError("execution_backend must be serial"))
    extension_cosets isa Integer && extension_cosets>0 || throw(ArgumentError("extension_cosets must be a positive integer"))
    switching_directions isa Integer && 1<=switching_directions<=255 || throw(ArgumentError("switching_directions must be in 1:255"))
    indices=order==:forward ? (first_index:last_index) : (last_index:-1:first_index)
    assigned=[(sigma_hash=String(rows[i].sigma_hash),lut_hex=String(rows[i].lut_hex),
        catalog_id=String(rows[i].catalog_id),lut_sha256=String(rows[i].lut_sha256),
        P6_bminK=String(rows[i].P6_bminK),root_index=i) for i in indices]
    selection=Dict{String,Any}("first"=>first_index,"last"=>last_index,"order"=>string(order),
        "index_base"=>1,"count"=>length(assigned))
    scientific=Dict{String,Any}("n"=>8,"m"=>8,"target_b6"=>52,"five_spaces"=>"all maximizing",
        "root_selection"=>selection,"execution_backend"=>string(backend),"extension_cosets"=>Int(extension_cosets),"switching_directions"=>Int(switching_directions),
        "max_kernel"=>23,"switching"=>"complete systems; all nonzero quotient combinations",
        "promotion"=>"all reached verified quadratic EA classes; no descendant profile filter",
        "path_scope"=>"parent, canonical V5, eligible coset, canonical output space; switching direction and quotient combination",
        "scheduling"=>"alternating root/discovered origin and v5/switching method; least recently serviced parent",
        "atomic_unit"=>"one complete eligible extension coset; one complete switching direction or bounded combination suffix")
    identity=Dict{String,Any}("schema"=>CLOSURE_SCHEMA,"campaign"=>path,"campaign_sha256"=>inputs[path],
        "roots_sha256"=>digest,"initial_roots"=>length(assigned),"qualified_roots"=>expected,"qualification_complete"=>true,
        "inputs"=>inputs,"implementation"=>implementation_fingerprint(),"julia"=>string(VERSION),"scientific"=>scientific)
    _closure_initialize(output,identity,assigned;normalized=compact_storage)
end

function _closure_initialize(directory, identity, roots;normalized=false)
    dir=abspath(directory)
    isdir(dir) && !isempty(readdir(dir)) && error("closure output directory must be empty")
    mkpath(dir);lease=_closure_lease(dir);db=SQLite.DB(joinpath(dir,"closure.sqlite"))
    s=ClosureStore(db,dir,lease,identity,0,UInt64(0))
    try
        _closure_exec(db,"PRAGMA journal_mode=WAL");_closure_exec(db,"PRAGMA synchronous=FULL")
        _closure_exec(db,"PRAGMA foreign_keys=ON");_closure_create_schema(db;normalized)
        _closure_transaction(s) do
            _closure_exec(db,"INSERT INTO metadata VALUES('identity',?)",(_closure_text(identity),))
            for (key,value) in (("created_utc",_closure_now()),("dispatch_sequence","0"),("origin_turn","root"),("method_turn","v5"),("ledger_encoding","VBFCHN02"))
                _closure_exec(db,"INSERT INTO metadata VALUES(?,?)",(key,value))
            end
            for (position,row) in enumerate(roots)
                p=Dict{String,Any}("lut_sha256"=>String(row.lut_sha256),"lut_hex"=>String(row.lut_hex),
                    "sigma_hash"=>String(row.sigma_hash),"apn"=>true,"quadratic"=>true,"algebraic_degree"=>2,
                    "verification"=>"pinned, previously VBF-verified published-root audit; freshly rechecked before construction",
                    "source"=>String(row.catalog_id),"root_audit_sha256"=>identity["roots_sha256"],
                    "root_index"=>hasproperty(row,:root_index) ? Int(row.root_index) : position)
                child=_closure_insert_candidate!(s,p)
                _closure_add_parent!(s,child,p["sigma_hash"];origin="root",source=String(row.catalog_id))
            end
        end
        DiscoveryStore.atomic_toml(joinpath(dir,"identity.toml"),identity)
        for (relative,digest) in identity["implementation"]
            source=joinpath(DiscoveryInputs.ROOT,relative);destination=joinpath(dir,"replay","workspace",relative)
            mkpath(dirname(destination));cp(source,destination)
            DiscoveryEvidence.filehash(destination)==digest || error("implementation changed during archival")
        end
        for (i,(source,digest)) in enumerate(sort!(collect(identity["inputs"]);by=first))
            destination=joinpath(dir,"replay","inputs",string(i)*"-"*basename(source))
            mkpath(dirname(destination));cp(source,destination)
            DiscoveryEvidence.filehash(destination)==digest || error("input changed during archival")
        end
        _closure_exec(db,"INSERT INTO metadata VALUES('initialization_complete','true')")
        snapshot=closure_snapshot(dir)
        DiscoveryStore.atomic_toml(joinpath(dir,"progress.toml"),snapshot)
        snapshot
    finally
        _closure_close(s)
    end
end

function _closure_writer_alive(directory)
    path=joinpath(directory,"closure.lock");isfile(path) || return false
    open(path,"r") do io
        held=ccall(:flock,Cint,(Cint,Cint),fd(io),6)!=0
        !held && ccall(:flock,Cint,(Cint,Cint),fd(io),8)
        held
    end
end

"""Report full published-seed expansion and the earliest unfinished seed's cursors."""
function _closure_seed_progress(db)
    unfinished="j.parent_id=p.id AND j.kind IN ('prepare_v5','v5','switching') AND j.status!='done'"
    counts=Dict{String,Any}(only(_closure_rows(db,"SELECT COUNT(*) total,COALESCE(SUM(NOT EXISTS(SELECT 1 FROM jobs j WHERE $unfinished)),0) completed,COALESCE(SUM(NOT EXISTS(SELECT 1 FROM jobs j WHERE j.parent_id=p.id AND j.kind IN ('prepare_v5','v5') AND j.status!='done')),0) v5_completed,COALESCE(SUM(NOT EXISTS(SELECT 1 FROM jobs j WHERE j.parent_id=p.id AND j.kind='switching' AND j.status!='done')),0) switching_completed FROM parents p WHERE p.origin='root'")))
    roots=_closure_rows(db,"SELECT p.id,p.source,c.properties FROM parents p JOIN candidates c ON c.id=p.candidate_id WHERE p.origin='root' AND EXISTS(SELECT 1 FROM jobs j WHERE $unfinished) ORDER BY p.id LIMIT 1")
    counts["focus_available"]=!isempty(roots)
    isempty(roots) && return counts
    parent=only(roots)
    jobs=_closure_rows(db,"SELECT id,kind,status,direction,result FROM jobs WHERE parent_id=? AND kind IN ('prepare_v5','v5','switching') ORDER BY id",(parent["id"],))
    prepared=any(j->j["kind"]=="prepare_v5" && j["status"]=="done",jobs)
    spaces=filter(j->j["kind"]=="v5",jobs)
    proofs=[TOML.parse(j["result"]) for j in spaces]
    known=all(p->haskey(p,"total_x"),proofs)
    switching=filter(j->j["kind"]=="switching",jobs)
    focus=Dict{String,Any}("parent_id"=>parent["id"],"source"=>parent["source"],
        "root_index"=>get(TOML.parse(parent["properties"]),"root_index",parent["id"]),
        "prepared"=>prepared,"five_spaces_total"=>prepared ? length(spaces) : -1,
        "five_spaces_completed"=>count(j->j["status"]=="done",spaces),
        "cosets_checked"=>sum(max(0,Int(j["direction"])-1) for j in spaces;init=0),
        "cosets_total"=>prepared && known ? sum(Int(p["total_x"]) for p in proofs;init=0) : -1,
        "spaces_not_started"=>count(isempty,proofs),
        "switching_directions_checked"=>sum(clamp(Int(j["direction"])-1,0,255) for j in switching;init=0),
        "switching_directions_total"=>255*length(switching),
        "switching_complete"=>!isempty(switching) && all(j->j["status"]=="done",switching),
        "blocked_jobs"=>count(j->j["status"] in ("blocked","failed"),jobs))
    counts["focus"]=focus
    counts
end

"""
    closure_snapshot(directory)

Read committed counters in one read-only SQLite transaction. `running` requires
both an unfinished session and a presently held OS writer lease. Counts of EA
classes exclude unresolved candidates; seed completion excludes descendant work.
"""
function closure_snapshot(directory)
    dir=abspath(directory);path=joinpath(dir,"closure.sqlite")
    isfile(path) || error("closure frontier is not initialized")
    db=SQLite.DB("file:"*path*"?mode=ro")
    try
        _closure_exec(db,"PRAGMA query_only=ON");_closure_exec(db,"BEGIN")
        identity=TOML.parse(only(_closure_rows(db,"SELECT value FROM metadata WHERE key='identity'"))["value"])
        qualified_roots=Int(get(identity,"qualified_roots",identity["initial_roots"]))
        selection=get(identity["scientific"],"root_selection",Dict{String,Any}("first"=>1,
            "last"=>identity["initial_roots"],"order"=>"forward","index_base"=>1,"count"=>identity["initial_roots"]))
        initial=_closure_count(db,"SELECT COUNT(*) n FROM parents WHERE origin='root'")
        promoted=_closure_count(db,"SELECT COUNT(*) n FROM parents WHERE origin='discovered'")
        completed=_closure_count(db,"SELECT COUNT(*) n FROM parents p WHERE NOT EXISTS(SELECT 1 FROM jobs j WHERE j.parent_id=p.id AND j.kind IN ('prepare_v5','v5','switching') AND j.status!='done')")
        active=_closure_count(db,"SELECT COUNT(DISTINCT parent_id) n FROM jobs WHERE kind IN ('prepare_v5','v5','switching') AND status='running'")
        blocked=_closure_count(db,"SELECT COUNT(DISTINCT parent_id) n FROM jobs WHERE kind IN ('prepare_v5','v5','switching') AND status IN ('failed','blocked')")
        unresolved=_closure_count(db,"SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2 AND class_id IS NULL")
        jobs=_closure_count(db,"SELECT COUNT(*) n FROM jobs WHERE status!='done'")
        methods=Dict{String,Any}()
        for (name,kinds) in (("v5","('prepare_v5','v5')"),("switching","('switching')"))
            counts=Dict(String(r["status"])=>Int(r["n"]) for r in _closure_rows(db,"SELECT status,COUNT(*) n FROM jobs WHERE kind IN $kinds GROUP BY status"))
            m=Dict{String,Any}("parents_completed"=>_closure_count(db,"SELECT COUNT(*) n FROM parents p WHERE NOT EXISTS(SELECT 1 FROM jobs j WHERE j.parent_id=p.id AND j.kind IN $kinds AND j.status!='done')"))
            for key in ("done","pending","running","paused","failed","blocked");m["jobs_"*key]=get(counts,key,0);end
            m["candidates"]=name=="switching" ? _closure_count(db,"SELECT COUNT(*) n FROM evaluations") :
                _closure_count(db,"SELECT COUNT(*) n FROM paths WHERE method='v5'")
            m["candidate_count_scope"]=name=="switching" ? "all evaluated switching candidates, including rejected LUTs" : "verified APN completion paths, canonical outputs per eligible coset"
            if name=="v5"
                m["parents_prepared"]=_closure_count(db,"SELECT COUNT(*) n FROM jobs WHERE kind='prepare_v5' AND status='done'")
                m["cosets_checked"]=_closure_count(db,"SELECT COALESCE(SUM(direction-1),0) n FROM jobs WHERE kind='v5'")
            else
                m["directions_checked"]=_closure_count(db,"SELECT COALESCE(SUM(direction-1),0) n FROM jobs WHERE kind='switching'")
                m["nontrivial_kernels"]=_closure_count(db,"SELECT COUNT(*) n FROM kernels WHERE dimension>0")
            end
            methods[name]=m
        end
        sessions=_closure_rows(db,"SELECT id,started,finished,heartbeat,pid,host,state,jobs,evaluations FROM sessions ORDER BY id DESC LIMIT 10")
        cluster=Dict{String,Any}("enabled"=>false,"workers"=>Any[])
        if _closure_count(db,"SELECT COUNT(*) n FROM sqlite_master WHERE type='table' AND name='cluster_work'")==1 && !isempty(sessions)
            budgets=TOML.parse(only(_closure_rows(db,"SELECT budgets FROM sessions WHERE id=?",(first(sessions)["id"],)))["budgets"])
            if get(budgets,"backend","")=="Dagger"
                slots=budgets["slots"];workers=Any[]
                timing_columns=Set(row["name"] for row in _closure_rows(db,"PRAGMA table_info(cluster_work)"))
                for host in sort!(unique(slot["host"] for slot in slots))
                    active_work=_closure_count(db,"SELECT COUNT(*) n FROM cluster_work WHERE host=? AND status='running' AND session_id=?",(host,first(sessions)["id"]))
                    done=_closure_count(db,"SELECT COUNT(*) n FROM cluster_work WHERE host=? AND status='done'",(host,))
                    threads=[Int(r["thread_id"]) for r in _closure_rows(db,"SELECT DISTINCT thread_id FROM cluster_work WHERE host=? AND status='done' ORDER BY thread_id",(host,))]
                    worker=Dict{String,Any}("host"=>host,"configured_workers"=>count(slot->slot["host"]==host,slots),
                        "active_jobs"=>active_work,"completed_jobs"=>done,"observed_threads"=>threads)
                    if "compute_seconds" in timing_columns
                        timings=only(_closure_rows(db,"SELECT COUNT(*) jobs,COALESCE(SUM(compute_seconds),0) compute_seconds,COALESCE(SUM(context_wait_seconds),0) context_wait_seconds,COALESCE(SUM(ready_wait_seconds),0) ready_wait_seconds,COALESCE(SUM(commit_seconds),0) commit_seconds FROM cluster_work WHERE host=? AND session_id=? AND status='done'",(host,first(sessions)["id"])))
                        worker["session_timings"]=timings
                        if "execution_seconds" in timing_columns
                            extra=only(_closure_rows(db,"SELECT COALESCE(SUM(submit_wait_seconds),0) submit_wait_seconds,COALESCE(SUM(submit_seconds),0) submit_seconds,COALESCE(SUM(execution_seconds),0) execution_seconds,COALESCE(SUM(transfer_wait_seconds),0) transfer_wait_seconds,COALESCE(SUM(transfer_seconds),0) transfer_seconds FROM cluster_work WHERE host=? AND session_id=? AND status='done'",(host,first(sessions)["id"])))
                            merge!(timings,extra)
                        end
                    end
                    push!(workers,worker)
                end
                cluster=Dict{String,Any}("enabled"=>true,"backend"=>"Dagger","dagger_version"=>budgets["dagger_version"],
                    "coordinator_host"=>first(sessions)["host"],"workers"=>workers,"global_frontier"=>true,
                    "repeated_derivation_paths"=>_closure_count(db,"SELECT COUNT(*)-COUNT(DISTINCT child_id) n FROM paths"),
                    "verified_equivalent_luts"=>_closure_count(db,"SELECT COUNT(*) n FROM candidates WHERE state='equivalent'"))
            end
        end
        unfinished=!isempty(sessions) && first(sessions)["finished"]==""
        running=unfinished && _closure_writer_alive(dir)
        initialized=_closure_count(db,"SELECT COUNT(*) n FROM metadata WHERE key='initialization_complete' AND value='true'")==1
        complete=initialized && identity["qualification_complete"] && initial==identity["initial_roots"] && jobs==0 && unresolved==0
        state=complete ? "exhausted" : running ? "running" : unfinished ? "interrupted" : isempty(sessions) ? "ready" : first(sessions)["state"]
        heartbeat=isempty(sessions) ? "" : first(sessions)["heartbeat"]
        age=isempty(heartbeat) ? -1.0 : max(0.0,Dates.value(Dates.now(Dates.UTC)-DateTime(chop(heartbeat;tail=1)))/1000)
        result=Dict{String,Any}("schema"=>CLOSURE_PROGRESS_SCHEMA,"directory"=>dir,"state"=>state,"running"=>running,
            "heartbeat_utc"=>heartbeat,"heartbeat_age_seconds"=>age,"heartbeat_stale"=>running && age>120,
            "initial_roots"=>initial,"promoted_parents"=>promoted,"total_parents"=>initial+promoted,
            "qualified_roots"=>qualified_roots,"root_first"=>selection["first"],"root_last"=>selection["last"],
            "root_order"=>selection["order"],"root_selection"=>selection,
            "completed_parents"=>completed,"active_parents"=>active,"queued_parents"=>max(0,initial+promoted-completed-active-blocked),
            "blocked_parents"=>blocked,"unresolved_equivalence"=>unresolved,
            "nonquadratic_apn_luts"=>_closure_count(db,"SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree>2"),
            "exact_luts"=>_closure_count(db,"SELECT COUNT(*) n FROM candidates"),
            "quadratic_apn_luts"=>_closure_count(db,"SELECT COUNT(*) n FROM candidates WHERE apn=1 AND degree=2"),
            "signature_buckets"=>_closure_count(db,"SELECT COUNT(DISTINCT sigma) n FROM candidates WHERE apn=1 AND degree=2"),
            "construction_paths"=>_closure_count(db,"SELECT COUNT(*) n FROM paths"),"methods"=>methods,"sessions"=>sessions,"cluster"=>cluster,
            "seed_progress"=>_closure_seed_progress(db),
            "campaign_sha256"=>identity["campaign_sha256"],"roots_sha256"=>identity["roots_sha256"],
            "closure_complete"=>complete,"updated_utc"=>_closure_now(),"literature_novelty"=>"unresolved",
            "scope"=>"recursive closure from assigned published root rows $(selection["first"]):$(selection["last"]) under both declared operators; global EA admission when clustered; not all APNs or all profile-52 APNs")
        _closure_exec(db,"ROLLBACK");result
    finally
        SQLite.intransaction(db) && _closure_exec(db,"ROLLBACK")
        close(db)
    end
end

"""Join an outstanding reader before final publication or releasing the writer."""
function _closure_wait_report!(s)
    task=s.report_task
    s.report_task=nothing
    task===nothing || fetch(task)
    nothing
end

mutable struct _ClosureProgressReader
    process::Base.Process
    timeout_seconds::Float64
    request_id::Int
end

"""Reap only the owned progress child; never leave a reader behind a closed store."""
function _closure_stop_reader!(reader::_ClosureProgressReader;graceful=true)
    process=reader.process
    try
        try closewrite(process) catch end
        if !process_exited(process)
            graceful && timedwait(()->process_exited(process),2.0;pollint=0.02)
            if !process_exited(process)
                try kill(process,Base.SIGTERM) catch end
                timedwait(()->process_exited(process),1.0;pollint=0.02)
            end
            if !process_exited(process)
                try kill(process,Base.SIGKILL) catch end
            end
        end
        wait(process)
    finally
        try close(process) catch end
    end
    nothing
end

function _closure_shutdown_reporter!(s)
    reader=s.report_reader;s.report_reader=nothing
    reader===nothing || _closure_stop_reader!(reader)
    nothing
end

function _closure_reader_reply(reader::_ClosureProgressReader)
    pending=@async readline(reader.process)
    if timedwait(()->istaskdone(pending),reader.timeout_seconds;pollint=min(0.05,reader.timeout_seconds/10))==:timed_out
        _closure_stop_reader!(reader;graceful=false)
        try fetch(pending) catch end
        error("external progress reader timed out")
    end
    line=fetch(pending)
    isempty(line) && error("external progress reader closed its response pipe")
    JSON3.read(line)
end

function _closure_reader_event!(directory,event)
    open(joinpath(directory,"progress-reader-events.jsonl"),"a") do io
        JSON3.write(io,event);write(io,'\n')
    end
end

"""Private child entry point: snapshots retain the existing read transaction and atomic publisher."""
function _closure_progress_reader_main()
    JSON3.write(stdout,Dict("schema"=>"vbfsearch-progress-reader-v1","julia"=>string(VERSION),
        "source_root"=>realpath(DiscoveryInputs.ROOT),"implementation"=>implementation_fingerprint()))
    write(stdout,'\n');flush(stdout)
    while !eof(stdin)
        line=readline(stdin);isempty(line) && continue
        request=JSON3.read(line);id=Int(request["request_id"])
        directory=String(request["directory"]);started=time()
        _closure_reader_event!(directory,Dict("request_id"=>id,"phase"=>"started","unix_time"=>started,"pid"=>getpid()))
        reply=try
            request["operation"]=="snapshot" || error("unsupported progress reader request")
            DiscoveryStore.atomic_toml(joinpath(directory,"progress.toml"),closure_snapshot(directory))
            Dict{String,Any}("request_id"=>id,"ok"=>true)
        catch err
            Dict{String,Any}("request_id"=>id,"ok"=>false,"error"=>sprint(showerror,err))
        end
        finished=time()
        reply["started_unix"]=started;reply["finished_unix"]=finished;reply["snapshot_seconds"]=finished-started;reply["pid"]=getpid()
        _closure_reader_event!(directory,Dict("request_id"=>id,"phase"=>"finished","unix_time"=>finished,
            "started_unix"=>started,"snapshot_seconds"=>finished-started,"pid"=>getpid(),"ok"=>reply["ok"]))
        JSON3.write(stdout,reply);write(stdout,'\n');flush(stdout)
    end
    nothing
end

function _closure_start_reader(directory;timeout_seconds=180.0,command=nothing,verify_identity=true)
    isfinite(timeout_seconds) && timeout_seconds>0 || throw(ArgumentError("positive finite progress reader timeout required"))
    if command===nothing
        project=Base.active_project();project===nothing && error("external progress reader needs an active project")
        expression="using VBFSearch; VBFSearch._closure_progress_reader_main()"
        command=`$(Base.julia_cmd()) --startup-file=no --history-file=no --compiled-modules=existing --threads=1,0 --gcthreads=1 --project=$(dirname(project)) -e $expression`
    end
    process=open(joinpath(directory,"progress-reader.stderr.log"),"a") do errors
        open(pipeline(command;stderr=errors),"r+")
    end
    reader=_ClosureProgressReader(process,Float64(timeout_seconds),0)
    try
        hello=_closure_reader_reply(reader)
        hello["schema"]=="vbfsearch-progress-reader-v1" || error("external progress reader protocol mismatch")
        if verify_identity
            hello["julia"]==string(VERSION) && hello["source_root"]==realpath(DiscoveryInputs.ROOT) || error("external progress reader environment mismatch")
            fingerprint=Dict(String(k)=>String(v) for (k,v) in pairs(hello["implementation"]))
            fingerprint==implementation_fingerprint() || error("external progress reader implementation mismatch")
        end
        reader
    catch
        _closure_stop_reader!(reader;graceful=false)
        rethrow()
    end
end

function _closure_reader_snapshot!(reader::_ClosureProgressReader,directory)
    try
        reader.request_id+=1
        JSON3.write(reader.process,Dict("request_id"=>reader.request_id,"operation"=>"snapshot","directory"=>directory))
        write(reader.process,'\n');flush(reader.process)
        reply=_closure_reader_reply(reader)
        reply["request_id"]==reader.request_id || error("external progress reader response mismatch")
        get(reply,"ok",false) || error("external progress reader failed: "*String(get(reply,"error","unknown error")))
    catch
        _closure_stop_reader!(reader;graceful=false)
        rethrow()
    end
    nothing
end

"""Publish progress with a separate read transaction without stalling dispatch.

Only the writer touches its SQLite handle. At most one background reader may
publish, and forced checkpoints join it before publishing the final state.
"""
function _closure_report!(s;force=false,read_snapshot=closure_snapshot,
    write_snapshot=DiscoveryStore.atomic_toml)
    now=time_ns()
    if s.report_task!==nothing
        !force && !istaskdone(s.report_task) && return false
        _closure_wait_report!(s)
    end
    !force && now-s.last_report_ns<UInt64(10_000_000_000) && return false
    if s.session>0
        _closure_exec(s.db,"UPDATE sessions SET heartbeat=? WHERE id=?",(_closure_now(),s.session))
    end
    s.last_report_ns=now
    directory=s.directory
    external=s.report_backend==:process && read_snapshot===closure_snapshot && write_snapshot===DiscoveryStore.atomic_toml
    s.report_backend in (:thread,:process) || throw(ArgumentError("progress report backend must be thread or process"))
    publish=external ? ()->begin
        if s.report_reader===nothing
            s.report_reader=_closure_start_reader(directory;timeout_seconds=s.report_timeout_seconds)
        end
        _closure_reader_snapshot!(s.report_reader,directory)
    end : ()->write_snapshot(joinpath(directory,"progress.toml"),read_snapshot(directory))
    if force
        publish()
    else
        s.report_task=Threads.@spawn publish()
    end
    true
end

"""
    closure_progress(directory)

Read the last atomically published report without scanning evidence tables.
Counters describe its committed read transaction. Process liveness and heartbeat
age are refreshed cheaply; cached counters never establish additional coverage.
"""
function closure_progress(directory)
    dir=abspath(directory);path=joinpath(dir,"progress.toml")
    isfile(path) || return closure_snapshot(dir)
    result=TOML.parsefile(path)
    get(result,"schema",nothing)==CLOSURE_PROGRESS_SCHEMA || error("unsupported closure progress schema")
    result["directory"]=dir
    sessions=get(result,"sessions",Any[])
    unfinished=!isempty(sessions) && first(sessions)["finished"]==""
    running=unfinished && _closure_writer_alive(dir)
    result["running"]=running
    if unfinished
        result["state"]=running ? "running" : "interrupted"
    end
    heartbeat=get(result,"heartbeat_utc","")
    age=isempty(heartbeat) ? -1.0 : max(0.0,Dates.value(Dates.now(Dates.UTC)-DateTime(chop(heartbeat;tail=1)))/1000)
    result["heartbeat_age_seconds"]=age
    result["heartbeat_stale"]=running && age>120
    result
end

"""Request a cooperative stop. The current atomic coset/APN test commits first."""
function closure_stop!(directory)
    dir=abspath(directory);isfile(joinpath(dir,"closure.sqlite")) || error("closure frontier is not initialized")
    write(joinpath(dir,"STOP"),_closure_now()*"\n");nothing
end
