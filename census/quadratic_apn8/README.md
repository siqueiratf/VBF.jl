# Census of quadratic APN functions on F_2^8

**Path**: `census/quadratic_apn8/`

**Current scientific status:** the [consolidated discovery pipeline](../../search/apn/README.md)
has moved to `search/apn/` with the supported `bin/vbf` command. It provides
reproducible search, transactional resume, independent APN validation,
bounded EA/CCZ checks, evidence inspection and publication exports. Read its
[audit](../../search/apn/AUDIT.md) before using the historical novelty or census claims below.
The five historical lists contain **110,868 pairwise CCZ-separated quadratic APNs**
absent from the original-source quadratic reference and the public supplement.
This is a rigorously scoped finite-computation result; literature-wide novelty
remains unresolved. The census estimates mass, and converting mass to a class
count requires additional assumptions; capture–recapture uniformity/independence
have not been established.

Historical estimator validation used exact cases for n <= 7 and 4,012,000 n = 8
samples. The 553 examples were verified against the original indexed sources
([reports/verification/REPORT.md](reports/verification/REPORT.md)).
The two items that were open are now closed:

- The x^57 Kasami class (three non-quadratic catalog rows) has no quadratic
  member: its CCZ class is equal to its EA class ([kasami_x57/REPORT.md](kasami_x57/REPORT.md)).
- All 31,390,363 records of the authors' raw files were checked. None has the σ of
  one of the 553 ([crosscheck_raw/REPORT.md](crosscheck_raw/REPORT.md)). The raw file
  holds 546 more public classes that are absent from the published list and from the
  index (`crosscheck_raw/raw_only_546.tsv`).

**Targeted search.** `search_b52/` extends 5-dim bent subspaces of B6 = 52 functions
(step 3 of Algorithm 3.1 for B6 = 52). A 17-minute trial on 2 threads found **773 more
new classes**, verified again by `make novelty` (`search_b52/new_classes_trial_773.tsv`).
They are disjoint from the 553, from the extra class and from the 546 raw-only classes.
The long run is for a larger machine ([search_b52/README.md](search_b52/README.md)).

**Hyperplane scan.** Restricting known and new functions to all 255 hyperplanes and
extending them again (APN codimension-1 changes) found **463 more new classes**
(`theory/hyperplane_scan/new_classes_hyperplane.tsv`; theory in
[theory/HYPERPLANE.md](theory/HYPERPLANE.md)).

**Framework run (2026-10-09).** An 8-hour run of the B6 = 52 search on the Framework
desktop (30 threads; about 10 hours in total) found **109,943 verified search-new classes**.
61 of them are public raw-only classes, and 804 are already in the trial and hyperplane
lists, so 109,078 are new only in this run (`search_b52/framework_20261009_new.tsv.gz`). Two
exploratory capture–recapture calculations suggested about 1.6 M additional
classes and 6–7 % coverage, conditional on unestablished sampling assumptions
([search_b52/RUN_20261009_FRAMEWORK.md](search_b52/RUN_20261009_FRAMEWORK.md)).

**Total historical corpus-absent signature buckets: 553 (census) + 1 (theory) + 773 (search trial) + 463
(hyperplane scan) + 109,078 (Framework run) = 110,868.** With the 3,808,491 indexed classes
and the 546 raw-only public classes, this gave a lower bound of 3,919,905 classes.
The additional public Galissant representative raises that baseline-plus-study
lower bound to **3,919,906**; it does not establish how many are literature-new.

Also: 0 of the 553 new functions are CCZ-equivalent to a permutation
([permutation/REPORT.md](permutation/REPORT.md)). One more new class came from the
theory experiment (`new_classes_extra.tsv`, see [theory/UNIQUENESS.md](theory/UNIQUENESS.md)).

A fresh clone runs `make test` and `make analyze` with the committed data in `data/`.
[SETUP.md](SETUP.md) tells how to set up another machine.

---

## Question

How many CCZ classes of quadratic APN functions exist on F_2^8?

Beierle et al. (2025) give the lower bound 3,808,491 (Theorem 5.1). This study estimates orbit mass and explores conditional estimates of the
class count N; it does not establish an unbiased estimator of N. It also collects sampled APN functions whose CCZ
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

