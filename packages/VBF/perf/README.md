# VBF performance experiments

This development environment measures VBF's mathematical public API using
[BenchmarkTools](https://juliaci.github.io/BenchmarkTools.jl/stable/manual/).
It is independent of VBFCatalog. The runtime VBF package has no benchmarking
or application dependencies.

From the repository root:

```sh
julia --project=packages/VBF/perf -e 'using Pkg; Pkg.instantiate()'
julia --project=packages/VBF/perf packages/VBF/perf/run.jl --list
julia --project=packages/VBF/perf packages/VBF/perf/run.jl --group=spectra --workload=ddt --n=8 --seconds=1 --samples=100
julia --project=packages/VBF/perf packages/VBF/perf/test.jl
```

Each other package has the same `perf/run.jl`, `perf/profile.jl`, `perf/test.jl`
and Make targets. `make -C packages/VBF/perf help` lists the commands. Use the
package's own environment; `JULIA_LOAD_PATH='@:@stdlib'` checks that it is
self-contained. Julia 1.12 or newer is required.

The inventory retains representation, GF(2) algebra, spectra, invariants,
equivalence, constructions and bounded search primitive workloads. Pure
signature/key measurements live here; database queries live in
[VBFCatalog/perf](../../VBFCatalog/perf/README.md), durable discovery/evidence
operations in [VBFSearch/perf](../../VBFSearch/perf/README.md), and paper
implementations in [VBFRepro/perf](../../VBFRepro/perf/README.md).

## Measurement protocol

`run.jl` accepts `--group`, `--workload`, `--n`, `--paper`, `--mode`, `--level`,
`--seconds`, `--samples` and `--out`. `--list --level=3` shows the entire
inventory. Dimension-independent cases (`n=0`) remain selected with `--n`.
Level 1 contains quick workloads; level 2 admits larger tables/searches; level
3 includes expensive diagnostics and searches. These levels are historical
cost estimates, not execution time guarantees. Some APIs additionally have
explicit search budgets, recorded in workload parameters.

BenchmarkTools supplies timing, allocation counts, GC statistics and native
trial serialization. Every sample uses `evals=1`, a fresh setup payload and a
reset RNG. Fixture constructors with their own explicit RNG retain their
original seeds in source. Setup, teardown, compilation warm-up and validation
are outside the measured expression. Mutable buffers and scratch files are
reset per sample. Workloads run a separate validation execution before timing;
some assert mathematical properties, while others only require successful API
execution. The manifest states the validation scope. Performance trials do
not certify mathematical correctness or novelty; use the package tests and
the discovery validation pipeline for those claims.

`--seconds` and the sample limit constrain each trial. Without `--samples`,
ordinary cases default to 100 and costly cases retain smaller documented
caps. An explicit `--samples` overrides every case cap. The output records the
effective limit and the actual number of samples. One-sample historical probes
are useful diagnostics but provide no estimate of sampling variability.

Each run creates a fresh directory under `data/perf/VBF/<UTC-time>_<pid>/`:

- `benchmarktools.json`: standard BenchmarkTools trial/group serialization;
- `timings.tsv`: one scalar summary per completed workload, in nanoseconds;
- `manifest.toml`: configuration, workloads, seeds, validation scope, source
  SHA-256 hashes, git state, Julia/BenchmarkTools versions and hardware;
- `Project.toml` and `Manifest.toml`: copies of the active resolved environment.

Completed trials are saved incrementally. Existing output directories are
refused. The runner does not implement resumable timing experiments; select
remaining workloads for a new run if interrupted. Source hashes describe the
files present when the run starts, so finish edits before collecting evidence.
Measurements are hardware-dependent; compare configuration and provenance
before combining runs. The shared perf analysis reader preserves the protocol and
source identity rather than mixing these trials with older custom timings.

## Diagnostics and profiling

```sh
julia --project=packages/VBF/perf packages/VBF/perf/profile.jl --group=spectra --workload=ddt --n=8
julia --project=packages/VBF/perf packages/VBF/perf/compare_partition_refinement.jl --reference=/path/to/CCZ-EA-equivalence --samples=5 --only=gold5_positive
julia --project=packages/VBF/perf packages/VBF/perf/refinement_optimizations.jl --samples=5
```

Profiling saves `profile_raw.jls` and a source/configuration manifest under
`data/perf/<package>/profiles/`. Julia's stdlib profiler samples a separate
execution; its duration is metadata, never a benchmark statistic. Attribution
and figure tooling live in
[shared perf analysis](analysis/README.md).
A very short operation can produce no samples; select a sufficiently long
workload. Profiles and timings are joined only when their identity is explicit.

The C++ comparison preserves the external implementation's within-process
`chrono` measurements, compiler flags and source hash. Julia measurements use
BenchmarkTools; the protocols remain separate in `comparison.csv`. Both native
diagnostic runners save BenchmarkTools JSON, a manifest and environment copies.
The specification audit driver is retained as
`partition_refinement_specification_audit.cpp`; see the documentation's
partition refinement conformance instructions.

The level-3 `diagnostics/gamma_rank` workload now measures the public n8
opt-in API with a 2 GiB estimated-storage budget and a 600-second deadline.
Its Gold8 regression is 11,818. The estimate is not an operating-system
memory cap; the deadline is checked cooperatively. Historical probe code
and measurements remain in the archived original benchmark files.

## Historical evidence

[historical/benchmark_notes.md](historical/benchmark_notes.md) links to the
original archived measurements, machine context and caveats, retained verbatim.
[historical/calibration.toml](historical/calibration.toml) preserves the original
calibration. Their old command paths identify historical procedures; current
commands are above. Original retired tooling and all locally present artifacts
were copied byte-for-byte to `data/perf/archive/bench/`, with a SHA-256 inventory.
They are retained for audit, not used by the current runner. See
[data/perf](../../../data/perf/README.md) for storage and migration details.
