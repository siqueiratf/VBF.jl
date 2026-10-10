# VBFRepro

Standalone paper reproductions and their cross-paper analysis consume VBF,
VBFCatalog and VBFSearch here. Importing `VBFRepro` loads a small standard-library
runner; it does not import the papers, solve polynomial systems, or start searches.
Each paper keeps one claim per runnable Julia file and its own Make targets.

From the repository root:

```julia
using VBFRepro
discover_papers()                       # 44 paper IDs, years and paths
paper_path("Yu_202211d")
run_paper("Yu_202211d"; target="qam_correspondence", timeout_seconds=900)
test_paper("Taniguchi_201909"; timeout_seconds=900)
run_paper("Yu_202211d"; target="small_searches",
          parameters=Dict("max_evaluations"=>1000, "save_results"=>false),
          timeout_seconds=900)
```

The runner launches an isolated `make` process in the selected paper directory,
using the root workspace environment. `papers/paper.mk` supplies this same
environment for direct execution:

```sh
make -C packages/VBFRepro instantiate
make -C packages/VBFRepro list
make -C packages/VBFRepro run paper=Yu_202211d target=qam_correspondence
make -C packages/VBFRepro/papers/2022/Yu_202211d test
make -C packages/VBFRepro/papers/2022/Yu_202211d small_searches max_evaluations=1000 save_results=false
```

Dependencies are instantiated explicitly once; paper tests do not silently
instantiate the workspace on every invocation. Paper-specific dependencies such
as Nemo and AlgebraicSolving remain in that execution environment, outside the
lightweight runner's dependencies.

`run_paper` writes a fresh run directory under `data/repro/runs/<paper>/<run-id>/`.
Use `output="/absolute/empty/directory"` to choose a different location. `run.toml`
records arguments, parameters, explicit environment overrides, source hashes,
timestamps, elapsed time and status; `output.log` contains stdout and stderr.
Existing evidence cannot be overwritten by another run.
An atomic `.vbf-repro-claim/` marker reserves the output directory, so simultaneous
runs cannot both acquire it. The marker remains after success or failure; select
a fresh directory for the next execution.

A timeout terminates the process group on Unix, including the Julia subprocess; a timed-out result
must never be interpreted as exhaustive. On other systems only the direct
process is terminated. Execution success reports a passing Make target, not an
independent mathematical proof.

The source hashes record all paper scripts (including cross-paper helpers), the
shared runner environment, workspace manifest and package implementation. They do not archive dependencies
or replace paper-specific input/result provenance. Input hashes cover the selected
paper's `input/`, `inputs/`, `tuples/` and the curated catalog database. External
corpora and inputs supplied through custom parameters still require the paper's
own provenance records. The output log is hashed when execution finishes.
The `environment` argument records only supplied overrides; the inherited environment is not serialized.
Runs using private inputs still need those files for replay.

Original ignored inputs and historical result files remain beside the migrated
paper, byte-for-byte, under `papers/<year>/<id>/`. Existing paper targets retain
their explicit `save_results` controls and paper-local `results/` output; the
execution log and configuration are consistently stored under `data/repro/`.
The runner does not rewrite historical evidence or add checkpoint guarantees to
paper algorithms that lack them. Package-owned new analysis lives in `analysis/`;
publication text and publication-specific presentation remain in `manuscript/`.

See [analysis/README.md](analysis/README.md) for the optional cross-paper audit,
grading, comparison and publication-data workflow. API timing workloads live in
each package's `perf/` environment, including [perf/](perf/) here.

Run lightweight discovery/execution/evidence tests with
`make -C packages/VBFRepro test`. Individual paper tests remain independently
runnable and are deliberately excluded from the runner's fast package tests.

The same runner is available as `bin/vbfrepro list`,
`bin/vbfrepro run Yu_202211d --target qam_correspondence --timeout-seconds 900`,
and `bin/vbfrepro test Taniguchi_201909 --timeout-seconds 900` from the root.
Use repeated `--param key=value` flags for target parameters.
