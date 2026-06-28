# Beierle 2025 Experiment Inventory

## Paper Metadata

- Title: "Millions of inequivalent quadratic APN functions in eight variables"
- Authors: Christof Beierle, Philippe Langevin, Gregor Leander, Alexandr Polujan, Shahram Rasoolzadeh
- Year: 2025
- Venue: arXiv preprint, August 2025
- Dataset: https://doi.org/10.5281/zenodo.16752428

## Mathematical Setting

- Main setting: quadratic `(8,8)` functions over `F_2^8`.
- Component functions are quadratic forms in `Q(8)`.
- The first construction extends `(8,4)` vectorial bent functions by output coordinates.
- The second construction extends `(n,8)` functions by input coordinates using a linear map criterion.
- Equivalence claims use ortho-derivative labels; for quadratic APN functions, CCZ-equivalence and EA-equivalence coincide.

## Claims Inventory

### theorem23-component-moment

- Type: Theorem
- Section + number: Section 2, Theorem 2.3 and Remark 2.4
- Statement: An `(n,n)` function is APN iff the normalized fourth Walsh moments of its non-zero components sum to `2^(n+1)-2`; for quadratic components, the moment is `2^(n-rank)`.
- Reproducibility: Exact for small and built-in APN examples.
- VBF APIs likely needed: `SBox`, `gold_apn`, `anf`, `rank_f2`, `differential_uniformity`.
- Estimated cost: Fast.
- Proposed Julia file: `component_profiles.jl`
- Proposed Makefile target: `component_profiles`

### table41-known-profile-counts

- Type: Experiment
- Section + number: Section 4.1, Table 4.1
- Statement: The 32,892 previously known quadratic APN classes have the listed `P_6` profile distribution.
- Reproducibility: Exact arithmetic check from the paper table; recomputing the full distribution requires the pre-2025 corpora and full profile classification.
- VBF APIs likely needed: none for the arithmetic check; `VBFCatalog` optional diagnostics.
- Estimated cost: Fast.
- Proposed Julia file: `paper_counts.jl`
- Proposed Makefile target: `paper_counts`

### lemma46-extension-filter

- Type: Lemma
- Section + number: Section 4.1, Lemma 4.6
- Statement: If an `(n,m)` function has differential uniformity greater than `2^(n-m+1)`, it cannot have an APN extension.
- Reproducibility: Exact for square `SBox` examples; paper-scale use is a bounded construction filter.
- VBF APIs likely needed: `differential_uniformity`.
- Estimated cost: Fast.
- Proposed Julia file: `extension_criteria.jl`
- Proposed Makefile target: `extension_criteria`

### lemma47-rank2-orthogonal

- Type: Lemma
- Section + number: Section 4.1, Lemma 4.7
- Statement: A quadratic `(n,n)` function is APN iff the orthogonal complement of its component space contains no rank-2 quadratic form.
- Reproducibility: Exact for `n <= 4` default tests; bounded for larger `n` unless explicitly configured.
- VBF APIs likely needed: `anf`, `rank_f2`, `differential_uniformity`, `gold_apn`.
- Estimated cost: Fast for small `n`, slow for exhaustive `n=8`.
- Proposed Julia file: `extension_criteria.jl`
- Proposed Makefile target: `extension_criteria`

### theorem49-input-extension

- Type: Theorem
- Section + number: Section 4.2, Theorem 4.9
- Statement: The input-extension construction preserves differential uniformity 2 exactly when the chosen linear map avoids the listed derivative values.
- Reproducibility: Exact exhaustive check on small dimensions; bounded/random in the paper-scale search.
- VBF APIs likely needed: `gold_apn`.
- Estimated cost: Fast for the default small case.
- Proposed Julia file: `extension_criteria.jl`
- Proposed Makefile target: `extension_criteria`

### theorem51-new-class-count

- Type: Theorem
- Section + number: Section 5, Theorem 5.1
- Statement: The paper reports at least 3,808,491 CCZ-inequivalent quadratic APN functions on `F_2^8`, including 3,775,599 new classes.
- Reproducibility: Exact arithmetic and streamed dataset sample validation; full inequivalence proof depends on the full Zenodo dataset and sboxU labels.
- VBF APIs likely needed: `SBox`, `algebraic_degree`, `differential_uniformity`, `is_quadratic_apn`, `apn_ea_mugshot`.
- Estimated cost: Fast by default, slow for full dataset validation.
- Proposed Julia file: `dataset_validation.jl`
- Proposed Makefile target: `dataset_validation`

### section5-total-estimates

- Type: Experiment
- Section + number: Section 5, estimates after Theorem 5.1
- Statement: The inverse coupon-collector estimator gives a maximum near 6,123,206, and the known-class overlap estimator gives about 5,786,151.
- Reproducibility: Exact numerical recomputation from the paper's `(t,l)=(92955,92253)`, `M=3776451`, and `t'=32286`.
- VBF APIs likely needed: none.
- Estimated cost: Fast.
- Proposed Julia file: `estimators.jl`
- Proposed Makefile target: `estimators`

### prior-corpus-diagnostics

- Type: Experiment
- Section + number: Sections 3 and 5, comparison to previously known functions
- Statement: The local VBFCatalog pre-2025 corpora can be compared to the paper's prior-known counts without using them as the source of the theorem.
- Reproducibility: Diagnostic only because local corpus counts can include reconciliation/importer choices that differ from the paper table.
- VBF APIs likely needed: `VBFCatalog.load_catalog`, `list_corpora`, `corpus_length`.
- Estimated cost: Fast.
- Proposed Julia file: `catalog_validation.jl`
- Proposed Makefile target: `catalog_validation`

## Routines Checklist

- Recompute Table 4.1 count sum and Theorem 5.1 arithmetic.
- Implement component Walsh-moment/rank checks for quadratic examples.
- Implement Lemma 4.6 and Lemma 4.7 small/exhaustive checks.
- Implement Theorem 4.9 small exhaustive verification.
- Implement Section 5 estimators.
- Implement streamed parser and bounded validator for the Zenodo `new_apns.txt` file.
- Implement optional local catalog diagnostics.

## Open Questions

- The Zenodo file is intentionally not downloaded by default; set `BEIERLE2025_NEW_APNS_PATH` or pass `dataset_path=...` to validate local samples.
- Full reproduction of the 3,775,599-class generation and sboxU inequivalence labels is computationally out of scope for the default target.
- The local VBFCatalog pre-2025 bulk corpora total 32,916 members, not the paper's 32,892 previously known classes; the reproduction labels this as diagnostic.
