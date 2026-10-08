# Component profiles of sampled quadratic (8,8)-APN functions: new versus known

Date: 2026-10-08. Scripts, logs and tables are in this directory.

## 1. Data

- Probes: 4,012,000 (`s1.tsv` + `chunks/c101..c140.tsv`). APN hits: 1,661.
- `analyze_hits.jl` is a copy of the study's analysis script. It also writes
  `all40_hits.tsv` (status, matched source, log weight `logw + log(e)`, σ hash,
  coefficients) for each hit. It gives the same numbers as the analysis
  (coverage 0.6770 ± 0.0133). Its 553 new rows are identical to the list of new
  classes.
- Known hits by source: beierle2025 1,101; beierleleanderperrin2022 3;
  yuperrin2022_qam 3; yuwangli2014_qam 1.

## 2. Methods (`profiles_lib.jl`)

- Rank of component b = F2-rank of the alternating matrix (b·c_ij).
  α = 2^(8−rank).
- P_k: an exact level-by-level search. It keeps every distinct subspace V_i
  that reaches the best prefix. Subspaces are 256-bit masks.
- Two pair orders: `lex` (standard lexicographic order on (b, K)) and `bminK`
  (b descending, then K ascending).
- Bent subspaces: a depth-first search over increasing bases of bent elements.
- Weighted fraction = Σ_profile w / Σ w. Known fraction in a profile =
  Σ_profile,known w / Σ_profile w.
- Estimated classes = weighted fraction × 5.5e6. The weights estimate mass
  (Σ 1/|Stab|), not class counts. Almost all classes have a trivial stabilizer,
  so the difference is small.

## 3. Validation (`validate.log`, `corpus_beierle2025_5000.log`)

- Both orders give the README profiles for `edelpott2009_n8` #1 and #3, and for
  the three `beierleleander2022_n8` outliers (#9172, #9624, #10320).
- The ranks agree with `component_quadratic_rank`. The bent sets agree with
  `VBF.bent_components`. All 1,661 hits are APN with Σα = 510.
- `bminK` is the order that agrees with Table 3.1 of the paper. On 400 random
  `beierleleander2022_n8` members, every `bminK` profile is a Table 3.1 row.
  With `lex`, 42 of 400 get the level-5 entry (30,46), which the table does not
  have.
- `beierle2025_n8`: 398 of 400 satisfy profile (3.7) with B6 ≥ 54. In a sample
  of 5,000, about 0.5% have B6 = 52.

## 4. Results (P6 under `bminK`; the prefix `[(0,0),(1,1),(3,3),(7,7),(15,15),` is not shown)

| Levels 5–6 | New | Known | Weighted fraction | Estimated classes | Known fraction |
|---|---:|---:|---:|---:|---:|
| (28,40),(52,96) | 53 | 1 | 0.030 | 1.7e5 | 0.01 |
| (28,40),(54,90) | 6 | 1 | 0.004 | 2e4 | 0.13 |
| (30,34),(52,96) | 302 | 5 | 0.179 | 9.8e5 | 0.02 |
| (30,34),(54,90) | 179 | 918 | 0.670 | 3.68e6 | 0.84 |
| (30,34),(56,84) | 10 | 176 | 0.112 | 6.1e5 | 0.95 |
| others | 3 | 7 | 0.006 | 3e4 | — |

By branch (weighted share of the new mass):

| Branch | Share of new | Known fraction | Estimated unknown classes |
|---|---:|---:|---:|
| B6 = 52 (Algorithm 3.1 needs B6 ≥ 54) | 54% | 2% | about 1.0e6 |
| B6 = 54 (only half extended, Remark 3.19) | 34% | 84% | about 0.6e6 |
| Level-5 entry (28,40) (Remark 3.11) | 10% | 2.5% | about 0.18e6 |
| B6 ≥ 56 (fully targeted) | less than 2% | 95% | about 0.03e6 |

Cross-check: about 23k published known classes have B6 = 52 (3.6k before 2025
and 19.6k in beierle2025). The estimate from the weights is 22k.

Rank types (counts of ranks 8, 6, 4, 2):

| Type | New | Known | Known fraction |
|---|---:|---:|---:|
| (170,85,0,0) | 542 | 1,018 | 67% |
| (174,80,1,0) | 11 | 88 | 86% |
| (178,75,2,0) | 0 | 2 | 100% |

Hypothesis 3.2: all 553 new and all 1,108 known hits contain a 4-dimensional
all-bent subspace (213 to 776 such subspaces for each new function). There is no
counterexample.

Automorphism group and CCZ-equivalence to a permutation: both VBF calls are too
slow (all 6 calls on 3 new functions stopped at the 120 s limit).

## 5. Conclusion

The B6 = 52 branch is the main unexplored region: about 1e6 classes, about 98%
unknown, mostly `[..,(30,34),(52,96)]`. The next targets are the other half of
the B6 = 54 branch and the level-5 (28,40) branch ((8,5)-functions with 28 bent
components).

## 6. Rerun (from the directory that holds `s1.tsv` and `chunks/`, with `J="julia --project=$ROOT"`)

```
$J properties/analyze_hits.jl properties/all40 s1.tsv chunks/c1*.tsv > properties/analyze_hits.log
$J properties/validate.jl 400 400 > properties/validate.log
$J properties/corpus_profiles.jl beierle2025_n8 3775599 5000 7 > properties/corpus_beierle2025_5000.log
$J properties/compute.jl            # -> hit_properties.tsv (about 5 min)
$J properties/tabulate.jl > properties/tables.txt
sh properties/run_aut_perm.sh 3 > properties/aut_perm.log   # optional, 120 s for each call
```
