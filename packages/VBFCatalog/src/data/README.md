# Catalog inputs

This directory owns curated APN definitions (`apn/`), literature and sporadic
LUTs, bibliography and publication identities, source pins (`sources.toml`),
dataset declarations (`corpora.toml`) and immutable normalized inputs (`luts/`).
`catalog.sqlite` is their deterministic generated queryable form.

Eight-bit quadratic inputs can be frozen as 37-byte VBF coefficient records in
gzip streams without timestamps. Declarations bind transport checksums, ordered
record digests, counts and provenance. Search runs themselves remain local.

See the [package guide](../../README.md) for rebuilding and checking. Raw
originals, large downloaded records, signatures, proofs and research evidence
live under package-level `data/` and are excluded from the tracked catalog.