Stream `th` of S uses `Xoshiro(seed · 100003 + th)` and computes the samples
`i = th : S : N`. Thus a chunk is a function of (N, seed, S, n, m). **The same seed and the
same stream count S reproduce a chunk byte for byte.** A different S gives a different,
equally valid chunk. The parameter `streams` sets S; its default is `threads`. The streams
run on any number of threads, so `threads=4 streams=12` gives a 12-thread chunk. The
legacy (8,8) chunks use S = 12, and `s77.tsv` uses S = 4. The default of `threads` is 12.

### Compact data (`data/`)

A row with weight 0 changes the estimates only through its position. Thus the hit rows
and the number of rows of each file describe the data completely. `data/` holds the
legacy run in this compact form (175 KB instead of 90 MB):

| File | Content |
|---|---|
| `legacy_chunks.tsv` | Manifest. Header `file seed samples neg_inf zero_e hits sha256`; one row per legacy file (`s1.tsv`, `chunks/c101.tsv` … `chunks/c140.tsv`). `neg_inf` counts rows with `logw = -Inf`; `zero_e` counts rows with `e = 0` (the `-Inf` rows included); `sha256` is the hash of the full file. |
| `legacy_hits.tsv` | 1,661 rows, no header: `file seed i logw e coeffs`. `logw` is the original text. |
| `legacy_s77_chunks.tsv` | Manifest row of `s77.tsv` only (200,000 samples, 116,527 hits). Its hit rows are 4.7 MB compressed, so they are not in the repository. `make validate threads=4` regenerates the file. |

`read_samples` accepts a manifest wherever it accepts a sample file. It gives the same
log weights and hits, bit for bit. `make compact_data legacy=<dir>` writes `data/` again
from the full files. `make verify_data` regenerates one chunk with `make sample` and
compares the counts, the hit rows and the SHA-256 with the manifest.

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
| (7,7) mass | pipeline, legacy `s77.tsv` (200,000 samples, seed 7, 4 threads) | 475.002 ± 1.31 (z = +0.22) | 474.7177 | `make validate threads=4` (same weights, see the note on `s77.tsv`) |

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
each, seeds 101–140), all with 12 streams. The committed compact form is
`data/legacy_chunks.tsv`.

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
| Distinct new σ | 553, no repeats (**verified**, see below) |

Thus about 32 % of the mass of quadratic APN classes on F_2^8 is outside the known
classes. The 553 new σ are in `new_classes_553.tsv` (`sigma_hash<TAB>coeffs`, sorted by
hash). `make analyze` writes the same list to `results/new_sigma.tsv` and compares the two
files. Each line certifies a CCZ class that is absent from the indexed corpora.

The verification ([reports/verification/REPORT.md](reports/verification/REPORT.md)) found:

- The σ index is complete and consistent: 4,005,445 members of 10 sources, all APN,
  3,808,491 distinct σ (equal to Theorem 5.1 of Beierle et al.).
- None of the 553 σ occurs in the recalculated set of all indexed members.
- The 553 functions are quadratic APN and pairwise CCZ-inequivalent.

Novelty is relative to the 10 indexed sources, to the x^57 class
([kasami_x57/REPORT.md](kasami_x57/REPORT.md)) and to all public raw files of the
authors ([crosscheck_raw/REPORT.md](crosscheck_raw/REPORT.md)). Classes that were never
published (for example, in a talk) are not covered.

**Known classes and the coverage estimate.** The public data holds at least
3,808,491 + 546 = 3,809,037 classes. The 546 raw-only classes change the known mass by
less than 0.015 %, which is far below the standard error of the coverage estimate. The
estimate uses the mass of the 3,808,491 indexed classes.

**Note on e.** In this run, every hit had e = 128 (one coset). This is not a theorem.
Hyperplane restrictions of known functions sometimes give e = 256 or 512
([theory/UNIQUENESS.md](theory/UNIQUENESS.md)). The estimator uses the exact value of e,
so the census numbers do not depend on this observation.

### Where the new classes are

The properties report ([reports/properties/REPORT.md](reports/properties/REPORT.md))
compares the component profiles of the new and the known hits. **The new classes are
concentrated in the branch B6 = 52**, which Algorithm 3.1 of Beierle et al. does not search
(it needs B6 ≥ 54):

