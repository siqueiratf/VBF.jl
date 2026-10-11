# VBFCatalog

The canonical function and dataset layer for VBF. VBF supplies the mathematics;
VBFCatalog provides original-source ingestion and catalog queries. Shared source
data and citations live in this package's `src/data/` directory.
Searches and paper reproductions consume this package.

Package code lives in `src/`, `test/` and optional `perf/`. The self-contained
`src/data/` directory holds declarative catalog resources; other packages reference them.

| Location | Purpose |
|---|---|
| `src/storage/` | Runtime loaders, queries, corpus access and derived indexes |
| `packages/VBFCatalog/src/data/apn/n*_apn.toml` | Curated APN definitions: LUTs or constructor parameters, with citations |
| `packages/VBFCatalog/src/data/literature_sboxes.toml` | Curated literature S-box LUTs and metadata |
| `packages/VBFCatalog/src/data/sporadic.toml` | Fixed literature functions formerly embedded in Julia |
| `packages/VBFCatalog/src/data/corpora.toml` | Dataset files, readers, names and citations |
| `packages/VBFCatalog/src/data/bibliography.bib` | Shared citations for VBF, catalog entries and reproductions |
| `packages/VBFCatalog/src/data/publications.toml` | VBFRepro slug-to-citation-key mapping |
| `packages/VBFCatalog/src/data/sources.toml` | Source locations, pins, checksums and converter names |
| `src/import/` | Fetching, raw-format converters, one shared writer and rebuilding |
| `src/import/reference/` | Checkpointed original-source signature rebuilds and comparison snapshots |
| `test/` | Runtime, import, storage, corruption and checkpoint tests |
| `perf/` | Optional BenchmarkTools measurements of query/loading/index APIs |

These TOMLs are source declarations, not competing catalogs. The SQLite file is
their generated queryable form. The bibliography is provenance and is retained.
There are no schema migrations or empty artifact registries; schema changes
require a rebuild.

## Storage

`packages/VBFCatalog/src/data/catalog.sqlite` is the single tracked catalog. It contains curated LUTs,
citations, build input digests, dataset descriptors and the compact members of
small bundled corpora. Corpora share `corpus_members(corpus, idx, coeffs)`;
there is no database per family. Member IDs remain local to each named dataset.

Downloaded large datasets share `packages/VBFCatalog/data/members.sqlite`, with the same
schema. The default currently stores Beierle's millions-record corpus locally.
Keeping that extension out of git permits small checkouts. Dataset descriptors
remain in the authoritative catalog. Coefficients reconstruct LUTs using VBF;
they are not separate function definitions.

`packages/VBFCatalog/data/ccz_sigma_index.sqlite` is a regenerable lookup index. `packages/VBFCatalog/data/raw/` holds originals and
`imports.toml` holds local import receipts. Override this local directory with
`BFA_DATA_DIR`; override declarations with `BFA_SOURCE_DIR` and the catalog file with `BFA_CATALOG_PATH`.

`store_sha256` binds the concatenated fixed-width encodings in increasing member
order, rather than SQLite's page layout. Its count, encoding and width are in
the descriptor. `corpus_digest(db, name)` recomputes it. `with_corpus_rows` streams
records without consumers opening private tables; `corpus_function` retrieves
one reconstructed SBox. Different datasets retain separate names and provenance
within the shared table, even when they overlap.

Old benchmark measurements were preserved locally in
`packages/VBF/perf/data/archive/catalog-benchmarks.sqlite`; measurements are no longer stored
in the catalog. New timings belong under `packages/VBF/perf/data/`.

## Stored equivalence checks

`equivalence_checks` in local `data/equivalence_checks.sqlite` retains pair attempts, including checks
between reconstructed corpus members. Each row binds the dimension and exact
LUT hashes to `relation` (`ea` or `ccz`), `status` (`equivalent`, `inequivalent`,
or `inconclusive`), UTC time, Julia version, VBF source digest, parameters and
TOML evidence. Positive evidence contains an affine graph witness; negative
evidence records complete native solver exhaustion. Budget stops remain
inconclusive. Checks do not change the tracked catalog. Rebuilding it leaves local evidence intact.
For an alternate catalog path, the evidence file is `<path>.checks.sqlite`.

```julia
using VBF, VBFCatalog
db = load_catalog()
try
    F = corpus_function(db, "edelpott2009_n8", 1)
    G = corpus_function(db, "edelpott2009_n8", 2)
    check = check_equivalence!(db, F, G; relation=:ccz,
        timeout_seconds=30, max_nodes=1_000_000)
    check.status
    list_equivalence_checks(db, F, G)
    verify_equivalence_check(check, F, G) # replays positive evidence only
finally
    close(db)
end
```

