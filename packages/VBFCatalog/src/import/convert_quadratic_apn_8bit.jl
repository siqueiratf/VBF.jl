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
                entry["source"]=="quadratic_apn_8bit" || continue
                if entry["reader"] in ("lut_tsv","quadratic_coeffs")
                    store=import_lut_corpus!(db,entry)
                    println("[$(entry["name"])] members=$(store.count)")
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
                VBFCatalog._register_declared_corpus!(db,entry,store;
                    source_repo=get(entry,"source_repo","sboxu@"*source_revision(root)))
                println("[$(entry["name"])] members=$(store.count) skipped=$skipped")
            end
        finally
            close(db)
        end
    end
end
abspath(PROGRAM_FILE)==(@__FILE__) && main(;names=isempty(ARGS) ? nothing : ARGS)
