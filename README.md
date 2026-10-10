# VBF.jl

Julia >= 1.12 workspace for vectorial Boolean functions. `packages/VBF` contains
mathematical algorithms; `packages/VBFCatalog` provides the catalog and corpora;
`packages/VBFSearch` manages reproducible discovery experiments.
The core package never depends on the catalog. See [project context](.claude/context/PROJECT.md)
and the [API documentation sources](docs/src).

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
all commands. The [evidence inspector](apps/apn-inspector/README.md) can
browse these runs. Historical data is preserved under `data/apn/archive/`;
the [census review](packages/VBFSearch/CENSUS_REVIEW.md) documents promoted
mathematics, retained research consumers and retired runners.
