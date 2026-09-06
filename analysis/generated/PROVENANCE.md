# Provenance of `analysis/generated/`

Do not edit these files. Rebuild them with `make -C analysis all`.
`analysis/METRICS.md` says what each table is for.

| Field | Value |
|---|---|
| Generated (UTC) | 2026-09-01 20:28 |
| Julia | 1.12.7 |
| Sections | papers |
| Wall time | 5.5 s |

## Sources

- the 42 reproductions — `audit/readme_index.yaml` (2026-08-28 17:38)
- the 36 audit findings — `audit/findings.yaml` (2026-08-28 17:38)
- the classification — `analysis/taxonomy.toml` (2026-09-01 18:57)
- the evidence grades — `manuscript/generated/bfa4r_grades.csv` (2026-09-01 18:52)
- the measured costs — `bench/generated/benchmarks.csv` (2026-09-01 17:34)
- the catalog — `packages/VBFCatalog/BFA_catalog.sqlite` (2026-08-27 20:49)
- the sigma index — `packages/VBFCatalog/corpora/ccz_sigma_index.sqlite` (2026-08-27 20:48)

## Files

| File | Rows | Columns | Written | This run |
|---|---|---|---|---|
| `corpus_overlap.csv` | 13 | 10 | 2026-09-01 20:19 | no |
| `corpus_sigma.csv` | 18 | 10 | 2026-09-01 20:19 | no |
| `defect_kind_by_tier.csv` | 18 | 5 | 2026-09-01 20:28 | yes |
| `evidence_depth.csv` | 9 | 8 | 2026-09-01 20:18 | no |
| `evidence_vs_outcome.csv` | 11 | 10 | 2026-09-01 20:28 | yes |
| `findings.csv` | 36 | 14 | 2026-09-01 20:28 | yes |
| `invariant_power.csv` | 170 | 15 | 2026-09-01 20:19 | no |
| `method_by_dimension.csv` | 26 | 6 | 2026-09-01 20:18 | no |
| `method_completeness.csv` | 36 | 9 | 2026-09-01 20:28 | yes |
| `papers.csv` | 42 | 26 | 2026-09-01 20:28 | yes |
| `reproduction_by_method.csv` | 7 | 13 | 2026-09-01 20:28 | yes |
| `reproduction_by_year.csv` | 17 | 10 | 2026-09-01 20:28 | yes |

Every file above holds data only. No file carries a comment line.
