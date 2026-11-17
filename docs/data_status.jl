# Is the signature index of the inspector data current? The index depends on the
# catalog inputs, not on the date of catalog.sqlite: a rebuild of the same inputs
# (for example by the catalog gate) leaves the index valid.
#
#   julia --project=packages/VBFCatalog/src/import docs/data_status.jl check DATA_DIR
#   julia --project=packages/VBFCatalog/src/import docs/data_status.jl stamp DATA_DIR
#
# `check` exits 0 if the index exists and was built for the inputs_sha256 of the
# catalog. The digest of the index comes from ccz_sigma_index.inputs (written by
# `stamp` after a local build) or from prebuilt.toml (written by a Zenodo install).
using SQLite, DBInterface, TOML

function catalog_inputs(dir)
    db = SQLite.DB("file:" * joinpath(dir, "catalog.sqlite") * "?mode=ro")
    try
        String(only(r.inputs_sha256 for r in DBInterface.execute(db, "SELECT inputs_sha256 FROM schema_meta")))
    finally
        close(db)
    end
end

function index_inputs(dir)
    stamp = joinpath(dir, "ccz_sigma_index.inputs")
    isfile(stamp) && return strip(read(stamp, String))
    prebuilt = joinpath(dir, "prebuilt.toml")
    isfile(prebuilt) && return get(TOML.parsefile(prebuilt), "inputs_sha256", "")
    ""
end

function main(args)
    length(args) == 2 || error("usage: data_status.jl check|stamp DATA_DIR")
    command, dir = args
    if command == "check"
        isfile(joinpath(dir, "ccz_sigma_index.sqlite")) && isfile(joinpath(dir, "catalog.sqlite")) || exit(1)
        index_inputs(dir) == catalog_inputs(dir) || exit(1)
    elseif command == "stamp"
        write(joinpath(dir, "ccz_sigma_index.inputs"), catalog_inputs(dir) * "\n")
    else
        error("unknown command $command")
    end
end

main(ARGS)
