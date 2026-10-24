"""Checkpoint-preserving execution upgrades with immutable implementation lineage.

The target inherits every mathematical record and cursor. Only explicitly listed
controller files and switching packet size may change; VBF mathematics, catalog,
toolchain and the original scientific search parameters remain pinned.
"""
const _CLOSURE_UPGRADE_PATHS=Set([
    "packages/VBFSearch/src/VBFSearch.jl","packages/VBFSearch/src/closure.jl",
    "packages/VBFSearch/src/closure_upgrade.jl","packages/VBFSearch/src/closure_store.jl",
    "packages/VBFSearch/src/closure_ledger.jl",
    "packages/VBFSearch/src/closure_ledger_v2.jl","packages/VBFSearch/src/closure_normalized.jl",
    "packages/VBFSearch/src/closure_normalized.sql","packages/VBFSearch/src/closure_reduce.jl",
    "packages/VBFSearch/src/closure_portable.jl","packages/VBFSearch/src/closure_segments.jl",
    "packages/VBFSearch/src/closure_algorithms.jl","packages/VBFSearch/src/closure_cluster.jl",
    "packages/VBFSearch/src/closure_equivalence.jl","packages/VBFSearch/src/cli.jl",
    "packages/VBFSearch/tools/closure_cluster.jl",
])

const _CLOSURE_PERFORMANCE_PATHS=union(_CLOSURE_UPGRADE_PATHS,Set([
    "packages/VBF/src/constructions/quadratic_extension_du7.jl",
    "packages/VBF/src/constructions/quadratic_extensions.jl",
    "packages/VBF/src/constructions/quadratic_v5_plan.jl",
    "packages/VBF/src/invariants/classification_keys.jl",
    "packages/VBF/src/spectra/linear.jl",
    "packages/VBF/src/spectra/differential.jl",
    "packages/VBF/src/spectra/walsh.jl",
    "packages/VBF/src/equivalence/partition_refinement/partition.jl",
    "packages/VBF/src/equivalence/partition_refinement/refine.jl",
    "packages/VBF/src/equivalence/partition_refinement/search.jl",
    "packages/VBF/src/equivalence/partition_refinement/automorphisms.jl",
    "packages/VBFSearch/src/closure_prepared_proof.jl",
    "packages/VBFSearch/src/closure_prepared_construction.jl",
    "packages/VBFSearch/src/closure_prepared_v5.jl",
    "packages/VBFSearch/src/closure_equivalence_snapshots.jl",
    "packages/VBFSearch/src/store.jl","packages/VBFSearch/src/evidence.jl",
    "packages/VBFSearch/src/reference/equivalence.jl",
]))

"""Bind an explicit performance transition to a completed fixed-work parity replay.

This records bounded computational evidence, not a proof that all future search
outputs agree. Catalogs, dependencies, unrelated mathematics and Julia remain
pinned. Ordinary controller upgrades retain their narrower source whitelist.
"""
function _closure_performance_evidence(path,identity,implementation,changed)
    all(in(_CLOSURE_PERFORMANCE_PATHS),changed) || error("performance upgrade changes unrelated mathematics, catalog or toolchain")
    proof=JSON3.read(read(path,String),Dict{String,Any})
    get(proof,"schema","")=="vbfsearch-cpu-performance-validation-v1" || error("unsupported performance validation schema")
    before=proof["before"];after=proof["after"]
    before["implementation"]==identity["implementation"] || error("performance baseline does not match source implementation")
    after["implementation"]==implementation || error("performance replay does not match current implementation")
    before["julia"]==after["julia"]==identity["julia"]==string(VERSION) || error("performance replay changes Julia version")
    before["fixture_sha256"]==after["fixture_sha256"] || error("performance replays used different fixtures")
    digest=before["fixture_sha256"]
    digest isa AbstractString && occursin(r"^[0-9a-f]{64}$",digest) || error("invalid performance fixture digest")
    for result in (before,after)
        result["result"]["state"]=="paused_window_limit" || error("performance replay did not finish its finite plan")
        result["result"]["processed_packets"]>0 || error("performance replay did no work")
        Set(keys(result["science"]))==Set(("paths","classes","kernels","coverage")) || error("performance replay lacks scientific digests")
        for value in values(result["science"])
            value["rows"]>0 && occursin(r"^[0-9a-f]{64}$",value["sha256"]) || error("invalid performance scientific digest")
        end
    end
    before["science"]==after["science"] || error("performance replay scientific outputs differ")
    Dict("sha256"=>DiscoveryEvidence.filehash(path),"fixture_sha256"=>digest,
        "scope"=>"completed bounded construction/EA replay with identical paths, classes, kernels and coverage",
        "science"=>before["science"])
