"""Register one representative per new separating signature in VBFCatalog.

All LUTs are rechecked with VBF against the current catalog. Equal signatures
are retained in the run and require equivalence checks; they are not promoted
as new classes. Registered corpora retain their immutable input file and run
evidence inside the catalog. This operation never asserts literature novelty.
"""
function publish(directory;name)
    occursin(r"^[a-z][a-z0-9_-]*$",name) || error("use a lowercase corpus slug")
    dir=abspath(directory);data=VBFCatalog.catalog_data_dir()
    startswith(dir,data*"/") || error("publish needs a catalog-local run; use discover or validate under $data/search")
    isfile(joinpath(dir,"run.sqlite")) || error("missing search run")
    lockpath=joinpath(data,".publish.lock")
    publish_lease=open(lockpath,"a+")
    ccall(:flock,Cint,(Cint,Cint),fd(publish_lease),6)==0 || (close(publish_lease);error("another catalog publication is active"))
    db=nothing;reference=nothing;writer_lease=nothing
    try
        writer_lease=open(joinpath(dir,"writer.lock"),"a+")
        ccall(:flock,Cint,(Cint,Cint),fd(writer_lease),6)==0 || error("stop the search writer before publishing")
        db=SQLite.DB("file:"*joinpath(dir,"run.sqlite")*"?mode=ro")
        SQLite.execute(db,"BEGIN")
        rows=[NamedTuple(r) for r in DBInterface.execute(db,"SELECT lut_id,lut_hex FROM candidates ORDER BY lut_id")]
        snapshot_sha=bytes2hex(sha256(join([r.lut_id*":"*r.lut_hex for r in rows],'\n')))
        declarations=joinpath(data,"corpora.toml")
        inventory=TOML.parsefile(declarations)
        entries=inventory["corpus"]
        prior=findfirst(e->e["name"]==name,entries)
        if prior!==nothing
            entry=entries[prior]
            get(entry,"run_snapshot_sha256",nothing)==snapshot_sha || error("corpus name already belongs to different results; publish the increment under a new name")
            filehash(joinpath(data,entry["file"]))==entry["sha256"] || error("registered input changed")
        else
            reference=open_reference(data;supplement_path="")
            accepted=Tuple{String,String}[];seen=Set{String}();matching=0
            powtab=monomial_power_table(8,conway_polynomial(8))
            for row in rows
                p=properties(hex2bytes(row.lut_hex))
                p["lut_sha256"]==row.lut_id || error("candidate LUT identity changed")
                p["apn"] && p["quadratic"] || continue
                hash=p["sigma_hash"]
                if VBFCatalog.reference_contains_signature(reference,hash)
                    matching+=1;continue
                end
                hash in seen && continue
                push!(seen,hash)
                enc=encode_quadratic(SBox{8}(hex2bytes(row.lut_hex));modulus=conway_polynomial(8),powtab)
                push!(accepted,(hash,bytes2hex(enc)))
            end
            if isempty(accepted)
                return Dict("accepted_classes"=>0,"matching_luts"=>matching,"literature_novelty"=>"unresolved")
            end
            sort!(accepted)
            path=joinpath(dir,name*".tsv")
            open(path*".partial","w") do io
                println(io,"sigma_hash\tcoeffs")
                for pair in accepted;println(io,join(pair,'\t'));end
            end
            mv(path*".partial",path;force=true)
            entry=Dict{String,Any}("name"=>name,"reader"=>"lut_tsv","family"=>"discovery",
                "file"=>relpath(path,data),"count"=>length(accepted),"sha256"=>filehash(path),
                "run_snapshot_sha256"=>snapshot_sha,"source_repo"=>"VBFSearch:"*relpath(dir,data),
                "notes"=>"Verified quadratic APNs with pairwise distinct signatures absent from frozen catalog "*reference.metadata["sha256"]*"; literature-wide novelty unresolved.")
            atomic_toml(joinpath(dir,name*".promotion.toml"),Dict("corpus"=>entry,
                "reference"=>VBFCatalog.reference_metadata(reference),"matching_luts"=>matching,
                "snapshot_luts"=>length(rows),"solver_source_sha256"=>VBFCatalog.equivalence_solver_fingerprint(),
                "generated_utc"=>string(Dates.now(Dates.UTC))))
            push!(entries,entry)
            atomic_toml(declarations,inventory)
            close_reference(reference);reference=nothing
        end
        cat=VBFCatalog.load_catalog()
        try
            info=VBFCatalog.corpus_info(cat,name)
            if info===nothing
                VBFCatalog.import_lut_corpus!(cat,entry)
            else
                info.member_count==entry["count"] && VBFCatalog.corpus_digest(cat,name)==info.store_sha256 || error("registered corpus changed")
            end
        finally
            close(cat)
        end
        cat=VBFCatalog.load_catalog()
        try
            idx=SQLite.DB(VBFCatalog.sigma_index_path())
            indexed=try
                only(Int(r.c) for r in DBInterface.execute(idx,"SELECT COUNT(*) c FROM ccz_sigma_index WHERE source=?",(name,)))
            finally
                close(idx)
            end
            if indexed!=entry["count"]
                idx=SQLite.DB(VBFCatalog.sigma_index_path())
                try
                    SQLite.transaction(idx) do
                        SQLite.execute(idx,"DELETE FROM ccz_sigma_index WHERE source=?",(name,))
                        SQLite.execute(idx,"DELETE FROM sigma_coverage WHERE source=?",(name,))
                        SQLite.execute(idx,"INSERT INTO sigma_coverage VALUES(?,8,0)",(name,))
                    end
                finally
                    close(idx)
                end
                VBFCatalog.build_sigma_index!(cat;rebuild=false,corpora=[name],include_functions=false)
            end
        finally
            close(cat)
        end
        Dict("corpus"=>name,"accepted_classes"=>entry["count"],"literature_novelty"=>"unresolved",
            "input"=>entry["file"],"reused"=>prior!==nothing)
    finally
        reference===nothing || close_reference(reference)
        db===nothing || close(db)
        writer_lease===nothing || close(writer_lease)
        close(publish_lease)
    end
end
