# Census of quadratic APN functions on F_2^8

**Path**: `census/quadratic_apn8/`

**Status**: The estimator is validated against exact values for n ≤ 7. The census
numbers below come from 4,012,000 samples. The novelty claims (the 553 new σ) are
**pending verification**. A separate verification is running.

---

## Question

How many CCZ classes of quadratic APN functions exist on F_2^8?

Beierle et al. (2025) give the lower bound 3,808,491 (Theorem 5.1). This study gives an
unbiased estimate of the total number N. It also collects sampled APN functions whose CCZ
invariant σ is absent from the known-class index of VBFCatalog.

## Mathematics

### Exact reduction

A quadratic function is EA-equivalent to its pure quadratic part. For quadratic APN
functions, CCZ-equivalence is the same as EA-equivalence (Yoshiara). Thus a CCZ class is
an orbit of `GL(n,2) × GL(m,2)` on pure quadratic APN functions

    F(x) = XOR_{i<j} x_i x_j c_ij,   c_ij ∈ F_2^m.

F is APN if and only if the linear map `Λ²(F_2^n) → F_2^m`, `e_i ∧ e_j ↦ c_ij`, is nonzero
on every decomposable vector `x ∧ y`. Let `T(n,m)` be the number of APN coefficient tuples.
Then `T(n,m) = χ_{G(2,n)}(2^m)`, the characteristic polynomial of the Grassmannian matroid
(Crapo–Rota). For n = 3, every nonzero vector of `Λ²` is decomposable, so
`T(3,m) = (2^m−1)(2^m−2)(2^m−4)`.

### Mass formula

The orbit-stabilizer theorem gives

    T(n,m) / (|GL(n,2)| · |GL(m,2)|) = Σ_classes 1/|Stab|.

We call the right side the **mass** M. Each class with `|Stab| ≥ 2` contributes less than 1.
For a class representative F, `|Stab| = |Aut(F)| / 2^n`, where `|Aut(F)|` is the number of
linear self-equivalences from `automorphisms_from_ortho_derivative` (VBF).

### Knuth estimator

The extension tree adds one input variable at a time. Theorem 4.1 of Beierle et al.
(2025, v2): `G(x, x_n) = F(x) + x_n L(x)` is APN if and only if F is APN and
`L(α) ∉ I_α = Im B_F(α, ·)` for all `α ≠ 0`. The sampler builds L one basis vector at a
time. It selects `L(e_k)` uniformly among the `d_k` values that are valid at that step. It
multiplies the numbers `d_k` (Knuth 1975). The weight `W = Π d_k` satisfies `E[W] = T(n,m)`.
A dead end gives `W = 0`.

### Exact last step

The sampler stops the random walk at n−1 variables. It counts the last step exactly: `e(G)`
is the number of linear L that extend G to an APN function on n variables. The group
`Λ = { x ↦ B(x, β) }` acts freely on these L (Lemma 4.5). Thus `e(G) = 2^(n−1) · c`, where c
counts one canonical L per orbit. The counter (`fastlast.jl`, module `FL3`) uses 256-bit
coset masks, forward checking and fail-first ordering. The weight of a sample is
`W = Π d_k · e(G)`. When `e(G) > 0`, the sampler selects one canonical completion uniformly
and writes the resulting APN function.

### Coverage estimator

A sampled function of class K appears with probability proportional to `|orbit(K)| / W`.
Weighting each hit by W gives an unbiased estimate of the mass share of a set of classes.
Let `known_t = 1` when the σ of hit t is in the index. Then

    c      = Σ W_t · known_t / Σ W_t            (ratio estimator, delta-method SE)
    M_cov  = KNOWN_MASS / c
    N(cov) = M_cov + (KNOWN_CLASSES − KNOWN_MASS)

`KNOWN_CLASSES = 3,808,491`. `KNOWN_MASS = 3,799,974.1228` is `Σ 2^8/|Aut|` over Table 5.2
(a)+(b) of Beierle et al. (2025, v2). The difference (8,517) corrects for the known classes
with a nontrivial stabilizer. The estimate `N(mass) = M + 8,517` is a lower-side estimate,
because unknown classes with `|Stab| ≥ 2` add less than 1 to M.

σ is the ortho-derivative signature (differential and absolute Walsh spectra of the
ortho-derivative). It is a CCZ invariant of quadratic APN functions. A σ that is absent
from the index proves that the class is absent from the indexed corpora.

## Sample files

Each line of a sample TSV file has four columns:

