# B6 = 52 search: run on the Framework desktop (2026-10-08/09)

Scientific scope update: the APN/signature results were reconciled against the
source-rebuilt baseline in the [current audit](../../../packages/VBFSearch/AUDIT.md). The
capture–recapture calculations below are historical exploratory estimates;
uniform sampling and independence are not established. They do not certify a
global class count, coverage fraction or exhaustiveness.

**Input**: `results/20261009-search-b52-results/results/desk1/` (copied by the user into the
main checkout; analysed in a copy at `results/desk1_framework/`, ignored by git).
**Machine**: Framework desktop, 30 threads (`mode=v5`).
**Verified list**: `framework_20261009_new.tsv.gz` (σ, status, generation, recorded B6,
coefficients).

## 1. Summary

| Quantity | Value |
|---|---|
| Run segments | 3 (10-seed test; about 2 h, interrupted; 8 h, stopped at the timeout) |
| Expanded seeds | 11,405 (plus 67 of the earlier trial) |
| Thread-hours | 277 |
| Distinct σ found | 498,300 |
| Known (in the σ index) | 388,343 (10.2 % of the known classes) |
| Census classes found again | 14 |
| Search-new, verified by `make novelty` | **109,943** (0 failed; APN, σ recalculated, absent from the index and from the 553) |
| Of these, public raw-only classes (`../crosscheck_raw/raw_only_546.tsv`) | 61 (not new) |
| Of these, already in the trial list / the hyperplane list | 773 / 31 |
| New classes found only in this run | **109,078** |
| New classes per thread-hour | 396 |

**All new classes of the study (union): 553 + 1 + 463 + 773 + 109,078 = 110,868.**

## 2. Yield over time (8-hour segment)

| Hour | Seeds | New (first found) | Known | Known / new | New per seed |
|---:|---:|---:|---:|---:|---:|
| 1 | 960 | 11,097 | 39,387 | 3.55 | 11.6 |
| 2 | 1,437 | 11,979 | 46,908 | 3.92 | 8.3 |
| 3 | 1,402 | 11,863 | 46,546 | 3.92 | 8.5 |
| 4 | 1,092 | 11,323 | 42,048 | 3.71 | 10.4 |
| 5 | 1,168 | 11,540 | 43,160 | 3.74 | 9.9 |
| 6 | 1,154 | 11,401 | 42,805 | 3.75 | 9.9 |
| 7 | 1,171 | 11,339 | 43,751 | 3.86 | 9.7 |
| 8 | 1,214 | 11,445 | 43,564 | 3.81 | 9.4 |

The yield is constant: about 11,500 new classes per hour. The seed queue grew from 6,530 to
42,280 seeds. Thus the search is far from saturation.

The yield per thread-hour (396) is lower than in the trial (about 1,400). The cost per seed
is the reason: 87.4 thread-seconds here against 29.5 s in the trial. The 30 threads share 16
cores (SMT), and the queue now holds more of the expensive seeds. The new classes per seed
are almost the same (9.6 against 11.5).

## 3. Composition (random samples, `framework_b6_sample.jl`, seed 20261009)

P6 profile in the bminK order (the order that agrees with Table 3.1 of the paper):

| B6 (profile) | New, sample of 500 | Known, sample of 2,000 |
|---:|---:|---:|
| 52 | 265 (53.0 %) | 2 (0.1 %) |
| 54 | 204 (40.8 %) | 1,427 (71.4 %) |
| 56 | 30 (6.0 %) | 527 (26.4 %) |
| 58 | 1 (0.2 %) | 40 (2.0 %) |
| 60 | 0 | 4 (0.2 %) |

- 18 of the 500 new classes (3.6 %) have the level-5 entry (28,40). All 2,000 known classes
  have (30,34).
- Almost all the B6 = 52 classes that the search reaches are new. The known classes that it
  reaches are the B6 ≥ 54 classes of the published list. This agrees with the census
  (B6 = 52 is 98 % unknown).

