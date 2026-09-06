# VBF benchmark suite

The suite measures public VBF and VBFCatalog APIs. `run.jl` appends one row per
timed repetition to `benchmark` in the project database,
`packages/VBFCatalog/BFA_catalog.sqlite`. It generates no plots, CSV, or LaTeX.
The SQLite database is tracked and must be committed with benchmark changes.

## Run

From the repository root:

```bash
make -C bench quick                         # level 1
make -C bench bench                         # level 2
make -C bench full                          # level 3, expensive searches
make -C bench list                          # no measurements or writes
julia --project=. bench/run.jl --group=constructions --n=6 --target-seconds=0.25
julia --project=. bench/run.jl --reference-family=APN
julia --project=. bench/run.jl --database=/path/to/existing/catalog.sqlite
make -C bench test
```

`BFA_CATALOG_PATH` also overrides the default catalog path. `--database` selects
the destination and reference catalog; catalog-query cases still use the catalog
selected by `BFA_CATALOG_PATH`. Use that environment variable when both should
use the same alternate catalog. An alternate database must already be a catalog.
The default reference scope is all first-class `functions` rows with `is_apn=1`,
restricted to the output dimension and optionally `--reference-family`.
Side corpora and EA/CCZ equivalence are outside this exact-LUT reference scope.

Level 3 can take an hour and needs at least 4 GB free memory. Avoid concurrent
heavy jobs when collecting timings.

## Stored data

Each invocation has a `run_id`; every case repetition has its own `id` and
`repetition`. Warm-up and allocation probes are excluded. Successfully completed
repetitions are committed immediately, so later failures do not erase them.
The console retains the existing minimum/median summary.

| Columns | Meaning |
|---|---|
| `algorithm`, `approach`, `n` | Group/case identifier, analytical grouping, case input dimension; dimensionless cases use NULL |
| `elapsed_seconds` | Wall time of this call, including optional observation overhead; excludes database writes and hashing |
| `time_to_first_apn_seconds` | First verified/constructed APN event; scalar constructors use call completion; NULL if no APN was produced |
| `search_space_size` | Exact decimal integer stored as TEXT to avoid SQLite's 64-bit overflow; NULL when no size is defined |
| `candidates_processed` | Completed candidates evaluated; partial backtracking assignments are excluded |
| `candidates_final_apn_test` | Candidates reaching the full DDT or equivalent QAM rank test |
| `total_apns`, `distinct_apns` | APN events before internal deduplication, and unique `(n, SHA-256(LUT))` identities |
| `known_apns_recovered`, `total_known_apns` | Distinct exact identities recovered, and distinct reference identities in scope |
| `apn_identities_json` | Sorted `[n, sha256]` pairs, enabling unions across runs |
| `reference_scope_json` | Table, filter, output dimensions, identity convention and reference-set digest |
| `parameters_json` | Options, limits, payload snapshot after the call, RNG seed, repetitions, Julia/CPU/thread details, source-tree hash, Git revision and metric semantics |

LUT hashes reuse `VBFCatalog.canonical_lut_bytes`: input order, `ceil(n/8)`
little-endian bytes per output. Equal functions in different dimensions remain
different identities. Trims and extensions use their output dimension for
identities and catalog comparison, while the case's `n` retains its input meaning.
Zero known functions is stored as zero; analysis must guard against zero
denominators. Non-producing operations use NULL for all APN metrics.

Searches use optional `observer(event, value)` callbacks. Events are `:candidate`,
`:final_test`, and `:apn`; only the last carries an SBox. Observers must not mutate
the supplied function. The hooks leave search order, pruning, limits, and return
values unchanged. Candidate units are parameter tuples for the Taniguchi sweep,
completed matrices for QAM, completed LUTs for backtracking, and generated trims
or switching candidates. A pruned subtree is not counted as explicitly processed.
Counts and search-space sizes therefore describe explicit work, not the amount
of space logically excluded by pruning. APNs are observed before EA fingerprint
deduplication. Database writes and identity comparisons happen outside the timer.

Raw counts are retained; coverage, throughput and aggregation are left to later
analysis. Earlier rows may have NULL metrics unavailable to older instrumentation;
their source provenance and metric semantics distinguish them from current runs.

## Schema and extension

Schema 4 includes `src/data/benchmark.sql`. To migrate an existing schema 3 catalog:

```bash
julia --project=. packages/VBFCatalog/data-build/migrations/004_benchmark.jl
```

Migration is transactional and idempotent. A full catalog rebuild copies benchmark
history from the previous database before installing the rebuilt catalog. Run the
required catalog rebuild and `make -C packages/VBFCatalog/data-build check` before
committing database changes; never bypass the hooks.

Cases still register with `bench!(reg; group, name, n, setup, call, ...)`.
Optional `approach`, `parameters` (NamedTuple), and `metrics(payload, value, seconds)`
provide structured metadata. Construction cases wire observers in their registry.
Every expensive search must have explicit limits. Setup remains outside timing;
the harness retains its seed, warm-up, allocation probe, and repetition policy.
For mutating APIs the payload snapshot is the state after the call. Reproduce the
sequence by rerunning the recorded source revision's setup with the stored seed,
then its warm-up, allocation probe, and preceding repetitions.

`export.jl`, `crossings.jl`, `calibrate.jl`, and existing `generated/` artifacts
remain available for historical workflows. Normal benchmark targets do not run
the exporters or refresh those artifacts. `make crossings` explicitly processes
the old CSV; it does not read the new database table.
