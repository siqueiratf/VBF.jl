-- Migration 003 -> 004: add the σ-signature novelty index (ccz_sigma_index).
-- Auxiliary table only; no existing table altered. Idempotent.
CREATE TABLE IF NOT EXISTS ccz_sigma_index (
    sigma_hash  TEXT    NOT NULL,
    n           INTEGER NOT NULL,
    source      TEXT    NOT NULL,
    member_idx  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ccz_sigma_hash ON ccz_sigma_index(sigma_hash, n);
CREATE INDEX IF NOT EXISTS idx_ccz_sigma_src  ON ccz_sigma_index(source);
UPDATE schema_meta SET schema_version = 4;
