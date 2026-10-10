# Reproduction and performance analysis

One optional Julia environment owns the table readers, statistics, plots, and
publication evidence analysis. Loading `VBFRepro` itself does not load these
packages. Analysis consumes saved results; it does not launch benchmark suites
or write to the curated catalog.

```sh
make -C packages/VBFRepro/analysis instantiate
make -C packages/VBFRepro/analysis grades
make -C packages/VBFRepro/analysis fast
make -C packages/VBFRepro/analysis invariants sample=128 seed=20260901 budget=15
make -C packages/VBFRepro/analysis figures figure_output=/absolute/publication/figures
make -C packages/VBFRepro/analysis test
```

`reproductions/METRICS.md` defines the scientific metrics. The evidence grades
are stated proxies over publication inputs and reproduction reviews, not expert
judgments or mathematical correctness proofs. Private paper inputs are required
for complete grades. `fast` reads the frozen 42-publication audit, catalog, and
corpora; `invariants` performs explicitly bounded computations and records its
sample, seed, and budget. Outputs default to `data/repro/analysis/reproductions/`.
Override `output=DIR` consistently for grades, metrics, and figures.

## Performance measurements

Each package's `perf/` suite records BenchmarkTools trials in `data/perf/`.
Analysis reads `timings.tsv` and its adjacent `manifest.toml`, retaining paths,
hashes, run identity, input configuration, and execution provenance:

```sh
make -C packages/VBFRepro/analysis consolidate input=/absolute/path/to/measurements
make -C packages/VBFRepro/analysis inspect
make -C packages/VBFRepro/analysis export
make -C packages/VBFRepro/analysis plots
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

## Applying the historical audit

The August audit is frozen evidence. Current per-finding dispositions live in
[`audit/resolutions.toml`](../../../audit/resolutions.toml); they distinguish repaired
implementation defects from unresolved paper claims and unfinished exhaustive runs.

Revalidate the eight historical LUT proposals through the actual Julia builders:

```sh
julia --project=. packages/VBFRepro/analysis/scripts/revalidate_audit_luts.jl
```

This checks APN properties and exact little-endian LUT hashes against
[`audit/revalidated_luts.toml`](../../../audit/revalidated_luts.toml). It writes no
catalog entries and supplies no novelty guarantee. The script needs only the root
workspace environment, independently of the optional plotting environment.
