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
- `packages/VBFCatalog/data-build/`: importer/build scripts with their own
  environment. Do not include these from package tests or a casual REPL.
- `papers/`: standalone paper-reproduction scripts. Keep one paper claim,
  theorem, lemma, algorithm, table, or experiment per file, and make each file
  runnable on its own.
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
- Keep generated results, local overrides, credentials, and copyrighted paper
  inputs out of git.
- Every `README.md` in the repo is a tracked file, `papers/<year>/<Paper_ID>/`
  review summaries included. Commit the README you write or edit in the same
  pass; an untracked or uncommitted README is an omission, not a scratch file.
  Never add an ignore pattern that hides one — the negations at the bottom of
  the root `.gitignore` must stay last, and a nested `.gitignore` must mirror
  them rather than ignore a directory that holds a README.

## Test Commands

- VBF package tests:
  `julia -e 'using Pkg; Pkg.activate("packages/VBF"); Pkg.test()'`
- Single paper folder:
  `make -C papers/<Paper_ID> test`
- Paper reports should run from the root project, not from a package-local
  project unless that paper's Makefile explicitly does so.

Environment knobs for the main test suite:
- `RETESTITEMS_NWORKERS` defaults to `min(CPU_THREADS, 8)`.
- `RETESTITEMS_TESTITEM_TIMEOUT` defaults to `900`.

## Paper Reproductions

- Follow the organization used by `papers/Beierle_202201/` and the recent
  multi-file example `papers/Yu_202211d/`.
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
