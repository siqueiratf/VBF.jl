# Catalog ingestion

Use the [package guide](../../README.md) for entry formats, storage and rebuilding.
`Makefile` is a thin wrapper over the Julia scripts here. `packages/VBFCatalog/src/data/sources.toml` is the
source registry; fetching and importing use the same pins. Parser helpers are
shared rather than duplicated between ingestion and reference rebuilding.
`make fetch SOURCE=NAME` retains originals under `packages/VBFCatalog/data/raw/` and
`make convert SOURCE=NAME` calls the registered `convert_X.jl`. Fixed LUTs and
corpus metadata are declared in TOML, with one common function-row writer.

Search discoveries freeze deterministic `quadratic_coeffs` gzip inputs in
`src/data/luts/` and declarations in `src/data/corpora.toml`. The common
`import_lut_corpus!` reader checks checksums, count, APN property, degree and
separating signatures using VBF, then packs members into the catalog. Original
run evidence remains local under `data/search/`.

`make catalog` builds from the pinned registry and declarations without reading
an old catalog. It verifies a staging database, rewrites rows in a fixed order
and replaces the tracked file atomically. Missing or changed inputs fail.
`make reproducible` builds twice and compares their SHA-256 digests. Reproduction
requires the same input bytes, Julia/SQLite versions and implementation. Local
external-member receipts are verified before reuse; `BFA_REIMPORT=1` forces import.

A source-comparison snapshot is built in three sequential stages:

```sh
julia --project=packages/VBFCatalog/src/import packages/VBFCatalog/src/import/reference/fetch.jl /path/to/reference
make -C packages/VBFCatalog/src/import stored OUTDIR=/path/to/reference threads=16
make -C packages/VBFCatalog/src/import raw OUTDIR=/path/to/reference threads=16
make -C packages/VBFCatalog/src/import compare OUTDIR=/path/to/reference
```

The first command fetches the pinned originals and records their byte hashes,
including the public Langevin binary dump. Rebuilding uses VBF's APN, degree and
signature APIs. It records rejected nonquadratic source positions explicitly.
Comparison requires complete inputs, checks original/stored LUT and signature
sets, compares the derived index and emits `comparison.toml` plus
`fresh_union.sqlite`. Consumers open these with `open_apn_reference`.

Each rebuild checkpoints committed batches and binds inputs, provenance,
computation source, environment and Julia version. Repeat the same command to
resume. Changed identities are rejected: choose a new output directory.
For a bounded smoke run, invoke `reference/rebuild.jl stored --outdir DIR --limit N`;
its coverage remains incomplete. These commands do not compare search candidates;
use VBFSearch for candidate validation and equivalence checks.

VBFSearch normally reads the catalog index directly using
`open_catalog_reference()`, freezing its verified source set and logical digest.
It does not require an additional reference snapshot or supplemental TSV.

`make index` rebuilds the runtime signature index. On a fresh clone without the
large bulk store, skipped datasets remain explicit coverage gaps and affected
novelty queries refuse a definitive result. `make check` runs the Julia
source/database agreement check and package tests. There is no Python verifier,
historical-path adapter, migration runner or selective in-place catalog sync.

`make classify threads=30 CLASSIFY_ARGS='--n 8 --seconds 1'` deduplicates the
repeated-signature buckets and checkpoints native EA/CCZ classification evidence.
Repeat with a larger budget to retry unresolved pairs; completed checks are
reused. See the package guide for the SQL summary and precise guarantees.
