# Extension search in the B6 = 52 branch of quadratic APN functions on F_2^8

For new reproducible experiments use the [consolidated pipeline](../discovery/README.md).
This historical runner uses heuristic histogram pruning, per-seed completion
markers and bounded construction choices; its outputs do not certify exhaustion.
“New” below means absent from the comparison sources used at execution, not proven
literature-wide novelty. The [current audit](../discovery/AUDIT.md) records the
source-rebuilt comparison, 61 previously public classes, and statistical limits.

**Path**: `census/quadratic_apn8/search_b52/`

**Status**: The method is validated (n = 6 and n = 8). A trial run on this machine
found 773 new CCZ classes. A run of about 10 hours on the Framework desktop (30 threads)
found 109,943 verified search-new classes: see
[RUN_20261009_FRAMEWORK.md](RUN_20261009_FRAMEWORK.md) and
`framework_20261009_new.tsv.gz`.

**NOTE**: The `b6` column of `found.tsv` is the largest bent count over all 6-dim
subspaces. The P6 profile (bminK order) can give a smaller value (52 instead of 54 for about
8 % of the new classes). The seed queue uses the recorded value.

---

## Question

The census (`../README.md`, `../reports/properties/REPORT.md`) estimates about 1.0e6 CCZ
classes of quadratic APN functions on F_2^8 with P6 profile B6 = 52. About 98 % of them
are unknown. Beierle et al. (2025, Algorithm 3.1) extend only (8,6)-functions with
B6 >= 54. This study extends (8,6)-subspaces with 52 bent elements to (8,8) APN
functions, and collects the new classes.

## Mathematics

### Setting

V = Alt(8) = F_2^28 is the space of alternating 8 x 8 matrices over F_2, with the basis
x_i x_j (1 <= i < j <= 8, i outer, j inner). A quadratic form is a vector of V. The
coordinate dot product pairs V with itself. For F(x) = XOR x_i x_j c_ij, the component
b.F is the vector (b . c_ij). Comp(F) is the 8-dim span of the components.

The flats are the decomposable bivectors x ^ y, with entries x_i y_j + x_j y_i. There
are 10,795 of them. For a form s, s . (x ^ y) = s(x, y).

**APN criterion** (Lemma 3.14, Remark 3.15 of v2): F is APN if and only if Comp(F)^perp
contains no flat.

### The Fourier extension step (U route)

Let U be a 6-dim subspace and W = U^perp (22-dim). Put U in reduced row echelon form
(pivot set P). A coset t + U has a unique representative with zero bits on P. Its other
22 bits tau(t) are coordinates on V/U. For w in W, w . t = w|_Q . tau(t), and
w -> w|_Q is injective on W. Define

    g(tau) = sum over the flats w in W of (-1)^(w|_Q . tau).

This is a 22-bit Walsh-Hadamard transform of the indicator of the about 100 flats in W.
Poisson summation gives sigma_U(t) = sum_{u in U} fhat(t+u) = 2^6 g(tau(t)), where fhat
is the transform of the flat indicator on V (Eq. 3.3-3.4).

S = U + lift(T), with T = {0, u, v, u+v} 2-dim in V/U, is APN if and only if
g(0) + g(u) + g(v) + g(u+v) = 0. Let Z(u) be the flats of W with w . u = 0. For a valid
T, Z(u), Z(v) and Z(u+v) partition the flats of W. Thus the smallest part has at most
g(0)/3 elements, i.e. g(u) <= -g(0)/3 (Remark 3.16). For each such candidate u, the
valid v are exactly the solutions of the linear system {w . v = 1 : w in Z(u)}. We solve
this system by Gaussian elimination. This step replaces the second inequality of
Remark 3.16 and is exact. A prefilter uses Lemma 4.6 (v1): U has no APN extension if a
point a lies in more than 3 flats of W (differential uniformity of U above 8).

### Why not the 2^28 table

