# PLAN — Yu_202512

## Paper

Yu, Li, Ichanska, Kaleyski (2025).
"Classification of quadratic APN functions with coefficients in F₂ in dimension 10."
*Applicable Algebra in Engineering, Communication and Computing.*
DOI: 10.1007/s00200-025-00711-8

## Source material

- `input/Yu et al. - 2025 - Classification of quadratic APN functions …pdf`
- `input/paper_info.txt` — artifact/reproducibility assessment
- Author artifact: https://github.com/telegrin/3to1_vbf_equivalence (3-to-1 linear equivalence tester)

## Mathematical context

Quadratic homogeneous APN functions F(x) = Σ_{0≤t<i≤n-1} c_{i,t} x^{2^i+2^t} with c_{i,t} ∈ F₂.
The QAM (quadratic APN matrix) H is the derivative matrix in the **normal basis** {α, α², …, α^{2^{n-1}}}.
Key property (Theorem 1): c_{i,t} ∈ F₂ ⟺ H[u+1,v+1] = H[u,v]² (indices mod n).
The paper speeds up Algorithm 1 of [27] by a factor ≈ 2^n/n using cyclic equivalence of
row-combination vectors (Theorem 2, Corollary 1, Algorithm 1), then exhaustively classifies
all such functions for n=10 (3 CCZ-classes) and partially for n=11 (6 conjectured classes).

## Reproduction scope

| Claim | Status |
|-------|--------|
| Theorem 1: diagonal squaring property | exact (n=5,6) |
| Proposition 1: squaring H → EA-equiv | exact (n=5,6) |
| Theorem 2: rank reduction | exact (n=5) |
| Example 1: rank computations for specific H | exact |
| Corollary 1: CR size ≈ 2^n/n | exact |
| Example 2: CR=(1,3,5,7,11,15,31), ID array | exact |
| Algorithm 1 (IsQAM): optimised QAM test | exact, verified against `is_qam` |
| Algorithm 2: APN generation, n=5,6 | exact count (n=5: Gold only, n=6: Count=4) |
| Table 1: 3 CCZ-reps for n=10 | APN verified; CCZ-class check via ortho-derivative |
| Table 2: counts n=6,7 | n=6 exact; n=7 budget-limited (0.375 s original) |
| Algorithm 3: partial search | bounded demo (n=6, small limit) |
| Table 3: 6 CCZ-reps for n=11 | APN verified |
| n=10 exhaustive search (100 days, 22 Magma scripts) | out of scope |
| n=11 full classification | out of scope |

## Architecture restrictions

- No new VBF core code. Paper folder is orchestration only.
- Use `is_qam`, `quadratic_apn_matrix`, `qam_to_sbox`, `apn_ea_mugshot`, `gf_pow`, `gf_mul`,
  `conway_polynomial`, `rank_f2`, `gold_apn`, `solve_f2`, `differential_uniformity`,
  `ortho_derivative`, `is_quadratic_apn` from VBF.
- `find_normal_element` and `normal_basis_deriv_matrix` copied from Ichanska helpers.
- VBFCatalog optional (comparison only).
- GF(2^11) modulus: 2053 (x¹¹ + x² + 1, verified primitive).

## File layout

```
Yu_202512/
  PLAN.md
  helpers.jl          — print_section/check/kv, find_normal_element,
                         normal_basis_deriv_matrix, polynomial_sbox, update_diagonal!
  theorem1.jl         — Theorem 1: diagonal squaring property
  proposition1.jl     — Proposition 1: squaring H gives EA-equiv APN
  theorem2.jl         — Theorem 2: rank reduction via cyclic equivalence
  example1.jl         — Example 1 (n=5 H matrix, rank computations)
  corollary1.jl       — Corollary 1: |CR| ≈ 2^n/n
  example2.jl         — Example 2 (n=5 CR/RC/IDlen)
  algorithm1.jl       — Algorithm 1: IsQAM (optimised, cyclic equivalence)
  algorithm2.jl       — Algorithm 2: depth-first APN generation with F₂ coeffs
  table1.jl           — Table 1: 3 CCZ-reps for n=10
  table2.jl           — Table 2: counts n=6,7
  algorithm3.jl       — Algorithm 3: partial search for n=11
  table3.jl           — Table 3: 6 CCZ-reps for n=11
  report.jl           — paper_report()
  Makefile
  test/
    runtests.jl
    test_theorem1.jl … test_table3.jl
```

## Makefile targets

- `make test` — fast test suite (< 2 min)
- `make report` — full report (bounded n=6,7)
- `make table2_n7` — Table 2 n=7 (~ a few minutes)

## Parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `limit` | 200 | max APN functions to collect |
| `max_evaluations` | 1<<20 | max is_qam_fast calls |
| `full_search` | false | run n=7 exhaustively |
| `seed` | 42 | unused (search is deterministic) |

## Acceptance criteria

- `make test` passes.
- Theorem 1 verified on Gold x³ and Gold x⁹ (n=5, n=6).
- CR for n=5 matches paper: (1,3,5,7,11,15,31).
- ID array for n=5 matches Example 2.
- `is_qam_fast` agrees with `is_qam` on ≥20 test matrices.
- Algorithm 2 count for n=6 = 4.
- Table 1: x⁴ and x⁹ verified APN over GF(2^10).
- Table 3: x⁴, x⁵, x⁹ verified APN over GF(2^11).
