"""Bounded coordinator-local snapshots of ordered EA reference-parent identities.

Only parent IDs, exact candidate IDs and LUT bytes are cached. Saved exhaustive
decisions remain candidate-specific and are queried by packet construction.
Connection-local triggers clear native state conservatively on identity writes;
class/state admission updates leave it intact. Dirty transaction reads bypass
the cache until an observed commit or rollback boundary, because rolling back a
savepoint does not run SQL triggers and must never restore stale native state.
"""
const _CLOSURE_PARENT_TARGET_SQL="SELECT p.id,c.id candidate_id,c.lut_hex FROM parents p JOIN candidates c ON c.id=p.candidate_id WHERE p.sigma=? ORDER BY p.id"
const _CLOSURE_PARENT_TARGET_ONE_SQL="SELECT p.candidate_id,c.lut_hex FROM parents p JOIN candidates c ON c.id=p.candidate_id WHERE p.id=?"

"""Immutable string-keyed reference identity; no candidate-specific decisions."""
struct _ClosureParentTargetRow <: AbstractDict{String,Any}
    id::Int
    candidate_id::String
    lut_hex::String
end
Base.length(::_ClosureParentTargetRow)=3
Base.keys(::_ClosureParentTargetRow)=("id","candidate_id","lut_hex")
Base.haskey(row::_ClosureParentTargetRow,key)=key in keys(row)
Base.get(row::_ClosureParentTargetRow,key,default)=haskey(row,key) ? row[key] : default
function Base.getindex(row::_ClosureParentTargetRow,key)
    key=="id" && return row.id
    key=="candidate_id" && return row.candidate_id
    key=="lut_hex" && return row.lut_hex
    throw(KeyError(key))
end
function Base.iterate(row::_ClosureParentTargetRow,state::Int=1)
    state>3 && return nothing
    key=keys(row)[state]
    (Pair{String,Any}(key,row[key]),state+1)
end
Base.copy(row::_ClosureParentTargetRow)=Dict{String,Any}(row)

"""A read-only row sequence whose entire reachable storage is immutable."""
struct _ClosureParentTargets <: AbstractVector{_ClosureParentTargetRow}
    rows::Tuple{Vararg{_ClosureParentTargetRow}}
end
Base.IndexStyle(::Type{_ClosureParentTargets})=IndexLinear()
Base.size(rows::_ClosureParentTargets)=(length(rows.rows),)
Base.getindex(rows::_ClosureParentTargets,index::Int)=rows.rows[index]

"""Connection-bound FIFO cache, bounded independently by rows and signatures.

Construction requires a committed boundary and the open exclusive writer lease.
Cache reads and invalidation run only on the coordinator that owns the store.
"""
mutable struct _ClosureParentTargetCache
    store::ClosureStore
    connection::SQLite.DB
    entries::Dict{String,_ClosureParentTargets}
    parent_rows::Dict{Int,_ClosureParentTargetRow}
    order::Vector{String}
    order_head::Int
    max_targets::Int
    max_entries::Int
    target_rows::Int
    dirty::Bool
    hits::Int
    misses::Int
    clears::Int
    bypasses::Int
    evictions::Int
    oversized::Int
    parent_hits::Int
    parent_misses::Int
    query_seconds::Float64
    setup_seconds::Float64
end

"""Clear immediately; native invalidation deliberately survives SQL rollback."""
function _closure_clear_parent_targets!(cache::_ClosureParentTargetCache)
    empty!(cache.entries);empty!(cache.parent_rows);empty!(cache.order);cache.order_head=1;cache.target_rows=0
    cache.dirty=true;cache.clears+=1
    0
end

