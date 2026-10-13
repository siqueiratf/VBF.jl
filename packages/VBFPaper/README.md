# VBFPaper

The working paper's studies, manuscript analysis and presentation live here.
This package consumes VBF, VBFCatalog, VBFSearch and VBFRepro. None of those
packages depends on it. Importing the package starts no experiment.

- `src/analysis/reproductions/`: publication assessments, editorial taxonomy,
  catalog-derived tables and bounded invariant-discrimination experiments.
- `src/analysis/performance/`: manuscript-specific fits and selected-run reports.
- `doc/`: document templates and configuration; `doc/overleaf/` is the pinned
  Overleaf Git submodule.
- `packages/VBFPaper/doc/generated/` at workspace root: ignored derived tables, figures,
  staged paper builds and archived generated manuscript files.

Shared measurement/profile readers live in `VBFPaper/bench/analysis/`. Mathematical
algorithms live in VBF, stored signature summaries in VBFCatalog, and generic
Gold-power/equivalence evidence and VBF-backed graph witness checks in VBFSearch.
Finite construction-proposal checks remain in VBFRepro's `tools/` and `test/proposals/`.
There is no second curated function catalog here.

From the workspace root:

```sh
make -C packages/VBFPaper instantiate
make -C packages/VBFPaper fast
make -C packages/VBFPaper invariants sample=128 seed=20260901 budget=15
make -C packages/VBFPaper figures
make -C packages/VBFPaper test
```

`grades` extracts publication-evidence proxies from local paper inputs and
reproduction READMEs. Private PDF conversions are needed to interpret complete
scores. `curated_bfa4r.csv` records the author's separate assessments and drives
the Overleaf audit table. These are different assessment methods; neither
certifies mathematical correctness. Publication identities come from VBFRepro;
VBFPaper retains explicit paper-citation overrides where a dataset has a
different bibliography key.

Signature counts and overlaps describe stored invariants, not confirmed CCZ
classes. Method-group signature counts are unions across their sources. Absence
from the database does not establish literature completeness. Invariant sampling
has explicit size, seed and budget; partial/error outcomes remain in its output.
See [METRICS.md](src/analysis/reproductions/METRICS.md).

## Build the paper

Initialize the private submodule once (Overleaf Git credentials are required):

```sh
git submodule update --init packages/VBFPaper/doc/overleaf
make -C packages/VBFPaper paper paper_output=/tmp/vbf-paper-build
```

The `paper` target renders the curated audit table, copies the pinned Overleaf
checkout to a **fresh** build directory, replaces the existing `tab:audit` table
body with `\input{generated/tab_audit.tex}`, and invokes `latexmk`. It leaves the
Overleaf checkout untouched and pushes nothing. `build.toml` records input hashes,
implementation hashes, the Overleaf commit, Julia environment and PDF digest.
The build fails if the table anchor is missing/ambiguous or the output exists.
Use `stage` instead of `paper` to prepare sources without LaTeX compilation.

The remaining Overleaf prose and its other numerical claims remain author-edited;
rendering a table does not validate those claims. Invariant and benchmark figures
are separate explicit targets; they are not silently regenerated during a paper
build. The older thesis templates remain under `doc/performance/`.

## Saved performance evidence

```sh
make -C packages/VBFPaper consolidate input=/path/to/measurements
make -C packages/VBFPaper export
make -C packages/VBFPaper plots
```

These call the shared perf reader. Its output defaults to `packages/VBFPaper/bench/data/analysis/`;
`performance_output=DIR` selects another derived snapshot. Modern BenchmarkTools
trials and explicitly supplied historical SQLite repetitions retain distinct
protocols. `crossings` analyzes archived CSVs; `manuscript input=/path/to/legacy.sqlite`
builds the older selected-run thesis report. Gold-input corpus projections remain
assumption-dependent projections, not full-corpus measurements.

Census and hyperplane studies live under `src/census/` and `src/hyperplanes/`;
finite construction coverage is under `src/literature/`. These use VBF mathematics
and VBFSearch evidence. Their tests run in the VBFPaper package suite and use
generated fixtures. Historical controls and separate verification engines were
retired. The catalog API/layout consolidation is a separate change.

For publication figures from a search snapshot:

```sh
make -C packages/VBFPaper search-figures \
  run="$PWD/packages/VBFCatalog/data/research/runs/experiment01" figure_output="$PWD/packages/VBFPaper/doc/generated/search-figures"
```
