# VBFCatalog performance experiments

This development environment measures catalog reads, literature loaders,
bibliography parsing, content addressing, signature-index queries and optional
corpus operations. Mathematical invariant workloads live in VBF's perf suite.

```sh
julia --project=packages/VBFCatalog/perf -e 'using Pkg; Pkg.instantiate()'
julia --project=packages/VBFCatalog/perf packages/VBFCatalog/perf/run.jl --list --level=3
julia --project=packages/VBFCatalog/perf packages/VBFCatalog/perf/run.jl --group=catalog --workload=count_functions --samples=100
julia --project=packages/VBFCatalog/perf packages/VBFCatalog/perf/test.jl
```

The [shared measurement protocol](../../VBF/perf/README.md) fixes `evals=1`,
resets payloads/RNG per sample, validates separately, and writes BenchmarkTools
JSON, scalar timings, source/configuration/hardware metadata and environment
copies under `data/perf/VBFCatalog/<run>/`. `make -C packages/VBFCatalog/perf help`
provides the same commands. Optional indexes and corpus stores must already
exist; unavailable workloads are omitted from `--list`. No importer or builder
runs here. SQLite handles for warm query cases are opened once outside timing;
`load_catalog` measures opening and closing a handle explicitly. Cached loaders
measure warmed API calls, not first-access latency.

The committed catalog database is read-only throughout these workloads.
Materialization benchmarks write a new isolated temporary directory per sample
and remove it afterward. The smoke test verifies the catalog SHA-256 before and
after its read workload. The manifest hashes the catalog and selected optional
corpus/index input files outside timing. Hashing a large selected store can take
substantial time. SQLite inputs should be quiescent: changing a database or its
WAL during measurement is not a reproducible benchmark.

Index-query timing does not establish candidate novelty or database completeness.
Its scientific interpretation follows the catalog API's documented assumptions.
Use VBFSearch's validation/evidence pipeline to assess discovered candidates.
