# Calderini_202009 — Reproduction Review

## Scoped feasibility review (2026-10-10)

**F051: Partial.** The local PDF recovers the polynomial material lost from LaTeX Table 3 rows 13 and 14. Sourced row reconstruction and bounded per-row evidence are feasible. Trace-row probes hit their node budgets without an upper bound, so full table counts and EA classification need completed pilot runs before a runtime commitment. Existing function-equivalence APIs can be reused.

The bounded commands and remaining requirements are documented here.
This current assessment supersedes conflicting historical scope descriptions below.

Scope correction: the Frobenius/inverse power-exponent orbit census is not a full CCZ classification, and an inverse outside the cyclotomic coset does not itself prove EA inequivalence. Predicted counts are now labeled as predictions; the census returns exact_class_count_established=false.

Additional F032 correction: graph-code coordinate blocks now match the documented definition. Kim and Dillon have equal C2 weight enumerators; the previous claimed weight-based separation was caused by the coordinate bug. Their degrees 2 and 4 still prove EA inequivalence. Equality of code weight enumerators is an inconclusive filter.

Current audit application (2026-10-10): F051: `make table_bounds` now runs native, bounded Walsh-zero subspace enumeration for the specified power rows of Tables 2–4. Only exhausted searches yield an upper bound; found subspaces do not themselves count EA classes. The full polynomial-row tables and general code-equivalence classification remain unreproduced.


**Paper:** M. Calderini, *On the EA-classes of known APN functions in small
dimensions*, Cryptogr. Commun. (2020).

**Reproduction:** `packages/VBFRepro/src/202009-calderini-equivalence-classes/` — `helpers.jl`, `section3.jl`,
`section4.jl`, `section5.jl`, `section6.jl`, `report.jl`.

**Verdict:** **Mostly complete.** Section 5 — the paper's headline — reproduces
exactly and impressively (all 13 Table 1 EA-counts and per-class degree
multisets, the full 5.1 analysis, and F₁/F₂/F₃ term-by-term).

*Update (fix pass):* R1, R3, R4, R6, R8, R9 are resolved — Procedure 2 now runs
for every k, Propositions 2 and 3 are implemented and the paper's own pipeline
(Procedure 2 → Prop-3 code filter → EA-classes) reproduces the EA-class counts
independently of `ea_class_orbits`; Theorem 8 is extended to a full census of
the APN power classes for n=5..9. **Still open:** Theorem 6 is assumed rather
than verified at the code level (R5; the bounded VBF binary-code API
exists, but the paper comparisons remain unexecuted) and Tables 2/3/4 (~47 rows) are not computed (R7, blocked on
`extract_linear_subspaces` performance). Both need a decision — see Open
Questions.

---

## Issue Catalog

### Paper Issues

**P1. Remark 5's x⁵⁷ (n=7) claim is false.** *(already flagged by the repro;
independently confirmed)*

The paper claims x⁵⁷ over F₂⁷ is "cyclotomic equivalent (and thus affine
equivalent) to its inverse". But `57 · 78 = 4446 = 35·127 + 1`, so
`57⁻¹ = 78 mod 127`, while `coset(57) = {57,114,101,75,23,46,92}` — which does
**not** contain 78. The reproduction's complete AE decision confirms
`x⁵⁷ ≁AE x⁷⁸` (with `x⁶³ AE x¹²⁵` passing as a control). The paper's
justification fails, and by its own x¹³ argument the count should be **2, not
1**.

**P2. Table 1 row 2 uses an undefined symbol.** The row reads
`x³ + ζ¹¹x⁶ + u·x⁹` with `u` never defined. The reproduction reads `u = ζ`,
which matches Edel–Pott's table and yields the paper's EA count of 3. Benign, but
it is an ambiguity in the source.

**P3. OCR/typesetting artifact in Section 5.1.** The tex's Walsh multiset shows
`16^^44`, which must be `16^^4` (the spectra have to sum to 64). Correctly
resolved at `section5.jl:167`.

### Reproduction Issues

**R1. [RESOLVED] Live `[FAIL]` in the repro's own report.**

