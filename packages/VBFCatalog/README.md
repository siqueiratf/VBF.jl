# VBFCatalog

The canonical function and dataset layer for VBF. VBF supplies the mathematics;
VBFCatalog provides original-source ingestion and catalog queries. Shared source
data and citations live in this package's `data/` directory.
Searches and paper reproductions consume this package.

Package code lives in `src/`, `test/` and optional `perf/`. The self-contained
`data/` directory holds all catalog resources; other packages reference them.

| Location | Purpose |
|---|---|
| `src/data/` | Runtime loaders, queries, corpus access and derived indexes |
| `packages/VBFCatalog/data/apn/n*_apn.toml` | Curated APN definitions: LUTs or constructor parameters, with citations |
| `packages/VBFCatalog/data/literature_sboxes.toml` | Curated literature S-box LUTs and metadata |
| `packages/VBFCatalog/data/sporadic.toml` | Fixed literature functions formerly embedded in Julia |
| `packages/VBFCatalog/data/corpora.toml` | Dataset files, readers, names and citations |
| `packages/VBFCatalog/data/bibliography.bib` | Shared citations for VBF, catalog entries and reproductions |
| `packages/VBFCatalog/data/publications.toml` | VBFRepro slug-to-citation-key mapping |
| `packages/VBFCatalog/data/sources.toml` | Source locations, pins, checksums and converter names |
| `src/import/` | Fetching, raw-format converters, one shared writer and rebuilding |
| `src/import/reference/` | Checkpointed original-source signature rebuilds and comparison snapshots |
| `test/` | Runtime, import, storage, corruption and checkpoint tests |
| `perf/` | Optional BenchmarkTools measurements of query/loading/index APIs |

These TOMLs are source declarations, not competing catalogs. The SQLite file is
their generated queryable form. The bibliography is provenance and is retained.
There are no schema migrations or empty artifact registries; schema changes
require a rebuild.

## Storage

`packages/VBFCatalog/data/catalog.sqlite` is the single tracked catalog. It contains curated LUTs,
citations, equivalence metadata, dataset descriptors and the compact members of
small bundled corpora. Corpora share `corpus_members(corpus, idx, coeffs)`;
there is no database per family. Member IDs remain local to each named dataset.

Downloaded large datasets share `packages/VBFCatalog/data/members.sqlite`, with the same
schema. The default currently stores Beierle's millions-record corpus locally.
Keeping that extension out of git permits small checkouts. Dataset descriptors
remain in the authoritative catalog. Coefficients reconstruct LUTs using VBF;
they are not separate function definitions.

`packages/VBFCatalog/data/ccz_sigma_index.sqlite` and the optional fingerprint index are
regenerable lookup indexes. `packages/VBFCatalog/data/raw/` holds originals and
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

For one source:

```sh
make -C packages/VBFCatalog/src/import fetch SOURCE=simonberg
make -C packages/VBFCatalog/src/import convert SOURCE=simonberg
```

The flow is `URL or local original -> convert_X.jl -> normalized LUTs/coefficients
-> catalog.sqlite`. Originals retain their published filenames and formats in
`packages/VBFCatalog/data/raw/`; upstream Python files are parsed as data, never executed.
Large converters stream into the compact store, avoiding another full copy in a
temporary database. The full build writes a staging database instead.
Converters are safe to include and start only when explicitly called.

Fetching explicitly downloads the registered public sources, including the
3.4 GB Beierle text. For a single source, run
`julia --project=packages/VBFCatalog/src/import packages/VBFCatalog/src/import/fetch.jl simonberg`.
Local overrides such as `BFA_SBOXU_PATH`, `BFA_THESIS_PATH` and
`BFA_BEIERLE2025_PATH` accept existing originals. Optional sources without a
registered upstream still require their declared local override.

The full build assembles a staging catalog, rejects lost function families or corpus members, and
checks bundled data before installing it. Converters run in isolated modules
and use VBF for mathematics. `write.jl` computes properties and inserts normalized
rows once; SQLite handles uniqueness and relational constraints. These scripts
are not loaded by `using VBFCatalog`.
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
