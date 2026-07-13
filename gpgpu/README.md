# gpgpu — GPU-accelerated quadratic-APN search

A small, **codebase-agnostic** toolkit for hunting quadratic APN functions by
GPU. The C/C++ kernels depend on nothing but a compiler and (for the GPU paths)
ROCm/HIP: they take a search description as data and emit APN look-up tables.
Nothing here needs VBF.jl or any paper directory to build or run.

It grew out of the Kuznetsov (2026) self-equivalence census pipeline and was
generalized so the same rank oracle can drive *other* papers' searches — the
ones whose authors admit they ran out of compute.

## The one idea

`apn_search`'s inner test — "every nonzero F₂-linear combination of the n rows
has rank n−1" — **is the QAM oracle**. Yu–Wang–Li's `is_qam`, Ichanska's
Theorem 3 and Kuznetsov's APN criterion are the same F₂ rank test over the same
packed representation. So extending the reach of these searches is a
**re-enumeration** problem, not a new-kernel problem: both kernels below share
one `check_rank`.

## Two kernels

| file | model | when |
|---|---|---|
| `apn_search.cpp` | flat V_A subspace, Gray-code over 2^dim candidates, full `is_qam` per leaf | the space is a linear subspace you can walk directly (Kuznetsov census; Beierle V_A) |
| `qam_dfs.cpp` | depth-first over a **level plan**, with a leading-principal-submatrix (or forward-checking) prune | the flat space is astronomically larger than the pruned one (Yu–Perrin H₈: 2^104 flat → 2^49 pruned) |

Plus two portable helpers:

- `ortho_sigma.c` — the ortho-derivative σ signature, a CCZ-invariant for
  quadratic APN, for fast dedup (~ms/function). **A σ *mismatch* certifies
  CCZ-inequivalence; a σ *match* does not certify equivalence** — Gold x³ and x⁵
  over F₂⁵ share a σ (and Γ- and Δ-rank) yet are CCZ-inequivalent. Use it to
  reject and to bucket; confirm a collision with a complete decision before
  calling two functions equal.
- `fast_checker.cpp` — standalone APN check.

All are parametric in dimension: `-DDIM_N=n` (n=8 default; n≤8 uses a byte-packed
`uint64` row, n∈{9..12} uses `uint16` column lanes).

## Build

```
make searchers GPU_ARCH=gfx1031      # apn_search_n{8..12}, qam_dfs_{cpu,gpu}
make tools                           # ortho_sigma, fast_checker (portable, no GPU)
make validate_dfs                    # correctness gate, see below
```

`apn_search` and `qam_dfs_gpu` need `hipcc` (ROCm). `qam_dfs_cpu`, `ortho_sigma`
and `fast_checker` build with plain `gcc`/`g++`. Set `GPU_ARCH` to your card
(`gfx1031`, `gfx90a`, …); for NVIDIA, swap `HIPCC` for `nvcc` and the launch
intrinsics are HIP/CUDA-portable.

## The level-plan format

`qam_dfs` is generic over a binary *level plan* — the full little-endian layout
is documented at the top of `qam_plan.jl`. In brief: a header (magic `QAMD`, n,
modulus, prune mode), the fixed base matrix and its "known" mask, then one record
per level giving the fill type (single entry vs. whole diagonal), the position,
the leading-submatrix size to re-check for properness, and the candidate domain.
`qam_plan.jl` is the **reference generator** and the one codebase-coupled file
(it reads VBF and the paper reductions); any program that writes the format works.

## Calibration and validated results

- Throughput: a saturated GPU does ~1×10⁹ candidate-nodes/s, so a **flat** space
  is exhaustible up to ~2^42 (≈1 h), 2^45 (≈10 h), 2^49 (≈6.5 d), 2^55 (≈14 mo).
- `qam_dfs` reproduces the reference oracle exactly: the diagonal model gives
  **72 / 32 / 4410** classes at n=5/6/7, matching a from-scratch Julia
  enumeration.
- For the Yu–Perrin H₈ traversal it reproduces the paper's per-level survivor
  counts, **including** the dynamic Prop-3 EA-coset reduction at the two coupled
  levels (x₇ domain 3, x₆ domain 96) — collapsing 2^56 to the paper's **2^49**.
- The fast forward-checking prune is **byte-identical** to the reference prune
  (`--verify`, 0 mismatches over a 36.7 M-node sweep).

### The prize this was built for

