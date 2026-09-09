# VBF benchmark suite

The suite measures public VBF and VBFCatalog APIs (`run.jl`) and registered paper
workloads (`run_papers.jl`). Each runner appends one row per timed repetition to
`benchmark` in `packages/VBFCatalog/BFA_catalog.sqlite`. The raw database remains
the source of truth; benchmark execution generates no plots, CSV, or LaTeX.

Separate Make targets consolidate persisted data with SQLite.jl and DataFrames.jl,
export CSV/Arrow datasets, and generate optional exploratory Plots.jl figures.
Profile, FlameGraphs, ProfileView, and ProfileSVG provide profiling diagnostics;
structured owner/subsystem summaries support thesis analysis. Raw flame graphs
are optional diagnostic artifacts, not the main thesis visualization.

## Reproduce on another computer

The commands below use a Bash shell on Linux, macOS, or Windows through WSL.
Install Julia **1.12 or newer**, Git, GNU Make, and the `sqlite3` command-line
client. Julia downloads package dependencies on the first setup, so that step
requires internet access and a writable Julia depot.

```bash
git clone https://github.com/zambonin/VBF.jl.git
cd VBF.jl
git rev-parse HEAD
julia --version
julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'
git config core.hooksPath .githooks
make -C bench list
make -C bench quick
```

To reproduce a published experiment, check out the commit identified by its
`parameters_json` before instantiating the dependencies. A dirty-source run also
requires the corresponding local changes: a source hash detects a mismatch but
cannot reconstruct those changes. Keep the source revision with the data you
publish. The committed SQLite catalog is sufficient to start collecting results;
there is no need to rebuild it or download the catalog importers' external sources.
For an older database, see the version-specific migrations below.

`quick` runs all available level-1 cases with the default target of one second per
case. It is a benchmark run, not the assertion-based test suite (`make -C bench
test`). Compilation, hashing, database writes, and the repetition cap mean the
total wall time is not simply the number of cases times one second. Some catalog
cases depend on optional corpus files, so another checkout may register fewer
cases. Compare the case list and parameters as well as the timings.

Without Make, the equivalent quick command from the repository root is:

```bash
julia --startup-file=no --project=. bench/run.jl --level=1 --target-seconds=1.0
```

Run one benchmark process at a time, with no competing heavy workload. Keep the
same Julia thread count and reference scope when comparing runs. Hardware,
operating-system scheduling, and Julia versions affect elapsed times; reproduce
the experiment configuration and outputs, not an identical timing. The recorded
CPU, thread count, Julia version, seed, limits, and source fingerprint document
those conditions. Repeated runs append results and do not erase earlier runs.

## Run

From the repository root:

```bash
make -C bench quick                         # level 1
make -C bench bench                         # level 2
make -C bench benchmark                     # alias for bench
make -C bench benchmark-papers              # registered paper workloads
make -C bench benchmark-papers paper=Beierle_202107 mode=paper_specific
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

## Consolidate, export, and plot saved data

Run these commands from the repository root after collecting measurements:

```bash
make -C bench setup-analysis       # install the separate analysis environment
make -C bench consolidate          # rebuild derived datasets from saved inputs
make -C bench inspect-analysis     # list dataset row counts
make -C bench export-all           # export all datasets as CSV and Arrow
make -C bench plots-runtime        # optional exploratory runtime figure
make -C bench plots-profiles       # optional structured subsystem figure
```

Consolidation reads the raw benchmark database and saved profile artifacts,
then transactionally replaces tables in `bench/analysis/generated/analysis.sqlite`.
Exports and plots read that derived database. Run `consolidate` again after new
measurements or analysis changes; neither export nor plotting implicitly refreshes
it. Expensive benchmarks are never required just to regenerate an export or figure.

| Target | Purpose |
| --- | --- |
| `help` | Show benchmark and analysis commands |
| `consolidate` | Rebuild benchmark, core, paper, profile, component, runtime, and provenance datasets |
| `inspect-analysis` | Inspect the persisted analysis dataset sizes |
| `export`, `export-all` | Export every dataset as CSV and Arrow |
| `export-core`, `export-papers` | Export the selected workload datasets |
| `export-profiles` | Export profile sessions and normalized component summaries |
| `plots-runtime`, `plots-approach`, `plots-profiles` | Generate exploratory figures from persisted data |
| `plots` | Generate all available exploratory figures |
| `test-analysis` | Check metrics, joins, profile replay, exports, and raw-data preservation |
| `clean-analysis` | Remove default generated analysis outputs, preserving raw measurements and profiles |

Analysis targets accept `database=PATH`, `profiles=DIR`, and
`analysis_output=DIR`. Pass the same output directory to subsequent exports and
plots. `clean-analysis` only cleans the default `bench/analysis/generated/`
directory; custom output directories are managed explicitly. The historical
`bench/generated/` directory belongs to the separate legacy export workflow.

For interactive analysis, start Julia with `julia --project=bench/analysis`
from the repository root:

```julia
include("bench/analysis/BenchAnalysis.jl")
using .BenchAnalysis, DataFrames

