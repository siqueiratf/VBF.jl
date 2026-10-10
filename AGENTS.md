# AGENTS.md - Codex Adapter For VBF.jl

This file is the Codex-facing adapter for the Claude-authored project setup. Keep
it short and operational: Claude-facing knowledge remains the source material,
and this file tells Codex where to look and what rules matter on every task.

Primary sources:
- If a local root `CLAUDE.md` exists, treat it as the canonical private project
  note. It is intentionally ignored by git.
- In this checkout, project knowledge lives in `.claude/context/PROJECT.md`.
- Claude workflows are mirrored for Codex under `.agents/skills/` and
  `.codex/agents/`.

## Project Map

- `packages/VBF/`: core Julia algorithms for vectorial Boolean functions:
  representations, GF(2) linear algebra, spectra, invariants, equivalence, and
  constructions. This package must not depend on `VBFCatalog`.
- `packages/VBFCatalog/`: catalog/data layer for APN functions, S-boxes,
  bibliography, importers, and SQLite-backed corpora. It depends on `VBF`.
- `packages/VBFSearch/`: reproducible search application consuming VBF and VBFCatalog;
  owns experiment state, checkpoints and evidence, never curated catalog writes.
- `packages/VBFCatalog/tools/reference/`: independent original-source rebuild tools;
  run in the root project and write to `data/apn/rebuilds/`.
- `packages/VBFSearch/{experiments,tools}/`: research consumers of package APIs.
- `docs/inspector/`: HTTP evidence viewer; own Julia environment.
- `data/apn/`: reference snapshots, runs, rebuilds and historical artifacts. The
  root `search/` and `census/` trees are retired; see `packages/VBFSearch/CENSUS_REVIEW.md`.
- `packages/VBFCatalog/data-build/`: importer/build scripts with their own
  environment. Do not include these from package tests or a casual REPL.
- `packages/VBFRepro/papers/`: standalone paper-reproduction scripts. Keep one paper claim,
  theorem, lemma, algorithm, table, or experiment per file, and make each file
  runnable on its own.
- `packages/<package>/perf/`: optional BenchmarkTools workloads and profiling.
  Separate development environments; never dependencies of package runtime code.
  Measurements live under `data/perf/`, separate from the curated catalog.
- `packages/VBFRepro/`: reproduction runner, standalone paper claims, and
  cross-paper analysis. Heavy paper dependencies load only in subprocesses.
- `docs/`: Documenter.jl API-reference site generated from source docstrings.
- `.claude/`: Claude source material: project context, original skills, and
  original agent markdown.
- `.agents/skills/`: Codex repo skills copied from the important Claude skills.
- `.codex/`: project-scoped Codex config and custom Codex agents.

## Core Rules

- Requires Julia >= 1.12.
- Math indexing is 0-based; Julia storage is 1-based. Use `lut[x+1]`.
- `FunctionGraph` packs `(x << N) | F(x)`. Walsh zeroes pack `(a << N) | b`.
- Reuse `VBF` APIs before writing paper-local helpers. `helpers.jl` is for
  paper-specific math only.
- Never add a dependency from `VBF` to `VBFCatalog`.
- Curated function entries, LUTs and corpora belong in `VBFCatalog`; consumers
  load them through its APIs. Paper reconstructions and run evidence must not
  become a parallel curated catalog.
- Keep generated results, local overrides, credentials, and copyrighted paper
  inputs out of git.
- **Catalog changes are gated.** `packages/VBFCatalog/BFA_catalog.sqlite` is a
  tracked build product of `data-raw/`, and the catalog test items rebuild their
  expected counts from `data-raw/` and compare them against that DB — so editing
  one without the other fails CI. After touching anything under
  `packages/VBFCatalog/{data-raw,data-build,src,corpora}/` or the DB itself,
  rebuild (`make -C packages/VBFCatalog/data-build catalog`) and run
  `make -C packages/VBFCatalog/data-build check` until it prints
  `catalog-check: OK` — before committing, in the same commit. Enable the hook
  that enforces this once per clone: `git config core.hooksPath .githooks`.
  **Never commit a catalog change with `--no-verify`/`-n`.** That flag skips the
  gate outright, and the gate is the only thing standing between a half-updated
  `data-raw/` and a `catalog_queries_test` count mismatch 40 minutes into CI.
  Two layers enforce this and neither is optional:
  `.githooks/pre-commit` (runs the gate on every catalog-touching commit) and
  `.githooks/claude-commit-guard` (a Claude Code `PreToolUse` hook, wired up in
  `.claude/settings.json`, that refuses `--no-verify` on such a commit and runs
  the gate itself when the clone never enabled `core.hooksPath`). If the gate is
  genuinely wrong, fix the gate — do not route around it. The one sanctioned
  bypass is `VBF_SKIP_CATALOG_CHECK=1`, which prints loudly and must be
  justified in the commit message.
  Adding a family, or changing how many rows one holds, is not done until every
  total in `packages/VBFCatalog/test/unit/catalog_queries_test.jl` that counts it has
  been updated too — total, per-`n`, `is_apn`, `is_permutation`. The gate
  reconstructs those same sums from `data-raw/` and fails on the exact figure
  that would otherwise surface as a bare CI count mismatch, and it separately
  refuses any family the test never names.
- Every `README.md` in the repo is a tracked file, `packages/VBFRepro/papers/<year>/<Paper_ID>/`
  review summaries included. Commit the README you write or edit in the same
  pass; an untracked or uncommitted README is an omission, not a scratch file.
  Never add an ignore pattern that hides one — the negations at the bottom of
  the root `.gitignore` must stay last, and a nested `.gitignore` must mirror
  them rather than ignore a directory that holds a README.

## Test Commands

- VBF package tests:
  `julia -e 'using Pkg; Pkg.activate("packages/VBF"); Pkg.test()'`
- Single paper folder:
  `make -C packages/VBFRepro/papers/<year>/<Paper_ID> test`
- Paper reports should run from the root project, not from a package-local
  project unless that paper's Makefile explicitly does so.

Environment knobs for the main test suite:
- `RETESTITEMS_NWORKERS` defaults to `min(CPU_THREADS, 8)`.
- `RETESTITEMS_TESTITEM_TIMEOUT` defaults to `900`.

## Paper Reproductions

- Follow the organization used by `packages/VBFRepro/papers/2022/Beierle_202201/` and the recent
  multi-file example `packages/VBFRepro/papers/2022/Yu_202211d/`.
- Mirror the publication closely enough that the paper can be read side by side
  with the implementation.
- Paper scripts orchestrate experiments; shared reusable math belongs in
  `packages/VBF/src/`.
- Expensive searches must accept explicit limits such as `limit`,
  `max_evaluations`, `timeout_seconds`, or `full_search`.
- Generated artifacts must be optional and written under the paper's `results/`
  directory.

Useful Codex skills:
- `$reproduce-paper` for implementing a paper reproduction.
- `$review-paper` for auditing existing paper reproductions.
- `$add-experiment` for the multi-agent new-experiment workflow.
- `$lean-ctx` when available for compressed reads, searches, and shell output.

Useful Codex custom agents:
- `paper-reproduction-reviewer`: read-only reproduction reviewer.
- `apn-catalog-updater`: write-side catalog updater, only after a review emits
  concrete Catalog-gap records.

## Codex Notes

- Prefer lean-ctx for large reads, searches, and noisy command output.
- Use raw command output when exact text, counts, or line numbers are evidence.
- Do not duplicate long Claude instructions here; update the Claude source and
  then refresh this adapter when project conventions change.
