using VBFSearch, TOML, SHA

"""Shared baseline helper for the threaded closure controllers.

The controllers include this file and archive it as `baseline-controller.jl`.
It never claims construction work and never rewrites the frontier identity.
"""
const EA = VBFSearch

"""Save the complete mutable classification projection before any EA attempt."""
function ea_baseline!(s, directory)
    path=joinpath(directory,"classification-before.sqlite")
    ispath(path) && error("baseline already exists")
    EA._closure_exec(s.db,"ATTACH DATABASE ? AS ea_before",(path,))
    try
        for table in ("metadata","candidates","parents","jobs","comparisons","sessions")
            EA._closure_exec(s.db,"CREATE TABLE ea_before.\"$table\" AS SELECT * FROM main.\"$table\"")
        end
        for table in ("candidates","parents","jobs")
            EA._closure_exec(s.db,"CREATE UNIQUE INDEX ea_before.\"$(table)_id\" ON \"$table\"(id)")
        end
    finally
        EA._closure_exec(s.db,"DETACH DATABASE ea_before")
    end
    Dict("path"=>path,"bytes"=>filesize(path),"sha256"=>EA.DiscoveryEvidence.filehash(path),
        "scope"=>"classification, parents and all job cursors; construction path/kernel/chunk evidence remains in the source database")
end

"""Small restart evidence by default; an explicit full projection remains available.

The summary records identity, cached counter freshness, indexed row watermarks
and the last session. It is not a rollback backup. The checkpoint retains all
derivation provenance. `ea_baseline!` keeps its original full-copy semantics for
other controllers; continuous campaigns opt into that copy with `policy="full"`.
"""
function continuous_baseline!(s,directory;policy="summary",cached_progress=Dict{String,Any}(),
    full_reserve_bytes::Integer=8*1024^3)
    policy in ("summary","full") || throw(ArgumentError("baseline_policy must be summary or full"))
    full_reserve_bytes>=0 || throw(ArgumentError("full baseline reserve must be nonnegative"))
    if policy=="full"
        source=joinpath(s.directory,"closure.sqlite")
        footprint=Int128(filesize(source))+(isfile(source*"-wal") ? filesize(source*"-wal") : 0)
        # The complete checkpoint is a conservative upper bound for the copied
        # classification subset; allow an additional 50% for index construction.
        estimate=cld(3footprint,2)
        available=Int128(Base.Filesystem.diskstat(directory).available)
        needed=estimate+Int128(full_reserve_bytes)
        available>=needed || error("full classification baseline needs at least $needed free bytes "*
            "($estimate conservative copy/index estimate plus $full_reserve_bytes reserve); "*
            "$available available; use baseline_policy=summary")
        result=ea_baseline!(s,directory)
        return merge(result,Dict("policy"=>"full","estimated_bytes"=>Int(estimate),
            "free_bytes_before"=>Int(available),"reserve_bytes"=>Int(full_reserve_bytes)))
    end
    path=joinpath(directory,"classification-before-summary.toml")
    ispath(path) && error("baseline already exists")
    watermarks=Dict{String,Int}()
    for table in ("candidates","parents","jobs","comparisons","sessions")
        physical=EA._closure_normalized(s.db) && table in ("candidates","comparisons") ? "closure_"*table : table
        watermarks[table*"_max_rowid"]=EA._closure_count(s.db,"SELECT COALESCE(MAX(rowid),0) n FROM $physical")
    end
    counters=Dict{String,Any}()
    for name in ("total_parents","promoted_parents","exact_luts","quadratic_apn_luts",
            "nonquadratic_apn_luts","unresolved_equivalence","construction_paths","completed_parents")
        haskey(cached_progress,name) && (counters[name]=cached_progress[name])
    end
    identity_path=joinpath(s.directory,"identity.toml")
    data=Dict{String,Any}("schema"=>"vbfsearch-continuous-baseline-summary-v1","policy"=>"summary",
        "scope"=>"identity, cached counters, indexed row watermarks and latest session; not a rollback backup",
        "derivation_provenance"=>"retained in the existing checkpoint; no construction evidence copied or changed",
        "checkpoint"=>s.directory,"created_utc"=>EA._closure_now(),
        "identity_sha256"=>EA.DiscoveryEvidence.filehash(identity_path),
        "cached_counters"=>counters,"cached_counters_updated_utc"=>get(cached_progress,"updated_utc","unknown"),
        "metadata"=>EA._closure_rows(s.db,"SELECT key,value FROM metadata WHERE key IN ('created_utc','origin_turn','method_turn','dispatch_sequence','ledger_encoding','initialization_complete') ORDER BY key"),
        "watermarks"=>watermarks,
        "latest_session"=>EA._closure_rows(s.db,"SELECT id,started,finished,heartbeat,state,jobs,evaluations FROM sessions ORDER BY id DESC LIMIT 1"))
    EA.DiscoveryStore.atomic_toml(path,data)
    Dict("policy"=>"summary","path"=>path,"bytes"=>filesize(path),
        "sha256"=>EA.DiscoveryEvidence.filehash(path),"scope"=>data["scope"])
end