- **Location:** `packages/VBFRepro/src/202009-calderini-equivalence-classes/section5.jl:306`
- **Symptom:** The check asserts `length(reps_meta) == 14`, but the
  `family="APN-rep"` filter returns **13**, so `section5_report()` prints
  `[FAIL] Catalog lists 14 CCZ-class representatives`.
- **Root cause:** Commit `8022d09` updated the *test* (`tests/test_section5.jl:96`
  → `== 13`) but not the *report check*. The 14th class (Kim) is catalogued as
  `n6_Kim`, outside the `APN-rep` family filter.
- **Fix:** new `n6_ccz_class_census` (`section5.jl`) asserts 13 `APN-rep` rows
  **plus** `n6_Kim` (found via `find_function`) = 14 CCZ classes, and prints both.
  `section5_report()` is now `[FAIL]`-free; covered by a test.

**R2. [RESOLVED] The previous README was stale and factually wrong.**

- **Location:** `packages/VBFRepro/src/202009-calderini-equivalence-classes/README.md` (this file supersedes it)
- **Symptom:** It claimed `tests/test_section5.jl:92` fails with
  `@test length(creps) == 14`, that section5 reports "66 pass / 1 fail", and that
  "the full suite aborts before reaching section6". All three are false — the
  suite is **146/146 PASS**.
- **Root cause:** The README (`013e845`) was committed *after* the fix that made
  those statements obsolete, and was never revisited.
- **Resolution plan:** Superseded by this file. Keep in sync on re-review.

**R3. [RESOLVED] Propositions 2 and 3 are absent — and Proposition 3 is the
paper's own Section-5 filter.**

- **Location:** `packages/VBFRepro/src/202009-calderini-equivalence-classes/section3.jl` (neither is implemented;
  `grep` over all `.jl` finds only Proposition 1)
- **Symptom:** The paper states, in the Section 5 opening, *"comparing the codes
  relative to L₁(x,F(x)) we used Proposition 3 for filtering"*. That filter does
  not exist in the reproduction.
- **Root cause:** Not written; also silently omitted from the previous README's
  "missing" list, so it read as complete.
- **Fix:** implemented in `section3.jl` — `permutation_code` (the code 𝒞_{F₁}
  generated by `(F₁(x))_x`, canonicalised by RREF), `left_linear_factor` (the
  unique `L` with `F₁' = L∘F₁`), and `propositions_2_3_check`, which verifies
  **both** hypotheses of Prop 2 (no *univariate* linear monomial — note x³'s
  multivariate ANF *does* carry degree-1 terms; and Span(Im(A₂∘F)) = Im(A₂)),
  the hypothesis of Prop 3 (𝒩ℒ(F) ≠ 0, Remark 3), the proof step
  (equal codes ⟹ L₁' = L∘L₁) and the conclusion (EA-equivalent graph functions),
  over every admissible L₁ of Gold x³ n=4. Not superseded by `ea_class_orbits` —
  see R4.

**R4. [RESOLVED] Procedure 2 only handles k=1, so the paper's method is not
reproduced.**

- **Location:** `packages/VBFRepro/src/202009-calderini-equivalence-classes/section3.jl:67`
  (`procedure2_admissible_pair`)
- **Symptom:** It handles only `k = dim(U) = 1` and returns the *first* pair
  found. Conditions (P1)–(P3) are exercised only degenerately.
- **Root cause:** Table 1 is actually obtained by a **different algorithm** — core
  `ea_class_orbits` (orbits of Walsh-zero subspaces under graph automorphisms
  lifted from the ortho-derivative). The *results* reproduce; the *method* does
  not.
- **Fix:** `procedure2_pairs(F)` implements Procedure 2 for **every** k, in the
  Observation-3/4 normal form: subspaces U ⊆ S_F of each dimension k, (P1)
  k-tuples aᵢ ∈ ZW(uᵢ), (P2)/(P3) via Remark 2's intersection (vacuous at k = n,
  which is where the A₁ = 0 / A₂ = id map F₁ = F lives). Every returned L₁ is
  checked to give a permutation (Observation 1). `procedure2_ea_classes` then
  runs the paper's *own* pipeline end to end — Procedure 2 (all k) →
  Proposition-3 code filter → EA-classes of the graph functions — and it
  reproduces the results independently of `ea_class_orbits`:

  | F | #admissible L₁ | #codes (Prop-3) | #EA-classes | cross-check |
  |---|---|---|---|---|
  | Gold x³, n=4 | 121 | **16** | **2** | = Corollary-1 bound 16; `ea_class_orbits` → 2 |
  | Gold x³, n=5 | 529 | **64** | **3** | = Corollary-1 bound 64; `ea_class_orbits` → 3 |
  | x¹⁵, n=5 | 2 | **2** | **1** | = Corollary-1 bound 2; Theorem 7/8 → 1 (involution) |

  The Prop-3 filter lands exactly on the simplex subcodes, so #codes *is* the
  Corollary-1 bound — the paper's two ingredients meet. The x¹⁵ row also shows
  where `ea_class_orbits` cannot be used (it needs a quadratic member): 2 codes,
  1 EA-class. Kim/n=6 is left to the orbit method (the L₁ enumeration there is
  far larger); the two methods agree wherever both apply.