fhat(s) depends only on the rank of s, because GL(8) is transitive on the forms of a
given rank and preserves the pairing: fhat = phi(rank) with phi = 10795, 2603, 555, 43,
-85 for the ranks 0, 2, 4, 6, 8. `make table` computes the full table (Int16,
2^28 entries, 512 MB, in `results/tables/fhat8.bin`) and checks phi on all 2^28 forms
and the identity sigma_U = 2^6 g on 12,000 points. The table route costs 2^28 random
reads per U (25.5 s in our loop). The restricted transform costs 7 to 9 ms per U. The
search therefore does not read the table.

### The two modes

**mode = comp** (the literal method): every U < Comp(F) with 52 bent elements, all APN
S > U. Measured on all 361 seeds with B6 = 52: 5,564 subspaces U (15.4 per seed). 5,551
of them have exactly one APN extension, Comp(F) itself. Only 13 extra component spaces
appear (0.036 per seed). On one seed we extended all 8,937 subspaces U with 40 to 52
bent elements: every U had Comp(F) as its only APN extension. The (8,6)-subspaces of an
APN function are almost rigid. This mode is kept for reference; it gives very few new
functions.

**mode = v5** (default): take every 5-dim V5 < Comp(F) with the maximal bent count of the
seed (30 for the (30,34) profile, 28 for (28,40); about 3 subspaces per seed). For every
x in V/V5 with 22 (or 24) bent forms in the coset x + V5, U = V5 + <x> has 52 bent
elements. U need not lie in Comp(F). This is step 3 of Algorithm 3.1 for B6 = 52.

- Coset bent counts: #bent(x + V5) = 2^-23 sum_{y in V5^perp} beta(rank y) (-1)^(y . x),
  with beta = 112881664, -888832, 28672, -4096, 4096 (the transform of the bent
  indicator; also a function of the rank). A Gray-code walk over the 2^23 elements of
  V5^perp and one 23-bit transform give all 8.4e6 counts in 0.3 s. About 15,000 cosets
  have 22 bent forms.
- One transform g5 per V5 serves all U = V5 + <x>: the flats of U^perp are the flats w of
  V5^perp with w . x = 0, and g_U(t mod x) = (g5(t) + g5(t+x)) / 2. A sorted list of the
  t with small g5 and a 1 MB bitmap replace the 22-bit transform per U. The cost drops
  from 7 ms to about 0.8 ms per U.

### Deduplication

- sigma (`VBFCatalog.sigma_hash`) for every function: one entry per sigma in `found.tsv`.
- Class keys (EA invariants, free by-products of the transforms): V5 key = SHA-256 of the
  histograms of the 2^23 coset bent counts and of g5; U key (mode comp) = histogram of g.
  Equivalent subspaces have equal keys, so a repeated key skips repeated work. A key
  collision of two inequivalent subspaces would lose their extensions; it cannot create
  a false result. We chose these keys instead of J2 (Definition 3.9) because they cost
  nothing extra; J2 needs 10,795 x 64 rank computations per subspace.
- Novelty: the n = 8 hashes of `ccz_sigma_index.sqlite` (3,808,491 distinct) are loaded
  once into a sorted array (`results/index/sigma_n8.bin`, 122 MB). Status `known` (in
  the index), `census` (in `../new_classes_553.tsv`) or `search` (new). A search-new
  function with B6 = 52 becomes a seed (breadth first; `gen` = distance from the census
  seeds).

## Validation

`make validate`: all checks pass (182 s with 2 threads). `make test` runs a subset in
about 35 s.

