# Provenance of `analysis/generated/`

Frozen historical output; the source paths below describe the original run.
The root investigation and its defect tables are retired. Their source snapshot
is available in Git at `9f0e7d1`; these archived CSVs are not current results.
Current analysis commands and table definitions live in
`packages/VBFRepro/analysis/` and require no root investigation files.

| Field | Value |
|---|---|
| Generated (UTC) | 2026-09-09 01:37 |
| Julia | 1.12.7 |
| Sections | corpus |
| Wall time | 41.4 s |

## Sources

- the 42 reproductions — `audit/readme_index.yaml` (2026-08-28 17:38)
- the 36 audit findings — `audit/findings.yaml` (2026-08-28 17:38)
- the classification — `analysis/taxonomy.toml` (2026-09-01 18:57)
- the evidence grades — `manuscript/generated/bfa4r_grades.csv` (2026-09-09 01:35)
- the measured costs — `bench/generated/benchmarks.csv` (ABSENT)
- the catalog — `packages/VBFCatalog/BFA_catalog.sqlite` (2026-09-07 21:06)
- the sigma index — `packages/VBFCatalog/corpora/ccz_sigma_index.sqlite` (2026-08-27 20:48)

## Files

| File | Rows | Columns | Written | This run |
|---|---|---|---|---|
| `corpus_overlap.csv` | 13 | 10 | 2026-09-09 01:37 | yes |
| `corpus_sigma.csv` | 18 | 10 | 2026-09-09 01:37 | yes |
| `defect_kind_by_tier.csv` | 18 | 5 | 2026-09-09 01:36 | no |
| `evidence_depth.csv` | 9 | 8 | 2026-09-09 01:37 | no |
| `evidence_vs_outcome.csv` | 11 | 10 | 2026-09-09 01:36 | no |
| `findings.csv` | 36 | 14 | 2026-09-09 01:36 | no |
| `invariant_power.csv` | 170 | 15 | 2026-09-01 20:19 | no |
| `method_by_dimension.csv` | 26 | 6 | 2026-09-09 01:36 | no |
| `method_completeness.csv` | 36 | 9 | 2026-09-09 01:36 | no |
| `papers.csv` | 42 | 26 | 2026-09-09 01:36 | no |
| `reproduction_by_method.csv` | 7 | 13 | 2026-09-09 01:36 | no |
| `reproduction_by_year.csv` | 17 | 10 | 2026-09-09 01:36 | no |

Every file above holds data only. No file carries a comment line.