df = derive_metrics(load_benchmarks())
paper_df = load_paper_benchmarks()
core_df = load_core_benchmarks()
profiles = load_profile_summaries()
joined = join_profiles(df, profiles)
selected = filter(:run_id => ==("YOUR_RUN_ID"), joined)
group_by_approach(selected)
group_by_dimension(selected)
group_by_mode(selected)
```

Default summaries retain case, dimension, mode, run, configuration, and source
provenance. Use `runtime_statistics(...; by=[...])` to explicitly choose other
grouping keys. Large raw JSON payloads stay in SQLite by default; row IDs preserve
traceability, and `load_benchmarks(include_raw=true)` retrieves the full payloads.
See [analysis/README.md](analysis/README.md) for detailed APIs and examples.

## Structured profiling

Profiling is a separate opt-in execution, never a benchmark timing measurement:

```bash
julia --project=bench/profiling -e 'using Pkg; Pkg.instantiate()'
julia --project=bench/profiling bench/profile.jl --paper=Beierle_202107 --case=Beierle_202107_algorithm1 --no-svg
make -C bench consolidate
make -C bench export-profiles
```

Saved `Profile.retrieve()` samples and frame dictionaries remain under
`bench/profiles/`. Consolidation reconstructs their FlameGraphs trees and stores
one session row per distinct artifact plus normalized owner/subsystem/operation
rows. ProfileView (`--view`) and SVG exports remain available for diagnostics;
see [profiling/README.md](profiling/README.md).

Exclusive samples belong to the nearest VBF/VBFCatalog or paper frame. External
callees inherit that caller's ownership; stacks with no project owner are
runtime/unattributed. Thus `core_fraction`, `paper_fraction`, and
`runtime_fraction` are sampling estimates, not exact timers or a direct census
of all Julia runtime activity. Sample counts accompany the estimates, and
zero-sample fractions remain missing.

Profiles join to timings only with matching case and execution provenance.
Compatible sessions are sample-weighted before a validated many-to-one join;
sample totals must not be summed over the resulting timing repetitions. Older
profiles without sufficient provenance remain available as standalone summaries
but are not automatically matched to benchmark rows. Implementation modes
(`core_only`, `hybrid`, `paper_specific`) describe workloads independently of
their measured fractions.

## Saving derived data

Use the separate, rebuildable analysis SQLite database plus CSV/Arrow exports.
Raw measurement rows and profile artifacts remain authoritative; derived data
can be discarded and reconstructed without rerunning workloads.

| Representation | Use and trade-off |
| --- | --- |
| Dynamic SQL/DataFrames | Flexible exploration and inexpensive metrics; repeats computation |
| SQL views | Reusable SQL projections without copied data; cannot replay Julia profile artifacts |
| Derived SQLite tables | Reusable joins and profile summaries; require explicit consolidation after changes |
| CSV | Portable, inspectable exchange; does not preserve a full typed schema |
| Arrow | Typed columnar exchange, including missing values; binary rather than human-readable |
| Parquet | An option for larger cross-tool datasets; adds another format and dependency |

The implemented exporters use CSV.jl and Arrow.jl. The analysis provenance table
records its source database snapshot identifiers, analysis source/environment
hashes, Julia version, and attribution rule. Preserve the raw inputs, analysis
sources, and resolved environment with a published result. Do not add derived
fractions to immutable benchmark rows or treat exported files as new raw evidence.

## Access results and verify that a run was saved

From the repository root, open the database read-only:

```bash
sqlite3 -readonly packages/VBFCatalog/BFA_catalog.sqlite
```

At the SQLite prompt, list the recorded invocations:

```sql
.timeout 5000
.headers on
.mode column
.nullvalue NULL