| Branch | Share of the new mass | Known fraction | Estimated unknown classes |
|---|---:|---:|---:|
| B6 = 52 | 54 % | 2 % | about 1.0e6 |
| B6 = 54 (only half extended, Remark 3.19) | 34 % | 84 % | about 0.6e6 |
| Level-5 entry (28,40) (Remark 3.11) | 10 % | 2.5 % | about 0.18e6 |
| B6 ≥ 56 (fully targeted) | < 2 % | 95 % | about 0.03e6 |

Most new hits (302 of 553) have the profile `[..,(30,34),(52,96)]`. All 1,661 hits
contain a 4-dimensional all-bent subspace (Hypothesis 3.2 holds).

## Reproduce the numbers

Run all commands from the repository root or from this folder. All targets use
`julia --project=<repo root>`.

| Number | Command | Time |
|---|---|---|
| Unit tests | `make test` | < 1 min after precompilation |
| Census table above, `results/new_sigma.tsv` | `make analyze` (reads `data/legacy_chunks.tsv`; `results/new_sigma.tsv` is identical to `new_classes_553.tsv`) | about 15 s |
| All numbers in `results/report.toml` | `make report` | about 3 min |
| (6,6), (7,7) validation | `make validate` | about 2.5 min |
| (7,7) with the legacy file | `make validate data77=$LEGACY/s77.tsv` | about 30 s |
| Exact masses n = 4..6 / n = 4..7 | `make exact_masses` / `make exact_masses nmax=7` | seconds / about 20 min |
| `s1.tsv` against the manifest (counts, hits, SHA-256) | `make verify_data threads=<cores>` (seed 1, 12,000 samples, 12 streams) | 1–2 min on 12 cores, about 4 min on 2 |
| `c101.tsv` against the manifest | `make verify_data seed=101 threads=<cores>` | 8–15 min on 12 free cores |
| `s1.tsv` byte for byte with the full file | `make reproduce streams=12 ref=$LEGACY/s1.tsv` | 1–2 min |
| All 40 chunks | `make sample first_seed=101 chunks=40` | about 8 h on 12 free cores |
| `s77.tsv` | `make verify_data seed=7 n=7 m=7 verify_streams=4 manifest=data/legacy_s77_chunks.tsv` | about 3.5 min on 4 threads (see the note below) |

**Note on `s77.tsv`.** The regenerated file has the same columns `i`, `logw` and `e` on
all 200,000 lines, so the mass estimate is the same. The `coeffs` column differs on 782 of
116,527 hit lines. The legacy script `samplenm.jl` in its current form gives the same
output as this port; `s77.tsv` was probably written by an earlier version of the counter that listed
the canonical completions in a different order. The random stream is the same, so only
the selected completion changes. `make reproduce` therefore reports "byte-identical: NO"
for `s77.tsv`, and `make verify_data` reports equal counts but a different SHA-256. The
(8,8) file `s1.tsv` is byte-identical. For `c101.tsv`, the first 400 samples of the five
thread streams that contain the six earliest hits (2,000 lines) are byte-identical; the
full-chunk check was not run because the machine was busy.

`$LEGACY` is `papers/2025/Beierle_202508/results/class_count`. The full files are
untracked and exist only on the original machine; `data/` replaces them for the analysis.
`make sample` keeps existing chunks, so you can stop and continue a long run. To add new
chunks to the analysis, use for example
`make analyze data="data/legacy_chunks.tsv results/chunks"`. Use new seeds (for example
`first_seed=141`). The same seed and stream count give the same samples again.

## Subprojects

Each subproject has its own Makefile. The census Makefile delegates to it and skips it
when the Makefile is absent. Command-line parameters reach the sub-make; `args="..."`
adds more.

| Target | Runs | Purpose |
|---|---|---|
| `make kasami_x57` | `make -C kasami_x57 check` | Is the x^57 Kasami class CCZ-equivalent to a quadratic function? |
| `make permutation` | `make -C permutation check` | CCZ-equivalence of new classes to permutations |
| `make theory_uniqueness` | `make -C theory check_uniqueness` | Checks of the theory notes |
| `make crosscheck_raw` | `make -C crosscheck_raw check` | Full σ check of the raw Langevin files |
| `make web_serve` | `make -C web serve` | Local web view of the census |
| `make search_b52` / `make search_b52_status` | `make -C search_b52 search` / `status` | Targeted search in the B6 = 52 branch |

## Reports

