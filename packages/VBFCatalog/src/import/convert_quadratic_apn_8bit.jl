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

"""Normalize the small quadratic corpora declared in data/catalog/corpora.toml."""
function main()
    with_source("quadratic_apn_8bit") do root
        n=8; modulus=conway_polynomial(n); powtab=monomial_power_table(n,modulus)
        db=load_catalog()
        try
            for entry in TOML.parsefile(joinpath(VBFCatalog.catalog_source_dir(),"corpora.toml"))["corpus"]
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
                    store_file=store.store_file,store_sha256=store.sha256,family="quadratic-apn-8bit",
                    bib_key=entry["bib_key"],source_repo="bfa@"*source_short_sha(pkgdir(VBF))*"|sboxu@"*source_short_sha(root),
                    contributor="BFA quadratic-APN 8-bit literature import (automated)",added_date=string(now(UTC))*"Z",notes)
                println("[$(entry["name"])] members=$(store.count) skipped=$skipped")
            end
        finally
            close(db)
        end
    end
end
abspath(PROGRAM_FILE)==(@__FILE__) && main()
