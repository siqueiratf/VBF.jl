"""Verified execution paths and transport snapshots; scientific identity is immutable."""
const _CLOSURE_PATH_MAP = "execution-paths.toml"
const _CLOSURE_BUNDLE_MANIFEST = "checkpoint-manifest.toml"
_closure_portable_digest(path)=isdefined(@__MODULE__,:_closure_storage_filehash) ? _closure_storage_filehash(path) : DiscoveryEvidence.filehash(path)

function _closure_portable_runtime_build()
    executable=joinpath(Sys.BINDIR,Sys.iswindows() ? "julia.exe" : "julia")
    Dict("commit"=>string(Base.GIT_VERSION_INFO.commit),"executable_sha256"=>_closure_portable_digest(executable))
end

function _closure_portable_relative(path)
    p=String(path)
    !isempty(p) && !isabspath(p) && normpath(p)==p && !(p in (".","..")) &&
        !startswith(p,".."*string(Base.Filesystem.path_separator)) || error("unsafe checkpoint path: $p")
    p
end

function _closure_portable_file(directory,relative)
    relative=_closure_portable_relative(relative)
    path=joinpath(directory,relative)
    # A bundle never dereferences symlinks, including symlinked ancestors.
    cursor=directory
    for part in splitpath(relative)
        cursor=joinpath(cursor,part)
        islink(cursor) && error("checkpoint symlink is not permitted: $relative")
    end
    path
end

function _closure_portable_hash(path,digest,label)
    isfile(path) && !islink(path) && _closure_portable_digest(path)==digest || error("$label changed or missing: $path")
    path
end

function _closure_portable_sync(path;directory=false)
    if directory
        descriptor=ccall(:open,Cint,(Cstring,Cint),path,0)
        descriptor>=0 || error("cannot open checkpoint directory for sync")
        try
            ccall(:fsync,Cint,(Cint,),descriptor)==0 || error("cannot sync checkpoint directory")
        finally
            ccall(:close,Cint,(Cint,),descriptor)
        end
    else
        open(path,"r") do io
            ccall(:fsync,Cint,(Cint,),fd(io))==0 || error("cannot sync checkpoint file: $path")
        end
    end
    nothing
end

function _closure_portable_toml(path,value)
    mkpath(dirname(path));temporary,io=mktemp(dirname(path))
    try
        TOML.print(io,value);flush(io)
        ccall(:fsync,Cint,(Cint,),fd(io))==0 || error("cannot sync checkpoint metadata")
        close(io);mv(temporary,path;force=true);_closure_portable_sync(dirname(path);directory=true)
    finally
        isopen(io) && close(io)
        isfile(temporary) && rm(temporary)
    end
end

function _closure_portable_identity(db,directory;require_runtime=true)
    identity=TOML.parse(only(_closure_rows(db,"SELECT value FROM metadata WHERE key='identity'"))["value"])
    identity==TOML.parsefile(joinpath(directory,"identity.toml")) || error("checkpoint identity differs from database")
    identity["schema"]==CLOSURE_SCHEMA || error("unsupported checkpoint schema")
    !require_runtime || identity["julia"]==string(VERSION) || error("closure Julia version changed")
    _closure_count(db,"SELECT COUNT(*) n FROM metadata WHERE key='initialization_complete' AND value='true'")==1 || error("checkpoint initialization incomplete")
    for (relative,digest) in identity["implementation"]
        path=_closure_portable_file(directory,joinpath("replay","workspace",relative))
        _closure_portable_hash(path,digest,"archived implementation")
    end
    for (i,(logical,digest)) in enumerate(sort!(collect(identity["inputs"]);by=first))
        _closure_portable_hash(joinpath(directory,"replay","inputs",string(i)*"-"*basename(logical)),digest,"archived input")
    end
    identity
end

