# VBFCatalog

The canonical function and dataset layer for VBF. VBF supplies the mathematics;
VBFCatalog owns curated entries, original-source ingestion, citations and queries.
Searches and paper reproductions consume this package.

Only `src/`, `test/` and the optional `perf/` environment contain package code.

| Location | Purpose |
|---|---|
| `src/data/` | Runtime loaders, queries, corpus access and derived indexes |
| `src/entries/apn_catalog/n*_apn.toml` | Curated APN definitions: explicit LUTs or constructor parameters, with citations |
| `src/entries/literature_sboxes.toml` | Curated literature S-box LUTs and metadata |
| `src/entries/bibliography.bib` | Citation records referenced by function and dataset `bib_key`s |
| `src/import/sources.toml` | Import order, source locations, pinned revisions and published checksums |
| `src/import/` | Fetching, parsers, importers, rebuilding and source-agreement checks |
| `src/import/reference/` | Checkpointed original-source signature rebuilds and comparison snapshots |
| `test/` | Runtime, import, storage, corruption and checkpoint tests |
| `perf/` | Optional BenchmarkTools measurements of query/loading/index APIs |

These TOMLs are source declarations, not competing catalogs. The SQLite file is
their generated queryable form. The bibliography is provenance and is retained.
There are no schema migrations or empty artifact registries; schema changes
require a rebuild.

## Storage

`BFA_catalog.sqlite` is the single tracked catalog. It contains curated LUTs,
citations, equivalence metadata, dataset descriptors and the compact members of
small bundled corpora. Corpora share `corpus_members(corpus, idx, coeffs)`;
there is no database per family. Member IDs remain local to each named dataset.

Downloaded large datasets share `data/catalog/members.sqlite`, with the same
schema. The default currently stores Beierle's millions-record corpus locally.
Keeping that extension out of git permits small checkouts. Dataset descriptors
remain in the authoritative catalog. Coefficients reconstruct LUTs using VBF;
they are not separate function definitions.

`data/catalog/ccz_sigma_index.sqlite` and the optional fingerprint index are
regenerable lookup indexes. `data/catalog/sources/` holds originals and
`imports.toml` holds local import receipts. Override this local directory with
`BFA_DATA_DIR`; override the catalog file with `BFA_CATALOG_PATH`.

`store_sha256` binds the concatenated fixed-width encodings in increasing member
order, rather than SQLite's page layout. Its count, encoding and width are in
the descriptor. `corpus_digest(db, name)` recomputes it. `with_corpus_rows` streams
records without consumers opening private tables; `corpus_function` retrieves
one reconstructed SBox. Different datasets retain separate names and provenance
within the shared table, even when they overlap.

Old benchmark measurements were preserved locally in
`data/perf/archive/catalog-benchmarks.sqlite`; measurements are no longer stored
in the catalog. New timings belong under `data/perf/`.

## Import and rebuild

```sh
julia --project=packages/VBFCatalog/src/import -e 'using Pkg; Pkg.instantiate()'
make -C packages/VBFCatalog/src/import fetch
make -C packages/VBFCatalog/src/import catalog
make -C packages/VBFCatalog/src/import check
```

Fetching explicitly downloads the registered public sources, including the
3.4 GB Beierle text. For a single source, run
`julia --project=packages/VBFCatalog/src/import packages/VBFCatalog/src/import/fetch.jl simonberg`.
Local overrides such as `BFA_SBOXU_PATH`, `BFA_THESIS_PATH` and
`BFA_BEIERLE2025_PATH` accept existing originals. Optional sources without a
registered upstream still require their declared local override.

The full build assembles a staging catalog, rejects lost function families or corpus members, and
checks bundled data before installing it. Import scripts run in isolated modules
and use VBF for mathematics. They are not loaded by `using VBFCatalog`.
Unchanged large imports can reuse a receipt binding original bytes, packed member
bytes, count, encoding, field modulus, dimensions and relevant source code.
`BFA_REIMPORT=1` recomputes them.
Run rebuilds with exclusive access to local bulk data and indexes.

The constructor sweep defaults to `--max-n 11`; increasing it changes catalog
contents. Run the catalog gate before committing any catalog change.

## Reference and novelty scope

The [reference rebuild commands](src/import/README.md) produce digest-bound
comparison snapshots using VBF. Partial runs cannot certify full source coverage.
Rebuild indexes after a content change; changing storage alone does not alter
function signatures.

Absence separates a quadratic APN candidate from the covered quadratic reference
through the separating invariant. A matching signature requires an equivalence
check. Neither database size nor absence from it certifies that all published
constructions or all APN functions have been covered. VBFSearch owns candidate
validation and equivalence evidence; VBFCatalog supplies the reference data.
