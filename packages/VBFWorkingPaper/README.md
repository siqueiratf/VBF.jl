# VBFWorkingPaper

The working paper's studies, manuscript analysis and presentation live here.
This package consumes VBF, VBFCatalog, VBFSearch and VBFRepro. None of those
packages depends on it. Importing the package starts no experiment.

- `src/analysis/reproductions/`: publication assessments, editorial taxonomy,
  catalog-derived tables and bounded invariant-discrimination experiments.
- `src/analysis/performance/`: manuscript-specific fits and selected-run reports.
- `doc/`: document templates and configuration; `doc/overleaf/` is the pinned
  Overleaf Git submodule.
- `data/working-paper/` at workspace root: ignored derived tables, figures,
  staged paper builds and archived generated manuscript files.

Shared measurement/profile readers live in `VBF/perf/analysis/`. Mathematical
algorithms live in VBF, stored signature summaries in VBFCatalog, and generic
Gold-power/equivalence evidence and independent witness replay in VBFSearch.
Finite construction-proposal checks remain in VBFRepro's `tools/` and `test/proposals/`.
There is no second curated function catalog here.

From the workspace root:

```sh
make -C packages/VBFWorkingPaper instantiate
make -C packages/VBFWorkingPaper fast
make -C packages/VBFWorkingPaper invariants sample=128 seed=20260901 budget=15
make -C packages/VBFWorkingPaper figures
make -C packages/VBFWorkingPaper test
```

`grades` extracts publication-evidence proxies from local paper inputs and
reproduction READMEs. Private PDF conversions are needed to interpret complete
scores. `curated_bfa4r.csv` records the author's separate assessments and drives
the Overleaf audit table. These are different assessment methods; neither
certifies mathematical correctness. Publication identities come from VBFRepro;
WorkingPaper retains explicit paper-citation overrides where a dataset has a
different bibliography key.

Signature counts and overlaps describe stored invariants, not confirmed CCZ
classes. Method-group signature counts are unions across their sources. Absence
from the database does not establish literature completeness. Invariant sampling
has explicit size, seed and budget; partial/error outcomes remain in its output.
See [METRICS.md](src/analysis/reproductions/METRICS.md).

## Build the paper

Initialize the private submodule once (Overleaf Git credentials are required):

```sh
git submodule update --init packages/VBFWorkingPaper/doc/overleaf
make -C packages/VBFWorkingPaper paper paper_output=/tmp/vbf-paper-build
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
make -C packages/VBFWorkingPaper consolidate input=/path/to/measurements
make -C packages/VBFWorkingPaper export
make -C packages/VBFWorkingPaper plots
```

These call the shared perf reader. Its output defaults to `data/perf/analysis/`;
`performance_output=DIR` selects another derived snapshot. Modern BenchmarkTools
trials and explicitly supplied historical SQLite repetitions retain distinct
protocols. `crossings` analyzes archived CSVs; `manuscript input=/path/to/legacy.sqlite`
builds the older selected-run thesis report. Gold-input corpus projections remain
assumption-dependent projections, not full-corpus measurements.
