# Taniguchi_202501

Taniguchi, Polujan, Pott, Arshad (2025), *"Changing almost perfect nonlinear
functions on affine subspaces of small codimensions"* (arXiv:2501.03922).

Reproduction path: `papers/2025/Taniguchi_202501/`

**Verdict: Partial.** Sections 3–4 (Theorem 3.2, Example 3.3, Table 3.1,
Theorem 3.7, Example 4.2) are correctly reproduced and independently
re-verified. Section 2 (Theorem 2.10, Proposition 2.11 — the paper's own
headline contribution per its abstract) has no code at all. Several smaller
verification gaps remain inside Section 3–4 coverage (Table 3.1 `D_k` column,
Theorem 3.5 completeness half, Remark 3.6.2).

---

## Issue Catalog

### Paper Issues

None found. No mathematical error was found in any paper item that the
reproduction implements. (The `.tex` source has OCR-garbled exponents in
several Table 3.1 rows — see Reproduction Issue 5 — but that is a source
transcription artifact, not a flaw in the published mathematics.)

### Reproduction Issues

1. **Section 2 entirely unreproduced (Theorem 2.10, Proposition 2.11, Proposition 2.4, Proposition 2.8, Example 2.7)**
   - **Location:** no file under `papers/2025/Taniguchi_202501/`; scope block at `helpers.jl:19-24` silently omits Section 2.
   - **Symptom:** no test, no script — the paper's stated headline contribution ("Our contribution" in Section 1 foregrounds Theorem 2.10 and Proposition 2.11) has zero code coverage. Proposition 2.11 is the direct antecedent Theorem 3.2 specializes.
   - **Root cause:** reproduction scope was set to Sections 3–4 only, without recording that exclusion explicitly.
   - **Resolution plan:**
     1. Decide whether Section 2 is in scope for this reproduction.
     2. If yes: add `theorem2_10.jl` implementing Theorem 2.10 conditions (1)/(2) and Proposition 2.11 Eq. (2.1) for small `n`, `m`, with tests.
     3. If no: update the scope comment in `helpers.jl:19-24` to state explicitly "Section 2 (Theorem 2.10, Prop 2.11) intentionally out of scope" instead of silent omission.

2. **Remark 3.6.2 (non-classical Walsh spectrum of `G₇`) unchecked**
   - **Location:** `table3_1.jl` (no corresponding check); paper `.tex` L289.
   - **Symptom:** no test asserts `G₇`'s Walsh spectrum differs from the other 12. Independently verified true: `G₇ → [-32,-16,-8,0,8,16,32]`, all other 12 → `[-16,-8,0,8,16]`.
   - **Root cause:** remark was not translated into a code check when Table 3.1 was implemented.
   - **Resolution plan:** add a ~5-line check in `table3_1.jl` (or new `remark3_6.jl`) using `lat` asserting `G₇`'s spectrum is exactly `{0,±8,±16,±32}` and the other 12 are exactly `{0,±8,±16}`.

3. **Theorem 4.1 not generalized; "only if" direction never exercised**
   - **Location:** `example4_2.jl:51-108`.
   - **Symptom:** only the single Example 4.2 instance is hard-coded; there is no reusable predicate over arbitrary `F`, `U`, `a₁..a₄`, so the negative ("only if") direction of Theorem 4.1 is untested. Independently verified true: for `a₁+a₂+a₃+a₄ ∉ A`, `du(G) = 4`; for `∈ A`, `du(G) = 2`.
   - **Root cause:** implementation was written directly against the one example instead of the general criterion.
   - **Resolution plan:** factor out `theorem4_1_condition(F, U, a1, a2, a3, a4)` and add both directions as tests, including the negative case.

4. **Missing cross-validation tests for Theorem 3.2 and Eq. (3.1) against ground truth**
   - **Location:** `test/test_theorem3_2.jl`, `test/test_theorem3_7.jl`.
   - **Symptom:** only a single `L = x` negative case exists in `test_theorem3_7.jl`; no test sweeps random `L` and cross-checks the criterion against `differential_uniformity`.
   - **Root cause:** tests cover the paper's stated example values but not general-criterion soundness.
   - **Resolution plan:** add randomized tests: Theorem 3.2 criterion ⟺ `differential_uniformity(F) == 2` over random `L` at n=4,5; Eq. (3.1) ⟺ APN over random `L` at n=4,5,6 (both independently confirmed true during review).

5. **Undocumented OCR repair of Table 3.1 exponents**
   - **Location:** `helpers.jl:121-135` (`TABLE_3_1_RAW`).
   - **Symptom:** the `.tex` source has garbled exponents in several rows (e.g. `L₂`, `L₄`, `L₁₀`, `L₁₁` show malformed `x²` terms instead of `x^{2^2}` etc.); `helpers.jl` silently reconstructs the correct exponents with no comment. A reader diffing against the `.tex` cannot distinguish repair from transcription error.
   - **Root cause:** reconstruction was done correctly (verified: all 13 come out APN, quadratic, pairwise EA-inequivalent, and satisfy Eq. 3.1) but undocumented.
   - **Resolution plan:** add a comment at `helpers.jl:121-135` noting which rows were OCR-garbled in the source `.tex` and how the exponents were reconstructed.

6. **Dead code: `linearized_poly_lut` duplicates core, never called**
   - **Location:** `helpers.jl:57-64`.
   - **Symptom:** function defined, never referenced anywhere in the paper directory.
   - **Root cause:** superseded by direct LUT construction elsewhere; not cleaned up. Equivalent to `terms_to_lut` in `packages/VBF/src/representations/univariate.jl:331`.
   - **Resolution plan:** delete `linearized_poly_lut`, or replace its one conceptual use with `terms_to_lut` if needed later.

