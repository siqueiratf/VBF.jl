using VBF, VBFCatalog, SQLite, DBInterface, SHA, TOML
include("load_sources.jl")
include("bibliography.jl")
include("write.jl")
include("check.jl")
include("convert.jl")

"""Build a deterministic catalog from declarations and checksum-bound originals.

The previous catalog, local proof history, indexes and wall clock are never build
inputs. A staging database is verified and canonically rewritten before install.
"""
function build_inputs(config)
    records=VBFCatalog._declaration_inputs()
    for source in config["source"]
        get(source,"enabled",true) || continue
        get(source,"external",false) && continue
        get(source,"builtin",false) && continue
        root=with_source(identity,source["name"])
        relative = haskey(source,"files") ?
            (get(source,"check_kind","dir")=="file" ? source["files"] :
                [joinpath(source["check_path"],file) for file in source["files"]]) : [source["check_path"]]
        for relative_path in relative
            path=joinpath(root,relative_path)
            digest=bytes2hex(open(SHA.sha256,path))
            haskey(source,"sha256") && digest!=source["sha256"] && error("original checksum changed: $(source["name"])")
            push!(records,(source=source["name"],path=relative_path,sha256=digest,bytes=filesize(path)))
        end
    end
    sort!(records;by=row->(row.source,row.path))
end

function main(;output=catalog_path())
    mkpath(catalog_data_dir())
    lease=open(joinpath(catalog_data_dir(),".publish.lock"),"a+")
    ccall(:flock,Cint,(Cint,Cint),fd(lease),6)==0 || (close(lease);error("another catalog build or publication is active"))
    try
    config=TOML.parsefile(_SOURCES_TOML)
    inputs=build_inputs(config)
    digest=VBFCatalog._inputs_digest(inputs)
    implementation=VBFCatalog._implementation_digest()
    final=abspath(output);staging=final*".building"
    mkpath(dirname(final))
    try
        withenv("BFA_CATALOG_PATH"=>staging) do
            db=create_catalog(staging;inputs_sha256=digest,implementation_sha256=implementation)
            try
                SQLite.transaction(db) do
                    for row in inputs
                        SQLite.execute(db,"INSERT INTO source_inputs VALUES(?,?,?,?)",Tuple(row))
                    end
                    insert_bibliography!(db)
                    for (family,names,loader,metadata) in (("Literature",literature_sbox_names(),load_literature_sbox,literature_sbox_metadata),
                            ("APN",apn_catalog_names(),load_apn_function,apn_catalog_metadata))
                        for name in names
                            entry=metadata(name)
                            insert_function!(db,loader(name);family,canonical_name=name,source_repo="VBF declarations",
                                contributor="VBFCatalog source import",bib_key=entry["bib_key"],notes=entry["description"],
                                algebraic_form=get(entry,"algebraic_form",nothing),require_apn=family=="APN")
                        end
                    end
                end
            finally
                close(db)
            end
            for source in config["source"]
                get(source,"enabled",true) || continue
                if get(source,"external",false)
                    db=load_catalog()
                    try
                        for entry in config["corpus"]
                            entry["source"]==source["name"] || continue
                            store=(count=entry["count"],bytes_per_member=37,
                                store_file="members.sqlite",sha256=entry["packed_sha256"])
                            VBFCatalog._register_declared_corpus!(db,entry,store)
                        end
                    finally
                        close(db)
                    end
                else
                    convert_source(source["name"])
                end
            end
            build_inputs(config)==inputs || error("build inputs changed during import")
            VBFCatalog._implementation_digest()==implementation || error("build implementation changed during import")
            finalize_catalog!(staging;refresh_inputs=false)
            check_catalog(staging)
        end
        mv(staging,final;force=true)
        @info "Deterministic catalog built" path=final bytes=filesize(final) inputs_sha256=digest
    finally
        rm(staging;force=true)
        rm(staging*".canonical";force=true)
    end
    nothing
    finally
        close(lease)
    end
end

if abspath(PROGRAM_FILE)==(@__FILE__)
    args=copy(ARGS)
    isempty(args) ? main() : length(args)==2 && first(args)=="--output" ? main(;output=args[2]) :
        error("usage: build_catalog.jl [--output PATH]")
end
