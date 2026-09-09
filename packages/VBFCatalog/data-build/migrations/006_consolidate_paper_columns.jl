using VBFCatalog
import VBFCatalog: SQLite, DBInterface

"""Drop the four paper-provenance columns migration 005 added that duplicated
an existing core column's semantics, folding their data into that column
instead: `tested_candidates` into `candidates_final_apn_test`, `apns_generated`
into `total_apns`, `known_recovered` into `known_apns_recovered`, `known_total`
into `total_known_apns`. `paper_id`, `mode`, and `total_candidates` (which has
no existing equivalent) are kept.

SQLite's own `ALTER TABLE ... DROP COLUMN` refuses `known_recovered` here: the
`total_known_apns` CHECK constraint that stays behind still names it. A rebuild
sidesteps that ordering problem outright, so this migration always rebuilds
rather than dropping columns one at a time."""
function migrate_consolidate_paper_columns(path = VBFCatalog.catalog_path())
    isfile(path) || error("Catalog does not exist: $path")
    db = SQLite.DB(path)
    try
        version = only([Int(r.schema_version) for r in
            DBInterface.execute(db, "SELECT schema_version FROM schema_meta")])
        version in (5, 6) || error("Expected schema 5 or 6, found $version")
        if version == 5
            SQLite.transaction(db) do
                SQLite.execute(db, """
                    CREATE TABLE benchmark_new (
                        id INTEGER PRIMARY KEY,
                        run_id TEXT NOT NULL,
                        repetition INTEGER NOT NULL CHECK (repetition > 0),
                        recorded_at TEXT NOT NULL,
                        algorithm TEXT NOT NULL,
                        approach TEXT NOT NULL,
                        n INTEGER,
                        elapsed_seconds REAL NOT NULL CHECK (elapsed_seconds >= 0),
                        time_to_first_apn_seconds REAL CHECK (time_to_first_apn_seconds >= 0),
                        search_space_size TEXT,
                        candidates_processed INTEGER CHECK (candidates_processed >= 0),
                        candidates_final_apn_test INTEGER CHECK (candidates_final_apn_test >= 0),
                        total_apns INTEGER CHECK (total_apns >= 0),
                        distinct_apns INTEGER CHECK (distinct_apns >= 0 AND distinct_apns <= total_apns),
                        known_apns_recovered INTEGER CHECK (known_apns_recovered >= 0 AND known_apns_recovered <= distinct_apns),
                        total_known_apns INTEGER CHECK (total_known_apns >= 0 AND known_apns_recovered <= total_known_apns),
                        reference_scope_json TEXT,
                        apn_identities_json TEXT,
                        parameters_json TEXT NOT NULL,
                        paper_id TEXT,
                        mode TEXT CHECK (mode IN ('core_only', 'hybrid', 'paper_specific')),
                        total_candidates INTEGER CHECK (total_candidates >= 0),
                        UNIQUE (run_id, algorithm, n, repetition)
                    )
                """)
                SQLite.execute(db, """
                    INSERT INTO benchmark_new
                    SELECT id, run_id, repetition, recorded_at, algorithm, approach, n,
                           elapsed_seconds, time_to_first_apn_seconds, search_space_size,
                           candidates_processed,
                           COALESCE(candidates_final_apn_test, tested_candidates),
                           COALESCE(total_apns, apns_generated),
                           distinct_apns,
                           COALESCE(known_apns_recovered, known_recovered),
                           COALESCE(total_known_apns, known_total),
                           reference_scope_json, apn_identities_json, parameters_json,
                           paper_id, mode, total_candidates
                    FROM benchmark
                """)
                SQLite.execute(db, "DROP TABLE benchmark")
                SQLite.execute(db, "ALTER TABLE benchmark_new RENAME TO benchmark")
                SQLite.execute(db, "CREATE INDEX IF NOT EXISTS idx_benchmark_approach_n ON benchmark(approach, n)")
                SQLite.execute(db, "CREATE INDEX IF NOT EXISTS idx_benchmark_paper_mode ON benchmark(paper_id, mode)")
                SQLite.execute(db, "UPDATE schema_meta SET schema_version = 6")
            end
        end
    finally
        close(db)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    migrate_consolidate_paper_columns(isempty(ARGS) ? VBFCatalog.catalog_path() : only(ARGS))
end
