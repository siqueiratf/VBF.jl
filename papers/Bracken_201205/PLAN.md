# PLAN — Bracken_201205

## Paper

Bracken, Tan, Tan (2012). "Binomial differentially 4 uniform permutations with high
nonlinearity." *Finite Fields and Their Applications* 18 (2012) 537–546.

Construction: **F(x) = α·x^{2^s+1} + α^{2^k}·x^{2^{2k}+2^{k+s}}** on GF(2^{3k}),
where α = 2 (primitive element) and 2^{-k} ≡ 2^{2k} (mod 2^{3k}−1).

## Source material

- `input/Bracken et al. - 2012 - Binomial...pdf` — full paper
- `input/paper_info.txt` — reproducibility assessment
- No author-released code.

## Reproduction scope

| Claim | Section | Status |
|---|---|---|
| Lemma 2.1 — permutation iff k/t odd | 2 | **exact** (n=6,12,15) |
| Lemma 3.1 — diff-2^t-uniform | 3 | **exact** (n=6 t=2; n=15 t=1) |
| Lemma 4.2 — Walsh spectrum bound | 4 | **exact** (n=6,15) |
| Theorem 1.1 (t=2, non-degenerate) | 1 | **out-of-scope** (n=30, 2^30 elements) |
| Problem 5.1 — function G | 5 | **out-of-scope** (open problem) |

### Degeneration note

When s ≡ 2k (mod 3k) the two exponents both reduce to 2^{2k}+1 mod (2^{3k}−1),
collapsing F to a monomial:
- n=6 (k=2, s=4): F = (α+α^4)x^{17} — a scalar of x^{17}, still diff-4-uniform
- n=12 (k=4, s=8): same degeneracy for t=4; all valid s≡8 mod 12

Smallest non-degenerate cases:
- t=1 (APN): **n=15, k=5, s=1** — verified here
- t=2: n=30 — out-of-scope

## Architecture restrictions

- No new math in `packages/VBF/` — orchestration only.
- VBF must not depend on VBFCatalog.
- Use `gf_pow`, `gf_mul`, `primitive_polynomial`, `SBox`, `is_permutation`,
  `differential_uniformity`, `linearity` from VBF.

## File layout

```
papers/Bracken_201205/
  PLAN.md           ← this file
  helpers.jl        ← bracken_binomial_lut/sbox + report formatting
  section2.jl       ← Lemma 2.1: permutation iff k/t odd
  section3.jl       ← Lemma 3.1: differential uniformity
  section4.jl       ← Lemma 4.2: Walsh spectrum bound
  report.jl         ← paper_report() entry point
  Makefile
  test/
    runtests.jl
    test_section2.jl
    test_section3.jl
    test_section4.jl
```

## Makefile targets

`test`, `report`, `section2`, `section3`, `section4`, `clean_results`.

## Implementation phases

1. `helpers.jl` — bracken_binomial_lut + formatting utils
2. `section2.jl` — is_permutation checks (n=6,12,15)
3. `section3.jl` — differential_uniformity checks (n=6 fast; n=15 in report)
4. `section4.jl` — linearity/Walsh bound checks (n=6,15)
5. `report.jl` — paper_report() stitching all sections
6. `Makefile` and `test/` files
7. Run `make test` and `make report`

## Acceptance criteria

- `make -C papers/Bracken_201205 test` passes in < 2 min.
- `make -C papers/Bracken_201205 report` completes without long search.
- Tests cover n=6 permutation+diff_unif+Walsh; n=12 non-permutation; n=15 permutation.
- report covers n=15 APN verification (diff_unif=2, linearity≤256).
- All expensive paths have explicit runtime notes; no exhaustive loops at n≥30.