function _closure_execution_map(directory,identity)
    path=joinpath(directory,_CLOSURE_PATH_MAP)
    isfile(path) || return nothing
    data=TOML.parsefile(path)
    data["schema"]=="vbfsearch-execution-paths-v1" || error("unsupported execution path map")
    data["identity_sha256"]==DiscoveryEvidence.filehash(joinpath(directory,"identity.toml")) || error("execution path map belongs to another identity")
    entries=data["inputs"]
    Set(keys(entries))==Set(keys(identity["inputs"])) || error("execution path map has incomplete or unexpected inputs")
    for (logical,digest) in identity["inputs"]
        entry=entries[logical]
        entry["sha256"]==digest || error("execution input digest differs from scientific identity")
    end
    if haskey(data,"active_environment")
        _closure_verify_active_environment(directory,data["active_environment"])
    end
    data
end

function _closure_verify_active_environment(directory,environment)
    for key in ("project","manifest")
        entry=environment[key]
        path=_closure_portable_file(directory,entry["path"])
        _closure_portable_hash(path,entry["sha256"],"active environment")
    end
    true
end

function _closure_validate_active_runtime_environment(directory,identity)
    map=_closure_execution_map(directory,identity)
    map===nothing && return true
    !haskey(map,"runtime_build") || map["runtime_build"]==_closure_portable_runtime_build() || error("closure Julia runtime build changed")
    !haskey(map,"active_environment") && return true
    project=Base.active_project()
    project===nothing && error("a pinned active project is required")
    environment=map["active_environment"]
    _closure_portable_hash(project,environment["project"]["sha256"],"loaded active Project.toml")
    _closure_portable_hash(joinpath(dirname(project),"Manifest.toml"),environment["manifest"]["sha256"],"loaded active Manifest.toml")
    true
end

"""Resolve staged execution locations without changing any logical input identity."""
function _closure_validate_execution_inputs(directory,identity)
    map=_closure_execution_map(directory,identity)
    for (logical,digest) in identity["inputs"]
        location=map===nothing ? logical : map["inputs"][logical]["path"]
        path=isabspath(location) ? location : _closure_portable_file(directory,location)
        _closure_portable_hash(path,digest,"closure input")
    end
    true
end

function _closure_portable_environment(directory,active_project)
    workspace=joinpath(directory,"replay","workspace")
    project=if active_project===nothing
        active=Base.active_project()
        active===nothing && error("specify the archived active project explicitly")
        candidate=joinpath(workspace,relpath(active,DiscoveryInputs.ROOT))
        isfile(candidate) || error("active environment is not archived; specify active_project inside replay/workspace")
        candidate
    else
        abspath(active_project)
    end
    isdir(project) && (project=joinpath(project,"Project.toml"))
    # Active environments must travel with the frozen replay workspace.
    _closure_portable_relative(relpath(project,workspace))
    relative=relpath(project,directory);_closure_portable_relative(relative)
    manifest=joinpath(dirname(project),"Manifest.toml")
    Dict(key=>Dict("path"=>relpath(path,directory),"sha256"=>DiscoveryEvidence.filehash(_closure_portable_file(directory,relpath(path,directory))))
        for (key,path) in (("project",project),("manifest",manifest)))
end

function _closure_write_execution_map(directory,identity;paths=Dict(),use_archived_inputs=true,active_environment=nothing,origin="explicit relocation")
    all(k->haskey(identity["inputs"],k),keys(paths)) || error("unknown logical input in execution path map")
    entries=Dict{String,Any}()
    for (i,(logical,digest)) in enumerate(sort!(collect(identity["inputs"]);by=first))
        path=haskey(paths,logical) ? abspath(paths[logical]) : use_archived_inputs ? joinpath(directory,"replay","inputs",string(i)*"-"*basename(logical)) : logical
        _closure_portable_hash(path,digest,"relocated input")
        relative=relpath(path,directory)
        location=startswith(relative,".."*string(Base.Filesystem.path_separator)) || relative==".." ? path : relative
        entries[logical]=Dict("path"=>location,"sha256"=>digest)
    end
    mapfile=joinpath(directory,_CLOSURE_PATH_MAP)
    previous=isfile(mapfile) ? DiscoveryEvidence.filehash(mapfile) : "none"
    if previous!="none"
        pinned=TOML.parsefile(mapfile)
        !haskey(pinned,"runtime_build") || pinned["runtime_build"]==_closure_portable_runtime_build() || error("relocation cannot change the pinned Julia runtime build")
    end
    data=Dict{String,Any}("schema"=>"vbfsearch-execution-paths-v1","identity_sha256"=>DiscoveryEvidence.filehash(joinpath(directory,"identity.toml")),
        "created_utc"=>_closure_now(),"origin"=>origin,"previous_map_sha256"=>previous,"runtime_build"=>_closure_portable_runtime_build(),"inputs"=>entries)
    active_environment===nothing || (data["active_environment"]=active_environment)
    lineage=joinpath(directory,"relocation-lineage");mkpath(lineage)
    previous!="none" && !isfile(joinpath(lineage,previous*".toml")) && cp(mapfile,joinpath(lineage,previous*".toml"))
    _closure_portable_toml(mapfile,data)
    receipt=DiscoveryEvidence.filehash(mapfile)
    cp(mapfile,joinpath(lineage,receipt*".toml");force=true)
    _closure_portable_sync(joinpath(lineage,receipt*".toml"));_closure_portable_sync(lineage;directory=true)
    data