Yu & Perrin (2022) Conjecture 2 says all CCZ-inequivalent quadratic APN over F₂⁸
are reached by traversing 13 free entries of a fixed matrix — a **2^49** space
they covered <1% of. Beierle et al. (2025) estimate ≈5.79 M such CCZ classes and
have found ≈3.81 M, so **~2 million are undiscovered** behind that traversal. On
one RX 6750 XT the validated pruned traversal is measured at **~32 GPU-days**
(saturation-limited; the ~6.5-day idealized rate needs a persistent-thread /
work-queue kernel — a plumbing change, since the 2^49 enumeration itself is
validated). Widening `apn_search` to `uint16` lanes also opens n=9..12 for the
BCP/BCL/isotopic-shift families and Yu (2025)'s n=11 F₂-coefficient conjecture.

## Splitting σ-buckets into true CCZ classes — `ccz_confirm`

`ortho_sigma` groups quadratic APN by the σ signature, a CCZ-invariant. That is
only a *necessary* condition: Gold x³/x⁵ over F₂⁵ and x³/x⁹ over F₂⁷ share a σ
(and Γ- and Δ-rank) yet are CCZ-inequivalent. Every multi-member σ-bucket must
therefore be **split** by a complete decision. `ccz_confirm` is that decision,
in native multithreaded C — the operation that is the multi-hour bottleneck when
run pairwise from Julia (`VBF.ea_mappings_from_ortho_derivative`).

### The complete decision

By Yoshiara, CCZ = EA for quadratic APN; by Canteaut–Couvreur–Perrin (2022),
two quadratic APN `F, G` are EA-equivalent **iff** their ortho-derivatives
`π_F, π_G` are *linearly* equivalent — i.e. there are invertible F₂-linear
`A, B` with `π_G = B ∘ π_F ∘ A`. This is exactly the non-empty condition of
VBF's `ea_mappings_from_ortho_derivative`, which enumerates those linear
equivalences (`linear_equivalences` / `linear_equivalences_general`) and lifts
them to CCZ maps of the graph. `ccz_confirm` decides the same predicate.

### The linear-equivalence method

For each function it first builds `π_F` exactly as VBF does
(`ortho_derivative`): per non-zero `a`, take the DDT row, form the affine
hyperplane `H_a = {b ≠ 0 : DDT(a,b) ≠ DDT(a,0)}`, and set `π_F(a)` to the
smallest non-zero vector with `⟨π_F(a), b⟩ = 1` for all `b ∈ H_a` (π_F(0)=0).

It then decides `π_G = B ∘ π_F ∘ A` with the propagation-pruned backtracking of
VBF's `linear_equivalences_general` (the non-permutation search — every
quadratic APN in even dimension has a many-to-one π): guess `A = L₂` on the
standard basis (each image independent of the previous, so `L₂` stays
invertible) and, for every point of the span fixed so far, fold the constraint
`B(π_F(L₂ x)) = π_G(x)` into a partial linear `B = L₁` kept as a triangular F₂
basis. A branch dies on the first inconsistency; a complete `L₂` whose forced
`L₁` is fully-determined and invertible (validated `π_G = L₁ ∘ π_F ∘ L₂`) is a
witness. We need only **existence** (non-empty), so the search early-exits on
the first witness — this is precisely the "records a solution" condition of the
collect-all routine, hence identical yes/no. The general search subsumes the
permutation variant VBF uses for odd-`n` Gold (linear-equivalence existence is
one predicate; both VBF routines are complete deciders of it), so a single code
path reproduces every dispatch branch.

### Parallelism (and why not GPU)

The top of that backtracking branches over `L₂(e₀)` in `2ⁿ−1` independent
subtrees. `ccz_confirm` emits one OpenMP task per `(pair, L₂(e₀)-candidate)` over
**all** pairs of **all** buckets and runs them in one dynamic parallel-for; a
per-pair "found" flag lets an equivalent pair short-circuit the moment any
subtree yields a witness, while an inequivalent pair exhausts its subtrees spread
across every core. This turns the exact pairs that are slow single-threaded
(minutes to first witness, or full exhaustion) into a few seconds. Pairwise
verdicts then feed union-find → CCZ classes.

GPU is **not** warranted here: the working set is one 2ⁿ≤256-entry LUT per
function, far too small to amortize a HIP launch, and the whole catalog test set
finishes in seconds on CPU. The GPU target on this branch is the *upstream* APN
search (`apn_search.cpp`, `qam_dfs.cpp`), not this per-bucket confirmer.

### Run it

