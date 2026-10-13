# VBFRepro performance experiments

This development environment benchmarks the existing Beierle_202107,
Canteaut_202205 and Kaleyski_202203 reproduction workloads and preserves the
Kuznetsov_202606 kernel/Groebner calibration probes. It includes the paper's own
Julia implementations directly, so subprocess startup and Make are outside
timing. Nemo and AlgebraicSolving are development dependencies in this perf
environment, not dependencies of the VBF runtime package.

```sh
julia --project=packages/VBFRepro/perf -e 'using Pkg; Pkg.instantiate()'
julia --project=packages/VBFRepro/perf packages/VBFRepro/perf/run.jl --list --level=3
julia --project=packages/VBFRepro/perf packages/VBFRepro/perf/run.jl --paper=202203-kaleyski-ea-invariants --level=2 --seconds=1 --samples=3
julia --project=packages/VBFRepro/perf packages/VBFRepro/perf/test.jl
```

Workloads retain their original scope: report-only, hybrid stored-result
verification, bounded paper-specific search, or core-only invocation. Read the
`--list` notes and manifest before interpreting a result as a paper algorithm's
runtime. Canteaut's configured dimensions are 5 and 6; its expensive minimal-EA
verification is disabled in this workload. Beierle's Algorithm 1 has explicit
solution/time limits; its report does not run that search. These bounds do not
certify exhaustive paper reproduction or an equivalence classification.

The [shared protocol](../../VBF/perf/README.md) uses BenchmarkTools with fresh
setup, reset seeds and `evals=1`. Expensive historical cases retain small default
sample caps; `--samples` explicitly overrides them. The smoke test imports the
full inventory and measures a small equivalence primitive, avoiding expensive
reports in CI. Loading some existing reports emits repeated-docstring warnings
because their standalone files include shared helpers again.

Results are saved under `packages/VBFPaper/bench/data/VBFRepro/<run>/`. Source manifests hash the
paper implementations, package sources, resolved environment and the selected
papers' stored inputs, including original input files when locally present.
Input files are hashed, never copied into benchmark output. Profiling records
the same selected paper/input identity. The catalog hash is also recorded.
Collect evidence only after finishing source edits and with unchanged inputs.

Performance analysis, profiling attribution and manuscript export live in
[shared perf analysis](../../VBFPaper/bench/analysis/README.md). That reader supports
both historical timing artifacts and the new `timings.tsv`/manifest format and
keeps their different measurement protocols distinct.