end

"""
    closure_relocate!(directory; paths=Dict(), use_archived_inputs=true, active_project=nothing)

Bind logical inputs to digest-checked execution files under an exclusive lease.
By default use the archived inputs, so the original directories may be unavailable.
The database, scientific identity and archived source identity are unchanged.
This operation does not authorize loading different source code or Julia versions.
"""
function closure_relocate!(directory;paths=Dict(),use_archived_inputs=true,active_project=nothing)
    dir=realpath(directory);lease=_closure_lease(dir);db=nothing
    try
        db=SQLite.DB("file:"*joinpath(dir,"closure.sqlite")*"?mode=ro")
        identity=_closure_portable_identity(db,dir)
        previous=_closure_execution_map(dir,identity)
        pinned=previous===nothing ? nothing : get(previous,"active_environment",nothing)
        environment=active_project===nothing ? pinned : _closure_portable_environment(dir,active_project)
        if pinned!==nothing && environment!==nothing
            all(k->pinned[k]["sha256"]==environment[k]["sha256"],("project","manifest")) || error("relocation cannot change the pinned active environment")
        end
        result=_closure_write_execution_map(dir,identity;paths,use_archived_inputs,active_environment=environment)
        _closure_validate_execution_inputs(dir,identity);result
    finally
        db===nothing || close(db);close(lease)
    end
end

function _closure_portable_copy(source,target)
    islink(source) && error("checkpoint exports do not follow symlinks: $source")
    if isdir(source)
        mkpath(target)
        for name in sort!(readdir(source))
            _closure_portable_copy(joinpath(source,name),joinpath(target,name))
        end
    else
        isfile(source) || error("unsupported checkpoint file: $source")
        mkpath(dirname(target));cp(source,target);_closure_portable_sync(target)
    end
end

function _closure_portable_files(directory)
    files=Dict{String,Any}()
    for (root,dirs,names) in walkdir(directory;follow_symlinks=false)
        any(name->islink(joinpath(root,name)),vcat(dirs,names)) && error("checkpoint contains a symlink")
        for name in names
            relative=relpath(joinpath(root,name),directory)
            relative in (_CLOSURE_BUNDLE_MANIFEST,"closure.lock") && continue
            endswith(relative,"closure.sqlite-wal") && error("checkpoint bundle contains WAL")
            endswith(relative,"closure.sqlite-shm") && error("checkpoint bundle contains SHM")
            path=joinpath(root,name)
            isfile(path) || error("unsupported checkpoint file: $relative")
            files[relative]=Dict("sha256"=>_closure_portable_digest(path),"bytes"=>filesize(path))
        end
    end
    files
end