SELECT run_id,
       MIN(recorded_at) AS started_at,
       COUNT(*) AS executions
FROM benchmark
GROUP BY run_id
ORDER BY started_at DESC;
```

Copy the new invocation's `run_id` and replace `YOUR_RUN_ID` in the following
queries. Match its timestamp to your run rather than mixing it with the bundled
historical results. Check both the command's successful exit and the rows: an
interrupted run retains completed repetitions, so its presence alone does not
prove that every selected case finished. The console reports the selected case
count and a final `measured ... cases` summary when the run completes.

```sql
SELECT algorithm, approach, n,
       COUNT(*) AS saved_repetitions,
       MAX(json_extract(parameters_json, '$.reps')) AS expected_repetitions,
       MIN(repetition) AS first_repetition,
       MAX(repetition) AS last_repetition
FROM benchmark
WHERE run_id = 'YOUR_RUN_ID'
GROUP BY algorithm, approach, n
ORDER BY approach, algorithm, n;
```

For every case, `saved_repetitions` and `last_repetition` should match
`expected_repetitions`, and `first_repetition` should be 1. The number of cases
in this query should match the runner's final summary. Inspect raw APN metrics:

```sql
SELECT algorithm, n, repetition, elapsed_seconds,
       time_to_first_apn_seconds, search_space_size,
       candidates_processed, candidates_final_apn_test,
       total_apns, distinct_apns,
       known_apns_recovered, total_known_apns
FROM benchmark
WHERE run_id = 'YOUR_RUN_ID'
ORDER BY algorithm, n, repetition;
```

## Analyze and use the results in a thesis

Start with one compatible invocation. This timing summary keeps `approach` as a
grouping key even if you later omit it from the displayed columns:

```sql
SELECT algorithm, approach, n,
       COUNT(*) AS repetitions,
       MIN(elapsed_seconds) AS minimum_seconds,
       AVG(elapsed_seconds) AS mean_seconds,
       COUNT(time_to_first_apn_seconds) AS repetitions_producing_apns,
       AVG(time_to_first_apn_seconds) AS mean_first_apn_seconds
FROM benchmark
WHERE run_id = 'YOUR_RUN_ID'
GROUP BY algorithm, approach, n
ORDER BY approach, algorithm, n;
```

SQLite ignores NULL in `AVG`: the first-APN mean is conditional on producing an
APN. Report the success count alongside it. The minimum matches the historical
benchmark summary; report your chosen timing statistic and variability explicitly.
Do not combine a minimum time from one repetition with a count from another to
calculate throughput. Compute each repetition's ratio first.

Export the complete selected invocation to CSV for a spreadsheet or Julia analysis:

```sql
.headers on
.mode csv
.nullvalue ""
.once benchmark_tcc.csv

SELECT *
FROM benchmark
WHERE run_id = 'YOUR_RUN_ID'
ORDER BY approach, algorithm, n, repetition;