| Check | Result |
|---|---|
| Flats: 651 (n = 6), 10,795 (n = 8); fast rank = slow rank (all 2^15 forms; 200,000 random 28-bit forms) | pass |
| n = 6, all 13 quadratic APN classes of the catalog, all 651 4-dim U < Comp(F) of each (8,463 U): Fourier T-list = brute force over all 2-dim T | 8,463 / 8,463 |
| n = 6: own component space among the extensions of every U | 8,463 / 8,463 |
| n = 6: every extension has differential uniformity 2 and the sigma of one of the 13 classes | 403,526 / 403,526 |
| n = 6: Lemma 4.6 prefilter changes nothing; 300 random U: Fourier = brute force (47 with extensions) | pass |
| n = 6: coset bent counts (Fourier) = direct counts; v5 route = U route | 2,333 / 2,333 (V, need) pairs |
| n = 8: phi from the flats; beta by a sweep of all 2^28 forms = built-in constant | pass |
| n = 8: 10 seeds (6 known, 4 new), 154 U with 52 bent: own Comp(F) among the extensions | 154 / 154 |
| n = 8: every extension has DU 2 and no flat in S^perp; 462 random S = U + T are not APN and have a flat | pass |
| n = 8: v5 route = U route on 2,000 x for 3 seeds (1.0 s vs 10 s); coset counts = direct counts | pass |
| `make table`: fhat = phi(rank) on all 2^28 forms; sigma_U from the table = 2^6 g | pass (12,000 / 12,000) |

From each n = 6 class, the 4-dim subspaces reach 11 to 13 of the 13 classes: in n = 6 the
extension graph is dense. In n = 8 it is almost rigid (mode comp above). Time per U:
0.04 ms (n = 6), 5.6 to 7 ms (n = 8, U route; the paper reports 50 ms), about 0.7 ms
(n = 8, v5 route).

## Trial run (this machine, 2 threads)

AMD Ryzen 5 5600G, 2 threads, mode v5, `results/trial`: `make search max_seeds=10`, then a
resume with `timeout_seconds=840`. Wall time 1,004 s; 67 seeds completed (all of
generation 0; the timeout dropped 2 running seeds, which a resume redoes).

| Quantity | Value |
|---|---|
| Thread-seconds per seed | 29.5 mean; (30,34) seeds 3 V5 and about 15 s; (28,40) seeds up to 207 V5 and 130 to 180 s |
| U = V5 + <x> with 52 bent per V5 | about 14,700 (about 10 % rejected by Lemma 4.6) |
| Time per U | about 0.7 ms |
| APN extensions S per seed | 52.6 (3,523 in total, all with DU 2) |
| Distinct sigma found | 3,444: known 2,671, search-new 773 |
| Search-new per seed | 11.5 (by B6: 52 => 394, 54 => 340, 56 => 37, 58 => 2) |
| `make novelty` | 773 / 773 verified (APN, sigma recomputed, absent from the SQLite index and the 553) |
| P6 levels 5-6 of 20 new | (30,34),(52,96) 8; (30,34),(54,90) 11; (30,34),(56,84) 1 |
| Yield | about 1,400 new classes per thread-hour; 47 per minute on 2 threads |
| V5 class keys | 1,375, no repeat (no V5 work was skipped) |
| Memory | 1.0 GB RSS (index 122 MB, about 60 MB per worker) |
| Queue after the run | 686 seeds (394 search-new with B6 = 52 were added) |

The 553 census classes were not met again: the found functions are far from the sampled
hits, as expected for 1e6 classes. Many found functions are known (78 %): the extensions
also reach the known B6 >= 54 region.

## Run on the Framework desktop (64 GB RAM, 16 cores / 32 threads)

### 1. Data files (ignored by git)

The search needs the catalog, which is in git, and one ignored file:

| File | Size | Needed for |
|---|---|---|
| `packages/VBFCatalog/corpora/ccz_sigma_index.sqlite` | 682 MB | novelty oracle (search, novelty) |
| `packages/VBFCatalog/corpora/beierle2025_n8.sqlite` | 178 MB | only to rebuild the index |

Copy both from this machine (about 860 MB). In a worktree these files are symbolic links;
`rsync -L` copies the targets:

    rsync -avL ts@<this-host>:VBF.jl/packages/VBFCatalog/corpora/{ccz_sigma_index,beierle2025_n8}.sqlite \
        <repo>/packages/VBFCatalog/corpora/