"""
    closure_verify_checkpoint(directory; require_runtime=true)

Verify a sealed checkpoint's file manifest, SQLite integrity, immutable identity,
archived sources/inputs and active environment. This never dispatches search or
accepts a changed loaded implementation; ordinary resume still checks that itself.
"""
function closure_verify_checkpoint(directory;require_runtime=true)
    dir=realpath(directory);manifest=TOML.parsefile(joinpath(dir,_CLOSURE_BUNDLE_MANIFEST))
    manifest["schema"]=="vbfsearch-checkpoint-bundle-v1" || error("unsupported checkpoint bundle")
    actual=_closure_portable_files(dir)
    actual==manifest["files"] || error("checkpoint file manifest mismatch")
    _closure_verify_active_environment(dir,manifest["active_environment"])
    !require_runtime || manifest["runtime_build"]==_closure_portable_runtime_build() || error("checkpoint Julia runtime build differs")
    db=SQLite.DB("file:"*joinpath(dir,"closure.sqlite")*"?mode=ro")
    try
        identity=_closure_portable_identity(db,dir;require_runtime)
        manifest["identity_sha256"]==DiscoveryEvidence.filehash(joinpath(dir,"identity.toml")) || error("bundle identity digest mismatch")
        manifest["julia"]==identity["julia"] || error("bundle runtime differs from identity")
        _closure_validate_execution_inputs(dir,identity)
        all(row->first(values(row))=="ok",_closure_rows(db,"PRAGMA quick_check")) || error("checkpoint integrity check failed")
        isempty(_closure_rows(db,"PRAGMA foreign_key_check")) || error("checkpoint foreign keys failed")
        _closure_validate_cursors((;db))
        isdefined(@__MODULE__,:closure_verify_segments) && closure_verify_segments(db,dir;full=true)
        Dict("verified"=>true,"identity_sha256"=>manifest["identity_sha256"],"files"=>length(actual),"julia"=>identity["julia"])
    finally
        close(db)
    end
end

function _closure_portable_tree_bytes(path)
    islink(path) && error("checkpoint exports do not follow symlinks")
    isfile(path) && return Int128(filesize(path))
    isdir(path) || error("checkpoint export input missing: $path")
    sum((_closure_portable_tree_bytes(joinpath(path,name)) for name in readdir(path));init=Int128(0))
end

