# Calderini_202009 — Reproduction Review

**Paper:** M. Calderini, *On the EA-classes of known APN functions in small
dimensions*, Cryptography and Communications 12:821–840 (2020).

**Reproduction:** `papers/Calderini_202009/` — `section3.jl`, `section4.jl`,
`section5.jl`, `section6.jl`, `helpers.jl`, `report.jl`, `tests/`.

**Verdict:** **Mostly complete.** All core mathematics reproduces (in several
places more strongly than expected — Table 1's full EA-class counts reproduce
exactly via core `ea_class_orbits`). One failing test caused by a stale catalog
cross-reference (plumbing, not math) and one honestly-documented paper error.

---

## Issue Catalog

### Paper Issues

Defects in the original paper. Not ours to fix — recorded for transparency.

1. **Remark 5, x⁵⁷ (n=7).** The paper states x⁵⁷ is "cyclotomically equivalent
   (and thus affine equivalent) to its inverse," yielding a single EA-class.
   This is **false**: 57⁻¹ mod 127 = 78 ∉ coset(57) = {57, 114, 101, 75, 23, 46,
   92}, and a complete affine-equivalence decision confirms x⁵⁷ ≁AE x⁷⁸ (control
   x⁶³ AE x¹²⁵ passes, so the AE routine is sound). The stated justification
   fails; the exact 1-vs-2 EA-class count stays undecided at the invariant level
   (equal WE(C₂)) and is MAGMA-only. Table 2's "≤ 2" bound is unaffected.
   Verified by `section6.jl` (`remark5_verify`).

### Reproduction Issues

Errors/inconsistencies in our implementation. Each carries a fix plan.

1. **Stale catalog cross-reference — one failing test.**
   - **Location:** `tests/test_section5.jl:92`; helper `section5.jl:97`
     (`load_n6_ccz_reps`); also the `print_check` at `section5.jl:306`.
   - **Symptom:** `@test length(creps) == 14` evaluates `13 == 14`;
     `section5` reports 66 pass / 1 fail, and the full suite aborts before
     reaching `section6`.
   - **Root cause:** `load_n6_ccz_reps` filters `family = "APN-rep"`, but the
     Kim/Dillon CCZ-class representative — historically `reprs6_4` — was
     deduplicated during `packages/VBFCatalog/data-build/import_apn_reps.jl` and
     now lives as catalog entry `n6_Kim` (id 593, family `APN`). The `APN-rep`
     family therefore returns only 13 of the 14 classes.
   - **Impact:** cosmetic/plumbing only. The reproduction builds all 14 Table 1
     representatives directly from the paper's own polynomials; the catalog is
     only a cross-check, so no math result is affected.
   - **Resolution plan:**
     1. In `load_n6_ccz_reps` (`section5.jl:97`), after fetching the 13
        `family="APN-rep"` entries, also fetch the Kim class (query `n6_Kim` by
        id/name, or by exact LUT match) and append it — OR broaden the filter to
        select all n=6 CCZ-inequivalent APN reps regardless of `family` tag,
        de-duplicating up to CCZ-equivalence to land on 14.
     2. Re-run `julia --project=. papers/Calderini_202009/tests/runtests.jl`;
        confirm `section5` passes 67/67 and the suite reaches `section6`.
     3. Adjust the `print_check` wording at `section5.jl:306` if it still says
        "APN-rep".

2. **Documentation note (not a data gap).** `reprs6_4` is absent from the
   `APN-rep` family because it merged into the pre-existing `n6_Kim` entry during
   import. All 14 known n=6 CCZ-inequivalent APN classes remain present in the
   catalog. Worth a one-line note in `import_apn_reps.jl`. No catalog-gap record
   is warranted (the paper claims no new APN functions).

### Correctly-scoped bounds (not errors)

- **Table 1 row 14** (Edel–Pott, non-quadratic): only the Corollary-1 upper
  bound (25, = paper's exact count) is computed; exact equality needs MAGMA code
  equivalence (orbit method requires a quadratic member, which this class lacks).
- **Tables 2/3/4 upper-bound columns** (n=7,8,9) and direct code-equivalence
  tests: MAGMA-only; AB Walsh-zero subspace enumeration measured > 30 min per
  function. Documented in `section6.jl` / `report.jl`.

---

## Items reproduced exactly (context)

Observation 1 (eq. 3); Procedure 2 (k=1, conditions P1–P3); Proposition 1;
Corollary 1 (n=4,5); C₁–C₄ dimension formulas; Theorem 5 (weight enumerators);
Theorem 6 (WE level + complete AE decisions); **Table 1 rows 1–13 EA-class counts
and per-class degree multisets — exact** (3, 3, 19, 13, 13, 91, 19, 85, 91, 91,
86, 92, 85); Section 5.1 (13 EA-classes, 2 with a permutation, 4 affine
permutation classes {F₁, F₁⁻¹, F₂, F₃}, Remark 4, component degrees {3⁷, 4⁵⁶},
per-component Walsh-spectrum multiset); Theorem 7 (n=5..9); Theorem 8 (n=5);
Remarks 5–7.

## Test results (as run)

| Section  | Result            |
|----------|-------------------|
| section3 | 37/37 pass        |
| section4 | 13/13 pass        |
| section5 | 66 pass / 1 fail  (Reproduction Issue 1) |
| section6 | 29/29 pass (run standalone) |

`table1_check`: all 13 quadratic rows match counts + degrees; row 14 bound = 25.

## Catalog status

The paper claims **no new APN functions** — it classifies *known* functions up to
EA-equivalence. No new-APN verification / novelty / catalog-gap records apply. All
14 known n=6 CCZ classes are present (13 as `reprs6_*` family `APN-rep`, plus the
Kim class as `n6_Kim` family `APN`).

## Library-reuse note

No helper duplicates a VBF core export. **Promote-to-core candidate:**
`cyclotomic_coset` (`helpers.jl:112`) — a generic finite-field primitive (orbit of
d under ×2 mod 2ⁿ−1) recurring across reproductions (Kalgin, Bracken, Zheng, and
here), currently absent from `packages/VBF/src/`. Not a reuse violation; a
consolidation opportunity.