end

"""Verify a stopped source against its own archived code and pinned inputs."""
function _closure_upgrade_source(db,directory;allow_execution_paths=false)
    if isfile(joinpath(directory,_CLOSURE_PATH_MAP)) && !allow_execution_paths
        error("this storage migration cannot preserve relocated execution paths; use closure_export_checkpoint for portable copies, or an explicitly supported migration")
    end
    identity=TOML.parse(only(_closure_rows(db,"SELECT value FROM metadata WHERE key='identity'"))["value"])
    identity==TOML.parsefile(joinpath(directory,"identity.toml")) || error("source identity manifest differs from database")
    identity["schema"]==CLOSURE_SCHEMA || error("unsupported source closure schema")
    identity["julia"]==string(VERSION) || error("upgrade cannot change Julia version")
    _closure_count(db,"SELECT COUNT(*) n FROM metadata WHERE key='initialization_complete' AND value='true'")==1 || error("source initialization is incomplete")
    _closure_count(db,"SELECT COUNT(*) n FROM sessions WHERE finished=''")==0 || error("source has an unfinished session; stop it with its archived implementation first")
    _closure_count(db,"SELECT COUNT(*) n FROM jobs WHERE status='running'")==0 || error("source contains running jobs")
    tables=[String(r["name"]) for r in _closure_rows(db,"SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")]
    if "cluster_work" in tables
        _closure_count(db,"SELECT COUNT(*) n FROM cluster_work WHERE status='running'")==0 || error("source contains running cluster work")
    end
    for (relative,digest) in identity["implementation"]
        archived=joinpath(directory,"replay","workspace",relative)
        isfile(archived) && DiscoveryEvidence.filehash(archived)==digest || error("source implementation archive changed: $relative")
    end
    _closure_validate_execution_inputs(directory,identity)
    _closure_validate_active_runtime_environment(directory,identity)
    for (index,(path,digest)) in enumerate(sort!(collect(identity["inputs"]);by=first))
        archived=joinpath(directory,"replay","inputs",string(index)*"-"*basename(path))
        isfile(archived) && DiscoveryEvidence.filehash(archived)==digest || error("source input archive changed: $path")
    end
    identity,tables
end

"""Carry verified execution pins across an explicit implementation upgrade."""
function _closure_upgrade_execution_paths!(origin,stage,previous,identity,current,record)
    map=_closure_execution_map(origin,identity)
    map===nothing && return
    source_map=joinpath(origin,_CLOSURE_PATH_MAP)
    cp(source_map,joinpath(previous,_CLOSURE_PATH_MAP))
    cp(source_map,joinpath(stage,_CLOSURE_PATH_MAP))
    for (source,target) in ((joinpath(origin,"relocation-lineage"),joinpath(previous,"relocation-lineage")),
            (joinpath(origin,"relocation-lineage"),joinpath(stage,"relocation-lineage")),
            (joinpath(origin,"execution"),joinpath(stage,"execution")))
        isdir(source) && _closure_portable_copy(source,target)
    end
    environment=get(map,"active_environment",nothing)
    if environment!==nothing
        _closure_verify_active_environment(origin,environment)
        for key in ("project","manifest")
            entry=environment[key]
            source=_closure_portable_file(origin,entry["path"])
            destination=_closure_portable_file(stage,entry["path"])
            if isfile(destination)
                _closure_portable_hash(destination,entry["sha256"],"upgraded active environment")
            else
                _closure_portable_copy(source,destination)
            end
        end
    end
    _closure_write_execution_map(stage,current;active_environment=environment,origin="verified execution upgrade from "*origin)
    record["source_execution_paths_sha256"]=DiscoveryEvidence.filehash(source_map)
    record["execution_paths_sha256"]=DiscoveryEvidence.filehash(joinpath(stage,_CLOSURE_PATH_MAP))
    environment===nothing || (record["active_environment"]=environment)
    haskey(map,"runtime_build") && (record["runtime_build"]=map["runtime_build"])