**R5. Theorem 6 — the paper's new theorem — is assumed, not verified.**

- **Location:** `packages/VBFRepro/src/202009-calderini-equivalence-classes/section4.jl:109`
- **Symptom:** The new C₄ code is built with correct dimensions, but the
  theorem's content (`C₄(F) ≅ C₄(G+b) ⟺ F AE G`) is never decided at the code
  level. `section4.jl:109` shows C₄(F₁) and C₄(F₁⁻¹+b) are WE-isospectral **for
  every b**, so the separation is *inferred from the theorem* rather than
  established by it.
- **Current capability:** `VBF.binary_code_equivalence` now accepts arbitrary
  binary generator matrices and verifies permutation witnesses. The paper
  comparisons have not yet been executed with this API.
- **Remaining work:** integrate the existing bounded code-equivalence API.
  Preserve inconclusive outcomes whenever a comparison hits its budget.
  **Needs a decision — see Open Questions.**

**R6. [RESOLVED] `sf_set` deviates from the paper's eq. (4).**

- **Location:** `packages/VBFRepro/src/202009-calderini-equivalence-classes/helpers.jl:47`
- **Symptom:** It scans `a = 1:(2ⁿ-1)`, excluding `a = 0`, whereas
  `ZW(λ) = {a ∈ F₂ⁿ : W_{F_λ}(a) = 0}` includes 0.
- **Root cause:** Off-by-one in the definition, not the math. Tested on 8
  functions (Gold n=4/5/6, Kasami n=5, Kim, Dillon, x⁻¹ n=6, row 14) — `S_F` is
  identical in every case, so it is **benign today**, but it is a definitional
  mismatch that could bite on a function where `W(0) = 0`.
- **Fix:** the scan is now `a = 0:(2ⁿ-1)`. Re-checked: `S_F` is byte-identical
  on all 8 functions (sizes 6/32/22/32/22/64/64/36). `zw_set` already included
  `a = 0` — which matters: for a *permutation* F every non-zero component is
  balanced, so `0 ∈ ZW(u)`, and that is precisely what makes the k = n branch of
  Procedure 2 (A₁ = 0, A₂ = id, F₁ = F) reachable in R4's enumeration.

**R7. Tables 2, 3 and 4 are not computed** (~47 rows, the "# EA-classes ≤"
columns for n=7/8/9).

- **Location:** `packages/VBFRepro/src/202009-calderini-equivalence-classes/` (no file)
- **Root cause:** The bottleneck is `extract_linear_subspaces`. Measured during
  review: Table 2 row 1 (`extract_linear_subspaces(walsh_zeroes(power_sbox(7,3)),
  7; max_bits=14)`, paper value 256) was killed by a **700 s timeout** — which
  empirically supports the repro's ">30 min per function" scoping note.
