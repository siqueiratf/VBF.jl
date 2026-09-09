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
    -- Paper-reproduction layer (bench/run_papers.jl). NULL for every row that
    -- bench/run.jl writes; the core suite's contract and columns above stay as
    -- they are. `mode` classifies the reproduction, not the paper itself: two
    -- rows with the same paper_id can carry different modes (see
    -- bench/paper_suites/Beierle_202107.jl, whose report.jl-level case is
    -- "hybrid" and whose standalone algorithm1.jl case is "paper_specific").
    paper_id TEXT,
    mode TEXT CHECK (mode IN ('core_only', 'hybrid', 'paper_specific')),
    -- The one raw counter with no existing equivalent: every node a search
    -- touched, complete or not, coarser than `candidates_processed` (complete
    -- candidates only). A paper reproduction reuses every other column above
    -- for a metric with identical semantics — `total_apns`, `distinct_apns`,
    -- `known_apns_recovered`, `total_known_apns`, `candidates_final_apn_test`
    -- — rather than a second, paper-only name for the same measurement. NULL
    -- when the paper's own code exposes no such count.
    total_candidates INTEGER CHECK (total_candidates >= 0),
    UNIQUE (run_id, algorithm, n, repetition)
);

CREATE INDEX IF NOT EXISTS idx_benchmark_approach_n ON benchmark(approach, n);
CREATE INDEX IF NOT EXISTS idx_benchmark_paper_mode ON benchmark(paper_id, mode);
