"""Transactional completion accounting for the controller's selected seed cohorts.

The original completion predicate requires every construction job to be done
and every quadratic APN child reached by those jobs to have a class. TEMP
tables maintain that predicate under the store's exclusive writer lease.
Dependencies include classified and nonquadratic children so revalidation is
accounted for, and shared exact children update every dependent parent. Only
selected cohorts and their unresolved retired parents are retained; completed
parents release their dependency rows. No state is added to a checkpoint.
"""
module ClosureCompletion
using VBFSearch
const FP=VBFSearch
const KINDS="('prepare_v5','v5','switching')"

"""Connection-local counters and elapsed accounting, independent of scientific rows."""
mutable struct Tracker
    store::FP.ClosureStore
    setup_seconds::Float64
    backfill_seconds::Float64
    backfill_calls::Int
    check_seconds::Float64
    check_calls::Int
    release_seconds::Float64
end

"""Install physical-table triggers whose changes roll back with each packet.

Job identity changes are rare maintenance operations and rebuild only the
affected tracked parents. Ordinary status, candidate and path writes update
indexed TEMP state without scanning historical paths.
"""
function install!(s::FP.ClosureStore)
    isopen(s.lease) || error("completion tracking requires the exclusive writer store")
    started=time_ns()
    physical=FP._closure_normalized(s.db) ? "closure_candidates" : "candidates"
    unresolved(alias)="($alias.apn=1 AND $alias.degree=2 AND $alias.class_id IS NULL)"
    child_pending(child)="coalesce((SELECT $(unresolved("c")) FROM main.$physical c WHERE c.id=$child),0)"
    parent_for(alias)="(SELECT parent_id FROM main.jobs WHERE id=$alias.job_id AND kind IN $KINDS)"
    function add_path(alias)
        parent=parent_for(alias)
        """
        INSERT INTO closure_completion_edges(child_id,parent_id,path_count)
          SELECT $alias.child_id,j.parent_id,1 FROM main.jobs j
          JOIN closure_completion_parents t ON t.parent_id=j.parent_id
          WHERE j.id=$alias.job_id AND j.kind IN $KINDS
          ON CONFLICT(child_id,parent_id) DO UPDATE SET path_count=path_count+1;
        UPDATE closure_completion_parents SET unresolved_paths=unresolved_paths+$(child_pending("$alias.child_id"))
          WHERE parent_id=$parent;
        """
    end
    function remove_path(alias)
        parent=parent_for(alias)
        """
        UPDATE closure_completion_parents SET unresolved_paths=unresolved_paths-$(child_pending("$alias.child_id"))
          WHERE parent_id=$parent;
        UPDATE closure_completion_edges SET path_count=path_count-1
          WHERE child_id=$alias.child_id AND parent_id=$parent;
        DELETE FROM closure_completion_edges WHERE child_id=$alias.child_id AND parent_id=$parent AND path_count=0;
        """
    end
    function refresh_parents(selected)
        """
        DELETE FROM closure_completion_edges WHERE parent_id IN ($selected);
        INSERT INTO closure_completion_edges(child_id,parent_id,path_count)
          SELECT p.child_id,j.parent_id,COUNT(*) FROM main.jobs j
          JOIN main.paths p ON p.job_id=j.id
          JOIN closure_completion_parents t ON t.parent_id=j.parent_id
          WHERE j.parent_id IN ($selected) AND j.kind IN $KINDS GROUP BY j.parent_id,p.child_id;
        UPDATE closure_completion_parents SET
          unfinished_jobs=(SELECT COUNT(*) FROM main.jobs j WHERE j.parent_id=closure_completion_parents.parent_id AND j.kind IN $KINDS AND j.status!='done'),
          unresolved_paths=coalesce((SELECT SUM(e.path_count) FROM closure_completion_edges e JOIN main.$physical c ON c.id=e.child_id
            WHERE e.parent_id=closure_completion_parents.parent_id AND $(unresolved("c"))),0)
          WHERE parent_id IN ($selected);
        """
    end
    # The edge primary key guarantees one joined source row per updated parent.
    candidate_delta(delta,child)="""
        UPDATE closure_completion_parents SET unresolved_paths=unresolved_paths+($delta)*e.path_count
          FROM closure_completion_edges e
          WHERE e.child_id=$child AND e.parent_id=closure_completion_parents.parent_id;
        """
    FP._closure_transaction(s) do
        FP._closure_exec(s,"CREATE TEMP TABLE closure_completion_parents(parent_id INTEGER PRIMARY KEY,unfinished_jobs INTEGER NOT NULL CHECK(unfinished_jobs>=0),unresolved_paths INTEGER NOT NULL CHECK(unresolved_paths>=0))")
        FP._closure_exec(s,"CREATE TEMP TABLE closure_completion_edges(child_id TEXT NOT NULL,parent_id INTEGER NOT NULL,path_count INTEGER NOT NULL CHECK(path_count>=0),PRIMARY KEY(child_id,parent_id)) WITHOUT ROWID")
        FP._closure_exec(s,"CREATE INDEX temp.closure_completion_edges_parent ON closure_completion_edges(parent_id)")
        triggers=(
            ("path_insert","AFTER INSERT ON main.paths",add_path("NEW")),
            ("path_delete","AFTER DELETE ON main.paths",remove_path("OLD")),
            ("path_update","AFTER UPDATE OF job_id,child_id ON main.paths WHEN OLD.job_id IS NOT NEW.job_id OR OLD.child_id IS NOT NEW.child_id",remove_path("OLD")*add_path("NEW")),
            ("candidate_insert","AFTER INSERT ON main.$physical WHEN $(unresolved("NEW"))",candidate_delta("1","NEW.id")),
            ("candidate_delete","AFTER DELETE ON main.$physical WHEN $(unresolved("OLD"))",candidate_delta("-1","OLD.id")),
            ("candidate_update","AFTER UPDATE OF apn,degree,class_id ON main.$physical WHEN $(unresolved("OLD"))!=$(unresolved("NEW"))",
                candidate_delta("$(unresolved("NEW"))-$(unresolved("OLD"))","NEW.id")),
            ("job_insert","AFTER INSERT ON main.jobs WHEN NEW.kind IN $KINDS AND NEW.status!='done'",
                "UPDATE closure_completion_parents SET unfinished_jobs=unfinished_jobs+1 WHERE parent_id=NEW.parent_id;"),
            ("job_status","AFTER UPDATE OF status ON main.jobs WHEN NEW.kind IN $KINDS AND OLD.parent_id IS NEW.parent_id AND OLD.kind IS NEW.kind AND (OLD.status='done')!=(NEW.status='done')",
                "UPDATE closure_completion_parents SET unfinished_jobs=unfinished_jobs+(NEW.status!='done')-(OLD.status!='done') WHERE parent_id=NEW.parent_id;"),
            ("job_identity","AFTER UPDATE OF parent_id,kind ON main.jobs WHEN OLD.parent_id IS NOT NEW.parent_id OR OLD.kind IS NOT NEW.kind",refresh_parents("OLD.parent_id,NEW.parent_id")),
            ("job_delete","AFTER DELETE ON main.jobs",refresh_parents("OLD.parent_id")))
        for (name,operation,body) in triggers
            FP._closure_exec(s,"CREATE TEMP TRIGGER closure_completion_$name $operation BEGIN $body END")
        end
    end
    Tracker(s,(time_ns()-started)*1e-9,0.0,0,0.0,0,0.0)
