# PLAN: Ichanska_202400 — Pushing the QAM method for finding APN functions further

## Context

Julia workspace for verifying algorithmic and mathematical claims of Ichanska, Berg,
Kaleyski & Yu (2024/2025), "Pushing the QAM method for finding APN functions further."
Core contribution: improved QAM depth-first search with multi-level orbit partitioning;
exhaustive classification for (n,m)=(8,2) → 27 CCZ classes (one new APN); and (n,m)=(10,1)
→ 3 CCZ classes. Full searches took weeks on 128-core servers and are out of scope.

## Source material

- PDF: `input/Ichanska et al. - Pushing the QAM method...pdf`
- No TeX source available (PDF-only); no author code release.
- Simon-Berg thesis data (the 27 GF(4)-coefficient CCZ reps) requires the external
  GitHub repo `Simon-Berg/thesis`; not available locally → 26 reps not in this run.

## Reproduction scope

| Claim | Status | Notes |
|---|---|---|
| Theorem 2: cyclic shift of QAM | **exact** | verified for n=4 with normal basis |
| Theorem 3: rank of cyclic combo | **exact** | verified for n=4 |
| Lemma 1: categories → orbit separation | **exact** | verified for (n,m)=(8,2) |
| Algorithm 1: orbit partition first level (n=4,m=2) | **exact** | small-field demo |
| Algorithm 1: (n,m)=(8,2) first level → {1,a,a^7,a^17} | **exact** | computed |
| New function (Table 5): APN + ODDS + NL | **exact** | matches paper |
| Section 5.3: (n,m)=(10,1) → 3 CCZ classes | **exact** | Gold classes + third |
| Full QAM search (weeks/months) | **out of scope** | no compute budget |
| Δ-rank, Γ-rank, automorphism group | **out of scope** | needs Magma |
| All 27 Simon-Berg reps (Table 10/11) | **out of scope** | repo not available |
| (8,4), (9,3), (10,2) partial searches | **out of scope** | no compute budget |

## Field convention

Paper uses Conway polynomial for F₂ⁿ: `conway_polynomial(n)` in VBF.jl.
- n=8: `conway_polynomial(8) = 285` (= x⁸+x⁴+x³+x²+1, paper Section 4.1 ✓)
- `a` (Magma/Simon-Berg) = element `2` in this representation

## Architecture

- Paper folder = orchestration only; no new math added to `packages/VBF`.
- VBFCatalog used for n=10 Gold functions and CCZ equivalence.
- `conway_polynomial(n)` used throughout for consistency with paper convention.

## File layout

```
helpers.jl          — odds, subfield_elements, normal_basis_deriv_matrix,
                      cyclic_shift_matrix, is_in_cat1, linear_perms_subfield,
                      orbit_partition, report helpers
theorem2.jl         — Section 3.4 Theorem 2: cyclic shift invariance of QAM
theorem3.jl         — Section 3.5 Theorem 3: rank of cyclic linear combination
lemma1.jl           — Section 3.2 Lemma 1: categories → orbit separation
algorithm1.jl       — Section 3.1 Algorithm 1: FINDLINEAR orbit partition
section5_1.jl       — Section 5.1: new APN function (Table 5), ODDS vs Table 11
section5_3.jl       — Section 5.3: (n,m)=(10,1) → 3 CCZ classes
report.jl           — paper_report()
Makefile
test/runtests.jl + test_*.jl
```

## Acceptance criteria

- `make test` passes under 3 minutes
- `make report` completes in under 60 seconds
- Each claim labelled: exact / out-of-scope