Checks reuse verified positives and negatives computed with the same VBF source
digest and Julia version. Inconclusive pairs can be retried with larger budgets;
`reuse=false` records a new attempt. Witness orientation follows the sorted LUT
hashes; verification accepts either input order. Checked LUTs remain in their
original catalog or corpus, rather than becoming new curated entries.

Stored outcomes are directly queryable:

```sql
SELECT status, COUNT(*) AS attempts
FROM equivalence_checks
WHERE n = 8 AND relation = 'ccz'
GROUP BY status;
```

This counts attempts, not classes. The API does not automatically resolve every
signature bucket or modify class memberships. Exhaustive negatives remain
implementation-dependent computational evidence, and EA negatives need a
theorem before they can be interpreted as CCZ negatives. Reference completeness
and literature novelty are separate questions.

## Corpus classification

```sh
make -C packages/VBFCatalog/src/import classify threads=30 \
    CLASSIFY_ARGS='--n 8 --seconds 1 --nodes 1000000 --algorithm optimized'
```

Repeat the command to resume, increasing the per-pair `--seconds` or `--nodes`
budget if necessary. `--pairs N` bounds newly attempted pairs in one invocation.
The APIs are `deduplicate_signature_buckets!`, `classify_signature_buckets!`,
and `classification_summary`. Both native algorithm profiles are available;
budgets include solver work and exhausted budgets remain inconclusive.

Preparation verifies source coverage, packed corpus digests and the exact index
snapshot. Repeated-signature members are reconstructed with VBF, their APN
signatures rechecked, and exact LUT duplicates collapsed with byte comparison.
Every original source/member alias is retained. Singleton signatures already
certify distinct LUTs and distinct classes against other signatures.

The derived index stores `ccz_bucket_members` (aliases), `ccz_bucket_luts` (one
verified LUT per content address), `ccz_bucket_results` (components and unresolved
pairs), and `ccz_classification_meta` (input snapshot digest and coverage).
Preparation checkpoints complete buckets; changed inputs require an explicit
`rebuild=true`. Local pair evidence survives those cache rebuilds.
After changing curated functions, rebuild the signature index: numeric function
row IDs are not stable identities.

Classification uses bounded native EA recovery on the verified quadratic APNs,
where EA and CCZ equivalence coincide. Positive graph witnesses join components;
exhaustive negatives separate them. Threads compute outcomes and one SQLite
writer commits bounded batches. Saved positives are replayed when resuming;
negatives are reused only for matching solver sources and Julia version.
No equivalence is inferred merely from matching signatures.

The last checkpoint is directly queryable in `ccz_sigma_index.sqlite`:

```sql
SELECT class_count_lower_bound, component_count_upper_bound,
       exact_class_count, unresolved_component_pairs
FROM ccz_classification_summary
WHERE n = 8;
```

`exact_class_count` is NULL until every repeated bucket is prepared and all
remaining components are separated. Counts describe the frozen indexed corpus,
whose digest is exposed by the view, and depend on the recorded VBF computation.
They do not classify every APN in dimension eight or certify literature coverage.
While a bucket is running, committed pair checks may be newer than its derived
summary; resuming reconstructs components from those checks.

The completed n=8 run on 2026-10-10 covered 4,005,445 indexed records and
3,808,491 signatures. Its 44 repeated buckets contained 196,998 records;
byte-checked LUT deduplication retained 196,922 LUTs and 76 duplicate aliases.
All 196,878 representative comparisons produced replayed EA witnesses, resolving
each bucket to one class with no unresolved pairs. Thus this indexed quadratic
corpus contains 3,808,491 CCZ classes. The input SHA-256 is
`4b6a683e4a07a58e1a3ac7c5d7ea3475fd42bc0473b4288e2495277d861c6b07`;
the VBF source SHA-256 is
`0f1cbd789ef0fa8b7bd02845292946eecbc2f0319f0d9484faa448c40ea6d1ba`.
The run used Julia 1.13.1, 30 threads, the optimized native algorithm, a
one-second timeout and a 1,000,000-node limit per pair. Pair witnesses remain in
local `data/equivalence_checks.sqlite` across rebuilds; the derived classification can be regenerated.

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

The full build assembles a staging catalog, checks declared function-family and corpus counts, and
checks bundled data before installing it. Converters run in isolated modules
and use VBF for mathematics. `write.jl` computes properties and inserts normalized
rows once; SQLite handles uniqueness and relational constraints. These scripts
are not loaded by `using VBFCatalog`.
Unchanged large imports can reuse a receipt binding original bytes, packed member
bytes, count, encoding, field modulus, dimensions and relevant source code.
`BFA_REIMPORT=1` recomputes them.
Run rebuilds with exclusive access to local bulk data and indexes.