"""Install a nondeterministic invalidator and TEMP-only identity triggers once."""
function _ClosureParentTargetCache(s::ClosureStore;max_targets::Int=16_384,max_entries::Int=16_384)
    max_targets>0 && max_entries>0 || throw(ArgumentError("parent-target cache limits must be positive"))
    isopen(s.lease) && isopen(s.db) || error("parent-target cache requires the open exclusive writer store")
    SQLite.intransaction(s.db) && error("install parent-target cache at a committed boundary")
    _closure_count(s,"SELECT COUNT(*) n FROM temp.sqlite_master WHERE type='trigger' AND name LIKE 'closure_parent_targets_%'")==0 || error("parent-target cache already installed on this connection")
    started=time_ns()
    cache=_ClosureParentTargetCache(s,s.db,Dict{String,_ClosureParentTargets}(),Dict{Int,_ClosureParentTargetRow}(),String[],1,max_targets,max_entries,
        0,false,0,0,0,0,0,0,0,0,0.0,0.0)
    name="vbfsearch_parent_targets_invalidate"
    SQLite.register(s.db,()->_closure_clear_parent_targets!(cache);name,nargs=0,isdeterm=false)
    normalized=_closure_normalized(s.db);physical=normalized ? "closure_candidates" : "candidates"
    columns=normalized ? "id,lut,lut_text,sigma" : "id,lut_hex,sigma"
    changed=normalized ? "OLD.id IS NOT NEW.id OR OLD.lut IS NOT NEW.lut OR OLD.lut_text IS NOT NEW.lut_text OR OLD.sigma IS NOT NEW.sigma" :
        "OLD.id IS NOT NEW.id OR OLD.lut_hex IS NOT NEW.lut_hex OR OLD.sigma IS NOT NEW.sigma"
    _closure_transaction(s) do
        triggers=(
            ("parent_insert","AFTER INSERT ON main.parents"),
            ("parent_delete","AFTER DELETE ON main.parents"),
            ("parent_update","AFTER UPDATE OF id,candidate_id,sigma ON main.parents WHEN OLD.id IS NOT NEW.id OR OLD.candidate_id IS NOT NEW.candidate_id OR OLD.sigma IS NOT NEW.sigma"),
            ("candidate_insert","AFTER INSERT ON main.$physical WHEN EXISTS(SELECT 1 FROM main.parents WHERE candidate_id=NEW.id)"),
            ("candidate_delete","AFTER DELETE ON main.$physical WHEN EXISTS(SELECT 1 FROM main.parents WHERE candidate_id=OLD.id)"),
            ("candidate_update","AFTER UPDATE OF $columns ON main.$physical WHEN ($changed) AND EXISTS(SELECT 1 FROM main.parents WHERE candidate_id IN (OLD.id,NEW.id))"))
        for (suffix,operation) in triggers
            _closure_exec(s,"CREATE TEMP TRIGGER closure_parent_targets_$suffix $operation BEGIN SELECT $name(); END")
        end
    end
    cache.setup_seconds=(time_ns()-started)*1e-9
    cache
end

"""Acknowledge a real transaction boundary before admitting cache entries again.

This does not infer commit from counters or restore any previous cache values.
The controller also calls it after each committed coordinator step, avoiding
an unnecessary disabled-cache period after a parent admission.
"""
function _closure_parent_target_cache_boundary!(cache::_ClosureParentTargetCache)
    cache.store.db===cache.connection || error("parent-target cache store changed its connection")
    if cache.dirty && isopen(cache.connection) && !SQLite.intransaction(cache.connection)
        empty!(cache.entries);empty!(cache.parent_rows);empty!(cache.order);cache.order_head=1;cache.target_rows=0;cache.dirty=false
    end
    nothing
end
_closure_parent_target_cache_boundary!(::Nothing)=nothing

"""Keep the cache-off query exactly identical to ordinary packet construction."""
_closure_parent_targets(s,sigma,::Nothing=nothing)=_closure_rows(s,_CLOSURE_PARENT_TARGET_SQL,(sigma,))

"""Load an immutable base snapshot without leaking dictionaries or mutable arrays."""
function _closure_read_parent_targets(s,sigma)
    rows=_closure_rows(s,_CLOSURE_PARENT_TARGET_SQL,(sigma,))
    _ClosureParentTargets(Tuple(_ClosureParentTargetRow(Int(row["id"]),String(row["candidate_id"]),String(row["lut_hex"])) for row in rows))
