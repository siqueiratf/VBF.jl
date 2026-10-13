# Performance evidence analysis

Use this optional environment (`julia --project=packages/VBFPaper/bench/analysis`), or VBFPaper. `BenchAnalysis.jl` reads
BenchmarkTools trial artifacts or explicitly supplied historical SQLite rows;
it never changes the source database. `consolidate` creates a separate SQLite
snapshot in one transaction, with CSV/Arrow exports and optional plots.

```julia
include("packages/VBFPaper/bench/analysis/BenchAnalysis.jl")
using .BenchAnalysis, DataFrames
trials = load_benchmarks("packages/VBFPaper/bench/data/VBF/chosen-run")
summary = runtime_statistics(trials)
# Historical repetition protocol is explicit:
legacy = load_benchmarks("/absolute/path/to/historical.sqlite")
selected = filter(:run_id => ==("chosen-run"), legacy)
summary = runtime_statistics(selected)
```

Default strata retain measurement protocol, package, run, paper, workload, approach,
mode, dimension, configuration, reference scope, source, CPU, Julia version,
thread count, and seed. Passing `by` deliberately pools strata and requires a
scientific justification. Missing groups stay missing; one observed execution
has no estimated between-execution standard deviation. Trial samples in
BenchmarkTools are not interpreted as independent runs.

APN ratios use only persisted counters. Missing or zero denominators give
`missing`; timing-only rows cannot imply APN discovery or coverage. Historical
known coverage compares exact LUT identity within the recorded reference scope,
not CCZ/EA equivalence. Historical `total_candidates` may count visited nodes,
so its ratio to completed candidates need not measure mathematical space coverage.

Saved Julia Profile artifacts remain authoritative for sampled attribution.
`profiles.jl` deduplicates artifacts by SHA-256 and reconstructs exclusive
core/paper/other sample counts with FlameGraphs. External callees inherit their
nearest project caller. This estimates runtime attribution rather than an exact
execution split. Zero samples imply missing fractions. Only compatible package, source,
workload parameters, input hashes, execution, and case provenance permits joins; unqualified legacy
artifacts remain inspectable but cannot join timings. Never deserialize
untrusted artifacts, and preserve the Julia environment with published profiles.

Full timing configuration remains in `case_parameters_json`;
`workload_parameters_json` supplies canonical structural parameter identity for
profile joins. Timing limits and sampling delays describe different instruments
and are retained separately. Unknown profile protocols and conflicting input
hashes prevent a join.

Provenance includes source snapshot identity, analysis source and manifest
hashes, measurement-file hashes, and protocol. Keep the resolved local manifest
with published outputs; the environment's generated manifest is ignored by git.

`crossings.jl` analyzes preserved historical summary CSVs against predictions
under `packages/VBFPaper/doc/performance/`. Manuscript scripts live in VBFPaper. `manuscript.jl` produces the legacy selected-run
SQLite report, whose corpus projections assume the measured Gold-input cost
for every corpus member. Those projections are not full-corpus measurements.
