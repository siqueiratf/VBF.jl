"""Catalog build primitives shared by source importers and explicit publication."""

include_dependency(joinpath(@__DIR__, "schema.sql"))
const SCHEMA_DDL = read(joinpath(@__DIR__,"schema.sql"),String)

"""Create an empty catalog for a source build; replace existing files explicitly."""
function create_catalog(path::AbstractString; bfa_version="0.1.0-DEV",
        inputs_sha256="unknown", implementation_sha256="unknown")
    isfile(path) && rm(path)
    db=SQLite.DB(path)
    for statement in _split_ddl(SCHEMA_DDL)
        SQLite.execute(db,statement)
    end
    SQLite.execute(db,"INSERT INTO schema_meta VALUES(?,?,?,?)",
        (SCHEMA_VERSION,inputs_sha256,bfa_version,implementation_sha256))
    db
end

function _split_ddl(ddl::AbstractString)
    stmts = String[]
    buf = IOBuffer()
    for line in eachline(IOBuffer(ddl))
        sl = strip(line)
        (startswith(sl, "--") || isempty(sl)) && continue
        println(buf, line)
        endswith(sl, ";") || continue
        push!(stmts, String(take!(buf)))
    end
    stmts
end

"""Actual declaration and immutable dataset bytes, independent of the local cache."""
function _declaration_inputs()
    records=NamedTuple[]
    for (dir,_,files) in walkdir(catalog_source_dir()), file in sort(files)
        any(ext->endswith(file,ext),(".toml",".bib",".tsv",".gz")) || continue
        path=joinpath(dir,file)
        push!(records,(source="declarations",path=relpath(path,catalog_source_dir()),
            sha256=bytes2hex(open(SHA.sha256,path)),bytes=filesize(path)))
    end
    sort!(records;by=row->(row.source,row.path))
end

_inputs_digest(records) = bytes2hex(SHA.sha256(join([string(row.source,':',row.path,':',row.sha256,':',row.bytes)
    for row in sort(records;by=row->(row.source,row.path))],"\n")))

"""Rewrite the catalog in a fixed table/key order and bind current declared inputs.

Runtime publication uses the same canonical writer as a clean source rebuild.
Proof history and local indexes are outside this file. Close catalog handles and
hold the publication lease before replacing it.
"""
function finalize_catalog!(path;refresh_inputs=true)
    input=load_catalog(path);output=path*".canonical"
    meta=only(NamedTuple(row) for row in DBInterface.execute(input,"SELECT * FROM schema_meta"))
    records=refresh_inputs ? vcat(_declaration_inputs(),[NamedTuple(row) for row in DBInterface.execute(input,"SELECT * FROM source_inputs WHERE source!='declarations'")]) : NamedTuple[]
    digest=refresh_inputs ? _inputs_digest(records) : meta.inputs_sha256
    target=create_catalog(output;bfa_version=meta.bfa_version,inputs_sha256=digest,
        implementation_sha256=meta.implementation_sha256)
    complete=false
    try
        tables=[String(row.name) for row in DBInterface.execute(input,
            "SELECT name FROM sqlite_master WHERE type='table' AND name!='schema_meta' ORDER BY name")]
        SQLite.transaction(target) do
            for table in tables
                if refresh_inputs && table=="source_inputs"
                    for record in sort(records;by=row->(row.source,row.path))
                        SQLite.execute(target,"INSERT INTO source_inputs VALUES(?,?,?,?)",Tuple(record))
                    end
                    continue
                end
                fields=[NamedTuple(row) for row in DBInterface.execute(input,"PRAGMA table_info($table)")]
                keys=sort(filter(field->field.pk>0,fields);by=field->field.pk)
                order=join([field.name for field in (isempty(keys) ? fields : keys)],",")
                statement=DBInterface.prepare(target,"INSERT INTO $table VALUES("*join(fill("?",length(fields)),",")*")")
                try
                    # Dataset identity is its name. Assign descriptor IDs by name so
                    # publication and a clean rebuild produce the same physical rows.
                    table=="bulk_corpora" && (order="name")
                    for (id,row) in enumerate(DBInterface.execute(input,"SELECT * FROM $table ORDER BY $order"))
                        values=NamedTuple(row)
                        table=="bulk_corpora" && (values=merge(values,(;id)))
                        DBInterface.execute(statement,Tuple(values))
                    end
                finally
                    DBInterface.close!(statement)
                end
            end
        end
        complete=true
    finally
        close(target);close(input)
        complete || rm(output;force=true)
    end
    mv(output,path;force=true)
    nothing
end

"""Digest the build implementation and Julia/SQLite toolchain, independent of Git HEAD."""
function _implementation_digest()
    roots=[joinpath(pkgdir(VBF),"src"),joinpath(pkgdir(VBFCatalog),"src")]
    paths=sort!([joinpath(dir,file) for root in roots for (dir,_,files) in walkdir(root)
        for file in files if endswith(file,".jl") || endswith(file,".sql")])
    digest=join([relpath(path,dirname(pkgdir(VBF)))*":"*bytes2hex(open(SHA.sha256,path)) for path in paths],"\n")
    db=SQLite.DB()
    try
        engine=only(String(row.version) for row in DBInterface.execute(db,"SELECT sqlite_version() version"))
        bytes2hex(SHA.sha256(string(VERSION,"\n",engine,"\n",digest)))
    finally
        close(db)
    end
end
