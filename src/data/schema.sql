-- BFA.jl catalog schema (schema_version = 1)
--
-- Authoritative source-of-truth lives in this file; the same SQL is
-- embedded as a constant in src/data/catalog.jl so the schema travels
-- with the package. Bumps require both:
--   1. an incremented `schema_version` row,
--   2. a numbered migration file under data-build/migrations/.

CREATE TABLE IF NOT EXISTS schema_meta (
    schema_version INTEGER NOT NULL,
    built_at       TEXT NOT NULL,    -- ISO-8601 UTC of the build_catalog.jl run
    bfa_version    TEXT NOT NULL,    -- BFA.jl package version when built
    git_sha        TEXT NOT NULL     -- git commit of BFA.jl source tree
);

CREATE TABLE IF NOT EXISTS bibliography (
    bib_key      TEXT PRIMARY KEY,
    bibtex       TEXT NOT NULL,
    doi          TEXT,
    url          TEXT,
    year         INTEGER NOT NULL,
    authors      TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS functions (
    id                       INTEGER PRIMARY KEY,
    family                   TEXT    NOT NULL,    -- "APN" | "Literature" | "RandomCorpus"
    n                        INTEGER NOT NULL,
    m                        INTEGER NOT NULL,
    lut_sha256               TEXT    NOT NULL,
    lut_blob                 BLOB    NOT NULL,    -- ceil(m/8) bytes per entry, input order, LE
    algebraic_form           TEXT,
    algebraic_degree         INTEGER,
    differential_uniformity  INTEGER,
    linearity                INTEGER,
    boomerang_uniformity     INTEGER,             -- NULL for non-permutations
    is_apn                   INTEGER NOT NULL,
    is_permutation           INTEGER NOT NULL,
    is_quadratic             INTEGER NOT NULL,
    canonical_name           TEXT,
    bib_key                  TEXT REFERENCES bibliography(bib_key),
    source_repo              TEXT NOT NULL,       -- pipe-list e.g. "bfa@<sha>"
    contributor              TEXT NOT NULL,
    added_date               TEXT NOT NULL,
    notes                    TEXT,
    UNIQUE(lut_sha256, n)
);

CREATE INDEX IF NOT EXISTS idx_functions_family_n ON functions(family, n);
CREATE INDEX IF NOT EXISTS idx_functions_apn_n    ON functions(is_apn, n);
CREATE INDEX IF NOT EXISTS idx_functions_bib_key  ON functions(bib_key);

CREATE TABLE IF NOT EXISTS equivalence_classes (
    id            INTEGER PRIMARY KEY,
    kind          TEXT NOT NULL,                  -- "EA" | "CCZ" | "Linear" | "Affine"
    n             INTEGER NOT NULL,
    canonical_id  INTEGER NOT NULL REFERENCES functions(id),
    discriminator TEXT,
    UNIQUE(kind, n, canonical_id)
);

CREATE TABLE IF NOT EXISTS class_members (
    class_id    INTEGER NOT NULL REFERENCES equivalence_classes(id),
    function_id INTEGER NOT NULL REFERENCES functions(id),
    strategy    TEXT NOT NULL,
    PRIMARY KEY (class_id, function_id, strategy)
);

CREATE TABLE IF NOT EXISTS reconciliation_disagreements (
    id              INTEGER PRIMARY KEY,
    n               INTEGER NOT NULL,
    function_id     INTEGER REFERENCES functions(id),
    present_in      TEXT NOT NULL,                 -- pipe-list of source repos
    absent_from     TEXT NOT NULL,                 -- pipe-list of source repos
    kind            TEXT NOT NULL,                 -- "missing_in_some" | …
    resolution      TEXT,
    resolver        TEXT,
    resolved_date   TEXT
);
