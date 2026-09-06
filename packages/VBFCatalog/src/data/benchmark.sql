CREATE TABLE IF NOT EXISTS benchmark (
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
    UNIQUE (run_id, algorithm, n, repetition)
);

CREATE INDEX IF NOT EXISTS idx_benchmark_approach_n ON benchmark(approach, n);
