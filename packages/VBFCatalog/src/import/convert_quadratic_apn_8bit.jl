using VBF, VBFCatalog, TOML, Dates
include("load_sources.jl")
include("readers.jl")

function family_luts(entry,root)
    reader=entry["reader"]
    reader=="taniguchi" && return [Int.(r.sbox.lut) for r in taniguchi_apn_representatives(entry["half"]) if r.new]
    path=joinpath(root,entry["file"])
    reader=="edelpott" && return SourceReaders.edelpott_luts(path)
    reader in ("literal","literal8") || error("unknown corpus reader $reader")
    luts=SourceReaders.parse_apn_lut_file(path)
    reader=="literal8" ? filter(l->length(l)==256,luts) : luts
end

"""Normalize quadratic corpora declared in data/corpora.toml, using VBF mathematics."""
function main(;names=nothing)
    with_source("quadratic_apn_8bit") do root
        n=8; modulus=conway_polynomial(n); powtab=monomial_power_table(n,modulus)
        db=load_catalog()
        try
            for entry in TOML.parsefile(joinpath(VBFCatalog.catalog_source_dir(),"corpora.toml"))["corpus"]
                names===nothing || entry["name"] in names || continue
                if entry["reader"]=="lut_tsv"
                    path=joinpath(VBFCatalog.catalog_source_dir(),entry["file"])
                    if !isfile(path) && haskey(entry,"run_snapshot_sha256")
                        # The tracked compact corpus regenerates this intermediate
                        # file when local search artifacts are unavailable.
                        previous=load_catalog(get(ENV,"BFA_PREVIOUS_CATALOG",joinpath(VBFCatalog.catalog_source_dir(),"catalog.sqlite")))
                        try
                            corpus_info(previous,entry["name"])===nothing && error("missing discovery corpus input: $path")
                            mkpath(dirname(path))
                            open(path*".partial","w") do io
                                println(io,"sigma_hash\tcoeffs")
                                with_corpus_rows(previous,entry["name"]) do rows
                                    for row in rows
                                        F=SBox{8}(decode_quadratic_lut(row.coeffs,8,modulus;powtab))
                                        println(io,sigma_hash(F),'\t',bytes2hex(row.coeffs))
                                    end
                                end
                            end
                            mv(path*".partial",path)
                        finally
                            close(previous)
                        end
                    end
                    store=import_lut_corpus!(db,entry;data=VBFCatalog.catalog_source_dir())
                    println("[$(entry["name"])] members=$(store.count) skipped=0")
                    continue
                end
                encodings=Vector{UInt8}[]; skipped=0
                for lut in family_luts(entry,joinpath(root,"sboxU","scripts","apnDB"))
                    length(lut)==1<<n || error("$(entry["name"]): invalid LUT length")
                    F=SBox{n}(lut)
                    if differential_uniformity(F)==2 && algebraic_degree(F)==2
                        push!(encodings,encode_quadratic(F;modulus,powtab))
                    else
                        skipped+=1
                    end
                end
                store=build_corpus_store!(entry["name"],encodings)
                notes=entry["notes"]*(skipped>0 ? " ($skipped non-quadratic-APN member(s) in the source excluded)" : "")
                register_corpus!(db;name=entry["name"],n,m=n,member_count=store.count,degree=2,modulus,
                    encoding="quadratic-coeffs-v1",bytes_per_member=store.bytes_per_member,
                    store_file=store.store_file,store_sha256=store.sha256,family=get(entry,"family","quadratic-apn-8bit"),
                    bib_key=get(entry,"bib_key",nothing),source_repo=get(entry,"source_repo","bfa@"*source_short_sha(pkgdir(VBF))*"|sboxu@"*source_short_sha(root)),
                    contributor="BFA quadratic-APN 8-bit literature import (automated)",added_date=string(now(UTC))*"Z",notes)
                println("[$(entry["name"])] members=$(store.count) skipped=$skipped")
            end
        finally
            close(db)
        end
    end
end
abspath(PROGRAM_FILE)==(@__FILE__) && main(;names=isempty(ARGS) ? nothing : ARGS)
