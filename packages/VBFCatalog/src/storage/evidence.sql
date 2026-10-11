-- Exact LUT identities also address bulk members, without promoting them into
-- curated entries. Repeated attempts retain their budgets and uncertainty.
CREATE TABLE IF NOT EXISTS equivalence_checks (
    id INTEGER PRIMARY KEY,
    n INTEGER NOT NULL CHECK(n BETWEEN 1 AND 16),
    left_sha256 TEXT NOT NULL CHECK(length(left_sha256) = 64),
    right_sha256 TEXT NOT NULL CHECK(length(right_sha256) = 64),
    relation TEXT NOT NULL CHECK(relation IN ('ea', 'ccz')),
    status TEXT NOT NULL CHECK(status IN ('equivalent', 'inequivalent', 'inconclusive')),
    solver_sha256 TEXT NOT NULL,
    julia_version TEXT NOT NULL,
    created_utc TEXT NOT NULL,
    parameters TEXT NOT NULL,
    evidence TEXT NOT NULL,
    CHECK(left_sha256 <= right_sha256)
);

CREATE INDEX IF NOT EXISTS idx_equivalence_checks_pair
    ON equivalence_checks(n, left_sha256, right_sha256, relation);
