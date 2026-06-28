# Budaghyan_202009 — Reproduction Plan

## Paper
Budaghyan, Carlet, Helleseth, Kaleyski (2020), "On the Distance Between APN
Functions", IEEE Transactions on Information Theory.

## Source material
- `input/Budaghyan_202009.tex` — converted TeX
- `input/paper_info.txt` — artifact analysis
- No author code released.

## Reproduction scope

| Claim | Status |
|-------|--------|
| Prop 2 — APN conditions (i)-(vi) for G | EXACT |
| Observation 1 — shifted deriv necessary condition | EXACT (via Alg 1) |
| Algorithm 1 — shift domain filtering | EXACT |
| Corollary 2 — lower bound d(F,G) ≥ ⌈m_F/3⌉+1 | EXACT |
| Prop 3 — CCZ-invariance of Π_F | EXACT |
| Prop 4 — EA-invariance of Π_F^β | EXACT |
| Prop 5 — quadratic: Π_F^β shift-independent | EXACT |
| Prop 6 — Gold x^3 formula for |Π_F^β(b)| | EXACT |
| Table I — m_F and bounds for Gold x^3, n=1..10 | EXACT |
| Table II — m_F for Edel-Pott switching classes | BOUNDED (monomial reps) |
| Table III — actual APN distances at n=5 | NOT EXECUTED |
| Section V — single shift linear system | EXACT |
| Full n≤8 invariant table | NOT EXECUTED |
| Timing benchmarks | NOT EXECUTED |

## File layout

```
proposition2.jl   Prop 2: check_apn_conditions + random verification
algorithm1.jl     Alg 1: domain filtering
corollary2.jl     Cor 2 + Props 3/4/5
proposition6.jl   Prop 6 + Table I
table2.jl         Table II (monomial representatives)
section5.jl       Section V: single shift kernel
helpers.jl        Shared: print utilities, gold_x3, compute_m_F, etc.
report.jl         paper_report()
Makefile
test/
  runtests.jl
  test_proposition2.jl
  test_algorithm1.jl
  test_proposition6.jl
  test_section5.jl
```

## Architecture
- All VBF math via `VBF` package; no core math reimplemented here.
- No `VBFCatalog` dependency (Table II polynomial n=6 reps noted as needing catalog).
- kernel_f2 used for Section V F₂ linear system.
