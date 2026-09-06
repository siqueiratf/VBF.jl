# Provenance of the benchmark crossings

Do not edit. Rebuild with `make -C bench crossings`.
`bench/README.md` explains each crossing.

| Field | Value |
|---|---|
| Measurements | `bench/generated/benchmarks.csv` |
| Predictions | `bench/crossings.toml` |
| Machine | AMD Ryzen 5 5600G with Radeon Graphics, 12 cores, 1 Julia thread(s), 30.7 GB |
| Julia | 1.12.7 |
| Measured | 2026-09-01, level 2 |
| Statistic | the minimum of N repetitions after one warm-up call |

## `crossing_growth.csv`

- `model = exponential`: the slope is bits of time for each unit of `n`, so time ~ 2^(slope*n).
- `model = power_law`: the slope is the exponent `c` in time ~ n^c, and `n` is a matrix side.
- `reach_n_time` and `reach_n_bytes` give the largest `n` under the ceilings of `bench/crossings.toml`.
- A reach that starts with `>` is a bound: the ceiling lies past the extrapolation cap of the fit.
- `verdict` reads `inconclusive` when the fastest point is under one microsecond, and `(curved fit)` when the straight line misses a point by more than half a bit.

Every case with three or more points carries a prediction.

**Excluded series.**

- `invariants/apn_ea_mugshot` — The payload changes class inside the sweep. n = 5 uses Kasami x^13 and n = 6 uses the Dillon permutation, and both take the fallback path. n = 8, 10 and 12 use Gold x^3, which takes the quadratic path. The two paths are different algorithms, so the five points do not form one series. A fit over all five returns 0.11 bits per n, which is below every path in the code.

**External checks of an extrapolation.**

| Case | n | Fit (s) | Measured (s) | Ratio | Source |
|---|---|---|---|---|---|
| `invariants/gamma_rank` | 8 | 141.9 | 166.8 | 0.85 | bench/calibration.toml [design_rank_gamma] n8_seconds |

## `crossing_polarity.csv`

`ratio_seconds` and `ratio_bytes` are the negative side over the positive side.
`direction` names the faster answer; `agrees` says whether it met the expectation of the spec.

## `crossing_memory.csv`

CAUTION: `bytes` comes from `@allocated`. It is the total that one call
allocates, and it is NOT the peak resident memory. A routine that allocates
2 GB in small pieces can run inside a much smaller resident set.

- Machine memory: 30.7 GB.
- Cases that allocate at least 1 GiB: 6 of 229.
- Highest allocation rate among those: 3.12 GiB/s.
