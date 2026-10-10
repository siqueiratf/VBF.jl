# VBF.jl

Julia >= 1.12 workspace for vectorial Boolean functions. `packages/VBF` contains
mathematical algorithms; `packages/VBFCatalog` provides the catalog and corpora;
`packages/VBFSearch` manages reproducible discovery experiments;
`packages/VBFRepro` runs paper reproductions and comparative research analysis.
The core package never depends on the catalog. See [project context](.claude/context/PROJECT.md)
and the [API documentation sources](docs/src).

## Paper reproductions and performance

Paper claims live under `packages/VBFRepro/papers/<year>/<id>/` and share one
execution environment. The [reproduction runner](packages/VBFRepro/README.md)
lists and runs selected papers in isolated processes, recording configurations,
logs, exit status and source identities under `data/repro/runs/`:

```sh
bin/vbfrepro list
bin/vbfrepro test Yu_202211d --timeout-seconds 300
```

Cross-paper metrics and performance analysis share
[one analysis environment](packages/VBFRepro/analysis/README.md).
Each package owns optional BenchmarkTools workloads in its `perf/` folder.
Performance environments are separate from runtime dependencies, and measurements
are stored under `data/perf/`; benchmark execution leaves the catalog unchanged.

## Reproducible APN searches

Instantiate the root project and prepare the [reference snapshot](data/apn/README.md).
Run from the repository root:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
bin/vbf search --output data/apn/runs/experiment01 --duration 8h --threads 30
bin/vbf status data/apn/runs/experiment01
bin/vbf stop data/apn/runs/experiment01
bin/vbf resume data/apn/runs/experiment01 --duration 8h --threads 30
bin/vbf audit data/apn/runs/experiment01
bin/vbf report data/apn/runs/experiment01
```

The default construction is checkpointed V5 extension of quadratic eight-bit
APNs; `--method switching` selects switching. Each experiment freezes a finite
parent plan. Discoveries are not automatically promoted to parents in that run.
Corpus absence is scoped evidence, not a literature-wide novelty guarantee.

[Search methodology and commands](packages/VBFSearch/README.md) describe seeds, checkpoints,
validation, equivalence checks and publication exports. `bin/vbf help` lists
all commands. Run `make -C docs serve` to use the
[evidence inspector](docs/src/inspector.md) alongside the API documentation
and browse saved experiments. Historical data is preserved under `data/apn/archive/`;
the [census review](packages/VBFSearch/CENSUS_REVIEW.md) documents promoted
mathematics, retained research consumers and retired runners.
