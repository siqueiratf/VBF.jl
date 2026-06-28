# PLAN — Li & Kaleyski (2024)

## Context

Li, Kaleyski (2024): "Two New Infinite Families of APN Functions in Trivariate Form".
Two families of quadratic APN functions over F_{2^{3m}}, in trivariate form F=(f,g,h):
F_{2^{3m}} ≅ F_{2^m}^3, elements encoded as triples (x,y,z) with m-bit chunks.

## Source material

- PDF: `input/Li e Kaleyski - 2024 - Two New Infinite Families of APN Functions in Trivariate Form.pdf`
- No author artifact.

## Reproduction scope

| Claim | Status |
|---|---|
| Theorem 1 — Family 1 APN (diff. unif. = 2^k) | exact, m ≤ 5 |
| Theorem 3 — Family 1 permutation (m/k odd) | exact, m ≤ 5 |
| Proposition 4 — explicit i=1, gcd(m,7)=1 | exact |
| Theorem 6 — Family 2 APN (diff. unif. = 2^k) | exact, m ≤ 5 |
| Theorem 7 — Family 2 permutation (m/k odd) | exact, m ≤ 5 |
| Proposition 8 — explicit i=1, gcd(m,7)=1 | exact |
| Section 5A — Table IV ortho-deriv. spectra n=9 | exact |
| Section 5B — Table V, m=4,5 (various i) | bounded (m≤4 default, m=5 opt-in) |
| Section 5C — exhaustive search m≤5 | out-of-scope (2^{45} candidates) |

## Architecture

- `helpers.jl`: trivariate encoding, LUT builder, polynomial root checkers
- `theorem1.jl`: Family 1 LUT + Theorems 1 & 3 verification
- `proposition4.jl`: Proposition 4 (gcd(m,7)=1, i=1) explicit case
- `theorem6.jl`: Family 2 LUT + Theorems 6 & 7 verification
- `proposition8.jl`: Proposition 8 (gcd(m,7)=1, i=1) explicit case
- `section5a.jl`: Table IV orthoderivative differential spectra
- `report.jl`: `paper_report()` top-level
- `Makefile`: targets per file

## File layout

```
Li_202402/
  PLAN.md
  helpers.jl
  theorem1.jl
  proposition4.jl
  theorem6.jl
  proposition8.jl
  section5a.jl
  report.jl
  Makefile
  tests/
    runtests.jl
    test_theorem1.jl
    test_proposition4.jl
    test_theorem6.jl
    test_proposition8.jl
    test_section5a.jl
```

## Families

**Family 1** (Theorems 1, 3, Proposition 4):
`F(x,y,z) = (x^{q+1} + x^q·z + y·z^q, x^q·z + y^{q+1}, x·y^q + y^q·z + z^{q+1})`
Conditions: gcd(i,m)=k, q=2^i; three univariate polys + one bivariate poly have no roots in F_{2^m}.

**Family 2** (Theorems 6, 7, Proposition 8):
`F(x,y,z) = (x^{q+1} + x·y^q + y·z^q, x·y^q + z^{q+1}, x^q·z + y^{q+1} + y^q·z)`
Conditions: gcd(i,m)=k, q=2^i; three univariate polys + one bivariate poly have no roots in F_{2^m}.

**Proposition 4**: i=1, q=2, gcd(m,7)=1 → X^7+X+1, X^7+X^4+1, X^7+X^4+X^3+X+1 irreducible over F_2
**Proposition 8**: i=1, q=2, gcd(m,7)=1 → X^7+X^3+X^2+X+1, X^7+X^4+1, X^7+X+1 irreducible over F_2

## Acceptance criteria

- `make -C papers/Li_202402 test` passes
- `make -C papers/Li_202402 report` completes (no long search)
- All expensive computations guarded by limit/m parameters
- Orthoderivative spectra at n=9 match paper Table IV
- Permutation verified for m=3 (Propositions 4 and 8)
