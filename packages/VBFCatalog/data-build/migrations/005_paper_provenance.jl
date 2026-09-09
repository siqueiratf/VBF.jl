using VBFCatalog
import VBFCatalog: SQLite, DBInterface

"""Add paper-reproduction provenance and raw metric columns to the benchmark
table on a version 4 catalog, preserving all existing rows. Every new column
is nullable; every existing row keeps its current values unchanged."""
function migrate_paper_provenance(path = VBFCatalog.catalog_path())
    isfile(path) || error("Catalog does not exist: $path")
    db = SQLite.DB(path)
    try
        version = only([Int(r.schema_version) for r in
            DBInterface.execute(db, "SELECT schema_version FROM schema_meta")])
        version in (4, 5) || error("Expected schema 4 or 5, found $version")
        SQLite.transaction(db) do
            existing = Set(String(r.name) for r in
                DBInterface.execute(db, "PRAGMA table_info(benchmark)"))
            for (column, ddl) in (
                "paper_id" => "paper_id TEXT",
                "mode" => "mode TEXT CHECK (mode IN ('core_only', 'hybrid', 'paper_specific'))",
                "total_candidates" => "total_candidates INTEGER CHECK (total_candidates >= 0)",
                "tested_candidates" => "tested_candidates INTEGER CHECK (tested_candidates >= 0)",
                "apns_generated" => "apns_generated INTEGER CHECK (apns_generated >= 0)",
                "known_recovered" => "known_recovered INTEGER CHECK (known_recovered >= 0)",
                "known_total" => "known_total INTEGER CHECK (known_total >= 0 AND known_recovered <= known_total)",
            )
                column in existing ||
                    SQLite.execute(db, "ALTER TABLE benchmark ADD COLUMN $ddl")
            end
            SQLite.execute(db, "CREATE INDEX IF NOT EXISTS idx_benchmark_paper_mode ON benchmark(paper_id, mode)")
            SQLite.execute(db, "UPDATE schema_meta SET schema_version = 5")
        end
    finally
        close(db)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    migrate_paper_provenance(isempty(ARGS) ? VBFCatalog.catalog_path() : only(ARGS))
end