end

"""Check that compression adds one dependency edge without changing pinned versions."""
function _closure_storage_environment(origin)
    root=DiscoveryInputs.ROOT;archive=joinpath(origin,"replay","workspace")
    relative="packages/VBFSearch/Project.toml"
    before=TOML.parsefile(joinpath(archive,relative));after=TOML.parsefile(joinpath(root,relative))
    pop!(after["deps"],"CodecZstd",nothing)=="6b39b394-51ab-5f42-8807-6242bab2b4c2" || error("unexpected compression dependency")
    pop!(after["compat"],"CodecZstd",nothing)=="0.8" || error("unexpected compression compatibility")
    before==after || error("storage migration changes other package requirements")
    before=TOML.parsefile(joinpath(archive,"Manifest.toml"));after=TOML.parsefile(joinpath(root,"Manifest.toml"))
    deps=only(after["deps"]["VBFSearch"])["deps"]
    count(==("CodecZstd"),deps)==1 || error("missing compression dependency edge")
    filter!(!=("CodecZstd"),deps)
    before==after || error("storage migration changes pinned dependency versions")
    true
end

"""Hash large storage artifacts with accelerated SHA-256 when OpenSSL is available."""
function _closure_storage_filehash(path)
    executable=Sys.which("openssl")
    executable===nothing && return DiscoveryEvidence.filehash(path)
    digest=first(split(read(Cmd([executable,"dgst","-sha256","-r",abspath(path)]),String)))
    occursin(r"^[0-9a-f]{64}$",digest) || error("invalid SHA-256 output")
    digest
end

