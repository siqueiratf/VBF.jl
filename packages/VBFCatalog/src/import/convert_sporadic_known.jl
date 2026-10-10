using VBF, VBFCatalog, TOML, Dates
include("write.jl")

"""Convert the fixed literature LUTs in data/catalog/sporadic.toml."""
function main()
    db=load_catalog()
    try
        for entry in TOML.parsefile(joinpath(VBFCatalog.catalog_source_dir(),"sporadic.toml"))["functions"]
            F=SBox{entry["n"]}(entry["lut"])
            find_function(db;lut_sha256=lut_sha256_hex(F))===nothing || continue
            insert_function!(db,F;family="known-sporadic",canonical_name=entry["canonical_name"],
                bib_key=entry["bib_key"],notes=entry["notes"],source_repo=entry["source_repo"],
                contributor=entry["contributor"],added_date=string(today()))
        end
    finally
        close(db)
    end
end
abspath(PROGRAM_FILE)==(@__FILE__) && main()
