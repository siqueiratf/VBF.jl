# Beierle 2025 Reproduction Review

## Critical

None.

## Important

1. Full 3,775,599-class generation and sboxU inequivalence labeling are not reproduced by default. The report marks these as out of scope because they require the full Zenodo dataset and substantial external computation.
2. The local VBFCatalog pre-2025 corpora total 32,916 members, while the paper states 32,892 previously known classes. The implementation keeps this as a diagnostic and uses the paper constants for theorem arithmetic.

## Minor

1. The Zenodo file `new_apns.txt` is not present under `input/datasets/`; streamed sample validation is ready once `dataset_path=...` or `BEIERLE2025_NEW_APNS_PATH` is provided.

## Passed Checks

- `make -C papers/Beierle_202508 test` exits cleanly.
- `make -C papers/Beierle_202508 report` exits cleanly without reading the full dataset.
- `make -C papers/Beierle_202508 help` exits cleanly.
- `VBFCatalog` is imported only in `catalog_validation.jl`.
- Dataset reads are bounded by `sample_size` or `max_lines`.
- Generated report artifacts are guarded by `save_results=true` and written under `results/`.

## Summary

The folder is ready as a bounded reproduction harness: it exactly checks the paper's printed counts, small-case component/rank criteria, extension theorem behavior, and Section 5 estimators, and it can stream-validate local Zenodo samples without loading the full 3.4 GB file.
