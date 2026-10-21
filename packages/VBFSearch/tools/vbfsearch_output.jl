"""Publish a stopped one-command search as one SQLite file without a database copy.

Scientific tables stay in place. Configuration, reports and frozen provenance
files become SHA-256 checked BLOBs. Publication links the closed database into
its final name on the same filesystem; only then is the owned workspace removed.
"""
module VBFSearchOutput
using VBFSearch,SHA,TOML,Dates
const FP=VBFSearch
const SQLite=FP.SQLite
const DS=FP.DiscoveryStore
const FORMAT="vbfsearch-sqlite-v1"
const MANIFEST_KEY="vbfsearch_output"

"""Identify regular owned files, excluding the live database and its journals."""
function artifact_files(workspace,run)
    excluded=Set(joinpath(run,"closure.sqlite"*suffix) for suffix in ("","-wal","-shm","-journal"))
    files=String[]
    for (root,dirs,names) in walkdir(workspace;follow_symlinks=false)
        any(name->islink(joinpath(root,name)),vcat(dirs,names)) && error("single-file output cannot archive symlinks")
        for name in names
            path=joinpath(root,name)
            path in excluded && continue
            isfile(path) || error("single-file output requires regular files: $path")
            push!(files,FP._closure_portable_relative(relpath(path,workspace)))
        end
    end
    sort!(files)
end

"""Bind scientific input/source pins to their embedded archive locations."""
function archive_pins(identity,prefix)
    pins=Dict{String,String}()
    for (relative,digest) in identity["implementation"]
        pins[joinpath(prefix,"replay","workspace",relative)]=digest
    end
    for (i,(logical,digest)) in enumerate(sort!(collect(identity["inputs"]);by=first))
        pins[joinpath(prefix,"replay","inputs",string(i)*"-"*basename(logical))]=digest
    end
    pins
end

"""Verify embedded bytes and scientific source/input pins, without scanning results."""
function verify_database(cache)
    meta=TOML.parse(only(DS.query(cache,"SELECT value FROM metadata WHERE key=?",(MANIFEST_KEY,)))["value"])
    meta["schema"]==FORMAT || error("unsupported single-file search output")
    expected=meta["artifacts"]
    rows=DS.query(cache,"SELECT path,sha256,bytes FROM vbfsearch_artifacts ORDER BY path")
    Set(String(row["path"]) for row in rows)==Set(keys(expected)) || error("embedded archive inventory differs from its manifest")
    for row in rows
        path=FP._closure_portable_relative(String(row["path"]))
        info=expected[path]
        row["sha256"]==info["sha256"] && row["bytes"]==info["bytes"] || error("embedded archive metadata differs: $path")
        bytes=only(DS.query(cache,"SELECT content FROM vbfsearch_artifacts WHERE path=?",(path,)))["content"]
        length(bytes)==info["bytes"] && bytes2hex(SHA.sha256(bytes))==info["sha256"] || error("embedded archive content differs: $path")
    end
    command=only(DS.query(cache,"SELECT content FROM vbfsearch_artifacts WHERE path='command.toml'"))["content"]
    String(command)==only(DS.query(cache,"SELECT value FROM metadata WHERE key='vbfsearch_command'"))["value"] || error("embedded command differs from metadata")
    result=FP.JSON3.read(only(DS.query(cache,"SELECT value FROM metadata WHERE key='vbfsearch_result'"))["value"],Dict{String,Any})
    result["state"]==meta["state"] || error("output state differs from result metadata")
    if meta["initialized"]
        identity=TOML.parse(only(DS.query(cache,"SELECT value FROM metadata WHERE key='identity'"))["value"])
        path=joinpath(meta["state_directory"],"identity.toml")
        archived=only(DS.query(cache,"SELECT content FROM vbfsearch_artifacts WHERE path=?",(path,)))["content"]
        TOML.parse(String(archived))==identity || error("embedded scientific identity differs from database")
        for (path,digest) in archive_pins(identity,meta["state_directory"])
            haskey(expected,path) && expected[path]["sha256"]==digest || error("embedded scientific pin differs: $path")
        end
    end
    Dict("verified"=>true,"schema"=>FORMAT,"artifacts"=>length(rows),
        "artifact_bytes"=>sum(Int(row["bytes"]) for row in rows;init=0),"state"=>meta["state"])
end