- **Resolution plan:** Either accept a permanent "MAGMA-only" scope note in this
  README, or optimise `extract_linear_subspaces`. **Needs a decision — see Open
  Questions.**

**R8. [RESOLVED] Theorem 8 is verified only at n=5**, and only the distinctness
half. The coset arithmetic gives EA-class distinctness, not the "at most two"
half (which needs the simplex-code count = 2). Remark 6's "x⁵⁷ (n=8) has exactly
one simplex code" sits behind an opt-in flag that is off by default and never
run.

- **Location:** `packages/VBFRepro/src/202009-calderini-equivalence-classes/section6.jl`
- **Fix:** `theorem8_census(n)` now covers **n = 5..9 over every APN power CCZ
  class**, not just hand-picked ones: `apn_power_ccz_classes(n)` enumerates the
  cyclotomic classes of APN exponents, pairs each with its inverse class
  (x^d ≃CCZ x^{d⁻¹}), tags the classes containing a Gold function
  (`is_gold_exponent`) and derives the EA-class count of the rest. This
  reproduces Remarks 5–7 and the non-Gold rows of Tables 2/3/4 **exactly**:

  | n | non-Gold classes (coset minima) | computed # EA-classes | paper |
  |---|---|---|---|
  | 5 | x¹⁵ | 1 | 1 |
  | 6 | *(none — Gold x³ is the only APN power class)* | — | — |
  | 7 | x¹¹ (=x¹³'s inverse class), x²³ (=x⁵⁷), x⁶³ | 2, **2**, 1 | 2, **1** (P1), 1 |
  | 8 | x³⁹ (=x⁵⁷, not a permutation) | 1 | 1 |
  | 9 | x¹³, x¹⁹, x⁴⁷ (=x²⁴¹), x²⁵⁵ | 2, 2, 2, 1 | 2, 2, 2, 1 |

  The census re-derives **P1** independently (x⁵⁷ at n=7 ⟹ 2, not 1). Two
  clarifications it forced:
  - *"non-Gold" means the CCZ class contains no Gold function* — not merely that
    d is not a Gold exponent. x^d and x^{d⁻¹} are CCZ-equivalent, so e.g. n=5's
    Kasami exponent 13 ∈ coset(11) has 11⁻¹ = 17 ∈ coset(3): its class **is**
    Gold's. `theorem8_gold_inverse_check` decides this exactly at n=5 with
    `are_ccz_equivalent` (x¹¹ ≃CCZ Gold x³; x¹⁵ ≁CCZ Gold x³).
  - consequently the catalog name `n5_Kasami_x15` is a **misnomer**: at n=5 the
    unique non-Gold APN power class is x¹⁵ ≃linear x⁻¹ (15·2 = 30 = 2⁵−2), i.e.
    the *inverse* class, so Theorem 8's n=5 instance coincides with Theorem 7's.
    (Catalog-side; not changed here.)
- **Still scoped out (unchanged):** the "at most two" (simplex-count) half is
  exact only for n=5 and the x⁻¹-linked classes (Theorem 7). The AB classes
  (x¹³, x⁵⁷ at n=7; x¹³, x¹⁹, x²⁴¹ at n=9) and x⁵⁷ at n=8 have |Z| ≈ 2¹³–2¹⁴ and
  were measured at > 30 min each — MAGMA-only. Remark 6's x⁵⁷ (n=8) flag stays
  opt-in, but the *Theorem-8 half* of it is now checked without it: x⁵⁷ is not a
  permutation over GF(2⁸) ⟹ no F⁻¹ ⟹ 1 EA-class = the paper's Table 3 value.

**R9. [RESOLVED] Missing Table-1 row-14 ↔ `reprs6_13` catalog cross-check.**

- **Location:** `packages/VBFRepro/src/202009-calderini-equivalence-classes/section5.jl`
- **Symptom:** Row 14 (the Edel–Pott cubic) is present in the catalog as
  `reprs6_13`, but the reproduction never asserts the correspondence — and it
  cannot do so with `are_ccz_equivalent`, which false-negatives here (see C1).
- **Fix:** `row14_catalog_crosscheck` (`section5.jl`) decides the pair on CCZ
  invariants only — Γ-rank 1300, Δ-rank 152, extended Walsh spectrum
  `[0=>1071, 8=>2688, 16=>336]`, DDT spectrum `[0=>2016, 2=>2016]`, and 25
  Walsh-zero 6-dim subspaces — all identical, plus degree 3 / APN. It
  deliberately does **not** call `are_ccz_equivalent` (C1), and says so in the
  docstring and the report. Covered by tests.

---

## Core-library and catalog issues surfaced by this review

*(Not paper-local. These belong in `packages/`, and should be fixed as their own
commits — not by the paper fixer.)*

**C1. `are_ccz_equivalent` returns a best-effort `false` when it is actually
inconclusive.** **← highest-severity finding in this review**

- **Location:** `packages/VBF/src/equivalence/ea/api.jl:183`
- **Symptom:** `are_ccz_equivalent(table1_row14(), reprs6_13)` returns **`false`**
  while warning *"inconclusive — returning best-effort `false`"* — even though
  every strong CCZ invariant matches (Γ-rank 1300, Δ-rank 152, Walsh spectrum,
  DDT spectrum, #Walsh-zero 6-subspaces = 25), and dimension 6 has only **one**
  known non-quadratic APN CCZ class.
- **Why it matters:** "Don't know" reported as "not equivalent" is a
  false-negative that manufactures **fake novelty**. This is precisely the failure
  mode that forced commit `8022d09` ("drop false-novel APN additions") — four of
  six "new" functions turned out to be already-known classes.
- **Resolution plan:** Return `missing` (or throw) when inconclusive; never
  collapse uncertainty to `false`. Audit callers — especially any novelty path —
  for reliance on the current behaviour.

**C2. `n6_Kasami_x48` duplicates `n6_Gold_x3` in the catalog.**

- **Location:** `packages/VBFCatalog/data/apn/n6_apn.toml`
- **Symptom:** `x⁴⁸` is *linearly* equivalent to `x³` at n=6: `48 = 3·2⁴ mod 63`
  lies in the cyclotomic coset of 3 (`{3,6,12,24,48,33}`), and their OD mugshots
  coincide. The paper's Table 1 correctly lists a **single** Gold class for n=6.
- **Resolution plan:** This is a duplicate CCZ class, not a gap. Decide whether to
  drop it or keep it with an explicit "linearly equivalent to `n6_Gold_x3`" note.

---

## Items reproduced exactly (context)

| Paper item | Evidence |
|---|---|
| Observation 1 / eq. (3) | verified as a two-way equivalence (`section3.jl:47,125`) |
| Procedure 2, **all k** | `procedure2_pairs` — (P1)/(P2)/(P3), Observation-3/4 normal form; every L₁ gives a permutation (R4) |
| Propositions 2 and 3 | `propositions_2_3_check` — hypotheses + proof step (L₁' = L∘L₁) + conclusion (R3) |
| The paper's pipeline | `procedure2_ea_classes` — Gold n=4: 121 L₁ → 16 codes → 2 EA; Gold n=5: 529 → 64 → 3; x¹⁵ n=5: 2 → 2 → 1 (R4) |
| Theorem 8 (n=5..9) | `theorem8_census` — every APN power CCZ class; matches Remarks 5–7 / Tables 2–4 (R8) |
| Proposition 1 | real graph transforms (`section3.jl:192`) |
| Corollary 1 | Gold n=4 → 16, Gold n=5 → 64, Kasami n=5 → 2 |
| C₁–C₄ dimension formulas | n=6: (13,64), (13,127), (13,190), (13,191) |
| **Table 1, rows 1–13** | EA counts 3,3,19,13,13,91,19,85,91,91,86,92,85 + per-class degree multisets — **all match** |
| **Section 5.1** | 13 EA-classes, 2 with a permutation, 4 affine perm classes {F₁,F₁⁻¹,F₂,F₃}; Remark 4; degrees {3⁷,4⁵⁶}; per-component Walsh multiset |
| F₁, F₂, F₃ polynomials | all 50/53/55 terms checked against the tex; all APN permutations of degree 4 |
| **Theorem 7 (5≤n≤9)** | x⁻¹ has exactly 2 Walsh-zero n-subspaces and is an involution, n=5..9 |
| Remark 5 (x¹³, x⁶³) | `section6.jl:128` |

## Test results (as run)

All Julia run through a 2 GiB-capped cgroup wrapper. **No step hit the cap — no
exit 137 anywhere.**

| Command | Result |
|---|---|
| `tests/runtests.jl` (before the fix pass) | **146/146 PASS** (37+13+67+29), exit 0 |
| `tests/runtests.jl` (after) | **188/188 PASS** (57+13+76+42), exit 0 |
| `section3_report()`, `section4_report()`, `section5_report()` | all PASS, **no `[FAIL]`** |
| `section6_report()` (Theorem 8 census, Remarks 5–7) | all PASS |

The R1 `[FAIL]` is gone. Skipped for **time, not memory**: Table 2 row 1's
Corollary-1 bound — `extract_linear_subspaces(...)` killed by a 700 s timeout
(exit 143). See R7.

## Catalog status

**The paper claims no new APN functions** — it classifies *known* APN functions
up to EA-equivalence. **No catalog-gap records.**

A completeness cross-check of all 14 Table-1 CCZ classes was run anyway: rows
1–13 are present (`reprs6_0`…`reprs6_12`, plus `n6_Kim` for row 5, byte-identical
LUT to the paper's polynomial), and row 14 is present as `reprs6_13` (matched on
invariants — see R9/C1). See **C2** for the `n6_Kasami_x48` redundancy.

## Library-reuse note

**No helper duplicates a VBF core export** (checked against the full `export`
list). `zw_set`/`sf_set` are Procedure-2 sets (paper-specific);
`sbox_from_zeta_terms`/`power_sbox` are thin, documented wrappers over core
`terms_to_lut` / `gf_monomial_lut` + `conway_polynomial`. This reproduction has
already had `ea_matrix`, `ae_matrix`, `ae_perm_matrix`, `code_weight_enumerator`,
`ea_class_orbits`, and `component_degree_spectrum` promoted into core — good
hygiene.

**Promote-to-core candidates:**
- `cyclotomic_coset(d, m)` (`helpers.jl:112`) — generic finite-field primitive
  (orbit of `d` under ×2 mod m), absent from core, and it recurs in the Kalgin,
  Bracken and Zheng reproductions.
- `component_walsh_spectra(F)` (`helpers.jl:89`) — generic EA-invariant, sibling
  of the already-core `component_degree_spectrum`.

## Open questions (need a decision before fixing)

1. ~~**Are Propositions 2 and 3 intentionally superseded by `ea_class_orbits`?**~~
   **Answered by the fix pass:** no — both are implemented, and the paper's
   pipeline is reproduced end to end and cross-validated against
   `ea_class_orbits` (R3, R4). The two methods agree wherever both apply.
2. **Is the Theorem 6 status acceptable?** The paper's headline new theorem is
   used but never verified. The VBF code-equivalence API exists; integration and
   completed comparisons (R5) remain open.
3. **Are Tables 2/3/4 a permanent "MAGMA-only" scope decision**, or should
   `extract_linear_subspaces` be optimised (R7)? — **still open.** Note the
   *non-Gold power rows* of Tables 2/3/4 are now derived exactly by
   `theorem8_census` (R8); what is missing is the ≤-bound column for the
   quadratic/AB entries, which needs the subspace enumeration.
4. **Should the x⁵⁷ paper error (P1) be escalated as an errata note?** For APN
   power functions, EA-equivalence implies cyclotomic equivalence, which would
   settle the count at 2 definitively. The Theorem-8 census now re-derives the
   contradiction independently (R8).
5. **`n5_Kasami_x15` is a catalog misnomer** (surfaced by R8): at n=5 the Kasami
   exponent is 13 ∈ coset(11), whose CCZ class *is* Gold's; x¹⁵ is the inverse
   class. Catalog-side rename/annotation — out of scope for the paper fixer, and
   related to C2.