7. **Stale `VBF API used` header comments**
   - **Location:** `theorem3_2.jl:12`, `helpers.jl:6-7`.
   - **Symptom:** `theorem3_2.jl:12` lists `gold_apn, SBox, differential_uniformity`, none of which appear in that file; it actually uses `gf_inv`, which is unlisted. `helpers.jl:6-7` lists `gf_relative_trace`, unused in that file.
   - **Root cause:** headers not updated as implementation evolved.
   - **Resolution plan:** regenerate both header comments to match actual imports/usage.

8. **`theorem3_2_report` returns misleading result shape for n ≥ 6**
   - **Location:** `theorem3_2.jl:87-90, 108-110`.
   - **Symptom:** for n ≥ 6 (infeasible exhaustive search, ~40000 expected but never attempted), returns `(count=-1, expected=40000, match=false)` — same shape as a genuine failed check.
   - **Root cause:** no distinct "skipped/infeasible" status defined.
   - **Resolution plan:** add a distinct status (e.g. `:skipped`) instead of reusing the failure shape; update `report.jl:29` to explain the `n ≤ 7` `_design_rank_guard` limit (`packages/VBF/src/invariants/design_ranks.jl:75-81`) rather than "out-of-scope (Magma)".

9. **Table 3.1 `D_k` (Dillon numbering) column unverified**
   - **Location:** `helpers.jl:121-135` (carried as string label only).
   - **Symptom:** the `G_i ↦ D_k` correspondence from `[21, Table 4]` is stored but never checked against anything; Dillon's dimension-6 representatives are not present in `packages/VBFCatalog/data-raw/apn_catalog/n6_apn.toml` (only 3 of 13 entries exist there).
   - **Root cause:** catalog does not yet hold Dillon's 13 dimension-6 quadratic-APN classes to check against.
   - **Resolution plan:** either (a) add Dillon's 13 representatives to `n6_apn.toml` first, then verify `G_i ↦ D_k` by `apn_ea_mugshot`, or (b) relabel the column as explicitly unverified pending that data. Decision needed — see catalog gaps below.

10. **Theorem 3.5 completeness half unasserted**
    - **Location:** `table3_1.jl:62-65`.
    - **Symptom:** only "13 pairwise EA-inequivalent" is checked (via distinct mugshots); the paper's stronger claim — every quadratic APN on F₂⁶ has this form, i.e. these are *all* dimension-6 quadratic-APN EA classes — is never asserted or cited.
    - **Root cause:** completeness was assumed rather than stated/checked in-repo.
    - **Resolution plan:** add an explicit comment/assertion citing that dimension 6 has exactly 13 quadratic-APN EA classes, so "13 distinct" ⇒ "all of them" is made explicit rather than implicit.

---

## Items reproduced exactly

- **Theorem 3.2** (H-equivalence characterization) — `theorem3_2.jl:21-35`; cross-validated against `differential_uniformity` on 4000 random `L` at n=4,5, exact agreement.
- **Example 3.3** counts — n=4: 448, n=5: 4608, exact match.
- **Table 3.1** — all 13 `G_i` APN, quadratic; field/modulus 91 confirmed.
- **Theorem 3.7 / Eq. (3.1)** — all 13 entries satisfy the doubled criterion; cross-validated against `differential_uniformity` at n=4,5,6.
- **Remark 3.8** — Table 3.1 polynomials satisfy Theorem 3.7, confirmed.
- **Example 4.2** (n=8) — `A`, cosets, simplified form, APN status all match exactly.

## Test results

- `julia --project=. papers/2025/Taniguchi_202501/test/runtests.jl` — all pass: `theorem3_2_test` 3/3, `table3_1_test` 28/28, `theorem3_7_test` 14/14, `example4_2_test` 5/5.
- `make report`, `make theorem3_2 n=4`, `make theorem3_2 n=5` — all pass, match paper values (448, 4608; n=5 timed 8.27s).

## Catalog status

- **Dimension 6 (Table 3.1, `G_1..G_13`):** `G₁`, `G₅` present in `n6_apn.toml` (Gold/Kasami, Kim). `G₂,G₃,G₄,G₆..G₁₃` (11 classes) missing from catalog — Dillon's classes, not new to literature, but catalog-worthy for completeness. **Blocked on open question:** `G_i ↦ D_k` correspondence unverified (see Reproduction Issue 9).
- **Dimension 8 (Example 4.2, `G`):** missing from `n8_apn.toml`. Catalog-gap record prepared (LUT, `du=2`, `algebraic_degree=2`, mugshot-distinct from all 4 existing n=8 entries). Caveat: dimension 8 has a large known quadratic-APN landscape — "absent from catalog" ≠ "new to literature"; paper only claims EA-inequivalence to `x³`. Γ-rank values (13842/11818) unverifiable in-repo (`_design_rank_guard` rejects n≥8).

## Library-reuse note

Good citizen overall — uses `gf_mul/pow/inv/trace`, `conway_polynomial`, `SBox`, `differential_uniformity`, `algebraic_degree`, `apn_ea_mugshot`, report emitters throughout. One dead duplicate (`linearized_poly_lut`, Issue 6). Two promote-to-core candidates identified: a generic polar/bilinear form `B_F(x,a) = F(x+a)+F(x)+F(a)+F(0)` (core currently has none, only paper-specific `bilinear_form_gold`), and a fast `(coeff, exponent)`-list point evaluator `evaluate_terms(terms, x, n; modulus)` (core only has string-based `evaluate_polynomial` and whole-LUT `terms_to_lut`, both unusable for the ~10⁹-call n=5 search in `theorem3_2.jl`).
