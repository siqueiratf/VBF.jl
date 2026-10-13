# VBF.jl

Julia >= 1.12 workspace for vectorial Boolean functions. `packages/VBF` contains
mathematical algorithms; `packages/VBFCatalog` provides the catalog and corpora
from pinned heterogeneous inputs under `src/data/`;
`packages/VBFSearch` manages reproducible discovery experiments;
`packages/VBFRepro` runs paper reproductions. `packages/VBFPaper` owns the working paper and comparative studies.
The core package never depends on the catalog. See [project context](.claude/context/PROJECT.md)
and the [API documentation sources](docs/src).

## Paper reproductions and performance

Paper claims live under `packages/VBFRepro/src/<id>/` and share one
execution environment. The [reproduction runner](packages/VBFRepro/README.md)
lists and runs selected papers in isolated processes, recording configurations,
logs, exit status and source identities under `packages/VBFRepro/src/results/runs/`:

```sh
bin/vbfrepro list
bin/vbfrepro test Yu_202211d --timeout-seconds 300
```

Cross-paper metrics and performance analysis share
[VBFPaper](packages/VBFPaper/README.md).
Each package owns optional BenchmarkTools workloads in its `perf/` folder.
Performance environments are separate from runtime dependencies, and measurements
are stored under `packages/VBFPaper/bench/data/`; benchmark execution leaves the catalog unchanged.

## Reproducible APN searches

Instantiate the root project and prepare the [catalog and its signature index](packages/VBFCatalog/README.md).
Run from the repository root:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
bin/vbf discover --name experiment01 --duration 8h --threads 30
bin/vbf status packages/VBFSearch/data/search/experiment01
bin/vbf resume packages/VBFSearch/data/search/experiment01 --duration 8h --threads 30
```

The default construction is checkpointed V5 extension of quadratic eight-bit
APNs; `--method switching` selects switching. Each experiment freezes a finite
parent plan. Discoveries are not automatically promoted to parents in that run.
Corpus absence is scoped evidence, not a literature-wide novelty guarantee.
Use `--corpus legacy20261009_n8 --parents 1000` to continue from the recovered
discovery corpus; `--seed` makes selection repeatable. The
[historical replay recipe](packages/VBFSearch/data/search/legacy20261009/replay.toml)
supplies the exact recovered 11,405-parent construction plan.
`discover` registers one verified representative per separating signature in
VBFCatalog. For repeated stop/resume cycles before registration, use `search`,
then `publish RUN --name SLUG`. New corpora do not change a run's frozen reference
source set. All package evidence has an owner; there is no root `data/` tree.

[Search methodology and commands](packages/VBFSearch/README.md) describe seeds, checkpoints,
validation, equivalence checks and publication exports. `bin/vbf help` lists
all commands. Run `make -C docs serve` to use the
[evidence inspector](docs/src/inspector.md) alongside the API documentation
and browse saved experiments. Historical data is preserved under `packages/VBFSearch/data/research/archive/`;
the [Search guide](packages/VBFSearch/README.md) documents checkpointing and mathematical guarantees.
