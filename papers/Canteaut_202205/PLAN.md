# PLAN — Canteaut_202205

## Source material
- `input/Canteaut_202205.tex` — full TeX source
- `input/paper_info.txt` — scope notes

## Paper
Canteaut, Couvreur, Perrin (2022). "Recovering or Testing Extended-Affine Equivalence."

## Reproduction scope

| Claim | Status |
|---|---|
| Proposition 3.5: Δ_a F(x) + Δ_a F(0) = Jac_lin F(a)·x | **exact** (small n) |
| Proposition 3.7: Jac_lin chain rule for EA-equivalent functions | **exact** (small n) |
| Proposition 3.12: rank_dist ↔ DDT distribution | **exact** (small n) |
| Corollary 3.14: APN ↔ Jac_lin rank = n-1 | **exact** (small n) |
| Algorithm 1: EA-recovery for quadratic functions | **bounded** (n=5, Gold APN) |
| Section 4.3: 6-bit APN partition into EA-classes | **exact** (catalog) |
| 8-bit APN partitioning (21 102 functions) | **out of scope** (needs large corpus) |
| Timing benchmarks (Table 1) | **out of scope** |

## Architecture
- No paper-specific math added to `packages/VBF`.
- `jac_lin_cols`, `rank_table`, `rank_distribution`, and `ea_recovery_quadratic`
  live entirely in the paper folder.
- VBF APIs used: `SBox`, `F2LinearMap`, `is_invertible`, `inv`, `compose`,
  `ortho_derivative`, `apn_ea_mugshot`, `are_ea_equivalent`, `ddt`, `rank_f2`,
  `gauss_jordan!`, `gf_monomial_lut`.

## File layout

```
helpers.jl              — jac_lin_cols, rank_table, rank_distribution, report utils
proposition14.jl       — Prop 3.5: derivative identity
proposition3_7.jl       — Prop 3.7: Jac_lin chain rule for EA-equiv functions
proposition3_12.jl      — Prop 3.12: rank distribution ↔ DDT distribution
corollary24.jl        — Cor 3.14: APN ↔ Jac_lin rank n-1
algorithm1.jl           — Alg 1: EA-recovery for quadratic functions (bounded)
section4_3.jl           — Section 4.3: 6-bit APN EA-partitioning via ortho-deriv.
report.jl               — paper_report() driver
Makefile
test/runtests.jl
test/test_proposition14.jl
test/test_proposition3_7.jl
test/test_proposition3_12.jl
test/test_corollary24.jl
test/test_algorithm1.jl
test/test_section4_3.jl
```

## Makefile targets

| Target            | Action |
|-------------------|---|
| `test`            | fast test suite (n=5 only) |
| `report`          | full paper_report() |
| `proposition14`   | run Proposition 3.5 |
| `proposition3_7`  | run Proposition 3.7 |
| `proposition3_12` | run Proposition 3.12 |
| `corollary24`     | run Corollary 3.14 |
| `algorithm1`      | run Algorithm 1 demo (n=5) |
| `section4_3`      | run Section 4.3 partition |
| `clean_results`   | remove results/ |

## Algorithm 1 implementation notes

Unknowns: rows of X ∈ F₂^{n×n} and Y ∈ F₂^{n×n}, packed as n² + n² bits in UInt128
(n ≤ 6 required: 2·36 = 72 ≤ 128).

Equations for one guess pair (v, w) with M = Jac_lin G(v), N = Jac_lin F(w):
- (i,j): Σ_k M[k,j]·x_{i,k} ⊕ Σ_k N[k,i]·y_{k,j} = 0
- (i): Σ_j v[j]·y_{i,j} = w[i]

For s=3 pairs: (n²+n)·s equations in 2n² unknowns, solved by augmented GF(2) elimination.
Search over all (v_1,v_2,v_3) with rank(Jac_lin G(v_i)) = r_min, up to `max_guesses`.
For each guess with solution space dim ≤ T_threshold, iterate 2^dim solutions checking
non-singularity of X and Y.

## Acceptance criteria
- `make -C papers/Canteaut_202205 test` passes in < 2 min.
- `make -C papers/Canteaut_202205 report` completes without timeout.
- All four proposition/corollary checks pass on Gold x^3 n=5,6.
- Algorithm 1 recovers EA triple for a known Gold n=5 EA-equivalent pair.
- Section 4.3 partitions 15 n=6 quadratic APN into 13 EA-classes.
