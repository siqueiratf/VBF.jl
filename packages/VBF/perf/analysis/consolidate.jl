"""Rebuild a disposable analysis SQLite database without mutating raw measurements.

All output tables are replaced in one SQLite transaction. The raw benchmark read
is one snapshot; provenance records the row count and IDs of that snapshot.
"""
function consolidate(raw=RAW_DATABASE; output=ANALYSIS_DATABASE,
                     profiles=joinpath(normpath(joinpath(@__DIR__, "..", "..", "..", "..")), "packages/VBF/perf/data"))
    abspath(raw) == abspath(output) && error("Analysis output must differ from raw database")
    ispath(output) && realpath(raw) == realpath(output) && error("Output aliases raw database")
    df = load_benchmarks(raw)
    sessions, components = read_profiles(profiles)
    processed = join_profiles(derive_metrics(df), sessions)
    sources = sort(filter(p -> endswith(p, ".jl"), readdir(@__DIR__; join=true)))

    source_digest = bytes2hex(sha256(JSON3.write([basename(p) => bytes2hex(open(sha256, p)) for p in sources])))
    manifest = joinpath(@__DIR__, "..", "Manifest.toml")
    tables = Dict("benchmarks" => processed,
        "core" => filter(:paper_id => ismissing, processed),
        "papers" => filter(:paper_id => !ismissing, processed),
        "profiles" => sessions, "profile_components" => components,
        "runtime" => runtime_statistics(processed),
        "provenance" => DataFrame(raw_database=[abspath(raw)],
            generated_at=[string(now(UTC))], analysis_version=[1], raw_rows=[nrow(df)],
            max_benchmark_id=[isempty(df.id) ? 0 : maximum(df.id)],
            julia_version=[string(VERSION)],
            analysis_source_sha256=[source_digest],
            analysis_manifest_sha256=[isfile(manifest) ? bytes2hex(open(sha256, manifest)) : missing],
            attribution_rule=["nearest project ancestor; exclusive samples; v1"]))
    mkpath(dirname(output))
    db = SQLite.DB(output)
    try
        SQLite.transaction(db) do
            for (name, table) in tables
                DBInterface.execute(db, "DROP TABLE IF EXISTS \"$name\"")
                SQLite.load!(table, db, name)
            end
        end
    finally
        close(db)
    end
    tables
end