**Note on the B6 definition.** The search records the largest bent count over all 6-dim
subspaces (`b6_of` in `search.jl`). The profile takes B6 along the best flag, which starts
from the best 5-dim subspace. For 41 of the 500 sampled new classes, the free maximum is 54
and the profile value is 52. Thus the recorded column (`b6_free_max`) gives 48.5 % with B6 =
52, and the profile gives 53 %. The search only queues classes with a free maximum of 52, so
it does not use about 8 % of the new profile-B6 = 52 classes as seeds.

## 4. How much of the unknown classes has the search found? (capture–recapture)

A marked sample that is independent of the search gives the fraction of the unknown classes
that the search has found (Lincoln–Petersen). Heterogeneous capture by the search does not
bias this estimate if the marked sample is a uniform sample.

1. **Census classes with B6 ≥ 54 (profile).** The census sample is a mass-weighted, thus
   almost uniform, sample of all classes. Its 355 classes with B6 = 52 were seeds of the
   search, so they are not independent. Its 198 classes with B6 ≥ 54 (187 with 54, 10 with
   56, 1 with 58) were not seeds. The search found 14 of them (13 with 54, 1 with 56): 7.1 %.
   The search found about 0.47 × 109,943 + 14 ≈ 51,700 unknown classes with profile B6 ≥ 54.
   Thus the unknown classes with B6 ≥ 54 number about 51,700 × 198 / 14 ≈ **0.73 M**
   (95 % interval 0.44–1.34 M, from the Poisson interval 7.7–23.5 for 14). The census
   estimate for these branches is about 0.64 M (`../reports/properties/REPORT.md`).
2. **The hyperplane-scan classes.** The 463 new classes of `../theory/hyperplane_scan/` come
   from a different mechanism. The search found 31 of them: 6.7 %. Thus the unknown classes
   number about 109,957 × 463 / 31 ≈ **1.64 M** (95 % interval 1.16–2.42 M). The census gives
   1.66 M (mass) to 1.81 M (coverage). This estimate assumes that the hyperplane classes are
   a uniform sample of the unknown classes. That is not proved (`../theory/HYPERPLANE.md`,
   Observation 6.4).
3. The 546 raw-only classes are not a uniform sample (they come from the authors' Algorithm
   3.1). The search found 61 of them (11.2 %).

Both independent checks agree with the census. After about 10 hours, the search has found
about 6–7 % of the unknown classes:

| Branch (profile) | Unknown classes (census) | New found in this run (estimate) | Fraction found |
|---|---:|---:|---:|
| B6 = 52 | about 1.13 M | about 58,000 | about 5 % |
| B6 = 54 | about 0.61 M | about 45,000 | about 7 % (capture–recapture: 7.1 %) |
| B6 ≥ 56 | about 0.03 M | about 6,800 | about 20 % |

## 5. What a longer run gives

- The 42,280 queued seeds cost about 87 thread-seconds each, that is about 1,000
  thread-hours (about 34 hours on 30 threads). Each expanded seed adds about 3.6 seeds.
- At the present rate (396 new classes per thread-hour), the 1.6–1.8 M unknown classes need
  at least 4,200 thread-hours (about 140 hours on 30 threads). The rate will fall when the
  fraction found grows, so this is a lower bound.
- The search cannot prove that it found all classes (see `../README.md`).

## 6. Recommendations for the next run

1. Queue seeds by the profile B6, or by both definitions, so that the 8 % of B6 = 52 classes
   with a free maximum of 54 also become seeds.
2. The B6 = 54 branch has about 0.6 M unknown classes. The search already finds about 45,000
   of them as a by-product. Queuing the new B6 = 54 classes too (`enqueue_b6=-1`) widens the
   search to that branch.
3. The (28,40) branch (about 0.17 M unknown) is reached only a little (3.6 % of the new
   classes). A run with only (28,40) seeds would show its yield.
4. Use the physical cores (`threads=16`) and compare the yield per thread-hour with SMT.

## 7. Reproduce

```
cp -r <run directory>/desk1 results/desk1_framework
make novelty outdirs="$PWD/results/desk1_framework $PWD/results/trial"
julia --project=<root> -t 6 framework_b6_sample.jl results/desk1_framework/found.tsv 2000 500 20261009 \
    results/desk1_framework/b6_sample.tsv
```
