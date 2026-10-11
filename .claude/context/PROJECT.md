# VBF.jl — project context

## What this repo is

Julia workspace for analysing vectorial Boolean functions (VBF), focused on APN
(almost perfect nonlinear) functions and the linear / affine / EA / CCZ
equivalence hierarchy. Requires **Julia ≥ 1.12** (workspace feature).
  
## Workspace layout

```
packages/VBF/          core algorithms  (representations, spectra, invariants,
                        equivalence, constructions — no catalog dependency)
packages/VBFCatalog/   data layer: SQLite catalog, bibliography, importers
                        (depends on VBF; VBF must NOT depend on VBFCatalog)
packages/VBFSearch/    reproducible APN search and candidate evidence
docs/inspector/        HTTP evidence viewer consuming all three packages
packages/VBFCatalog/data/research/             reference snapshots, runs, rebuilds and historical data
packages/VBFRepro/      reproduction runner and standalone publication claims
packages/VBFWorkingPaper/ manuscript studies, analysis and Overleaf source under doc/
packages/*/perf/        optional per-package performance workloads
packages/VBF/perf/data/             performance measurements and provenance
docs/                  Documenter.jl API-reference site
```

Key layout rules:
- One concept per file, grouped by concept directory under `packages/VBF/src/`.
- `VBF` must never import `VBFCatalog`.
- `VBFCatalog` is the canonical source for curated function entries, LUTs and
  corpora. Consumers load its records through its APIs. Independent paper-formula
  reconstructions and generated experiment evidence do not form another catalog.
- Paper scripts in `packages/VBFRepro/src/` orchestrate experiments; they do not re-implement
  core math that belongs in `packages/VBF`.
- Reproduction folders use flat `YYYYMM-author-subject` slugs, e.g.
  `src/202508-beierle-millions/`; `00` retains an unspecified month.
  Working-paper studies live in `packages/VBFWorkingPaper/`. Reproductions
  never depend on WorkingPaper. Shared evidence belongs to VBFSearch, catalog
  queries to VBFCatalog, and saved timing readers to VBF/perf/analysis.
  Consumers are Julia and reuse VBF's tested algorithms for verification and invariants.

## Running tests

```bash
# VBF package test suite (ReTestItems, parallel)
julia -e 'using Pkg; Pkg.activate("packages/VBF"); Pkg.test()'

# Reproduction runner tests are independent of core math tests.
julia -e 'using Pkg; Pkg.activate("packages/VBFRepro"); Pkg.test()'

# Single paper folder (e.g. Yu_202211d)
make -C packages/VBFRepro/src/202211-yu-qam test
```

Environment knobs: `RETESTITEMS_NWORKERS` (default: min(CPU_THREADS, 8)),
`RETESTITEMS_TESTITEM_TIMEOUT` (default: 900 s).

## Key packages and APIs

### VBF (`packages/VBF/src/`)

| Directory | What lives there |
|---|---|
| `representations/` | `SBox`, F2 linear/affine maps, `Spectrum`, ANF, finite fields, univariate polynomials |
| `linalg/` | Bit-packed GF(2) linear algebra, subspace search |
| `spectra/` | DDT, Walsh/LAT, boomerang, algebraic degree, BPT anomaly |
| `invariants/` | `ortho_derivative`, `ortho_integral`, sigma multiplicities, `mugshot`, `apn_ea_mugshot`, design 2-ranks, bent/image structure |
| `equivalence/` | `are_ea_equivalent`, `are_ccz_equivalent`, linear/affine hierarchy, 3-to-1 tests |
| `constructions/` | QAM (`is_qam`, `qam_to_sbox`, `quadratic_apn_matrix`, `search_qam`, `search_qam_full`, `qam_cyclic_orbits`, `qam_from_cyclic`), switching neighbours, quadratic-APN graph search, Taniguchi, known families |

Important implementation notes:
- **Indexing**: math is 0-based, Julia is 1-based → `lut[x+1]`.
- **Bit-packing**: `FunctionGraph` packs `(x << N) | F(x)` (input high, output
  low); Walsh-zeroes pack `(a << N) | b`. Wrong convention causes silent failures.
- `are_ea_equivalent` falls back to the `:ortho_derivative` strategy for monomial
  APN where k=4 partition is degenerate.
- `permutation_order` must not be capped at `2^n`; Landau's function exceeds it.
- `thickness_spectrum` is EA-invariant, not CCZ-invariant.

### VBFCatalog (`packages/VBFCatalog/`)

Main APIs: `load_catalog()`, `list_functions`, `find_function`, `load_sbox`,
`load_apn_function`, `load_literature_sbox`, `literature_sbox_names`,
`load_bibliography` / `parse_bibtex`, `list_corpora`, `corpus_info`,
`corpus_length`, `corpus_function`, `materialize_corpus_luts`.