The constructor sweep and all active sources are pinned in `src/data/sources.toml`.
Missing required originals, changed revisions or checksums fail the build. Ambient
optional downloads, an old catalog, proof history, git HEAD and the wall clock
are not inputs. Source files and their byte digests are recorded in `source_inputs`.
Metadata binds those digests and the Julia/SQLite versions and implementation.
Rows are rewritten in a fixed order before atomic installation. With identical
inputs, code and toolchain, `make ... reproducible` compares two complete builds
byte for byte. `BFA_REIMPORT=1` disables the verified external-record cache.

Bundled corpora pack 1,024 fixed-width coefficient records per SQLite row; public
member IDs and ordered content digests are unchanged. Eight-bit quadratic records
use 37 bytes, sufficient to reconstruct their LUTs. Sigma hashes are useful
filters but cannot reconstruct functions or establish equivalence on a match,
so they remain a derived index rather than the tracked dataset representation.

VBFSearch publication freezes coefficients in `src/data/luts/<name>.coeffs.gz`
using gzip without timestamps, and appends the checksum, count, ordered coefficient
digest and run provenance to `corpora.toml`. Rebuilds consume that immutable input
without reopening the run or recovering records from a previous database. Full
search/checkpoint/proof evidence stays under local `data/search/`.

Curated equivalence classes are also derived evidence: `make ... classes` writes
`data/curated_classes.sqlite`. `ccz_class_representatives` checks its input and
solver digests before returning EA-confirmed classes through dimension seven.
Larger sigma buckets remain unconfirmed. Run the catalog gate before committing
any catalog change.

## Reference and novelty scope

VBFSearch now uses `open_catalog_reference()` directly. It checks index coverage,
source member digests and curated LUT identities, then freezes the source set in
each run. Adding a corpus leaves that run's comparison scope unchanged; changing
one of its covered sources refuses resume. A regenerated index with identical
logical records has the same digest.

The former root `data/` directory was inspected and removed. Unique APN research
evidence lives in `data/research/`, and current searches in `data/search/`.
Other packages own their performance, reproduction and manuscript results.
Over 12 GB of byte-identical downloads, superseded reference databases and
duplicate test inputs were removed after checking reference inclusion and
recovering candidates. Unique source snapshots and matching-signature LUTs were
retained.

The recovered archive contained 114,062 verified records and 111,835 distinct
LUTs. Before registration, 111,009 signatures were absent from the expanded
public reference (3,809,038 signatures): the earlier 110,868 plus 141 from later
runs. Missing public inputs contributed 546 Langevin signatures and one public
Galissant slide example. These are separate provenance-labelled corpora; they
are not discoveries. The recovered discovery corpus is `legacy20261009_n8`.

The expanded snapshot covers 4,117,001 indexed records and **3,920,047 CCZ
classes**. Its 44 shared buckets remain completely resolved: 76 exact duplicate
aliases, 196,922 distinct shared-bucket LUTs, and 196,878 retained positive
witnesses. Replaying this evidence required zero new solver attempts. The input
digest is `74ab08f0e92f7eb9e731249ea34a5a6aa50d0db532750124f83b6f1b6a41bf65`.
This is an exact computational count for the covered quadratic corpus, with
the same mathematical and implementation assumptions described above.

`src/data/corpora.toml` binds immutable public TSV and normalized coefficient
inputs to counts, checksums and provenance. `import_lut_corpus!` verifies their
quadratic APN properties using VBF. VBFSearch publication freezes coefficient
inputs under `src/data/luts/`; clean rebuilds require those inputs and do not
consult a previous catalog or local run database.

After appending and indexing corpora, explicitly regenerate classification:

```sh
make -C packages/VBFCatalog/src/import classify threads=30 \
    CLASSIFY_ARGS='--n 8 --rebuild true --pairs 0'
```

This replays stored positive witnesses while rebinding the classification to
the expanded input. If unresolved buckets remain, run the usual budgeted
classification command. The archive assessment and bounded replay result are in
[the replay recipe](data/search/legacy20261009/replay.toml).

The [reference rebuild commands](src/import/README.md) produce digest-bound
comparison snapshots using VBF. Partial runs cannot certify full source coverage.
Rebuild indexes after a content change; changing storage alone does not alter
function signatures.

Absence separates a quadratic APN candidate from the covered quadratic reference
through the separating invariant. A matching signature requires an equivalence
check. Neither database size nor absence from it certifies that all published
constructions or all APN functions have been covered. VBFSearch owns candidate
validation and run evidence; VBFCatalog supplies reference data and shared
equivalence evidence with persistent pair checks.
