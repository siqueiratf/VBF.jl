# PLAN — Calderini (2020): On the EA-classes of known APN functions in small dimensions

## Source

- PDF: `input/On the EA-classes of known APN functions in small dimensions.pdf`
- Reference: Calderini, M. (2020). *On the EA-classes of known APN functions in small dimensions*.
  Cryptography and Communications **12**, 821–840. DOI: 10.1007/s12095-020-00427-1

## Context

The paper uses Procedure 2 from [Budaghyan-Calderini-Villa 2020] to enumerate EA-classes
within the CCZ-class of each known APN function in n=6, and gives upper bounds for n=7,8,9.
The main tools are: linear codes C₁..C₄ associated to a function, Walsh-zero subspace
enumeration, and code permutation-equivalence (checked via MAGMA in the paper).

## Reproduction Scope

| Claim | Status | Method |
|---|---|---|
| C₃(F), C₄(F) code matrix construction | **Exact** | Implemented in helpers.jl |
| Observation 1 (Walsh admissibility criterion) | **Exact** | `lat(F)` + ZW(λ) |
| Proposition 1 (L₁∘L → same EA-class) | **Exact** | Illustrated for n=4 |
| Corollary 1 (upper bound = #Walsh-zero subspaces) | **Exact** | n=4,5 |
| Theorem 5 (code equiv ↔ function equiv) | Stated | Requires code-equiv kernel |
| Theorem 6 (C₄ detects affine-equiv of permutations) | **Exact** | Dillon/inverse demo |
| Section 5.1 Kim/Dillon CCZ-class structure | **Exact** | VBF APIs |
| Section 5.1 Remark 4 (F₂, F₃ AE to their inverses) | **Exact** | `are_affine_equivalent` |
| Dillon component degree distribution {* 3^^7, 4^^56 *} | **Exact** | `component_degrees` |
| Table 1: catalog mapping (14 n=6 CCZ-reps) | **Loaded** | VBFCatalog |
| Table 1: EA-class counts (exact, n=6) | **Out of scope** | Needs MAGMA code equiv |
| Theorem 7: CCZ~x⁻¹ iff AE~x⁻¹ (n=5,6) | **Exact** | Walsh-zero subspace count |
| Theorem 8: non-Gold power APN ≤2 EA-classes (n=5) | **Exact** | Walsh-zero subspace count |
| Tables 2,3,4 (upper bounds n=7,8,9) | **Out of scope** | Walsh-zero enum too slow |

## Architecture

```
papers/Calderini_202009/
  Calderini_202009.tex   # key theorems extracted for reference
  PLAN.md
  helpers.jl             # C₃, C₄, ZW, S_F, power_sbox, perm_inverse, component_degrees
  section3.jl            # Observation 1, Propositions 1-3, Corollary 1
  section4.jl            # C₁..C₄ code matrices, Theorem 5 (stated), Theorem 6
  section5.jl            # Table 1 catalog, Section 5.1 Kim/Dillon analysis, Remark 4
  section6.jl            # Theorem 7 (n=5,6), Theorem 8 (n=5)
  report.jl              # paper_report()
  Makefile
  tests/
    runtests.jl
    test_section3.jl
    test_section4.jl
    test_section5.jl
    test_section6.jl
```

## Acceptance Criteria

- `make -C papers/Calderini_202009 test` passes in < 2 minutes.
- `make -C papers/Calderini_202009 report` prints verifiable claims with [PASS] markers.
- All expensive searches guarded by `limit` parameter.
- Claims clearly labelled: exact / bounded / loaded from paper / out of scope.
