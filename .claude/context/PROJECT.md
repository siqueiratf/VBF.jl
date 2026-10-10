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
packages/VBFSearch/    reproducible APN search and research consumers
docs/inspector/        HTTP evidence viewer consuming all three packages
data/apn/             reference snapshots, runs, rebuilds and historical data
packages/VBFRepro/      reproduction runner, standalone claims and research analysis
packages/*/perf/        optional per-package performance workloads
data/perf/             performance measurements and provenance
docs/                  Documenter.jl API-reference site
```

Key layout rules:
- One concept per file, grouped by concept directory under `packages/VBF/src/`.
- `VBF` must never import `VBFCatalog`.
- `VBFCatalog` is the canonical source for curated function entries, LUTs and
  corpora. Consumers load its records through its APIs. Independent paper-formula
  reconstructions and generated experiment evidence do not form another catalog.
- Paper scripts in `packages/VBFRepro/papers/` orchestrate experiments; they do not re-implement
  core math that belongs in `packages/VBF`.

## Running tests

```bash
# VBF package test suite (ReTestItems, parallel)
julia -e 'using Pkg; Pkg.activate("packages/VBF"); Pkg.test()'

# Reproduction runner tests are independent of core math tests.
julia -e 'using Pkg; Pkg.activate("packages/VBFRepro"); Pkg.test()'

# Single paper folder (e.g. Yu_202211d)
make -C packages/VBFRepro/papers/2022/Yu_202211d test
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

Catalog content (committed, 603 first-class rows):
- 18 literature S-boxes (AES, AES-inv, 14 four-bit cipher S-boxes)
- 28 declarative APN functions (n ∈ {4..10})
- 530 quadratic-APN CCZ-class representatives
- 27 Simon-Berg GF(4)-coefficient CCZ representatives over GF(2^8)

Bulk corpora (not first-class rows): Simon Berg 196 863-member corpus, 7
literature 8-bit quadratic-APN families (Edel-Pott, Weng-Tan-Gong, Yu-Wang-Li,
Taniguchi, Beierle-Leander, Yu-Perrin, Beierle-Leander-Perrin; 32 916 members).

Data-build importers live under `packages/VBFCatalog/data-build/` and run in
their own environment — never `include` them from a REPL or test.

## Paper-reproduction conventions

See the skill: `.claude/skills/reproduce-paper/SKILL.md`.

Reference pattern: `packages/VBFRepro/papers/2021/Beierle_202107/` (older single-folder style).
Fully-worked recent example: `packages/VBFRepro/papers/2022/Yu_202211d/` (multi-file, Makefile, tests).

Single-file papers (`packages/VBFRepro/papers/*.jl`): expose `reproduce()` returning a NamedTuple
and `report(io=stdout)`. The `papers_test.jl` ReTestItems item calls
`reproduce()` and checks frozen expected values.

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

`BFA_SBOXU_PATH`, `BFA_XANADU_PATH`, `BFA_APN_REPO_PATH`, `BFA_THESIS_PATH` —
override upstream checkout paths for data-build scripts only.

## Reproducible APN command

APN experiment data lives in `data/apn/runs/<experiment>/`; inspector pair
certificates use `data/apn/runs/web/`. The retired root `search/` tree is removed.
Its historical class-orbit artifacts live in `data/apn/archive/class-orbit/`,
with the old code preserved in Git history and a local ignored source snapshot.

`bin/vbf` runs the `VBFSearch` package CLI: search/resume/status/stop, validate/audit,
compare/classify/verify and publication reports. Production workflows live
under `packages/VBFSearch/`; Fourier math is `VBF.QuadraticExtensions`, catalog seeds
use `VBFCatalog`. Reference evidence defaults to ignored `data/apn/reference`
and `data/apn/supplement.tsv`. Historical census outputs remain archived; old
checkpoints are unsupported. See `packages/VBFSearch/README.md` for the supported API.

The root `census/` tree is removed. Pure coefficient-tree, restriction and profile
math lives in VBF (`QuadraticAPNTree`, `QuadraticRestrictions`, `QuadraticProfiles`).
Original-source rebuild tools are `packages/VBFCatalog/tools/reference/`;
literature audits and study consumers are under `packages/VBFSearch/{tools,experiments}/`.
Historical data is `data/apn/archive/census/`; new rebuilds use `data/apn/rebuilds/`.
See `packages/VBFSearch/CENSUS_REVIEW.md` for the detailed audit and retired components.
