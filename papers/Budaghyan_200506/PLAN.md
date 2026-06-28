# PLAN — Budaghyan_200506

## Source

Budaghyan, Carlet, Pott (2005). "New Classes of Almost Bent and Almost Perfect
Nonlinear Polynomials." arXiv:math/0506604v1, published as IEEE Trans. IT 52(3), 2006.

Input material: `input/budaghyan_2005_new_classes_almost_bent_apn_polynomials.tex`

No author artifact released.

---

## Reproduction scope

### Section 5 — Theorems 1–4

| Claim | Status | Parameters |
|---|---|---|
| Theorem 1 — AB for m > 3 odd | **exact** | m=5,7 ; i=1,2 |
| Remark 4 — no linear perm on F_{2^5} | **exact (full search guarded)** | m=5, i=1 |
| Theorem 2 — APN for m ≥ 4 even | **exact** | m=4,6 ; i=1 |
| Theorem 3 — APN for m div 6 (F_8 computer check) | **exact** | m=6, i=1 |
| Theorem 3 — APN degree-4 verification | **exact** | m=6, i=1 |
| Theorem 4 — AB for m odd, n|m | **exact** | m=9 n=3 i=1 ; m=15 n=3 i=1 |
| Proposition 4 — EA-inequivalence criterion | **exact** | all above |

### Computationally infeasible
- Full CCZ-class enumeration (impractical at n≥7)
- Timing tables (not in paper)

---

## Architecture

- No VBF packages modified; paper folder orchestrates only.
- `gf_relative_trace` is paper-local (not in VBF yet).
- `gf_trace`, `gold_lut` reimplemented in helpers.jl (also in Budaghyan_202008 — local copies are fine; these stay in the paper folder).

---

## File layout

```
Budaghyan_200506/
  PLAN.md
  Makefile
  helpers.jl            — gf_trace, gf_relative_trace, gold_lut, print utils
  theorem1.jl           — Section 5, Theorem 1 (AB, m > 3 odd)
  remark4.jl            — Section 5, Remark 4 (computer check, F_{2^5})
  theorem2.jl           — Section 5, Theorem 2 (APN, m ≥ 4 even)
  theorem3.jl           — Section 5, Theorem 3 (APN, m div 6) + F_8 check
  theorem4.jl           — Section 5, Theorem 4 (AB, m odd div n)
  report.jl             — paper_report() entry point
  test/
    runtests.jl
    test_theorem1.jl
    test_remark4.jl
    test_theorem2.jl
    test_theorem3.jl
    test_theorem4.jl
```

---

## Key formulas

**Theorem 1** (m > 3 odd, gcd(m,i)=1):
```
F'(x) = x^{2^i+1} + (x^{2^i} + x) · tr(x^{2^i+1} + x)
```
AB; algebraic degree 3; tr(F'(x)) has degree 2 → Prop 4 applies.

**Theorem 2** (m ≥ 4 even, gcd(m,i)=1):
```
F'(x) = x^{2^i+1} + (x^{2^i} + x + 1) · tr(x^{2^i+1})
```
APN; algebraic degree 3; tr(F'(x)) has degree 2 → Prop 4 applies.

**Theorem 3** (6 | m, gcd(m,i)=1):
```
F'(x) = [x + trm/3(x^{2(2^i+1)} + x^{4(2^i+1)}) + tr(x)·trm/3(x^{2^i+1} + x^{2^i(2^i+1)})]^{2^i+1}
```
APN; algebraic degree 4. Computer check: for u,w ∈ F*_8, tr_3(w)=0 → (u^{2^i+1}w)^2+(u^{2^i+1}w)^4 ≠ u.

**Theorem 4** (m odd, n|m, m≠n, gcd(m,i)=1):
```
F'(x) = x^{2^i+1} + trm/n(x^{2^i+1}) + x^{2^i}·trm/n(x) + x·trm/n(x)^2
       + [A]^{1/(2^i+1)} · (x^{2^i} + trm/n(x)^2 + 1)
       + [A]^{2^i/(2^i+1)} · (x + trm/n(x))
```
where A = trm/n(x)^{2^i+1} + trm/n(x^{2^i+1}) + trm/n(x).
AB; algebraic degree n+2.

---

## Acceptance criteria

- `make -C papers/Budaghyan_200506 test` passes in < 5 min.
- `make -C papers/Budaghyan_200506 report` completes quickly.
- APN/AB, degree, and Prop 4 checks all PASS for all tested parameters.
- Theorem 3 F_8 computer check passes (exact, 21 pairs).
- Remark 4 default (sample) check passes; `full_search=true` available.