.quit
```

The CSV is written in the directory where you opened SQLite. Use a new filename
to preserve previous exports. This is an explicit manual export; running the
benchmark itself does not generate CSV, plots, or LaTeX.

Useful derived metrics, computed per execution, are:

- `distinct_apns_per_second = distinct_apns / elapsed_seconds`.
- `known_coverage = known_apns_recovered / total_known_apns`.
- `search_space_coverage = candidates_processed / total_candidates`.

The last formula needs careful interpretation: paper `total_candidates` currently
counts visited search nodes, whereas `candidates_processed` counts complete
candidates. This can be a completion ratio among visited nodes rather than
coverage of the full mathematical search space. When `search_space_size` and
candidate units are defined consistently, `candidates_processed / search_space_size`
is a separate explicitly processed fraction. Event throughput
`total_apns / elapsed_seconds` is also distinct from unique-function throughput.

Guard against zero denominators and retain NULL for inapplicable metrics. Display
NULL as a dash in the thesis, not as zero. Search-space sizes are decimal TEXT
because they can exceed 64-bit integers: use Julia's `parse(BigInt, value)` and
arbitrary-precision arithmetic instead of converting them to SQLite INTEGER or
spreadsheet numbers. Space excluded by pruning is not explicitly processed space.

Do not sum `distinct_apns` across repetitions or algorithms. To count the union of
exact functions produced in an invocation, expand the stored identities:

```sql
SELECT COUNT(*) AS distinct_apns_across_executions
FROM (
    SELECT DISTINCT json_extract(j.value, '$[0]') AS output_n,
                    json_extract(j.value, '$[1]') AS lut_sha256
    FROM benchmark AS b, json_each(b.apn_identities_json) AS j
    WHERE b.run_id = 'YOUR_RUN_ID'
);
```

Distinct LUTs are **not distinct EA/CCZ classes**. Recovering zero exact catalog
representatives is not evidence of a new APN class. A union query also counts only
producing executions: NULL identities on an unrelated API do not certify an
empty APN search. Across invocations, check source versions, limits, candidate
units, output dimensions, and `reference_scope_json` before combining metrics;
never sum the reference denominator across repeated measurements.

For the thesis, group algorithms by approach and present dimension, timing,
processed candidates, total/distinct APNs, and catalog recovery as appropriate.
Document the machine, Julia version, threads, source revision, seeds, limits,
warm-up/repetition policy, and reference scope in the methodology. Record the
selected run IDs with the analysis so every reported result can be traced back
to its raw rows. The initial bundled smoke runs are development checks, not a
complete comparative study. The explicit `plots-*` targets provide exploratory
figures; selecting and composing the final thesis figures remains a separate step.

## Stored data

Each invocation has a `run_id`; every case repetition has its own `id` and
`repetition`. Warm-up and allocation probes are excluded. Successfully completed
repetitions are committed immediately, so later failures do not erase them.
The console retains the existing minimum/median summary.

| Columns | Meaning |
|---|---|
| `algorithm`, `approach`, `n` | Group/case identifier, analytical grouping, case input dimension; dimensionless cases use NULL |
| `paper_id`, `mode` | Paper workload identity and implementation mode; NULL for the public API suite |
| `elapsed_seconds` | Wall time of this call, including optional observation overhead; excludes database writes and hashing |
| `time_to_first_apn_seconds` | First verified/constructed APN event; scalar constructors use call completion; NULL if no APN was produced |
| `search_space_size` | Exact decimal integer stored as TEXT to avoid SQLite's 64-bit overflow; NULL when no size is defined |
| `candidates_processed` | Completed candidates evaluated; partial backtracking assignments are excluded |
| `total_candidates` | Paper search nodes visited, including partial nodes when reported; not necessarily the full search-space size |
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

Raw counts are retained; the separate analysis layer derives coverage, throughput,
and grouped summaries. Earlier rows may have NULL metrics unavailable to older instrumentation;
their source provenance and metric semantics distinguish them from current runs.

## Schema and extension

Schema 4 introduced the benchmark table. Schema 5 added paper provenance, and
schema 6 consolidated overlapping paper counters into the existing metric
columns. Check an older catalog's version before running migrations:

```bash
sqlite3 -readonly packages/VBFCatalog/BFA_catalog.sqlite 'SELECT schema_version FROM schema_meta;'
```

Run only the required steps, in order: 004 for version 3, then 005 for version 4,
then 006 for version 5. A version 6 catalog needs none of these migrations.

```bash
julia --project=. packages/VBFCatalog/data-build/migrations/004_benchmark.jl
julia --project=. packages/VBFCatalog/data-build/migrations/005_paper_provenance.jl
julia --project=. packages/VBFCatalog/data-build/migrations/006_consolidate_paper_columns.jl
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
Payload metadata stores functions by module/name. Arrays with more than 256
elements store their Julia type and dimensions; opaque objects store their type.
Reconstruct these inputs through setup and the recorded seed/call sequence. This
avoids copying large input buffers into every timing row and does not remove any
raw benchmark counts or APN identities.

`export.jl`, `crossings.jl`, `calibrate.jl`, and existing `generated/` artifacts
remain available for historical workflows. Normal benchmark targets do not run
the exporters or refresh those artifacts. `make crossings` explicitly processes
the old CSV; it does not read the new database table.
