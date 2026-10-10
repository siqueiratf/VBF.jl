# Reproduction and performance analysis

One optional Julia environment owns the table readers, statistics, plots, and
publication evidence analysis. Loading `VBFRepro` itself does not load these
packages. Analysis consumes saved results; it does not launch benchmark suites
or write to the curated catalog.

`reproductions/` owns publication metrics and presentation classifications;
`performance/` owns measurement analysis; `validation/` owns finite comparison
experiments and their independent Julia certificate checks. Function entries
and reference LUTs are loaded from VBFCatalog. The publication taxonomy and
curated evidence grades describe papers, rather than functioning as APN catalogs.

```sh
make -C packages/VBFRepro/src/analysis instantiate
make -C packages/VBFRepro/src/analysis grades
make -C packages/VBFRepro/src/analysis fast
make -C packages/VBFRepro/src/analysis invariants sample=128 seed=20260901 budget=15
make -C packages/VBFRepro/src/analysis figures figure_output=/absolute/publication/figures
make -C packages/VBFRepro/src/analysis test
```

`reproductions/METRICS.md` defines the scientific metrics. The evidence grades
are stated proxies over publication inputs and reproduction reviews, not expert
judgments or mathematical correctness proofs. Private paper inputs are required
for complete grades. `fast` discovers the current runnable papers and reads VBFCatalog and its
corpora; `invariants` performs explicitly bounded computations and records its
sample, seed, and budget. Outputs default to `data/repro/analysis/reproductions/`.
Override `output=DIR` consistently for grades, metrics, and figures.

## Performance measurements

Each package's `perf/` suite records BenchmarkTools trials in `data/perf/`.
Analysis reads `timings.tsv` and its adjacent `manifest.toml`, retaining paths,
hashes, run identity, input configuration, and execution provenance:

```sh
make -C packages/VBFRepro/src/analysis consolidate input=/absolute/path/to/measurements
make -C packages/VBFRepro/src/analysis inspect
make -C packages/VBFRepro/src/analysis export
make -C packages/VBFRepro/src/analysis plots
```

The default input is `data/perf/`; derived SQLite, CSV, Arrow, and exploratory
plots go to `data/repro/analysis/performance/`. `performance_output=DIR` selects
a different derived snapshot. Missing or invalid manifests are rejected.
Raw BenchmarkTools JSON preserves trial samples; the table reader interprets
one completed summary as one trial, not as `samples` independent executions.
`elapsed_seconds` is the median per evaluation for this protocol.

Historical custom-timer rows are supported only when a SQLite path is supplied
explicitly, for example `input=/absolute/path/to/historical.sqlite`. The reader
opens the database query-only. Protocol identity participates in default
aggregation, preventing silent pooling of historical repetitions with
BenchmarkTools summaries. Original output bytes remain in
`data/perf/archive/` and `data/repro/analysis/archive/`; historical timing
limitations remain limitations of those results.

## Publication presentation

Manuscript-specific run selections, theoretical predictions, and LaTeX templates
live in `manuscript/performance/`. Figure destinations are explicit; no target
selects the private manuscript directory by name. The `manuscript` target is the
legacy SQLite-backed selected-run report and requires that database via `input`.
The `crossings` target reads historical `benchmarks.csv` evidence, never executes
a benchmark, and writes to the derived analysis directory. These reports retain
their original timing protocol; rerunning them does not upgrade historical data.

Independent mathematical evidence, measured API costs, sampling attribution,
statistical estimates, and publication-layout choices remain distinct.

## Candidate validation and reference comparisons

VBFCatalog owns curated function entries, LUTs, bibliography and corpora.
Analysis loads known references through its API; it does not maintain another
catalog or add entries. Paper builders reconstruct specified formulas for
independent reproduction. Unvalidated proposals and their computed LUTs are
experiment outputs, with no automatic novelty or catalog admission.

The source-representative encoding regressions live in the existing tests for
Budaghyan 2009, Edel–Pott 2009 and Bracken 2011. Run each paper with
`bin/vbfrepro test <paper-id>`; no root investigation files are required.

The proposal review regenerates 32 specified paper representatives, verifies
quadratic APN properties, and replays nine positive certificates. All 32 were
excluded from every APN power function through complete Gold-domain coverage
and Yoshiara's theorem. All 583 current functions-table comparisons were
conclusive: 31 proposals separated, one represented. Five within-inventory
duplicates and three selected prior controls remain explicit positive matches;
31 catalog separations therefore do not identify 31 novel classes.

Non-power constructions outside the named references and literature-wide
completeness remain unresolved. Empty reference sets, corrupted records and
budget stops produce inconclusive results. Catalog contents are never changed.

```sh
make -C packages/VBFRepro/src/analysis review_catalog_proposals
make -C packages/VBFRepro/src/analysis test_catalog_proposals
make -C packages/VBFRepro/src/analysis verify_proposal_witnesses
```

Make exposes `proposal_output`, `equivalence_timeout` and
`max_equivalence_nodes`. The default output is
`data/repro/analysis/catalog_proposals.toml`, containing actual LUTs, invariants,
source hashes, catalog snapshot identity, scopes and verified maps. These are
derived evidence for the run, not an independent source of curated entries.
The independent Julia replay uses only standard-library integer arithmetic.

The paper inventory comes from `VBFRepro.discover_papers`; catalog contribution
counts come from VBFCatalog. Historical defect counts and README verdict plots
are retired. The existing curated publication-evidence grades remain an
explicit assessment of publication inputs, separate from correctness claims.
