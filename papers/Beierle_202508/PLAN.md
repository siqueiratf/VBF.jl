# Beierle 2025 Reproduction Plan

## Project Context

This folder reproduces selected experiments from Beierle, Langevin, Leander, Polujan, and Rasoolzadeh (2025) using VBF.jl primitives where the computation is practical. The full millions-scale search and sboxU inequivalence labeling are exposed as dataset-driven or out-of-scope checks, not run by default.

## Source Material

- PDF: `input/Beierle et al. - 2025 - Millions of inequivalent quadratic APN functions in eight variables.pdf`
- Extracted TeX: `input/Beierle_2025_APN_full_extraction.tex`
- Dataset: Zenodo record `10.5281/zenodo.16752428`, file `new_apns.txt`
- Local rules: `input/.codex/context/PROJECT.md`, `input/.codex/skills/reproduce-paper/SKILL.md`

## Reproduction Scope

- Exact: paper count arithmetic, Table 4.1 total, Lemma 4.6 on square examples, Lemma 4.7 on small quadratic examples, Theorem 4.9 on small exhaustive examples, Section 5 estimators.
- Bounded: streamed validation of local `new_apns.txt` samples; optional line counting with a caller-provided limit.
- Diagnostic: local VBFCatalog pre-2025 corpus counts, because they do not exactly match the paper's 32,892 prior-class total.
- Out of scope: reconstructing all 3,775,599 new classes, applying full `J_2` classification at scale, and reproducing the full sboxU inequivalence/permutation-equivalence proof.

## Architecture Restrictions

- Keep paper-specific orchestration under `papers/Beierle_202508`.
- Do not add paper-specific algorithms to `packages/VBF`.
- Do not add any dependency from `VBF` to `VBFCatalog`.
- Use `VBFCatalog` only in `catalog_validation.jl`.
- Keep generated artifacts under `results/`, guarded by `save_results=true`.
- No hard-coded absolute paths; use `@__DIR__`, environment variables, or Makefile parameters.
- Default targets must avoid full dataset reads and long searches.

## Proposed File Layout

- `EXPERIMENTS.md`: extracted claim inventory and reproducibility classification.
- `PLAN.md`: this implementation plan and scope contract.
- `Makefile`: runnable paper targets with bounded parameters.
- `helpers.jl`: constants, reporting, TOML output, generic LUT helpers.
- `paper_counts.jl`: Table 4.1 and Theorem 5.1 arithmetic checks.
- `component_profiles.jl`: quadratic component rank and Walsh-moment checks.
- `extension_criteria.jl`: Lemma 4.6, Lemma 4.7, and Theorem 4.9 checks.
- `estimators.jl`: Section 5 coupon-collector and overlap estimators.
- `dataset_validation.jl`: streamed Zenodo dataset parser/sample validator.
- `catalog_validation.jl`: optional local VBFCatalog corpus diagnostics.
- `report.jl`: aggregate report that runs only fast/default checks.
- `test/`: focused tests for exact arithmetic, small examples, parser behavior, and estimators.
- `results/.gitkeep`: placeholder for optional generated artifacts.

## Makefile Targets And Parameters

- Targets: `help`, `test`, `report`, `paper_counts`, `component_profiles`, `extension_criteria`, `estimators`, `dataset_validation`, `catalog_validation`, `clean_results`.
- Parameters: `limit`, `max_evaluations`, `sample_size`, `dataset_path`, `save_results`, `seed`, `full_search`, `check_ortho`.
- Default `sample_size=0` means the report verifies metadata and arithmetic without reading the large dataset.

## Implementation Phases

- Phase 1: Normalize paper constants, profile-table counts, reporting helpers, and result writing.
- Phase 2: Implement exact arithmetic checks and Section 5 estimators.
- Phase 3: Implement small-dimension component-rank, Lemma 4.7, and Theorem 4.9 checks.
- Phase 4: Implement streamed Zenodo parser/sample validation with explicit limits.
- Phase 5: Implement optional catalog diagnostics and aggregate report.
- Phase 6: Add tests and run `make test` and `make report`.

## Acceptance Criteria

- `make -C papers/Beierle_202508 test` passes.
- `make -C papers/Beierle_202508 report` completes without reading the full dataset.
- The report labels every claim as exact, bounded, diagnostic, loaded artifact, or out of scope.
- Any dataset read requires `sample_size` or an explicit `limit`.
- Generated results are only written under `results/` when `save_results=true`.
- No `VBFCatalog` import occurs outside `catalog_validation.jl`.

## Validation Findings

- Required VBF APIs are exported: `SBox`, `gold_apn`, `anf`, `rank_f2`, `differential_uniformity`, `algebraic_degree`, `is_quadratic_apn`, `apn_ea_mugshot`.
- `VBFCatalog` is not needed for the theorem arithmetic and remains diagnostic.
- The full dataset is too large for default ingestion; the reproduction uses a streaming parser and sample validator.
- No missing VBF APIs block the bounded reproduction.
