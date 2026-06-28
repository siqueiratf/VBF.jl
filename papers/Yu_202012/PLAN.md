# PLAN — Yu, Kaleyski, Budaghyan, Li (2020)

## Source material
- PDF: `input/Yu et al. - 2020 - Classification of quadratic APN functions...pdf`
- TeX: `input/yu_2020_classification_quadratic_apn_f2.tex`
- No author code released (paper_info.txt: Artifact availability = A)

## Paper in one sentence
Exhaustive search for quadratic APN functions with F₂ coefficients over GF(2ⁿ)
for n ≤ 9 via F₂-cyclic QAMs; finds 2 new APN functions over GF(2⁹).

## Key mathematical content
| Name | Paper location | VBF API |
|---|---|---|
| Theorem 1 (QAM ↔ APN) | §3.1, cited from [27]=Yu_201411 | `is_qam`, `quadratic_apn_matrix`, `qam_to_sbox` |
| Theorem 2 (F₂-cyclic structure) | §3.1 | `qam_cyclic_orbits(n,1)`, `qam_from_cyclic(n,1,...)` |
| Definition (proper matrix) | §3.2 | implicit in `search_qam_full` |
| Proposition 1 (Frobenius-squared = EA-equiv) | §3.2 | `apn_ea_mugshot` |
| Algorithm 1 (F₂-coefficient QAM search) | §3.2 | `search_qam(n, 1)` |
| Tables 1–4 (classification n=4..9) | §3.2 | `differential_uniformity`, `sbox_from_exponents` |

## Reproduction scope
| Claim | Status |
|---|---|
| Theorem 2: cyclic structure holds for F₂-coefficient functions | **Exact** — verify on concrete examples |
| Proposition 1: Frobenius-squared QAM gives EA-equivalent function | **Exact** — verify on small examples |
| n=4,5,6 search: finds only x³ (n=4,6) and x³,x⁵ (n=5) | **Exact** — `search_qam(n,1)` fast enough |
| n=7 functions are APN | **Exact** — 14 distinct functions from TeX verified (1 TeX duplicate noted) |
| n=8 functions are APN | **Exact** — all 7 verified |
| n=9 functions are APN | **Exact** — all 8 verified including s₁,s₂ |
| s₁,s₂ are EA-inequivalent to x³,x⁵,x¹⁷ | **Exact** — via `apn_ea_mugshot` |
| n=7 exhaustive search produces exactly 15 CCZ-classes | **Bounded demo** — budget-limited scan |
| n=8,9 exhaustive search | **Not executed** — search space too large without pruning |

## Note on TeX duplicate (Table 2)
The TeX conversion of Table 2 (n=7) contains `x³+x⁹+x¹⁸+x⁶⁶` twice (lines 310
and 316). The paper claims 15 CCZ-classes (3 monomials + 12 polynomials). We verify
the 14 distinct functions from the TeX and note this issue.

## Architecture restrictions
- No new math in `packages/VBF` — all orchestration only
- Use `primitive_polynomial(n)` for `terms_to_lut` to match `search_qam` internals
- All expensive computations guarded by `limit` / `max_evaluations`

## File layout
```
papers/Yu_202012/
  PLAN.md          (this file)
  Makefile
  helpers.jl       (sbox_from_exponents, has_f2_cyclic_structure, print helpers)
  theorem2.jl      (Section 3.1, Theorem 2: F₂-cyclic structure)
  proposition1.jl  (Section 3.2, Proposition 1: Frobenius-squared EA-equivalence)
  algorithm1.jl    (Section 3.2, Algorithm 1: search_qam(n,1) wrapper)
  table1.jl        (Table 1: n=4,5,6)
  table2.jl        (Table 2: n=7)
  table3.jl        (Table 3: n=8)
  table4.jl        (Table 4: n=9, including new functions s₁,s₂)
  report.jl        (paper_report())
  test/
    runtests.jl
    test_theorem2.jl
    test_proposition1.jl
    test_algorithm1.jl
    test_table1.jl
    test_table2.jl
    test_table3.jl
    test_table4.jl
```

## Acceptance criteria
- `make -C papers/Yu_202012 test` passes in ≤ 5 minutes
- `make -C papers/Yu_202012 report` completes without a long search
- All APN checks pass for all functions in Tables 1–4
- Cyclic structure verified for representative F₂-coefficient functions
- n=6 exhaustive search matches Table 1