end

"""Backfill new cohort members once, joining paths through the existing job index.

May join an existing coordinator transaction. Registration and its dependency
rows then roll back together. Already tracked unresolved parents are retained.
"""
function track!(tracker::Tracker,parents)
    selected=sort!(unique!(Int[p for p in parents]));isempty(selected) && return
    s=tracker.store;started=time_ns()
    try
        selected_json=String(FP.JSON3.write(selected))
        fresh=FP._closure_rows(s,"SELECT value AS parent_id FROM json_each(?) WHERE value NOT IN (SELECT parent_id FROM temp.closure_completion_parents)",(selected_json,))
        isempty(fresh) && return
        fresh_json=String(FP.JSON3.write(Int[row["parent_id"] for row in fresh]))
        physical=FP._closure_normalized(s.db) ? "closure_candidates" : "candidates"
        FP._closure_transaction(s) do
            FP._closure_exec(s,"INSERT INTO temp.closure_completion_parents SELECT value,0,0 FROM json_each(?)",(fresh_json,))
            FP._closure_exec(s,"""INSERT INTO temp.closure_completion_edges(child_id,parent_id,path_count)
                SELECT p.child_id,j.parent_id,COUNT(*) FROM jobs j JOIN paths p ON p.job_id=j.id
                WHERE j.parent_id IN (SELECT value FROM json_each(?)) AND j.kind IN $KINDS
                GROUP BY j.parent_id,p.child_id""",(fresh_json,))
            FP._closure_exec(s,"""UPDATE temp.closure_completion_parents SET
                unfinished_jobs=(SELECT COUNT(*) FROM jobs j WHERE j.parent_id=closure_completion_parents.parent_id AND j.kind IN $KINDS AND j.status!='done'),
                unresolved_paths=coalesce((SELECT SUM(e.path_count) FROM temp.closure_completion_edges e JOIN $physical c ON c.id=e.child_id
                    WHERE e.parent_id=closure_completion_parents.parent_id AND c.apn=1 AND c.degree=2 AND c.class_id IS NULL),0)
                WHERE parent_id IN (SELECT value FROM json_each(?))""",(fresh_json,))
        end
    finally
        tracker.backfill_seconds+=(time_ns()-started)*1e-9;tracker.backfill_calls+=1
    end
    nothing
