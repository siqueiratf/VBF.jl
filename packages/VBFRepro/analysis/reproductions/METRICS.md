# Reproduction analysis tables

`metrics.jl` reads current package inputs and writes CSVs to
`data/repro/analysis/reproductions/`. `PROVENANCE.md` records the input paths,
execution configuration and files written in the run. Set
`VBF_REPRO_ANALYSIS_OUTPUT` (or Make's `output`) to select another destination.

VBFCatalog is the source of curated function entries and corpus descriptions.
These tables are derived views. They neither add functions nor establish that
all known APN classes have been collected.

| Section | Output | Meaning |
|---|---|---|
| papers | `papers.csv` | Current runnable paper inventory from `VBFRepro.discover_papers`, optional publication-evidence grades, test-file counts and catalog contributions. |
| catalog | `method_by_dimension.csv` | Curated functions and corpus membership/signature counts by method and dimension. |
| catalog | `evidence_depth.csv` | Declared reference coverage by dimension. |
| corpus | `corpus_sigma.csv` | Member counts, stored signature counts and within-source collision summaries. |
| corpus | `corpus_overlap.csv` | Signature overlap between explicitly available sources. |
| invariants | `invariant_power.csv` | Bounded computations on recorded catalog/corpus samples: evaluations, failures, buckets, pair separation and batch time. |

`taxonomy.toml` assigns paper subjects and presentation categories. It holds no
function LUTs. Two bibliography aliases connect reproduction IDs to catalog
keys; all contribution counts are queried from the catalog. New papers appear
in the inventory automatically, with an explicit unclassified subject until
classified. `test_files` counts files under `test/` and `tests/`; it does not
count successful assertions or certify a reproduction verdict.

`r1`–`r4` in `papers.csv` come from an optional generated `bfa4r_grades.csv`.
`grades.jl` documents the extraction rules and their limitations. The separately
curated `curated_bfa4r.csv` records assessments of publication inputs; it does
not grade mathematical correctness. Neither is inferred from historical defect
counts. Historical defect aggregations and verdict plots are retired.

Signature counts describe the stored index and its source provenance. Different
exact ortho-derivative tuples separate verified quadratic APNs through the
EA/CCZ theorem; equal tuples do not prove equivalence. Signature hashes require
the index's encoding and integrity assumptions. Corpus members, distinct
invariants and confirmed equivalence classes are different quantities.

The invariant section accepts `--sample`, `--seed` and `--budget-seconds`.
Budgeted prefixes, undefined results and failures remain visible. Pair
separation refers to the evaluated sample, not a whole corpus. A plot includes
only complete, error-free batches. Its time is total batch processing time per
evaluated member, including conversion and grouping; it is not an API
microbenchmark or a confidence interval. Historical benchmark values, when
present in the CSV, retain their original protocol and are not plotted as new
measurements.

`figures.jl OUTPUT [INPUT]` renders the current catalog/corpus tables, measured
invariant plot and curated publication-evidence grades. Figure destinations
are explicit. It does not require historical investigation files. Scientific
results and unresolved claims remain with each paper's implementation, tests,
README and independently reproducible result manifests.
