# VBFRepro

Standalone paper reproductions consume VBF,
VBFCatalog and VBFSearch here. Importing `VBFRepro` loads a small standard-library
runner; it does not import the papers, solve polynomial systems, or start searches.
Each paper keeps one claim per runnable Julia file and its own Make targets.

Reproductions live directly under `src/YYYYMM-author-subject/`, for example
`src/202508-beierle-millions/`. The CLI uses that directory slug; bibliography
keys remain the original publication identifiers in VBFCatalog. `00` preserves
an unspecified month. Cross-paper studies and manuscript analysis belong to VBFWorkingPaper.
Shared validation evidence belongs to VBFSearch.

From the repository root:

```julia
using VBFRepro
discover_papers()                       # 44 paper IDs, years and paths
paper_path("202211-yu-qam")
run_paper("202211-yu-qam"; target="qam_correspondence", timeout_seconds=900)
test_paper("201909-taniguchi-quadratic-apns"; timeout_seconds=900)
run_paper("202211-yu-qam"; target="small_searches",
          parameters=Dict("max_evaluations"=>1000, "save_results"=>false),
          timeout_seconds=900)
```

The runner launches an isolated `make` process in the selected paper directory,
using the root workspace environment. `src/paper.mk` supplies this same
environment for direct execution:

```sh
make -C packages/VBFRepro instantiate
make -C packages/VBFRepro list
make -C packages/VBFRepro run paper=202211-yu-qam target=qam_correspondence
make -C packages/VBFRepro/src/202211-yu-qam test
make -C packages/VBFRepro/src/202211-yu-qam small_searches max_evaluations=1000 save_results=false
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
own provenance records. Runtime TOML/JSON fixtures and CSV/TSV tables are included in source hashes, so
changing an equivalence certificate changes the recorded implementation identity.
The output log is hashed when execution finishes.
The `environment` argument records only supplied overrides; the inherited environment is not serialized.
Runs using private inputs still need those files for replay.

Original ignored inputs and historical result files remain beside the migrated
paper, byte-for-byte, under `src/<slug>/`. Existing paper targets retain
their explicit `save_results` controls and paper-local `results/` output; the
execution log and configuration are consistently stored under `data/repro/`.
The runner does not rewrite historical evidence or add checkpoint guarantees to
paper algorithms that lack them. Cross-paper studies and publication presentation belong to VBFWorkingPaper.
Reproductions never import that package.
The Beierle self-equivalence reproduction retains its four frozen tuple-class
fixtures for standalone tests and benchmark setup. These record matrices and
search witnesses; known function references continue to come from VBFCatalog.

The [working paper](../VBFWorkingPaper/README.md) consumes reproduction results.
The finite proposal checks live in `tools/catalog_proposals.jl` and use VBFSearch evidence. API timing workloads live in
each package's `perf/` environment, including [perf/](perf/) here.

Run lightweight discovery/execution/evidence tests with
`make -C packages/VBFRepro test`. Individual paper tests remain independently
runnable and are deliberately excluded from the runner's fast package tests.

The same runner is available as `bin/vbfrepro list`,
`bin/vbfrepro run 202211-yu-qam --target qam_correspondence --timeout-seconds 900`,
and `bin/vbfrepro test 201909-taniguchi-quadratic-apns --timeout-seconds 900` from the root.
Use repeated `--param key=value` flags for target parameters.
