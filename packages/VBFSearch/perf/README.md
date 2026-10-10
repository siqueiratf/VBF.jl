# VBFSearch performance experiments

This development environment measures candidate-property computation,
identity/inequivalence evidence checks and discovery-store seed commits.
Bounded mathematical generation primitives remain in VBF's perf suite;
this suite measures application operations around those primitives.

```sh
julia --project=packages/VBFSearch/perf -e 'using Pkg; Pkg.instantiate()'
julia --project=packages/VBFSearch/perf packages/VBFSearch/perf/run.jl --list
julia --project=packages/VBFSearch/perf packages/VBFSearch/perf/run.jl --group=evidence --workload=candidate_properties --n=8 --samples=100
julia --project=packages/VBFSearch/perf packages/VBFSearch/perf/test.jl
```

The [shared measurement protocol](../../VBF/perf/README.md) uses BenchmarkTools,
`evals=1`, explicit seeds, fresh payloads and separate validation. Every selected
comparison is bounded and its evidence is checked through VBF outside timing.
Each persistence sample creates a fresh SQLite store in a temporary directory,
checks the resulting seed record and closes/removes the store afterward. No
existing experiment, checkpoint or reference corpus is modified.

Results go to `data/perf/VBFSearch/<run>/` with native BenchmarkTools trials,
scalar timings, source/configuration/hardware metadata and environment copies.
`make -C packages/VBFSearch/perf help` lists equivalent Make commands. These
microbenchmarks exercise application behavior; they do not replace a long
search's persisted progress or scientific validation evidence.