| Report | Content |
|---|---|
| [reports/verification/REPORT.md](reports/verification/REPORT.md) | Verification of the 553 novelty claims and of the σ index |
| [reports/properties/REPORT.md](reports/properties/REPORT.md) | Component profiles of new and known hits (B6 = 52 branch) |
| [reports/literature/LITERATURE.md](reports/literature/LITERATURE.md) | Survey of public sources of quadratic APN functions on F_2^8 |
| [theory/METHOD.md](theory/METHOD.md) | The mathematics of the census, with proofs |
| [theory/UNIQUENESS.md](theory/UNIQUENESS.md) | Number of APN completions e: what is proved, what is false (e = 128 is not general) |
| [theory/HYPERPLANE.md](theory/HYPERPLANE.md) | Hyperplane changes (TPPA 2025), admissible selections, the neighbour graph, and the hyperplane scan |
| [theory/hyperplane_scan/README.md](theory/hyperplane_scan/README.md) | Scan of all hyperplanes of 11,684 functions: rates, structure, 463 new classes |
| [kasami_x57/REPORT.md](kasami_x57/REPORT.md) | The x^57 class has no quadratic member (gap closed) |
| [permutation/REPORT.md](permutation/REPORT.md) | 0 of 553 new functions are CCZ-equivalent to a permutation |
| [crosscheck_raw/REPORT.md](crosscheck_raw/REPORT.md) | All raw files of the authors: 0 coincidences with the 553; 546 raw-only classes |
| [web/README.md](web/README.md) | Local web page: is a function new or known? |
| [search_b52/RUN_20261009_FRAMEWORK.md](search_b52/RUN_20261009_FRAMEWORK.md) | Framework run: 109,943 verified classes, yield, composition, capture–recapture |
| [search_b52/README.md](search_b52/README.md) | Targeted search in the B6 = 52 branch: method, validation, trial (773 new classes), run steps for a larger machine |

## Files

| File | Content | Legacy file |
|---|---|---|
| `qknuth.jl` | Modules `QK` (images, free values, Knuth probe, exact DFS count, LUT) and `QK2` (slow exact last-step counter) | `qknuth.jl` |
| `fastlast.jl` | Modules `FL`, `FL2`, `FL3` (fast exact last-step counters; `FL3` is the production counter) | `fastlast.jl` |
| `sampler.jl` | Threaded sampler (RNG streams), chunk writer, byte-level reproduction check | `sample88.jl`, `samplenm.jl`, `longrun.sh` |
| `helpers.jl` | Constants, coefficient strings, TSV and compact-data reader, compaction and chunk verification, mass estimate, TOML output | `est.jl` |
| `analyze.jl` | Mass, σ coverage, N estimates, new σ list | `analyze.jl`, `check.jl` |
| `validate.jl` | (6,6) and (7,7) checks against the exact masses | |
| `exact_masses.jl` | Exact masses from the catalog | `stabs.jl` |
| `diagnostics.jl` | σ-index spot check, invariants of single functions | `spot.jl`, `props.jl` |
| `report.jl` | Aggregate report, `results/report.toml` | |
| `test/` | Unit tests | |
| `data/` | Compact form of the legacy run (manifests and hit rows) | `s1.tsv`, `chunks/`, `s77.tsv` |
| `new_classes_553.tsv` | The 553 new classes (`sigma_hash<TAB>coeffs`) | `all40_new.tsv` |
| `SETUP.md` | Setup of a new machine | |

The algorithms and the random number scheme are the same as in the legacy scripts. The
legacy folder stays unchanged.

Generated files go to `results/` only: `results/chunks/` (`make sample`),
`results/repro/` (`make reproduce`), `results/verify/` (`make verify_data`),
`results/validate/` (`make validate`),
`results/new_sigma.tsv` (`make analyze`) and `results/report.toml` (`make report`).
Git ignores all of them except `results/report.toml`.

## Dependencies

`VBF` (SBox, differential_uniformity, is_quadratic_apn, automorphisms_from_ortho_derivative,
absolute_walsh_spectrum, is_ccz_equivalent_to_permutation) and `VBFCatalog` (catalog,
`sigma_hash`, the `ccz_sigma_index` side store). `make analyze` needs the side store
`packages/VBFCatalog/corpora/ccz_sigma_index.sqlite`. Git ignores it; [SETUP.md](SETUP.md)
tells how to copy or rebuild it. The sampler and the tests do not need it.