end

"""Return completion candidates only after their scientific transaction commits."""
function ready(tracker::Tracker)
    FP.SQLite.intransaction(tracker.store.db) && return Int[]
    started=time_ns()
    try
        Int[row["parent_id"] for row in FP._closure_rows(tracker.store,
            "SELECT parent_id FROM temp.closure_completion_parents WHERE unfinished_jobs=0 AND unresolved_paths=0 ORDER BY parent_id")]
    finally
        tracker.check_seconds+=(time_ns()-started)*1e-9;tracker.check_calls+=1
    end
end

"""Release completed or explicitly discarded cohort dependencies without campaign scans."""
function release!(tracker::Tracker,parents)
    selected=Int[p for p in parents];isempty(selected) && return
    started=time_ns();s=tracker.store;encoded=String(FP.JSON3.write(selected))
    try
        FP._closure_transaction(s) do
            FP._closure_exec(s,"DELETE FROM temp.closure_completion_edges WHERE parent_id IN (SELECT value FROM json_each(?))",(encoded,))
            FP._closure_exec(s,"DELETE FROM temp.closure_completion_parents WHERE parent_id IN (SELECT value FROM json_each(?))",(encoded,))
        end
    finally
        tracker.release_seconds+=(time_ns()-started)*1e-9
    end
    nothing
end

"""Report completion work separately from reporting and actual process CPU usage."""
function snapshot(tracker::Tracker)
    counts=Dict{String,Any}(only(FP._closure_rows(tracker.store,"SELECT COUNT(*) AS tracked_parents,coalesce(SUM(unfinished_jobs),0) AS unfinished_jobs,coalesce(SUM(unresolved_paths),0) AS unresolved_paths FROM temp.closure_completion_parents")))
    pragma(sql)=Int(only(values(only(FP._closure_rows(tracker.store,sql)))))
    temp_pages=pragma("PRAGMA temp.page_count");temp_page_bytes=pragma("PRAGMA temp.page_size")
    merge!(counts,Dict("policy"=>"transactional TEMP counters; selected cohorts and unresolved retired parents only",
        "setup_seconds"=>tracker.setup_seconds,"backfill_seconds"=>tracker.backfill_seconds,
        "backfill_calls"=>tracker.backfill_calls,"check_seconds"=>tracker.check_seconds,
        "check_calls"=>tracker.check_calls,"release_seconds"=>tracker.release_seconds,
        "temp_allocated_bytes"=>temp_pages*temp_page_bytes,"temp_store"=>pragma("PRAGMA temp_store"),
        "temp_bytes_scope"=>"connection TEMP database allocation, including other TEMP tables; SQLite temp_store policy applies"))
end
end