"""
    closure_compact(source; output, helper, prepared=nothing)

Stream a cooperatively stopped legacy ledger into lossless Zstandard blocks.
`helper` is built from tools/compact_closure_ledger.cpp. It independently hashes
both copies of every other table and re-decodes every stored coverage block.
The original directory remains the rollback checkpoint; immutable lineage records
pin its exact database and identity, without making another uncompressed copy.
No scientific parameters, mathematical code, candidate IDs or cursors change.
`prepared` may retain a completed helper result, pinned by prepared-proof.toml,
so interrupted finalization need not repeat the bulk conversion.
"""
function closure_compact(source;output,helper,prepared=nothing)
    origin=realpath(source);target=abspath(output)
    ispath(target) && error("compact output must not exist")
    startswith(target,origin*string(Base.Filesystem.path_separator)) && error("compact output cannot be inside source")
    lease=_closure_lease(origin);db=nothing;stage=nothing
    try
        db=SQLite.DB("file:"*joinpath(origin,"closure.sqlite")*"?mode=ro")
        _closure_reject_segmented_clone(db)
        identity,tables=_closure_upgrade_source(db,origin)
        _closure_storage_environment(origin)
        for suffix in ("-wal","-journal")
            path=joinpath(origin,"closure.sqlite"*suffix)
            (!isfile(path) || filesize(path)==0) || error("source needs a fully checkpointed database before compaction")
        end
        implementation=implementation_fingerprint()
        changed=sort!([path for path in union(keys(identity["implementation"]),keys(implementation)) if get(identity["implementation"],path,nothing)!=get(implementation,path,nothing)])
        allowed=union(_CLOSURE_UPGRADE_PATHS,Set(["Manifest.toml","packages/VBFSearch/Project.toml"]))
        all(path->path in allowed,changed) || error("storage migration changes mathematics or unrelated code")
        cutoff=_closure_count(db,"SELECT COALESCE(MAX(id),0) n FROM sessions")
        close(db);db=nothing
        mkpath(dirname(target))
        if prepared===nothing
            stage=mktempdir(dirname(target);prefix=".closure-compact-")
        else
            recovery=realpath(prepared)
            dirname(recovery)==dirname(target) && startswith(basename(recovery),".closure-compact-") || error("invalid prepared checkpoint location")
            proof=TOML.parsefile(joinpath(recovery,"prepared-proof.toml"))
            proof["source_directory"]==origin && proof["source_identity_sha256"]==DiscoveryEvidence.filehash(joinpath(origin,"identity.toml")) || error("prepared checkpoint has a different source")
            proof["database_sha256"]==_closure_storage_filehash(joinpath(recovery,"closure.sqlite")) &&
                proof["migration_log_sha256"]==DiscoveryEvidence.filehash(joinpath(recovery,"migration.jsonl")) || error("prepared checkpoint changed")
            check=SQLite.DB("file:"*joinpath(recovery,"closure.sqlite")*"?mode=ro")
            try
                TOML.parse(only(_closure_rows(check,"SELECT value FROM metadata WHERE key='identity'"))["value"])==identity || error("prepared checkpoint source identity differs")
            finally
                close(check)
            end
            stage=recovery
        end
        log=joinpath(stage,"migration.jsonl")
        println("Compacting ledger into ",stage);flush(stdout)
        if prepared===nothing
            open(log,"w") do io
                run(pipeline(Cmd([abspath(helper),joinpath(origin,"closure.sqlite"),joinpath(stage,"closure.sqlite")]);stdout=io))
            end
        end
        events=[JSON3.read(line,Dict{String,Any}) for line in eachline(log)]
        last(events)["event"]=="complete" || error("incomplete storage migration")
        record=Dict{String,Any}("schema"=>"vbfsearch-closure-storage-upgrade-v1","created_utc"=>_closure_now(),
            "source_directory"=>origin,"source_main_sha256"=>_closure_storage_filehash(joinpath(origin,"closure.sqlite")),
            "source_identity_sha256"=>DiscoveryEvidence.filehash(joinpath(origin,"identity.toml")),
            "source_sessions_through"=>cutoff,"prior_implementation"=>identity["implementation"],"new_implementation"=>implementation,
            "changed_implementation_paths"=>changed,"helper_sha256"=>DiscoveryEvidence.filehash(helper),
            "helper_source_sha256"=>DiscoveryEvidence.filehash(joinpath(DiscoveryInputs.ROOT,"packages/VBFSearch/tools/compact_closure_ledger.cpp")),
            "migration_log_sha256"=>DiscoveryEvidence.filehash(log),"coverage"=>last(events),
            "table_digests"=>filter(e->e["event"]=="table_verified",events),
            "scientific_scope"=>"unchanged; byte-exact per-coset evidence stored in lossless blocks",
            "rollback"=>"source_directory; restore closure.sqlite.archive.json first if archived")
        previous=joinpath(stage,"lineage","previous");mkpath(previous)
        cp(joinpath(origin,"identity.toml"),joinpath(previous,"identity.toml"))
        DiscoveryStore.atomic_toml(joinpath(previous,"external-checkpoint.toml"),record)
        mkpath(joinpath(stage,"replay"));cp(joinpath(origin,"replay","inputs"),joinpath(stage,"replay","inputs"))
        for (relative,digest) in implementation
            archived=joinpath(stage,"replay","workspace",relative);mkpath(dirname(archived))
            cp(joinpath(DiscoveryInputs.ROOT,relative),archived)
            DiscoveryEvidence.filehash(archived)==digest || error("source changed during migration archival")
        end
        current=deepcopy(identity);current["implementation"]=implementation
        current["storage_upgrade"]=Dict("record"=>"storage-upgrade.toml","source_main_sha256"=>record["source_main_sha256"],"source_sessions_through"=>cutoff)
        copydb=SQLite.DB(joinpath(stage,"closure.sqlite"))
        try
            _closure_exec(copydb,"BEGIN IMMEDIATE")
            _closure_exec(copydb,"UPDATE metadata SET value=? WHERE key='identity'",(_closure_text(current),))
            _closure_exec(copydb,"INSERT OR REPLACE INTO metadata VALUES('ledger_encoding','VBFCHN01')")
            _closure_exec(copydb,"INSERT OR REPLACE INTO metadata VALUES('storage_upgrade',?)",(_closure_text(record),))
            _closure_exec(copydb,"COMMIT")
        finally
            close(copydb)
        end
        DiscoveryStore.atomic_toml(joinpath(stage,"identity.toml"),current)
        DiscoveryStore.atomic_toml(joinpath(stage,"storage-upgrade.toml"),record)
        println("Validating compact checkpoint cursors");flush(stdout)
        validated=_closure_open(stage);_closure_close(validated)
        mv(stage,target);stage=nothing
        summary=closure_snapshot(target);DiscoveryStore.atomic_toml(joinpath(target,"progress.toml"),summary)
        summary
    finally
        db===nothing || close(db)
        close(lease)
        (stage===nothing || prepared!==nothing) || rm(stage;recursive=true,force=true)
    end