| Column | Meaning |
|---|---|
| `i` | Sample index in the chunk (1-based). |
| `logw` | `Σ log d_k` of the random walk to n−1 variables. `-Inf` when the walk dies before n−1 variables. |
| `e` | Exact number `e(G)` of APN completions of the (n−1, m) function. `0` for a dead end or when no completion exists. |
| `coeffs` | Only when `e > 0`: `c_ij` for `i < j` in row order, two hex digits each (28 bytes for n = 8). One canonical completion, chosen uniformly. |

The sample weight is `exp(logw) · e`. Rows with `-Inf` or `e = 0` have weight 0. **Keep
them in the data.** The estimator divides by the number of probes, not by the number of
hits. If you remove these rows, the mass estimate is too large by the factor
`samples / hits` (about 2,400 for n = 8).

### Random number scheme

Thread `th` of T uses `Xoshiro(seed · 100003 + th)` and computes the samples
`i = th : T : N`. Thus a chunk is a function of (N, seed, T, n, m). **The same seed and the
same thread count T reproduce a chunk byte for byte.** A different T gives a different,
equally valid chunk. The legacy chunks use T = 12. The default of `threads` is 12.

## Validation

| Check | Method | Estimate | Exact | Where |
|---|---|---|---|---|
| T(3,3), T(3,4), T(3,5) | DFS, closed form | 168, 2,520, 26,040 | same | `make test` |
| T(4,4) | DFS | 1,128,960 (mass 1/360) | same | `make test` |
| T(n,m), n ≤ 4 | plain Knuth, Knuth + exact last step | within 5 SE | | `make test` |
| FL, FL2, FL3 | vs slow counter QK2, 34 random cases | equal | | `make test` |
| (5,5) mass | pipeline, 2,000 samples | within 5 SE and 5 % | 2/155 = 0.012903 | `make test` |
| (6,6) mass | plain Knuth, 200,000 probes, seed 7 | 7.71986 ± 0.0415 (z = +2.10) | 7.632804 | `make validate` |
| (7,7) mass | pipeline, 200,000 samples, seed 7, 12 threads | 472.304 ± 1.31 (z = −1.85) | 474.7177 | `make validate` |
| (7,7) mass | pipeline, legacy `s77.tsv` (200,000 samples, seed 7, 4 threads) | 475.002 ± 1.31 (z = +0.22) | 474.7177 | `make validate data77=…/s77.tsv` |

Other seeds show the expected spread. (6,6), 200,000 probes, seeds 8–11:
z = +1.06, −0.62, +0.45, −0.06. (7,7), 50,000 samples, 12 threads, seeds 7–11:
z = −3.90, +0.70, −1.62, +0.82, −0.11. The seed-7 run with 50,000 samples is the largest
deviation that we saw; for this reason the default of `samples77` is 200,000.
`validate` fails when |z| ≥ 4.

The exact masses come from the catalog class representatives (`make exact_masses`):

| n | Classes | Σ 2^n/\|Aut\| | \|Aut\| histogram |
|---|---|---|---|
| 4 | 1 | 1/360 | 5760 × 1 |
| 5 | 2 | 2/155 | 4960 × 2 |
| 6 | 13 | 7 + 2/5 + 1/7 + 1/14 + 1/63 + 1/378 = 7.632804 | 64 × 7, 320 × 2, 448, 896, 4032, 24192 |
| 7 | 488 | 473 + 12/7 + 3/889 = 474.7177 | 128 × 473, 896 × 12, 113792 × 3 |

The catalog has no n = 3 representative. The n = 7 computation takes about 20 minutes.

## Results

Data: legacy `s1.tsv` (12,000 samples, seed 1) and chunks `c101`–`c140` (100,000 samples
each, seeds 101–140), all with 12 threads.

| Quantity | Value |
|---|---|
| Samples | 4,012,000 |
| APN hits (`e > 0`) | 1,661 (hit rate 4.14e−4) |
| Mass M = Σ 1/\|Stab\| | 5.464e6 ± 1.58e5 (2.9 %) |
| Hits with known σ | 1,108 of 1,661 (beierle2025_n8 1,101; beierleleanderperrin2022_n8 3; yuperrin2022_qam_n8 3; yuwangli2014_qam_n8 1) |
| Weighted coverage c | 0.6770 ± 0.0133 |
| Mass from coverage | 5.613e6 ± 1.1e5 |
| **N(cov)** | **5.621e6 ± 1.1e5** |
| N(mass) | 5.473e6 ± 1.58e5 |
| Distinct new σ | 553, no repeats (**pending verification**) |

Thus about 32 % of the mass of quadratic APN classes on F_2^8 is outside the known
classes. The 553 new σ are in `results/new_sigma.tsv` (`sigma_hash<TAB>coeffs`). Each line
certifies a CCZ class that is absent from the indexed corpora, if the σ index is complete.
A separate verification of these 553 functions is running. Do not cite them as new
classes before it ends.

