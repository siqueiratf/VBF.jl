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

## Provenance

Kernels lifted (up to lane width) from the Kuznetsov (2026) census on this
branch and generalized here. The math is Yu–Wang–Li / Ichanska / Yu–Perrin /
Yu (QAM method); see the header comments in each file for exact citations.
