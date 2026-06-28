# PLAN — Kaleyski_201911

## Paper

"Changing APN functions at two points" — Nikolay S. Kaleyski (2019).  
arXiv:1911.02608 / DesignsCodes&Cryptography 2020.

## Source material

- `input/kaleyski_2019_changing_apn_functions_at_two_points.tex` — full TeX source
- `input/paper_info.txt` — reproducibility assessment

## Reproduction scope

| Claim | Status | Notes |
|---|---|---|
| Theorem 17 — characterization formula (Eq. 29) | **exact** | verified on Gold x^3 n=5..8 |
| Table 2 — formula (34) for x^3, n=1..20 | **exact** | DDT-verified for n≤10, formula for n≤20 |
| Table 1 — S1, S2 for Edel-Pott switching classes n=5..8 | **bounded demo** | uses catalog APN functions (superset of paper's 47 reps); exact numerical values differ from paper's specific representatives |
| Conjecture 21 — power functions share S1,S2 with x^3 | **bounded demo** | verified for all power APN functions in catalog n=5..10 |
| Conjecture 22 — no APN two-point swap for n≥5 | **bounded demo** | checked over all catalog APN functions n=5..8 |
| Full classification for all n ≤ 8 | **not executed** | requires exhaustive enumeration of all APN functions |

## Architecture

- `helpers.jl` — normalize_apn, compute_s1, compute_s2, print utilities
- `theorem17.jl` — Section 4, Theorem 17: characterization via Eq. 29
- `table2.jl` — formula (34) for F(x)=x^3, n=1..20
- `table1.jl` — Table 1 reproduction: S1, S2 for Edel-Pott switching classes n=5..8
- `conjecture21.jl` — Conjecture 21: power APN functions share S1,S2 with x^3
- `conjecture22.jl` — Conjecture 22: no APN two-point swap for any known APN n=5..8
- `report.jl` — paper_report() aggregating all claims

## Makefile targets

| Target | Description |
|---|---|
| `test` | fast test suite (n≤7, small budgets) |
| `report` | fast aggregate report |
| `theorem17` | run Theorem 17 demo |
| `table2` | reproduce Table 2 (formula vs DDT) |
| `table1` | compute Table 1 S1/S2 values |
| `conjecture21` | Conjecture 21 check (power functions) |
| `conjecture22` | Conjecture 22 check (all catalog APN n=5..8) |

## Parameters

- `n_max_ddt` — max n for DDT-based verification in Table 2 (default 10)
- `n_max_formula` — max n for formula in Table 2 (default 20)
- `save_results` — write TOML results to results/ (default false)

## Key formulas

```
S1(F) = Σ_{y} DD_F(y,  F(y) ⊕ 1)
S2(F) = Σ_{y} DD_F(y ⊕ 1, F(y))

Theorem 17: G is APN ⟺ 6·DD_F(1,0) = S1(F) + S2(F)
  [requires F(0)=0, F(1)=1; G = F with values at 0,1 swapped]

Formula (34): S1(x^3) = 2(2^{n-1} - 1)           if n odd
              S1(x^3) = 2(2^{n-1} + 2^{n/2} - 1)  if n even, n/2 odd
              S1(x^3) = 2(2^{n-1} - 2^{n/2} - 1)  if n even, n/2 even
```

## Normalization

For Theorem 17 to apply, F must satisfy F(0)=0, F(1)=1.

- Power functions satisfy this automatically (in field arithmetic: 0^k=0, 1^k=1).
- Sporadic catalog functions: normalize via output-XOR (F(0)→0) then output-multiplication by gf_inv(F(1),n) (F(1)→1).
  This is an EA transform, preserving the APN property.

## Acceptance criteria

- `make -C papers/Kaleyski_201911 test` passes
- `make -C papers/Kaleyski_201911 report` runs in ≤2 minutes
- Theorem 17 condition verified on Gold x^3 examples
- Table 2 formula matches DDT for n=1..10
- Conjecture 22 holds for all n=5..8 catalog APN functions