## Reproduce the numbers

Run all commands from the repository root or from this folder. All targets use
`julia --project=<repo root>`.

| Number | Command | Time |
|---|---|---|
| Unit tests | `make test` | < 1 min after precompilation |
| Census table above, `results/new_sigma.tsv` | `make analyze` (reads the legacy data in place; `results/new_sigma.tsv` is identical to the legacy `all40_new.tsv`) | about 15 s |
| All numbers in `results/report.toml` | `make report` | about 3 min |
| (6,6), (7,7) validation | `make validate` | about 2.5 min |
| (7,7) with the legacy file | `make validate data77=$LEGACY/s77.tsv` | about 30 s |
| Exact masses n = 4..6 / n = 4..7 | `make exact_masses` / `make exact_masses nmax=7` | seconds / about 20 min |
| `s1.tsv` byte for byte | `make reproduce` (seed 1, 12,000 samples, 12 threads) | 1–2 min |
| `c101.tsv` byte for byte | `make reproduce seed=101 ref_samples=100000 ref=$LEGACY/chunks/c101.tsv` | 8–15 min on 12 free cores |
| All 40 chunks | `make sample first_seed=101 chunks=40` | about 8 h on 12 free cores |
| `s77.tsv` | `make reproduce n=7 m=7 seed=7 ref_samples=200000 threads=4 ref=$LEGACY/s77.tsv` | about 3.5 min (see the note below) |

**Note on `s77.tsv`.** The regenerated file has the same columns `i`, `logw` and `e` on
all 200,000 lines, so the mass estimate is the same. The `coeffs` column differs on 782 of
116,527 hit lines. The legacy script `samplenm.jl` in its current form gives the same
output as this port; `s77.tsv` was probably written by an earlier version of the counter that listed
the canonical completions in a different order. The random stream is the same, so only
the selected completion changes. `make reproduce` therefore reports "byte-identical: NO"
for `s77.tsv`. The (8,8) file `s1.tsv` is byte-identical. For `c101.tsv`, the first 400 samples of the five
thread streams that contain the six earliest hits (2,000 lines) are byte-identical; the
full-chunk check was not run because the machine was busy.

`$LEGACY` is `papers/2025/Beierle_202508/results/class_count`. `make sample` keeps
existing chunks, so you can stop and continue a long run. To add new chunks to the
analysis, use for example
`make analyze data="$LEGACY/s1.tsv $LEGACY/chunks census/quadratic_apn8/results/chunks"`.
Use new seeds (for example `first_seed=141`). The same seed and thread count give the same
samples again.

## Files

| File | Content | Legacy file |
|---|---|---|
| `qknuth.jl` | Modules `QK` (images, free values, Knuth probe, exact DFS count, LUT) and `QK2` (slow exact last-step counter) | `qknuth.jl` |
| `fastlast.jl` | Modules `FL`, `FL2`, `FL3` (fast exact last-step counters; `FL3` is the production counter) | `fastlast.jl` |
| `sampler.jl` | Threaded sampler, chunk writer, byte-level reproduction check | `sample88.jl`, `samplenm.jl`, `longrun.sh` |
| `helpers.jl` | Constants, coefficient strings, TSV reader, mass estimate, TOML output | `est.jl` |
| `analyze.jl` | Mass, σ coverage, N estimates, new σ list | `analyze.jl`, `check.jl` |
| `validate.jl` | (6,6) and (7,7) checks against the exact masses | |
| `exact_masses.jl` | Exact masses from the catalog | `stabs.jl` |
| `diagnostics.jl` | σ-index spot check, invariants of single functions | `spot.jl`, `props.jl` |
| `report.jl` | Aggregate report, `results/report.toml` | |
| `test/` | Unit tests | |

The algorithms and the random number scheme are the same as in the legacy scripts. The
legacy folder stays unchanged.

Generated files go to `results/` only: `results/chunks/` (`make sample`),
`results/repro/` (`make reproduce`), `results/validate/` (`make validate`),
`results/new_sigma.tsv` (`make analyze`) and `results/report.toml` (`make report`).
Git ignores all of them except `results/report.toml`.

## Dependencies

`VBF` (SBox, differential_uniformity, is_quadratic_apn, automorphisms_from_ortho_derivative,
absolute_walsh_spectrum, is_ccz_equivalent_to_permutation) and `VBFCatalog` (catalog,
`sigma_hash`, the `ccz_sigma_index` side store). `make analyze` needs the side store
`packages/VBFCatalog/corpora/ccz_sigma_index.sqlite`; build it with
`build_sigma_index!(load_catalog())` if it is missing. The sampler and the tests do not
need it.