Catalog contents and counts come from these APIs and the declarative catalog;
do not maintain a second inventory here. Bulk corpus records remain distinct
from the curated functions table. Use `list_corpora` and `corpus_info` to inspect
their current member counts and provenance.

Data-build importers live under `packages/VBFCatalog/src/import/` and run in
their own environment — never `include` them from a REPL or test.

## Paper-reproduction conventions

See the skill: `.claude/skills/reproduce-paper/SKILL.md`.

Reference pattern: `packages/VBFRepro/src/202107-beierle-self-equivalence/` (older single-folder style).
Fully-worked recent example: `packages/VBFRepro/src/202211-yu-qam/` (multi-file, Makefile, tests).

Each reproduction has a standalone Makefile and bounded targets. The lightweight
runner discovers their slugs without importing scripts; run a paper's own tests
with `bin/vbfrepro test <slug>`. Bibliography identifiers remain in VBFCatalog.

## Coding conventions

- No comments except when the WHY is non-obvious.
- Module docstring at top of each file: states the math and citation.
- Each function has its own docstring; name by concept, cite the algorithm's
  author (not the upstream repo).
- Tests: `@testitem "<feature>_test.jl"` under `packages/VBF/test/{unit,property}/`.
  Each item declares its own `using` dependencies. Prefer high-signal anchors:
  closed-form counts, round-trips, CCZ-invariance checks, parity between two
  strategies. Document limitations in docstrings, not by hiding them.

## Git / commit conventions

Branch: `main`. Recent commit style: `<type>: <description>` (feat/fix/refactor/
style/docs). Never skip hooks. Never amend published commits.

## Environment variables for catalog importers

`BFA_SBOXU_PATH`, `BFA_THESIS_PATH`, `BFA_BEIERLE2025_PATH` —
override original-source cache paths for `src/import/` scripts. `BFA_DATA_DIR`
selects local bulk/index/proof storage under `packages/VBFCatalog/data/`. `BFA_SOURCE_DIR` selects declarations under `src/data/`. Curated entries and small
compact corpora share `packages/VBFCatalog/src/data/catalog.sqlite`; old measurements live in `packages/VBF/perf/data/`.

## Reproducible APN command

APN experiment data lives in `packages/VBFCatalog/data/research/runs/<experiment>/`; inspector pair
certificates use `packages/VBFCatalog/data/research/runs/web/`. The retired root `search/` tree is removed.
Its historical class-orbit artifacts live in `packages/VBFCatalog/data/research/archive/class-orbit/`,
with the old code preserved in Git history and a local ignored source snapshot.

`bin/vbf` runs the `VBFSearch` package CLI: search/resume/status/stop, validate/audit,
compare/classify/verify and publication reports. Production workflows live
under `packages/VBFSearch/`; Fourier math is `VBF.QuadraticExtensions`, catalog seeds
use `VBFCatalog`. Reference evidence comes directly from the verified VBFCatalog signature index; frozen source sets allow resume after new corpora are appended. `discover --name SLUG` searches and registers new separating signatures through the catalog importer; `publish RUN --name SLUG` registers stopped runs. Historical census outputs remain archived; old
checkpoints are unsupported. See `packages/VBFSearch/README.md` for the supported API.

The root `census/` tree is removed. Pure coefficient-tree, restriction and profile
math lives in VBF (`QuadraticAPNTree`, `QuadraticRestrictions`, `QuadraticProfiles`).
Original-source rebuild tools are `packages/VBFCatalog/src/import/reference/`;
literature coverage and study consumers are under `packages/VBFWorkingPaper/src/`.
Historical data is `packages/VBFCatalog/data/research/archive/census/`; new rebuilds use `packages/VBFCatalog/data/research/rebuilds/`.
See `packages/VBFSearch/README.md` for checkpointing and mathematical guarantees.

The root `data/` is removed. APN archives live in `packages/VBFCatalog/data/research/`,
new runs in `packages/VBFCatalog/data/search/`, performance evidence in
`packages/VBF/perf/data/`, reproductions in `packages/VBFRepro/src/results/`, and
working-paper exports in `packages/VBFWorkingPaper/doc/generated/`.
The `legacy20261009_n8` corpus stores 111,009 verified separating signatures
(110,868 historical plus 141 later), after importing 547 missing public signatures.
Literature-wide novelty remains unresolved. `bin/vbf discover --name SLUG --corpus
legacy20261009_n8 --parents 1000 ...` selects deterministic catalog parents and
registers new separating signatures via the shared immutable TSV importer.
The tracked `packages/VBFCatalog/data/search/legacy20261009/replay.toml` and
`parents.tsv` reproduce the recovered 11,405-parent plan; a bounded pilot matched
all 25 original child signatures. The full plan has not been replayed.