end

"""Reuse only committed identities; mutation-era transaction reads never cache."""
function _closure_parent_targets(s,sigma,cache::_ClosureParentTargetCache)
    s===cache.store && s.db===cache.connection || throw(ArgumentError("parent-target cache belongs to another store or connection"))
    isopen(s.lease) && isopen(s.db) || error("parent-target cache store is closed")
    _closure_parent_target_cache_boundary!(cache)
    reusable=!cache.dirty && sigma isa AbstractString
    key=reusable ? String(sigma) : ""
    if reusable
        found=get(cache.entries,key,nothing)
        if found!==nothing
            cache.hits+=1
            return found
        end
    end
    cache.misses+=1
    started=time_ns()
    rows=try
        _closure_read_parent_targets(s,sigma)
    finally
        cache.query_seconds+=(time_ns()-started)*1e-9
    end
    if !reusable
        cache.bypasses+=1
    elseif length(rows)>cache.max_targets
        cache.oversized+=1
    else
        while !isempty(cache.entries) && (length(cache.entries)>=cache.max_entries || cache.target_rows+length(rows)>cache.max_targets)
            victim=cache.order[cache.order_head];cache.order_head+=1
            discarded=pop!(cache.entries,victim)
            for row in discarded;delete!(cache.parent_rows,row.id);end
            cache.target_rows-=length(discarded);cache.evictions+=1
        end
        if cache.order_head>cache.max_entries
            deleteat!(cache.order,1:cache.order_head-1);cache.order_head=1
        end
        cache.entries[key]=rows;push!(cache.order,key);cache.target_rows+=length(rows)
        for row in rows;cache.parent_rows[row.id]=row;end
    end
    rows
end

"""Retain ordinary missing-parent errors and uncached point-query semantics."""
_closure_parent_target(s,id,::Nothing=nothing)=only(_closure_rows(s,_CLOSURE_PARENT_TARGET_ONE_SQL,(id,)))

"""Reuse the exact cached identity row without omitting admission pair checks.

Point misses do not populate an independent cache, so both indexes share the
same bounded rows and eviction policy. Dirty transaction reads query SQLite.
"""
function _closure_parent_target(s,id,cache::_ClosureParentTargetCache)
    s===cache.store && s.db===cache.connection || throw(ArgumentError("parent-target cache belongs to another store or connection"))
    isopen(s.lease) && isopen(s.db) || error("parent-target cache store is closed")
    _closure_parent_target_cache_boundary!(cache)
    if !cache.dirty
        row=get(cache.parent_rows,id,nothing)
        if row!==nothing
            cache.parent_hits+=1
            return row
        end
    end
    cache.parent_misses+=1
    started=time_ns()
    try
        _closure_parent_target(s,id,nothing)
    finally
        cache.query_seconds+=(time_ns()-started)*1e-9
    end
end

"""Snapshot only native counters; no database count or cached rows are traversed."""
function _closure_parent_target_cache_stats(cache::_ClosureParentTargetCache)
    _closure_parent_target_cache_boundary!(cache)
    Dict{String,Any}("enabled"=>true,"hits"=>cache.hits,"misses"=>cache.misses,"clears"=>cache.clears,
        "entries"=>length(cache.entries),"target_rows"=>cache.target_rows,"max_targets"=>cache.max_targets,
        "max_entries"=>cache.max_entries,"bypasses"=>cache.bypasses,"evictions"=>cache.evictions,
        "oversized"=>cache.oversized,"dirty"=>cache.dirty,"query_seconds"=>cache.query_seconds,
        "parent_hits"=>cache.parent_hits,"parent_misses"=>cache.parent_misses,
        "setup_seconds"=>cache.setup_seconds,"policy"=>"bounded FIFO of immutable base targets; transactional identity invalidation; dirty transaction reads bypass")
end
_closure_parent_target_cache_stats(::Nothing)=Dict{String,Any}("enabled"=>false)