function _closure_export_checkpoint(db,directory;output,active_project=nothing,extra_paths=String[],reserve_bytes=8*1024^3)
    SQLite.intransaction(db) && error("export requires a coordinator transaction boundary")
    reserve_bytes>=0 || error("checkpoint reserve must be nonnegative")
    origin=realpath(directory);target=abspath(output)
    ispath(target) && error("checkpoint output already exists")
    mkpath(dirname(target));target=joinpath(realpath(dirname(target)),basename(target))
    startswith(target,origin*string(Base.Filesystem.path_separator)) && error("checkpoint export cannot be inside its source")
    identity=_closure_portable_identity(db,origin)
    _closure_validate_execution_inputs(origin,identity)
    existing_map=_closure_execution_map(origin,identity)
    pinned=existing_map===nothing ? nothing : get(existing_map,"active_environment",nothing)
    environment=active_project===nothing && pinned!==nothing ? pinned : _closure_portable_environment(origin,active_project)
    if pinned!==nothing
        all(k->pinned[k]["sha256"]==environment[k]["sha256"],("project","manifest")) || error("export cannot change the pinned active environment")
    end
    artifacts=isdefined(@__MODULE__,:closure_segment_artifacts) ? closure_segment_artifacts(db,origin) : Dict{String,String}()
    extra_paths=String[_closure_portable_relative(p) for p in extra_paths]
    estimate=_closure_portable_tree_bytes(joinpath(origin,"closure.sqlite"))+_closure_portable_tree_bytes(joinpath(origin,"replay"))
    wal=joinpath(origin,"closure.sqlite-wal");isfile(wal) && (estimate+=filesize(wal))
    for relative in ("identity.toml","progress.toml","relocation-lineage","execution")
        path=joinpath(origin,relative);ispath(path) && (estimate+=_closure_portable_tree_bytes(path))
    end
    estimate+=sum((_closure_portable_tree_bytes(path) for path in values(artifacts));init=Int128(0))
    estimate+=sum((_closure_portable_tree_bytes(_closure_portable_file(origin,p)) for p in extra_paths);init=Int128(0))
    # Page reshuffling, manifests and staging bookkeeping need additional room.
    estimate=cld(11estimate,10)+1024^2
    available=Int128(Base.Filesystem.diskstat(dirname(target)).available)
    available>=estimate+reserve_bytes || error("checkpoint export needs $(estimate+reserve_bytes) available bytes including reserve; $available available")
    stage=mktempdir(dirname(target);prefix=basename(target)*".staging-",cleanup=false)
    try
        SQLite.backup(db,joinpath(stage,"closure.sqlite"))
        for (relative,path) in artifacts
            _closure_portable_copy(path,_closure_portable_file(stage,relative))
        end
        snapshot=SQLite.DB(joinpath(stage,"closure.sqlite"))
        try
            if isdefined(@__MODULE__,:closure_segment_artifacts)
                _closure_exec(snapshot,"INSERT OR REPLACE INTO metadata(key,value) VALUES('closure_segment_root','cold')")
            end
            _closure_exec(snapshot,"PRAGMA journal_mode=DELETE")
        finally
            close(snapshot)
        end
        _closure_portable_sync(joinpath(stage,"closure.sqlite"))
        for relative in ("identity.toml","replay")
            _closure_portable_copy(_closure_portable_file(origin,relative),joinpath(stage,relative))
        end
        for relative in ("progress.toml","relocation-lineage",_CLOSURE_PATH_MAP,"execution")
            source=_closure_portable_file(origin,relative)
            ispath(source) && _closure_portable_copy(source,joinpath(stage,relative))
        end
        for relative in extra_paths
            relative=_closure_portable_relative(relative)
            relative in ("closure.sqlite",_CLOSURE_BUNDLE_MANIFEST,_CLOSURE_PATH_MAP) && error("reserved checkpoint export path")
            _closure_portable_copy(_closure_portable_file(origin,relative),joinpath(stage,relative))
        end
        _closure_write_execution_map(stage,identity;active_environment=environment,origin="verified SQLite backup from "*origin)
        manifest=Dict{String,Any}("schema"=>"vbfsearch-checkpoint-bundle-v1","created_utc"=>_closure_now(),"source_directory"=>origin,
            "identity_sha256"=>DiscoveryEvidence.filehash(joinpath(stage,"identity.toml")),"julia"=>identity["julia"],
            "runtime_machine"=>Sys.MACHINE,"runtime_kernel"=>string(Sys.KERNEL),"runtime_build"=>_closure_portable_runtime_build(),"active_environment"=>environment,
            "estimated_staging_bytes"=>Int(estimate),"reserve_bytes"=>Int(reserve_bytes),
            "files"=>_closure_portable_files(stage))
        _closure_portable_toml(joinpath(stage,_CLOSURE_BUNDLE_MANIFEST),manifest)
        closure_verify_checkpoint(stage)
        for (root,_,_) in walkdir(stage;topdown=false)
            _closure_portable_sync(root;directory=true)
        end
        ispath(target) && error("checkpoint output appeared during export")
        mv(stage,target);_closure_portable_sync(dirname(target);directory=true)
        Dict("directory"=>target,"manifest_sha256"=>DiscoveryEvidence.filehash(joinpath(target,_CLOSURE_BUNDLE_MANIFEST)),"verified"=>true)
    catch
        # An incomplete generation is never published; leave it recognizable for
        # inspection instead of deleting the only evidence of an I/O failure.
        rethrow()
    end
end

"""Publish an owning coordinator's verified SQLite snapshot outside a transaction."""
closure_export_checkpoint(s::ClosureStore;kwargs...)=_closure_export_checkpoint(s.db,s.directory;kwargs...)

"""Export under an exclusive application lease, including committed WAL pages."""
function closure_export_checkpoint(directory;kwargs...)
    dir=realpath(directory);lease=_closure_lease(dir);db=nothing
    try
        db=SQLite.DB("file:"*joinpath(dir,"closure.sqlite")*"?mode=ro")
        _closure_export_checkpoint(db,dir;kwargs...)
    finally
        db===nothing || close(db);close(lease)
    end
end
