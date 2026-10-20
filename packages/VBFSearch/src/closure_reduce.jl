"""
    closure_reduce(source; output, helper, threads=8, reserve_bytes=12*1024^3,
                   max_bytes=55*1024^3,resume_helper_sha256=nothing)

Losslessly normalize a cooperatively stopped checkpoint. The native helper is
built from `tools/reduce_closure_store.cpp`; it verifies all logical table bytes,
every ledger block, SQLite integrity and foreign keys. Its fixed `output.reducing`
staging directory supports resuming the same command after interruption. Neither
failure nor success deletes the source checkpoint. The output retains STOP and
pins new storage code while leaving mathematical code and parameters unchanged.
`resume_helper_sha256` explicitly permits replacing that pinned helper only after
all scientific tables and ledger have been verified; the predecessor is recorded
and final database checks run again. Source and schema pins remain mandatory.
"""
function closure_reduce(source;output,helper,threads=8,reserve_bytes=12*1024^3,max_bytes=55*1024^3,resume_helper_sha256=nothing)
    threads isa Integer && 1<=threads<=32 || throw(ArgumentError("threads must be 1..32"))
    reserve_bytes isa Integer && reserve_bytes>=0 && max_bytes isa Integer && max_bytes>0 || throw(ArgumentError("invalid disk budgets"))
    resume_helper_sha256===nothing || (resume_helper_sha256 isa String && occursin(r"^[0-9a-f]{64}$",resume_helper_sha256)) ||
        throw(ArgumentError("resume_helper_sha256 must be a lowercase SHA-256"))
    origin=realpath(source);target=abspath(output);stage=target*".reducing"
    (ispath(target) || startswith(target,origin*string(Base.Filesystem.path_separator))) && error("output must be new and outside source")
    isfile(joinpath(origin,"STOP")) || error("source must have a STOP marker")
    lease=_closure_lease(origin);db=nothing
    try
        db=SQLite.DB("file:"*joinpath(origin,"closure.sqlite")*"?mode=ro")
        _closure_reject_segmented_clone(db)
        identity,_=_closure_upgrade_source(db,origin)
        _closure_normalized(db) && error("source is already normalized")
        implementation=implementation_fingerprint()
        allowed=union(_CLOSURE_UPGRADE_PATHS,Set(["packages/VBFSearch/src/closure_normalized.jl",
            "packages/VBFSearch/src/closure_normalized.sql","packages/VBFSearch/src/closure_ledger_v2.jl",
            "packages/VBFSearch/src/closure_reduce.jl"]))
        changed=sort!([p for p in union(keys(identity["implementation"]),keys(implementation)) if get(identity["implementation"],p,nothing)!=get(implementation,p,nothing)])
        all(p->p in allowed,changed) || error("reduction changes mathematics, catalog or pinned environment: "*join(setdiff(changed,allowed),", "))
        cutoff=_closure_count(db,"SELECT COALESCE(MAX(id),0) n FROM sessions")
        close(db);db=nothing
        mkpath(stage);write(joinpath(stage,"STOP"),"Storage migration; search remains stopped.\n")
        log=joinpath(stage,"migration.jsonl");schema=joinpath(@__DIR__,"closure_normalized.sql")
        open(log,"a") do io
            arguments=[abspath(helper),joinpath(origin,"closure.sqlite"),joinpath(stage,"closure.sqlite"),schema,
                string(threads),string(reserve_bytes),string(max_bytes)]
            resume_helper_sha256===nothing || push!(arguments,resume_helper_sha256)
            run(pipeline(Cmd(arguments);stdout=io))
        end
        check=SQLite.DB("file:"*joinpath(stage,"closure.sqlite")*"?mode=ro")
        proofs=try
            Dict(r["key"]=>r["value"] for r in _closure_rows(check,"SELECT * FROM closure_reduction_state"))
        finally
            close(check)
        end
        get(proofs,"complete","")=="true" || error("helper did not complete verification")
        events=[JSON3.read(line,Dict{String,Any}) for line in eachline(log)]
        record=Dict{String,Any}("schema"=>"vbfsearch-closure-reduction-v1","created_utc"=>_closure_now(),
            "source_directory"=>origin,"source_main_sha256"=>_closure_storage_filehash(joinpath(origin,"closure.sqlite")),
            "source_identity_sha256"=>DiscoveryEvidence.filehash(joinpath(origin,"identity.toml")),
            "source_bytes"=>filesize(joinpath(origin,"closure.sqlite")),"reduced_bytes"=>filesize(joinpath(stage,"closure.sqlite")),
            "source_sessions_through"=>cutoff,"prior_implementation"=>identity["implementation"],"new_implementation"=>implementation,
            "changed_implementation_paths"=>changed,"helper_sha256"=>DiscoveryEvidence.filehash(helper),
            "helper_sources"=>Dict(name=>DiscoveryEvidence.filehash(joinpath(pkgdir(VBFSearch),"tools",name)) for name in ("reduce_closure_store.cpp","closure_reduction_codec.hpp")),
            "migration_log_sha256"=>DiscoveryEvidence.filehash(log),"verification"=>proofs,
            "table_digests"=>filter(e->e["event"]=="table_verified",events),
            "scientific_scope"=>"unchanged; all logical records and original proof text retained byte for byte",
            "rollback"=>origin)
        previous=joinpath(stage,"lineage","previous");mkpath(previous)
        cp(joinpath(origin,"identity.toml"),joinpath(previous,"identity.toml");force=true)
        DiscoveryStore.atomic_toml(joinpath(previous,"external-checkpoint.toml"),record)
        mkpath(joinpath(stage,"replay"))
        isdir(joinpath(stage,"replay","inputs")) || cp(joinpath(origin,"replay","inputs"),joinpath(stage,"replay","inputs"))
        for (relative,digest) in implementation
            archived=joinpath(stage,"replay","workspace",relative);mkpath(dirname(archived))
            cp(joinpath(DiscoveryInputs.ROOT,relative),archived;force=true)
            DiscoveryEvidence.filehash(archived)==digest || error("implementation changed during migration archival")
        end
        current=deepcopy(identity);current["implementation"]=implementation
        current["storage_upgrade"]=Dict("record"=>"storage-reduction.toml","source_main_sha256"=>record["source_main_sha256"],"source_sessions_through"=>cutoff)
        db=SQLite.DB(joinpath(stage,"closure.sqlite"))
        _closure_exec(db,"BEGIN IMMEDIATE")
        _closure_exec(db,"UPDATE metadata SET value=? WHERE key='identity'",(_closure_text(current),))
        _closure_exec(db,"INSERT OR REPLACE INTO metadata VALUES('ledger_encoding','VBFCHN02')")
        _closure_exec(db,"INSERT OR REPLACE INTO metadata VALUES('storage_encoding','vbfsearch-normalized-v1')")
        _closure_exec(db,"INSERT OR REPLACE INTO metadata VALUES('storage_upgrade',?)",(_closure_text(record),))
        _closure_exec(db,"COMMIT");close(db);db=nothing
        DiscoveryStore.atomic_toml(joinpath(stage,"identity.toml"),current)
        DiscoveryStore.atomic_toml(joinpath(stage,"storage-reduction.toml"),record)
        validated=_closure_open(stage);_closure_close(validated)
        mv(stage,target)
        snapshot=closure_snapshot(target)
        DiscoveryStore.atomic_toml(joinpath(target,"progress.toml"),snapshot)
        snapshot
    finally
        db===nothing || close(db)
        close(lease)
    end
end
