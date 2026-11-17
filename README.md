# VBF.jl

[Documentation](https://siqueiratf.github.io/VBF.jl/) ·
[Getting started](https://siqueiratf.github.io/VBF.jl/getting_started/) ·
[Prebuilt data on Zenodo](https://doi.org/10.5281/zenodo.24297661)

Julia >= 1.12 workspace for vectorial Boolean functions. `packages/VBF` contains
mathematical algorithms; `packages/VBFCatalog` provides the catalog and corpora
from pinned heterogeneous inputs under `src/data/`;
`packages/VBFSearch` manages reproducible discovery experiments;
`packages/VBFRepro` runs paper reproductions. `packages/VBFPaper` owns the working paper and comparative studies.
The core package never depends on the catalog.

| Package | Contents |
|---|---|
| `packages/VBF` | core algorithms: representations, GF(2) linear algebra, spectra, invariants, equivalence, constructions |
| `packages/VBFCatalog` | the catalog of known APN functions, S-boxes and corpora |
| `packages/VBFRepro` | the reproductions of published papers, as the authors describe them |
| `packages/VBFSearch` | our own searches and optimizations, including the GPU toolkit in `gpu/` |
| `packages/VBFPaper` | the manuscript, its studies and the benchmark evidence in `bench/` |

## Run the APN inspector

The [APN inspector](docs/src/inspector.md) is a local web page. It validates an
(8,8)-function, shows its invariants and compares it with the catalog corpus.
You need Julia >= 1.12 ([install](https://julialang.org/install/)), `git`, `curl`, `gzip` and
about 1.5 GB of free disk (4.5 GB to build the data from the originals). Run these commands:

```sh
git clone https://github.com/siqueiratf/VBF.jl.git
cd VBF.jl
make -C docs serve-inspector
```

Open <http://127.0.0.1:8088/>. Stop the server with Ctrl-C.
The first run gets the catalog data. If Zenodo has the prebuilt data of your
commit, it downloads about 490 MB (`catalog.sqlite`, `members.sqlite` and
`ccz_sigma_index.sqlite`). Otherwise it builds the catalog from the originals:
it downloads the Beierle et al. 2025 corpus (3.16 GB, Zenodo 16752428), checks
all 3,775,599 functions and indexes their signatures. On a 12-thread machine,
this build took about 45 minutes, 11 of them for the download at about 5 MB/s. Use `prebuilt=0` to always build, `threads=N`
to set the build threads and `port=8090` to change the port.
After the first run, the server starts in about 40 seconds.
`make -C docs data` gets the data and does not start the server.

### Prebuilt catalog data

To use the catalog in your own research without a rebuild, run `make -C docs data`
in a clone. It installs the data in `.cache/vbfcatalog/`. After each merge that changes the
catalog sources, CI publishes a new version of the Zenodo record named in
[`prebuilt.toml`](packages/VBFCatalog/src/import/prebuilt.toml).
`manifest.toml` of each version gives the commit, the prebuilt key and the SHA-256 of each file.
`julia --project=packages/VBFCatalog/src/import packages/VBFCatalog/src/import/prebuilt.jl key`
prints the key of your checkout.

The documentation, with tutorials, one page per paper reproduction and the API
reference, is at <https://siqueiratf.github.io/VBF.jl/>. CI publishes it after
each push to `main`. Build it locally with `make -C docs build` (output in
`docs/build/`). The repository has one long-lived branch, `main`.

## Paper reproductions and performance

Paper claims live under `packages/VBFRepro/src/<id>/` and share one
execution environment. The [reproduction runner](packages/VBFRepro/README.md)
lists and runs selected papers in isolated processes, recording configurations,
logs, exit status and source identities under `packages/VBFRepro/src/results/runs/`:

```sh
bin/vbfrepro list                                     # paper IDs and bib keys
bin/vbfrepro info yu-qam                              # targets and parameters of one paper
bin/vbfrepro test 202211-yu-qam --timeout-seconds 300
```

A paper can be named by its ID, its bib key (`Yu_202211`) or a unique part of
them (`yu-qam`).

Cross-paper metrics and performance analysis share
[VBFPaper](packages/VBFPaper/README.md).
Each package owns optional BenchmarkTools workloads in its `perf/` folder.
Performance environments are separate from runtime dependencies, and measurements
are stored under `packages/VBFPaper/bench/data/`; benchmark execution leaves the catalog unchanged.

## Command-line help

`bin/vbfrepro` runs the paper reproductions and `bin/vbf` runs the searches.
Each one prints its commands with `help`, and the options of one command with
`COMMAND --help`. A unique prefix of a command also works (`bin/vbfrepro te`).
Load tab completion for commands, paper IDs, targets and options in your shell:

```sh
source <(bin/vbfrepro completions bash); source <(bin/vbf completions bash)   # bash
source <(bin/vbfrepro completions zsh);  source <(bin/vbf completions zsh)    # zsh
bin/vbfrepro completions fish | source; bin/vbf completions fish | source    # fish
```

To keep it, put the same lines, with the absolute path of `bin/`, in your shell
startup file (`~/.bashrc`, `~/.zshrc` or `~/.config/fish/config.fish`).

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
`--corpus NAME` samples parents from a catalog corpus (list them with
`list_corpora(load_catalog())`), and `--seed` makes the selection repeatable. The
[historical replay recipe](packages/VBFSearch/data/search/legacy20261009/replay.toml)
supplies the exact recovered 11,405-parent construction plan; pass its parents with
`--input packages/VBFSearch/data/search/legacy20261009/parents.tsv`. The recovered
discoveries are not a catalog corpus (see [DATASETS.md](packages/VBFSearch/DATASETS.md)).
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
