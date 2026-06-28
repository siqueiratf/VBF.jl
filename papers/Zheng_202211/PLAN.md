# PLAN — Zheng_202211

## Paper

Zheng, Kan, Li, Peng, Tang (2022). "Constructing new APN functions through relative
trace functions." arXiv:2101.11535v1 [cs.IT].

**General form (Eq. 1):**
f(x) = a·Tr_m^n(F(x)) + a^q·Tr_m^n(G(x))
where n=2m, q=2^m, Tr_m^n(x)=x+x^q, a ∉ F_q (so a+a^q ≠ 0).

**Case A studied in this reproduction:**
F(x)=bx^3, G(x)=cx^{2^s+1} → f_s(x)=a·Tr_m^n(bx^3)+a^q·Tr_m^n(cx^{2^s+1})

**Expanded as quadrinomial:**
f_s(x) = (a·b)x^3 + (a·b^q)x^{3q} + (a^q·c)x^{2^s+1} + (a^q·c^q)x^{(2^s+1)q}

## Source material

- `input/Zheng et al. - 2022 .... pdf` — full 16-page paper
- `input/Zheng_202211.tex` — simplified TeX (abstract-level only)
- `input/paper_info.txt` — reproducibility assessment
- No author-released code.

## Main results

| Result | Paper reference | Verifiable? |
|---|---|---|
| Lemma 2.1 — APN characterization via Δ_{d,F} ∈ F_{2^m} | Section 2 | **exact** n=10 |
| Theorem 3.3 Case iii — F15 family: s=3, b non-cube, c/b³ ∈ F*_{2^m} | Section 3A | **exact** n=10,14 |
| Table II F15 — f₃=a·Tr(bx³)+a^q·Tr(b³x⁹) new CCZ class | Table II | **partial** (EA-mugshot comparison) |
| Hexanomial families CCZ-equiv to Taniguchi (F12) | Section 3B | out-of-scope |
| Two sporadic APN instances over F_{2^{10}} | Computer search | out-of-scope |

## Architecture restrictions

- orchestration only, no new math in `packages/VBF/`
- VBF must not depend on VBFCatalog
- use `gf_mul`, `gf_pow`, `primitive_polynomial`, `SBox`, `differential_uniformity`,
  `apn_ea_mugshot` from VBF; `load_catalog`, `list_functions`, `load_sbox` from VBFCatalog

## File layout

```
papers/Zheng_202211/
  PLAN.md
  helpers.jl         ← zheng_lut, f15_sbox, in_subfield, is_cube, streaming DDT
  lemma2_1.jl        ← Lemma 2.1 direct characterization check
  theorem3_3.jl      ← Theorem 3.3 Case iii: F15 APN + EA-mugshot CCZ check
  report.jl          ← paper_report()
  Makefile
  test/
    runtests.jl
    test_lemma2_1.jl
    test_theorem3_3.jl
```

## Key parameter choices

F15 at n=10 (m=5, q=32): a=2 (primitive, ∉ F_{2^5}), b=2 (non-cube), c=b^3=8, s=3.
- Non-cube check: b^{(2^{10}-1)/3} = 2^{341} ≠ 1 in GF(2^{10}) ✓
- a ∉ F_{2^5}: ord(2)=1023>31 ✓
- c/b^3 = 1 ∈ F*_{2^5} (Case iii condition) ✓

F15 at n=14 (m=7, q=128): same a=b=2, c=8, s=3.
- DDT 16384² = 2 GB → use streaming differential_uniformity_rowwise

## Acceptance criteria

- `make test` passes in < 2 min (n=10 only)
- `make report` completes (n=10 fast; n=14 streaming, ~5 s)
- lemma2_1 check agrees with differential_uniformity at n=10
- EA-mugshot comparison: F15 mugshot differs from all catalog n=10 APN functions
