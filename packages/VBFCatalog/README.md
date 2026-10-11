# VBFCatalog

Source inputs, adapters and a query API for VBF functions. Mathematics comes from
VBF. Searches, proof histories and reference snapshots belong to VBFSearch.

```
src/
  VBFCatalog.jl     package entry and exports
  catalog.jl       paths, LUT identities and function queries
  sources.jl       shared curated-definition loader
  bibliography.jl BibTeX reader
  corpus.jl        packed corpus storage and reconstruction
  records.jl       immutable LUT/coefficient input reader
  sigma.jl         regenerable signature index and coverage queries
  build.jl         deterministic SQLite writer
  schema.sql       generated database schema
  import/          pinned source adapters and build commands
  data/            tracked source inputs only
```

`src/data/` is the only data directory in this package. Its `sources.toml` records
source locations, pins, adapters, corpus checksums, counts and provenance.
`apn.toml`, `literature_sboxes.toml` and `sporadic.toml` hold curated definitions;
`bibliography.bib` holds their citations. `luts/` contains immutable input files,
including compressed coefficients published from VBFSearch.

## Build and use

Requires Julia >= 1.12. From the repository root:

```sh
julia --project=packages/VBFCatalog/src/import -e 'using Pkg; Pkg.instantiate()'
make -C packages/VBFCatalog/src/import catalog
make -C packages/VBFCatalog/src/import check
```

The build fetches missing pinned Git sources, verifies their revisions and input
bytes, builds a staging database and installs it atomically. It does not read a
previous catalog or search run. `make ... reproducible` compares two complete
builds byte for byte; reproduction requires identical inputs, code and Julia/SQLite
versions. CI rebuilds the database and passes it to consumer jobs as an artifact.

```julia
using VBF, VBFCatalog
db = load_catalog()
try
    list_functions(db; n=8, is_apn=true)
    load_sbox(db, "AES")
    list_corpora(db)
    corpus_function(db, "edelpott2009_n8", 1)
finally
    close(db)
end
```

Generated SQLite, downloaded originals and materialized records live under the
workspace's ignored `.cache/vbfcatalog/`. `BFA_DATA_DIR` overrides this cache;
`BFA_SOURCE_DIR` overrides source inputs; `BFA_CATALOG_PATH` overrides the database.
Using the package does not fetch data or launch a build. A missing database
reports the build command.

Large external corpora are declared without downloading their members. Install
the Beierle dataset explicitly when needed:

```sh
make -C packages/VBFCatalog/src/import fetch SOURCE=beierle2025
make -C packages/VBFCatalog/src/import convert SOURCE=beierle2025 threads=30
make -C packages/VBFCatalog/src/import index threads=30
```

Members use VBF's 37-byte quadratic coefficients, sufficient to reconstruct an
8-bit LUT. Counts and ordered coefficient digests bind each corpus independently
of SQLite's page layout. `with_corpus_rows` streams members; `corpus_digest`
checks their ordered bytes. Missing external members fail explicitly.

Sigma hashes are derived lookup keys. Absence separates a verified quadratic APN
only from the covered reference; a matching hash requires an equivalence check.
The index records missing coverage and refuses unsupported absence claims.
Classification and saved witnesses are documented in
[VBFSearch](../VBFSearch/README.md).

To add source data, update its definition or immutable input and its manifest
entry, rebuild, and pass the gate before committing. Commit inputs, adapters and
README changes; generated databases stay out of git. Paper-to-citation mapping
belongs to VBFRepro, and archived research/run evidence to `VBFSearch/data/`.