"""Read a published output without needing its former directory or source inputs."""
function verify(path)
    isfile(path) || error("single-file search output is missing: $path")
    escaped=replace(abspath(path),"%"=>"%25","?"=>"%3f","#"=>"%23")
    db=SQLite.DB("file:"*escaped*"?mode=ro")
    cache=DS.StatementCache(db)
    try
        verify_database(cache)
    finally
        DS.close_statements!(cache);close(db)
    end
end

"""Fold owned provenance into the stopped database, then publish without copying it.

Failures retain the working database/files and never overwrite an existing
output. The fault-injection hook runs after verification but before publication.
"""
function publish(config,result;before_publish=()->nothing)
    output=abspath(config["output"]);workspace=abspath(config["workspace"])
    expected=joinpath(dirname(output),"."*basename(output)*".work")
    workspace==expected && !islink(workspace) || error("single-file output requires its owned adjacent workspace")
    (ispath(output) || islink(output)) && error("output already exists: $output")
    command=joinpath(workspace,"command.toml")
    saved=TOML.parsefile(command)
    saved["output"]==output && saved["workspace"]==workspace || error("workspace command does not own this output")
    run=abspath(config["run"])
    run==joinpath(workspace,"state") || error("unexpected working database location")
    mkpath(run);lease=FP._closure_lease(run)
    source=joinpath(run,"closure.sqlite");existed=isfile(source)
    db=nothing;cache=nothing;receipt=nothing
    try
      try
        db=SQLite.DB(source);cache=DS.StatementCache(db)
        if !existed
            result["state"]=="stopped_before_initialization" || error("search database is missing")
            FP._closure_create_schema(db;normalized=true)
        end
        initialized=isfile(joinpath(run,"identity.toml"))
        existed && !initialized && error("cannot publish a partially initialized search")
        identity=initialized ? FP._closure_portable_identity(db,run) : nothing
        pins=initialized ? archive_pins(identity,relpath(run,workspace)) : Dict{String,String}()
        checkpoint=only(DS.query(cache,"PRAGMA wal_checkpoint(TRUNCATE)"))
        checkpoint["busy"]==0 || error("database has active readers; working data retained")
        only(DS.query(cache,"PRAGMA journal_mode=DELETE"))["journal_mode"]=="delete" || error("cannot finish single-file journal")
        DS.execute!(cache,"PRAGMA synchronous=FULL")
        files=artifact_files(workspace,run)
        Set(keys(pins)) ⊆ Set(files) || error("scientific archive is incomplete")
        manifest=Dict{String,Any}("schema"=>FORMAT,"created_utc"=>string(Dates.now(Dates.UTC)),
            "state"=>String(result["state"]),"initialized"=>initialized,"state_directory"=>relpath(run,workspace),
            "artifacts"=>Dict{String,Any}())
        DS.execute!(cache,"BEGIN IMMEDIATE")
        try
            DS.execute!(cache,"CREATE TABLE IF NOT EXISTS vbfsearch_artifacts(path TEXT PRIMARY KEY,sha256 TEXT NOT NULL,bytes INTEGER NOT NULL,content BLOB NOT NULL,CHECK(length(content)=bytes))")
            DS.execute!(cache,"DELETE FROM vbfsearch_artifacts")
            for relative in files
                bytes=read(FP._closure_portable_file(workspace,relative));digest=bytes2hex(SHA.sha256(bytes))
                haskey(pins,relative) && pins[relative]!=digest && error("scientific archive changed during packaging: $relative")
                DS.execute!(cache,"INSERT INTO vbfsearch_artifacts VALUES(?,?,?,?)",(relative,digest,length(bytes),bytes))
                manifest["artifacts"][relative]=Dict("sha256"=>digest,"bytes"=>length(bytes))
            end
            for (key,value) in ((MANIFEST_KEY,DS.texttoml(manifest)),("vbfsearch_command",read(command,String)),
                    ("vbfsearch_result",String(FP.JSON3.write(result))))
                DS.execute!(cache,"INSERT OR REPLACE INTO metadata(key,value) VALUES(?,?)",(key,value))
            end
            receipt=verify_database(cache)
            DS.execute!(cache,"COMMIT")
        catch
            DS.execute!(cache,"ROLLBACK");rethrow()
        end
      finally
        cache===nothing || DS.close_statements!(cache)
        db===nothing || close(db)
      end
      FP._closure_portable_sync(source)
      before_publish()
      # Adjacent staging guarantees the same filesystem; link refuses overwrites.
      hardlink(source,output)
      FP._closure_portable_sync(dirname(output);directory=true)
      rm(workspace;recursive=true)
      FP._closure_portable_sync(dirname(output);directory=true)
      receipt
    finally
      close(lease)
    end
end
end
