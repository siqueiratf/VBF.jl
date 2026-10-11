-- VBFCatalog schema. Rebuild when SCHEMA_VERSION changes; no migrations.
--
-- Authoritative source-of-truth lives in this file; the same SQL is
-- embedded as a constant in src/storage/catalog.jl so the schema travels
-- with the package.

CREATE TABLE IF NOT EXISTS schema_meta (
    schema_version INTEGER NOT NULL,
    inputs_sha256  TEXT NOT NULL,    -- digest of declarations and pinned originals
    bfa_version    TEXT NOT NULL,    -- BFA.jl package version when built
    implementation_sha256 TEXT NOT NULL -- decoder and VBF source digest
);

CREATE TABLE IF NOT EXISTS bibliography (
    bib_key      TEXT PRIMARY KEY,
    bibtex       TEXT NOT NULL,
    doi          TEXT,
    url          TEXT,
    year         INTEGER NOT NULL,
    authors      TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS source_inputs (
    source TEXT NOT NULL,
    path TEXT NOT NULL,
    sha256 TEXT NOT NULL,
    bytes INTEGER NOT NULL,
    PRIMARY KEY(source,path)
) WITHOUT ROWID;

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

-- Bulk corpora: large families of functions kept OUT of the `functions` table
-- (which would bloat by gigabytes). One descriptor row per corpus; the members
-- themselves live in a compact, content-addressed side store in the catalog or shared local bulk store
-- (a packed encoding — e.g. `quadratic-coeffs-v1`, the weight-≤2 univariate
-- coefficients) from which each member's LUT is reconstructed on demand. Full
-- 2ⁿ-byte LUTs are materialised lazily, never committed.
CREATE TABLE IF NOT EXISTS bulk_corpora (
    id               INTEGER PRIMARY KEY,
    name             TEXT    NOT NULL UNIQUE,
    n                INTEGER NOT NULL,
    m                INTEGER NOT NULL,
    member_count     INTEGER NOT NULL,
    degree           INTEGER,                       -- algebraic degree (2 = quadratic)
    modulus          INTEGER NOT NULL,              -- GF(2ⁿ) modulus for encode/decode
    encoding         TEXT    NOT NULL,              -- e.g. "quadratic-coeffs-v1"
    bytes_per_member INTEGER NOT NULL,
    store_file       TEXT    NOT NULL,              -- catalog or members.sqlite
    store_sha256     TEXT    NOT NULL,              -- content hash of the side store
    family           TEXT,
    bib_key          TEXT REFERENCES bibliography(bib_key),
    source_repo      TEXT    NOT NULL,
    contributor      TEXT    NOT NULL,
    added_date       TEXT    NOT NULL,
    notes            TEXT
);

-- Bundled records are packed in fixed 1024-member chunks, indexed by first member.
-- Downloaded records use one member per row in the identical table
-- in packages/VBFCatalog/data/members.sqlite. store_sha256 hashes encodings in idx order.
CREATE TABLE IF NOT EXISTS corpus_members (
    corpus TEXT NOT NULL,
    idx INTEGER NOT NULL CHECK(idx > 0),
    coeffs BLOB NOT NULL,
    PRIMARY KEY(corpus, idx)
) WITHOUT ROWID;

-- NOTE: the σ-signature novelty index (ccz_sigma_index) is NOT part of the
-- committed catalog. It is large (one row per catalogued function — millions)
-- and fully regenerable from the corpora + functions table, so — like the
-- bulk-corpus LUT stores — it lives in its own side store under
-- packages/VBFCatalog/data/ccz_sigma_index.sqlite (build with `build_sigma_index!`, query with
-- `classify_ccz`/`is_novel`; see src/storage/sigma.jl).