To rebuild them instead: `make -C packages/VBFCatalog/data-build beierle2025` with
`BFA_BEIERLE2025_PATH` = the directory of `new_apns.txt` (Zenodo 16752428, 3.4 GB), then
`julia --project=packages/VBFCatalog/data-build -t auto packages/VBFCatalog/data-build/build_sigma_index.jl`
(it calls `build_sigma_index!(load_catalog())`; hours). The search refuses to run when
the index has coverage gaps at n = 8.

### 2. Steps

    cd <repo>                      # branch research/quadratic-apn8-census
    julia --project=. -e 'using Pkg; Pkg.instantiate()'
    cd census/quadratic_apn8/search_b52
    make seeds                     # results/seeds_b52.tsv (361 seeds)
    make index                     # results/index/sigma_n8.bin (about 10 s)
    make test threads=4            # about 30 s
    make validate threads=16       # optional, a few minutes
    make search threads=30 max_seeds=0 timeout_seconds=0 outdir=$PWD/results/desk1

Use 30 threads to keep two hardware threads free for the system. Memory: about 60 MB
per worker plus 1 GB base (about 3 GB at 30 threads). Stop with Ctrl-C at any time. The
next `make search` with the same `outdir` resumes: completed seeds stay done, and the
seeds that were running are redone. For a bounded run use for example
`timeout_seconds=86400` (24 h) or `max_seeds=5000`. `make status outdir=...` shows the
progress at any time (also during a run).

### 3. Expected run time and output

At 30 workers the run completes about 30 x 3600 / 29.5 = 3,700 seeds per hour (more if
a desktop core is faster than the 5600G core). With 11.5 new classes per seed this gives
roughly 40,000 new classes per hour at the start. Each seed adds about 6 new seeds with
B6 = 52, so the queue grows and the run does not end by itself; it ends at
`timeout_seconds` or `max_seeds`. The yield per seed will fall when the search starts to
meet its own classes again; `make status` shows the current ratio. A 24-hour run gives
about 90,000 seeds and `found.tsv` of about 4 million lines (about 1 GB); RAM stays
below about 6 GB (the sigma set grows by about 100 bytes per distinct sigma).

Output in `outdir`: `found.tsv` (one line per new sigma: sigma, status, gen, parent seed,
B6, coefficients), `done.tsv` (one line per completed seed), `keys.tsv`, `log.txt`
(progress every 60 s).

### 4. Merge the results back

Copy the run directory to this machine and run the novelty report over all runs:

    rsync -av <desktop>:<repo>/census/quadratic_apn8/search_b52/results/desk1 \
        census/quadratic_apn8/search_b52/results/
    make -C census/quadratic_apn8/search_b52 novelty \
        outdirs="$PWD/census/quadratic_apn8/search_b52/results/desk1 $PWD/census/quadratic_apn8/search_b52/results/trial"

`novelty` merges `found.tsv` by sigma, recomputes DU and sigma for every search-new
function, looks it up again in the SQLite index and in the 553 census classes, and writes
`<first outdir>/novelty/novelty_new.tsv` and `summary.toml`. To add the new classes to
the catalog, use `novelty_new.tsv` (sigma, coefficients) as the input of a corpus import.

## Files

| File | Content |
|---|---|
| `extlib.jl` | Module `Ext`: geometry of Alt(n), fast rank, coefficients, FWHT, Fourier extension (U route), v5 route, coset bent counts, subspace enumeration, brute-force reference |
| `common.jl` | Paths, sigma index cache and novelty sets, seeds from `hit_properties.tsv` |
| `search.jl` | Resumable multi-threaded search (`run_search`, `cli_search`) |
| `validate.jl` | n = 6 and n = 8 validation (`make test`, `make validate`) |
| `table.jl` | 2^28 Walsh table and its checks (`make table`) |
| `report.jl` | `make status`, `make novelty` |

## Dependencies

`VBF` (SBox, differential_uniformity), `VBFCatalog` (sigma_hash, the ccz_sigma_index side
store, load_catalog for the n = 6 representatives), `SHA`, `TOML`, and
`../reports/properties/profiles_lib.jl` (P6 profiles in the novelty report).
