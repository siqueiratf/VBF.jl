# Catalog ingestion

Use the [package guide](../../README.md) for entry formats, storage and rebuilding.
`Makefile` is a thin wrapper over the Julia scripts here. `sources.toml` is the
source registry; fetching and importing use the same pins. Parser helpers are
shared rather than duplicated between ingestion and reference rebuilding.

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

`make index` rebuilds the runtime signature index. On a fresh clone without the
large bulk store, skipped datasets remain explicit coverage gaps and affected
novelty queries refuse a definitive result. `make check` runs the Julia
source/database agreement check and package tests. There is no Python verifier,
historical-path adapter, migration runner or selective in-place catalog sync.
