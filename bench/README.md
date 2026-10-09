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

## Native partition refinement comparison

These historical performance comparisons explicitly select
`algorithm=:optimized`: bounded deterministic weights, canonical cell order
and quadratic root symmetry. The default `algorithm=:paper` follows the
paper's random-key and prescribed ordered-partition steps. These timings do
not describe the paper profile; see the conformance document under `docs/src/`.

The native CCZ/EA recovery algorithm is credited to Nikolay Kaleyski and Joakim
Sunde, [ePrint 2026/940](https://eprint.iacr.org/2026/940). A standalone runner
compares VBF's public `partition_refinement_equivalence` against their
[C++ reference core](https://github.com/zskiley/CCZ-EA-equivalence), on identical
seeded truth tables. It uses temporary files and leaves the catalog database
untouched. No reference implementation or paper PDF is vendored.

```bash
git clone https://github.com/zskiley/CCZ-EA-equivalence /tmp/CCZ-EA-equivalence
git -C /tmp/CCZ-EA-equivalence checkout c9cec6515b3297abf5c15fedd23e55b43f2ba888
julia --startup-file=no --project=. bench/compare_partition_refinement.jl \
  --reference=/tmp/CCZ-EA-equivalence --samples=5
# Add --hard to include the more expensive seven-bit Gold negative case.
# Use the paper profile with the same quadratic translation subgroup:
julia --startup-file=no --project=. bench/compare_partition_refinement.jl \
  --reference=/tmp/CCZ-EA-equivalence --samples=7 --hard \
  --algorithm=paper --translations=quadratic
# To measure Algorithm 7 without any supplied group, use:
# --algorithm=paper --translations=none
# --only=case1,case2 limits the run to named fixtures.
```

The runner compiles C++17 with `g++ -O3 -DNDEBUG -march=native` to match Julia's
use of the host CPU, warms both implementations,
reports median wall times, and checks every decision and recovered witness.
It also reports the minimum and maximum sampled wall times.
Timings include graph construction, preprocessing and search, excluding JIT,
compilation, fixture I/O and the driver's independent certificate checks.
The C++ timer now includes completion of the point correspondence to a full
ambient affine certificate. The historical table below predates this timing
boundary correction and excluded that small completion cost on the C++ side.

The runner defaults to `--algorithm=optimized --translations=quadratic`,
preserving the original comparison's root-symmetry policy. In
`--algorithm=paper --translations=quadratic`, both sides construct and supply
Lemma 14's quadratic translation generators during each timed call; Julia
also validates the supplied affine generators through its native solver API.
`--algorithm=paper --translations=none` supplies no group on either side.
The optimized profile automatically prunes quadratic root symmetry, so the
runner rejects `--algorithm=optimized --translations=none` as a mismatched
comparison. No mode discovers or supplies a general automorphism group.
The reference
process has a 180-second limit for the whole batch; native searches have
120-second and one-million-node limits per call. An inconclusive result fails
the comparison. Metadata records Julia/compiler/CPU, source revision, native
and reference source SHA-256 hashes, seed and sample count.

The two implementations follow different refinement heuristics: Julia follows
the paper's ordering of initial hyperplane classes by absolute Walsh value and
retains signed incidence signatures; the pinned C++ version selects the
smallest classes and takes absolute signatures. The paper profile also uses
fresh shared random keys and preserves the prescribed ordered partitions.
These timings compare complete
recovery procedures, not identical instruction sequences. This comparison
disables general automorphism discovery and stabilizer pruning on both sides;
workloads using a precomputed group are outside its scope. The separate
optimization runner below includes group discovery and stabilizer pruning.
Performance is instance-dependent, with exponential worst-case search and O(2^(2n))
transform storage for square functions. Timings with a supplied subgroup do
not describe the unseeded public default, which uses `algorithm=:paper` and no
group discovery unless requested.

The existing equivalence suite also registers strict native decisions and
`ccz_equivalence_certificate` / `ea_equivalence_certificate` recovery cases.

Measured on 2026-10-09 with Julia 1.13.1, GCC 16.2.1 and an AMD Ryzen AI MAX+
395, one Julia thread, seed 940, five timed samples plus warm-up (`--hard`):

| Fixture | Relation | Julia median (ms) | C++ median (ms) | Julia nodes |
| :--- | :--- | ---: | ---: | ---: |
| Gold 5-bit positive | EA | 0.533 | 4.337 | 12 |
| Gold 7-bit positive | EA | 7.164 | 16.059 | 18 |
| Gold 8-bit positive | EA | 3.369 | 10.504 | 6 |
| Gold 5-bit negative | CCZ | 28.098 | 75.618 | 963 |
| Gold 8-bit negative | CCZ | 79.198 | 251.257 | 257 |
| Kim / Dillon | CCZ | 1.473 | 4.265 | 10 |
| Kim / Dillon | EA (negative) | 626.425 | 1622.939 | 4097 |
| Random 8-bit positive | EA | 0.761 | 2.211 | 1 |
| Gold 7-bit negative | CCZ | 5304.480 | 9107.524 | 16131 |

Native source revision: `cb3050138a19bbe55a2c8ad27b489a346c249c21`.
Native source SHA-256:
`742ac7eb2699a79e2ee0299c1ee5e32cd24bb451cf7d272555a814c792e99290`.
Reference source SHA-256:
`d26c2ea762258e3ce3cf21a7b0cf6d4e55d6488a717c2f0b3e62bf04cbe09757`.
These local measurements are not a guarantee for other functions or hardware.

Validation on the same Julia version: 120,990 assertions pass across 86 test
items, including all new native tests and the independent exhaustive three-bit
EA oracle. The unfiltered suite has two failing baseline items,
`linear_backtracking` and `extensions`; both failures reproduce with the
unchanged source at `f0401a2`. The successful regression run excluded only
those two items (`VBF_TEST_NAME='(?!linear_backtracking$|extensions$).*'`).

## Group pruning and parallel refinement

`refinement_optimizations.jl` measures unpruned search, group discovery alone,
search with a supplied group, and discovery plus search under one query budget.
It also compares serial and threaded nine-bit refinement and Walsh transforms.
It runs public VBF APIs, verifies every certificate/generator, reports medians
and allocations, and writes no catalog data:

```bash
julia --threads=4 --startup-file=no --project=. bench/refinement_optimizations.jl --samples=5
```

Discovery gets a one-second sub-budget after compilation warm-up. A partial
subgroup is safe to prune with; its completion flag and order are recorded.
All equivalence calls use 120 seconds and one million DFS nodes. The
`discovery_and_search` row includes discovery, validation of its generators,
chain construction and equivalence. Its node count includes discovery nodes.
`supplied_group` excludes discovery but includes validation and chain building.
Compilation, fixture setup, independent verification and Walsh buffer resets
are outside timing. Run without competing heavy processes.

Threading follows [Julia's task-safety guidance](https://docs.julialang.org/en/v1/manual/multi-threading/):
parallel kernels write disjoint slices, finish before buffers are reused, and
do not index temporary buffers by thread ID. DFS and mutable group updates
remain serial. Small kernels fall back to serial execution; this is an opt-in
optimization rather than a promise that every search improves with threads.

Measured on 2026-10-09 on the same Ryzen AI MAX+ 395, Julia 1.13.1,
four default-pool threads, seed 940 and five timed samples after warm-up.
Source revision: `b6ad7b2937c4962a5d0948372c29f184ef875d3c`.
The group comparisons use serial refinement in every mode:

| Fixture | Discovery (ms) | Unpruned (ms) | Supplied group (ms) | Discovery + search (ms) | Search nodes, unpruned → seeded |
| :--- | ---: | ---: | ---: | ---: | ---: |
| Gold 8-bit negative, CCZ | 36.975 | 70.377 | 27.708 | 66.405 | 257 → 3 |
| Kim / Dillon, EA negative | 37.537 | 567.732 | 10.223 | 47.704 | 4097 → 75 |
| Gold 7-bit negative, CCZ | 15.418 | 4765.449 | 8.001 | 23.233 | 16131 → 21 |

All three discoveries completed within the one-second allowance. Their exact
ambient group orders were 522,240, 56 and 113,792 respectively. Counting
discovery as well, the combined runs visited 22, 353 and 61 DFS nodes.

| Fixture | Unpruned allocations (MiB) | Discovery + search allocations (MiB) |
| :--- | ---: | ---: |
| Gold 8-bit negative | 27.78 | 352.99 |
| Kim / Dillon, EA negative | 439.43 | 39.32 |
| Gold 7-bit negative | 2151.72 | 40.69 |

Allocations are cumulative bytes, not peak resident memory. Group construction
can cost more memory than unpruned search, as the eight-bit fixture shows.
Keep discovery opt-in and reuse groups for repeated target comparisons.

| Workload | Serial median (ms) | Threaded median (ms) |
| :--- | ---: | ---: |
| Random 9-bit EA positive, complete query | 2.060 | 2.071 |
| Int32 Walsh, 2^18 entries | 0.369 | 0.240 |
| Int32 Walsh, 2^20 entries | 1.701 | 0.597 |
| Int32 Walsh, 2^22 entries | 6.744 | 2.264 |

The threaded Walsh calls allocate approximately 29–35 KiB of task overhead;
their serial counterparts allocate zero bytes. The easy nine-bit query gains
no speed in this measurement. These are local timings for a small fixture set,
not a general speedup guarantee or a new comparison against the C++ core.

The updated regression run passes 124,505 assertions across 88 test items on
Julia 1.13.1, with four threads per worker. It excludes only the two baseline
failures documented above. New group tests compare native Schreier–Sims orders
and stabilizers with explicitly enumerated small groups, enumerate every
AGL(4,2) map for several graphs, and independently enumerate graph actions on
three-bit functions. Tests also verify the paper's Example 2, affine kernel
lifts, subgroup validation, shared budgets, concurrent searches, exact serial /
threaded signatures and transforms, and bounded serial signature allocations.