```
make ccz_confirm
./ccz_confirm luts.tsv buckets.tsv
#   luts.tsv    lines:  ID <tab> N <tab> NAME <tab> v0 v1 ... v_{2^N-1}
#   buckets.tsv lines:  N  <tab> SIGMAHASH <tab> id,id,...
# emits  "PAIR id1 id2 0|1"  per pair and  "CLASS N sigma8 id id ..."  per class.
```

Correctness is validated against Julia's `ea_mappings_from_ortho_derivative`
pair-by-pair; see "ccz_confirm: validation and speedup" at the end.

## ccz_confirm: validation and speedup

Test set = every multi-member σ-bucket of the catalog's quadratic-APN
`functions` rows: **18 buckets, 24 pairs** (sizes 2–3, all n≤8, 15 of them n=8),
extracted from `BFA_catalog.sqlite`.

**Correctness — 0 disagreements.** For every one of the 24 pairs the C verdict
equals Julia's decision:

- `ccz_confirm` vs `VBF.ea_mappings_from_ortho_derivative(F, G)` non-empty (the
  full collect-all + graph-lift decision — the routine the catalog actually
  calls): **24/24 identical, 0 disagreements.**
- `ccz_confirm` vs `VBF.are_linear_equivalent(π_F, π_G)` (the raw
  linear-equivalence of the ortho-derivatives the EA=CCZ test reduces to):
  **24/24 identical, 0 disagreements.**
- On all 24 pairs `ea_mappings`-non-empty `==` `are_linear_equivalent`, exactly
  as Canteaut–Couvreur–Perrin (2022) guarantees for quadratic APN.

Both known σ-collisions split correctly — **n=5 Gold x³ vs x⁵ INEQUIVALENT** and
**n=7 Gold x³ vs x⁹ INEQUIVALENT** (2 classes each) — while every n=8 bucket is a
single true CCZ class: **n=8 Gold x³ ≡ reprs8_0 ≡ SimonBerg class 26** and
**Gold x⁹ ≡ reprs8_1 ≡ SimonBerg class 1** are EQUIVALENT and do **not** split.
Net partition of the test set: 20 CCZ classes from 18 σ-buckets (only n5 and n7
refine).

**Speedup.** Same machine (Ryzen 7 9700X, 16 threads), identical LUT inputs, a
concurrent unrelated 16-thread catalog build sharing the box for both sides:

| operation (full 24-pair set) | wall |
|---|---|
| `ccz_confirm`, 16 threads | **37–57 s** (varies with concurrent machine load) |
| `ccz_confirm`, 1 thread | > 300 s (dominated by the two inequivalent exhaustions) |
| Julia `ea_mappings_from_ortho_derivative`, single-thread (as the catalog runs it) | **6896 s** (≈115 min; per n=8 pair 265–543 s — it enumerates *all* lifted CCZ maps × all constant offsets) |
| Julia `are_linear_equivalent(π_F,π_G)`, single-thread (the raw ortho-derivative test) | **1569 s** |

So against `ea_mappings` — the routine actually invoked per pair during a catalog
rebuild — `ccz_confirm` is **≈120–190×** faster wall-to-wall (6896 s → 37–57 s);
the per-rebuild σ-bucket confirm drops from ~2 hours to under a minute. Even
against the far cheaper raw `are_linear_equivalent` path it is **≈30–40×**
faster. A single n=8 `ea_mappings` pair (e.g. Gold x³ vs reprs8_0, 510 s) alone
takes ~9× the entire 24-pair C run. The win is purely (a) native code and (b)
splitting each pair's `L₂(e₀)` branch across all cores with an early-exit flag —
the several n=8 pairs where Julia's single-threaded search needs 100–540 s to
reach the first witness / exhaust are exactly the ones this parallelization
collapses. (Both sides were measured with a concurrent unrelated 16-thread
catalog build sharing the box, so the ratio is if anything conservative for the
C side.)

Reproduce: dump the buckets' LUTs to `luts.tsv` / `buckets.tsv`
(`ID⇥N⇥NAME⇥lut` and `N⇥σ⇥id,id,…`) and run `./ccz_confirm luts.tsv buckets.tsv`;
diff the `PAIR`/`CLASS` lines against `VBF.ea_mappings_from_ortho_derivative`.


## Provenance

Kernels lifted (up to lane width) from the Kuznetsov (2026) census on this
branch and generalized here. The math is Yu–Wang–Li / Ichanska / Yu–Perrin /
Yu (QAM method) for the searchers, and Canteaut–Couvreur–Perrin (ortho-derivative
linear equivalence) for `ccz_confirm`; see the header comments in each file for
exact citations.
