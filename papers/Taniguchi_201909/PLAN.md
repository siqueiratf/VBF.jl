# PLAN — Taniguchi_201909

## Context

Reproducing: Hiroaki Taniguchi (2019), "On some quadratic APN functions".
APN functions of the form F(x,y)=(xy,G(x,y)) over GF(2ⁿ)×GF(2ⁿ); new family
(Theorem 3) with two new CCZ-classes on F₂⁸ not found in prior work.

## Source material

- `input/Taniguchi_201909.tex` — paper TeX
- `input/paper_info.txt` — reproducibility assessment
- No author code released (Magma-computed Γ-ranks, scripts not published)

## Reproduction scope

| Claim | Status |
|---|---|
| Theorem 3: APN iff P(x)=x^{2^m+1}+ax+b rootless | **exact** (verified for half∈{4,5}) |
| Theorem 4: alternate form, EA-equiv to Thm 3 | **exact** (mugshot match) |
| Fact (Helleseth-Kholosha): rootless-b count formula | **exact** (n=5,6,7) |
| Section 2: Carlet Thm 1 + Zhou-Pott Cor 1 APN (small n) | **exact** |
| Theorem 5: presemifield no-zero-divisors | **exact** (GF(2⁴)/GF(2²)) |
| Γ-ranks 13200/13642/13700/13798 on F₂⁸ | **loaded** (Magma, no code released) |
| Theorem 6: nuclei ≅ K (presemifield) | **skip** (purely algebraic; no nucleus algorithm in VBF) |

## Architecture restrictions

- All orchestration stays in `papers/Taniguchi_201909/`; no new math added to `packages/VBF/`
- `taniguchi_apn`, `taniguchi_apn_representatives`, `gf_pow`, `gf_mul`,
  `primitive_polynomial`, `differential_uniformity`, `algebraic_degree`,
  `apn_ea_mugshot` from VBF are the main APIs used
- Root project `--project=$(ROOT)` for all Julia invocations

## File layout

```
papers/Taniguchi_201909/
  PLAN.md
  helpers.jl
  theorem3.jl              § 3 — Theorem 3 APN construction
  theorem4.jl              § 3 — Theorem 4 alternate form
  fact_helleseth_kholosha.jl  § 2 — Fact (rootless-b count)
  section2_carlet_zhou_pott.jl  § 2 — Carlet Thm 1 + Zhou-Pott Cor 1
  theorem5_presemifield.jl  § 4 — Theorem 5 presemifield
  report.jl                paper_report()
  Makefile
  tests/
    runtests.jl
    test_theorem3.jl
    test_theorem4.jl
    test_fact_helleseth_kholosha.jl
    test_theorem5_presemifield.jl
```

## Makefile targets

- `test` — run tests (small budgets, <60s)
- `report` — print full paper_report
- `theorem3`, `theorem4`, `fact`, `section2`, `theorem5` — individual claims

## Acceptance criteria

- `make test` passes
- `make report` completes without long search
- All expensive parts guarded by explicit budgets
- Claims labelled exact / loaded / skip