end

"""
    closure_upgrade(source; output, switching_directions=32, performance_evidence=nothing)

Clone a cooperatively stopped frontier under the source's exclusive application
lease. SQLite's backup API includes committed WAL pages without rewriting the
source. The target retains a runnable source snapshot, its complete replay tree,
the prior identity, session cutoff and snapshot digest under `lineage/previous/`.
All pre-existing rows and IDs survive; only identity metadata and the execution
batch policy change. The new directory appears only after integrity and cursor
validation. The source remains available for rollback.

`performance_evidence` explicitly permits the listed CPU implementation changes
only when before/after replay manifests bind both implementations and agree on
every scientific digest. The evidence is copied into the upgrade lineage.
"""
function closure_upgrade(source;output,switching_directions=32,performance_evidence=nothing)
    switching_directions isa Integer && 1<=switching_directions<=255 || throw(ArgumentError("switching_directions must be in 1:255"))
    origin=realpath(source);target=abspath(output)
    isfile(joinpath(origin,"closure.sqlite")) || error("source closure database is absent")
    ispath(target) && error("upgrade output must not exist")
    startswith(target,origin*string(Base.Filesystem.path_separator)) && error("upgrade output cannot be inside source")
    mkpath(dirname(target));lease=_closure_lease(origin);db=nothing;stage=nothing
    try
        db=SQLite.DB("file:"*joinpath(origin,"closure.sqlite")*"?mode=ro")
        performance_evidence===nothing && _closure_reject_segmented_clone(db)
        _closure_exec(db,"PRAGMA query_only=ON")
        identity,tables=_closure_upgrade_source(db,origin;allow_execution_paths=true)
        implementation=implementation_fingerprint()
        changed=sort!([path for path in union(keys(identity["implementation"]),keys(implementation)) if get(identity["implementation"],path,nothing)!=get(implementation,path,nothing)])
        validation=performance_evidence===nothing ? nothing :
            _closure_performance_evidence(abspath(performance_evidence),identity,implementation,changed)
        validation===nothing && !all(path->path in _CLOSURE_UPGRADE_PATHS,changed) &&
            error("upgrade changes mathematics, catalog or toolchain outside controller whitelist; an explicit validated CPU transition requires performance_evidence")
        artifacts=validation===nothing ? Dict{String,String}() : closure_segment_artifacts(db,origin)
        isempty(artifacts) || closure_verify_segments(db,origin;full=true)
        cutoff=_closure_count(db,"SELECT COALESCE(MAX(id),0) n FROM sessions")
        counts=Dict(table=>_closure_count(db,"SELECT COUNT(*) n FROM \"$table\"") for table in tables)
        stage=mktempdir(dirname(target);prefix=".closure-upgrade-")
        previous=joinpath(stage,"lineage","previous");mkpath(previous)
        snapshot=joinpath(previous,"closure.sqlite")
        SQLite.backup(db,snapshot)
        if !isempty(artifacts)
            for (relative,path) in artifacts
                _closure_portable_copy(path,joinpath(previous,relative))
                _closure_portable_copy(path,joinpath(stage,relative))
            end
            backup=SQLite.DB(snapshot)
            try
                _closure_exec(backup,"INSERT OR REPLACE INTO metadata(key,value) VALUES('closure_segment_root','cold')")
            finally
                close(backup)
            end
        end
        record=Dict{String,Any}("schema"=>"vbfsearch-closure-upgrade-v1","created_utc"=>_closure_now(),
            "source_directory"=>origin,"source_main_sha256"=>DiscoveryEvidence.filehash(joinpath(origin,"closure.sqlite")),
            "source_snapshot_sha256"=>DiscoveryEvidence.filehash(snapshot),"source_identity_sha256"=>DiscoveryEvidence.filehash(joinpath(origin,"identity.toml")),
            "source_sessions_through"=>cutoff,"source_table_counts"=>counts,
            "prior_implementation"=>identity["implementation"],"new_implementation"=>implementation,
            "changed_implementation_paths"=>changed,"prior_switching_directions"=>get(identity["scientific"],"switching_directions",1),
            "switching_directions"=>Int(switching_directions),
            "scientific_scope"=>"unchanged; switching packet size is an execution policy",
            "session_attribution"=>"sessions through source_sessions_through use prior_implementation; subsequent sessions use new_implementation")
        if validation!==nothing
            record["performance_validation"]=validation
            record["cold_artifacts_copied"]=length(artifacts)
            cp(abspath(performance_evidence),joinpath(stage,"performance-validation.json"))
        end
        wal=joinpath(origin,"closure.sqlite-wal")
        isfile(wal) && (record["source_wal_sha256"]=DiscoveryEvidence.filehash(wal))
        cp(joinpath(origin,"identity.toml"),joinpath(previous,"identity.toml"))
        cp(joinpath(origin,"replay"),joinpath(previous,"replay"))
        if isdir(joinpath(origin,"lineage"))
            cp(joinpath(origin,"lineage"),joinpath(previous,"lineage"))
        end
        for name in ("progress.toml","execution-config.toml","deployment-checksums.json","upgrade.toml")
            isfile(joinpath(origin,name)) && cp(joinpath(origin,name),joinpath(previous,name))
        end
        cp(snapshot,joinpath(stage,"closure.sqlite"))
        mkpath(joinpath(stage,"replay"))
        cp(joinpath(origin,"replay","inputs"),joinpath(stage,"replay","inputs");force=true)
        current=deepcopy(identity);current["implementation"]=implementation
        current["scientific"]["switching_directions"]=Int(switching_directions)
        current["execution_upgrade"]=Dict("record"=>"upgrade.toml","source_snapshot_sha256"=>record["source_snapshot_sha256"],"source_sessions_through"=>cutoff)
        for (relative,digest) in implementation
            archived=joinpath(stage,"replay","workspace",relative)
            mkpath(dirname(archived));cp(joinpath(DiscoveryInputs.ROOT,relative),archived)
            DiscoveryEvidence.filehash(archived)==digest || error("implementation changed during upgrade archival")
        end
        DiscoveryStore.atomic_toml(joinpath(stage,"identity.toml"),current)
        _closure_upgrade_execution_paths!(origin,stage,previous,identity,current,record)
        copydb=SQLite.DB(joinpath(stage,"closure.sqlite"))
        try
            all(table->_closure_count(copydb,"SELECT COUNT(*) n FROM \"$table\"")==counts[table],tables) || error("SQLite backup lost source rows")
            String(first(values(only(_closure_rows(copydb,"PRAGMA integrity_check")))))=="ok" || error("upgraded SQLite integrity check failed")
            isempty(_closure_rows(copydb,"PRAGMA foreign_key_check")) || error("upgraded frontier violates foreign keys")
            _closure_exec(copydb,"UPDATE metadata SET value=? WHERE key='identity'",(_closure_text(current),))
            _closure_exec(copydb,"INSERT OR REPLACE INTO metadata VALUES('execution_upgrade',?)",(_closure_text(record),))
            _closure_exec(copydb,"PRAGMA wal_checkpoint(TRUNCATE)")
        finally
            close(copydb)
        end
        DiscoveryStore.atomic_toml(joinpath(stage,"upgrade.toml"),record)
        validated=_closure_open(stage)
        _closure_close(validated)
        mv(stage,target);stage=nothing
        summary=closure_snapshot(target)
        DiscoveryStore.atomic_toml(joinpath(target,"progress.toml"),summary)
        summary
    finally
        db===nothing || close(db)
        close(lease)
        stage===nothing || rm(stage;recursive=true,force=true)
    end
end
