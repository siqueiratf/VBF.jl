# Brinkmann & Leander (2008) — On the classification of APN functions up to dimension five

- **Citation:** M. Brinkmann, G. Leander, "On the classification of APN functions up to
  dimension five", *Des. Codes Cryptogr.* 49(1–3):273–288, 2008.
- **Reproduction path:** `papers/2008/Brinkmann_200812/`
- **Paper source:** `input/Brinkmann e Leander - 2008 - On the classification of APN functions up to dimension five.tex`
- **Verdict:** **Partial** — the verified items are correct, but one headline conclusion is
  unsound, three result tables are absent despite being fully reconstructible, and the
  paper's entire algorithmic contribution (Sections 2, 3, 5, 6) is unimplemented.

---

## Issue Catalog

### Paper Issues

Flaws in the original publication / its OCR'd source. Not ours to fix.

1. **Table 1 header merges columns 0 and 1** (`# & 01 & 2 & 3 & …`), so every row is short
   by exactly one value. The missing value is `s(1) = 1` in all five rows: each row's 31
   present values omit exactly the element `1`, and re-inserting it at position 1 yields a
   permutation with the paper's stated algebraic degree. Reconstruction confirmed against
   the paper's own degree column (4, 3, 3, 2, 2).
2. **Table 3 header is doubly broken** — `01` merged, `11` split into `1 &` plus an empty
   cell — and each row carries a stray empty cell after position 10. The 32 numeric cells
   are nonetheless complete and correct (degrees 2, 2, 3, 3, 4, 3, 3 match the paper).
3. **Table 5 is split across two `tabular` environments** (a 33-value prefix and 31-value
   tails), which reads as truncated rows.
4. **Algorithms 1 and 2 verbatim blocks are OCR-corrupted**:
   `$\boldsymbol{\operatorname{Var}} a$`, `$\downarrow$` in place of `▷`, `$\tilde{\Delta}$`
   in place of `⋄̃`.
5. **Section 6, Note 9 permutation cycles are mangled** — `(217252228)` should be a cycle on
   `2, 17, 25, 22, 28`.
6. **Forward reference:** the Section 3 filter description cites "Prop. 11" before it is
   stated in Section 8.

### Reproduction Issues

Defects introduced in our implementation.

#### Bk-1 — "All 7 functions pairwise EA-inequivalent" is not soundly established

- **Location:** `theorem5.jl:76-83` (`print_check "All 7 functions pairwise EA-inequivalent
  (≥7 EA-classes confirmed)"`); same pattern at `theorem3.jl:55-63` and
  `test/test_theorem3.jl:18-20`.
- **Symptom:** the PASS is derived from `are_ea_equivalent(...) == false`. For 19 of the 21
  pairs that `false` is sound; for **two pairs it is a warned best-effort guess** reported as
  a positive result. The undecided pairs are **(x⁷, x¹¹)** and **(f6(1), f6(2))** — identical
  algebraic degree, identical extended Walsh spectrum `(0;496),(8;496)`, identical
  component-degree spectrum, and non-quadratic, so the exact `:ortho_derivative` route does
  not apply.
- **Root cause:** per `packages/VBF/src/equivalence/ea/api.jl:56-76` and `:108-115` —
  (a) x⁷/x¹¹ are monomial APN with the degenerate `[2ⁿ−1, 1]` Heggebakk partition ⇒ capped
  search; (b) f6(1)/f6(2) are non-permutations, routing to inner-affine enumeration of size
  `|AGL(5,2)| = 32 · 9 999 360 ≈ 3.2×10⁸`, far above the default `max_inner_affine = 10⁷`
  ⇒ capped. In both cases `on_inconclusive = :best_effort` warns and returns `false`, which
  the report reads as "inequivalent". The core docstring warns against exactly this: *"a
  novelty check reading it as 'inequivalent' manufactures a discovery"*.
- **Resolution plan:**
  1. Pass `on_inconclusive = :throw` at `theorem5.jl:78`, `theorem5.jl:88`, `theorem3.jl:57`;
     handle `InconclusiveEquivalence` explicitly instead of silently.
  2. For **(f6(1), f6(2))**: use `ea_class_orbits` / `enumerate_ea_classes_apn_quadratic` on
     the CCZ class (both lie in an n=5 CCZ class containing quadratic APN), or raise
     `max_inner_affine` to `4×10⁸` and accept the runtime.
  3. For **(x⁷, x¹¹)**: both are permutations, so `are_affine_equivalent` is decidable via
     `affine_representative` (32 `linear_representative` calls). Affine-inequivalence plus the
     cyclotomic-coset argument already cited at `theorem3.jl:64`
     (`{7·2^k mod 31} = {7,14,28,25,19}` vs `{11·2^k mod 31} = {11,22,13,26,21}`, and
     `7⁻¹ mod 31 = 9 ∈ {9,18,5,10,20}`, disjoint from x¹¹'s coset) constitutes a *proof*.
  4. Add `print_kv` lines recording, per pair, which invariant or exact procedure decided it,
     so the 19 sound and 2 previously-guessed pairs are distinguishable by a reader.

#### Bk-2 — Stale root-cause comment about `are_ea_equivalent`

- **Location:** `theorem5.jl:46-51`.
- **Symptom:** the comment claims the auto strategy "falls back to the permutation-only
  Heggebakk search (VBF ea/api.jl), which bails to false on non-permutation inputs". This is
  no longer true, so the CCZ workaround at `theorem5.jl:43-45` may be unnecessary.
- **Root cause:** core changed. `packages/VBF/src/equivalence/ea/api.jl:22-25` and `:108-115`
  now route non-permutation pairs to a complete inner-affine enumeration, exact up to
  `max_inner_affine` (default `10⁷`, which "decides every n ≤ 4 pair exhaustively"). The n=4
  F2/formula5 pair is therefore decidable.
- **Resolution plan:**
  1. Re-run `are_ea_equivalent(F2, formula5_n4())` against current core.
  2. If it returns a sound answer, replace the CCZ workaround at `theorem5.jl:43-45` with the
     direct EA test.
  3. Delete the stale note at `theorem5.jl:46-51`.

#### Bk-3 — Tables 1, 3 and 5 are not loaded, although all three reconstruct cleanly

- **Location:** `report.jl:37` admits `Table 1 / Table 3 canonical APN LUTs (not loaded)`;
  `report.jl:34` declares Section 7 / Table 5 out of scope. `helpers.jl:83-86` substitutes
  generic power functions for Table 1; `helpers.jl:94-99` substitutes power functions plus
  eq. (6) for Table 3.
- **Symptom:** the paper's three headline result tables are absent from the reproduction.
- **Root cause:** the tex tables are OCR-mangled (Paper Issues 1–3), so they were skipped
  rather than reconstructed.
- **Reconstruction was performed during review and validates exactly:**
  - **Table 1** (5 canonical APN permutations, n=5): re-insert the OCR-merged `s(1)=1` after
    the leading `0`. All 5 are permutations of `0..31`, all APN, degrees **4, 3, 3, 2, 2** —
    exactly the paper's degree column, with `Aff.` column x¹⁵, x¹¹, x⁷, x³, x⁵.
  - **Table 3** (7 canonical EA representatives, n=5): 32 numeric cells per row are complete.
    All 7 APN, degrees **2, 2, 3, 3, 4, 3, 3** — exactly the paper's degree column.
  - **Table 5** (14 canonical CCZ representatives, n=6): shared 33-value prefix + 31-value
    tails. All 14 are APN and **all 14 Γ-ranks reproduce the paper exactly**:

    | # | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 |
    |---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
    | paper Γ | 1172 | 1146 | 1102 | 1168 | 1170 | 1170 | 1170 | 1172 | 1174 | 1166 | 1170 | 1166 | **1300** | 1158 |
    | computed | 1172 | 1146 | 1102 | 1168 | 1170 | 1170 | 1170 | 1172 | 1174 | 1166 | 1170 | 1166 | **1300** | 1158 |

    Row 3's Γ = 1102 matches `n6_Gold_x3`, confirming the paper's `CCZ eq. = x³` entry.
    Rows 1–12 and 14 have degree 2; row 13 (the **new** class) has degree 3.
- **Resolution plan:**
  1. Add `table1.jl` with the 5 reconstructed LUTs; assert APN, `is_permutation`,
     `algebraic_degree`, and `are_affine_equivalent` against the stated power function.
  2. Add `table3.jl` with the 7 reconstructed LUTs; assert APN, degree, and the `EA` / `CCZ`
     columns.
  3. Add `section7.jl` + `table5.jl` with the 14 reconstructed n=6 LUTs; assert APN and
     `gamma_rank(F) == paper_value` for all 14.
  4. Document the OCR reconstruction rule in each file header (Table 1: re-insert `s(1)=1`;
     Table 5: prefix + tail concatenation).

#### Bk-4 — Table 4 n=4,5 declared "infeasible" but exactly derivable from Section 6

- **Location:** `section6.jl:15-21` (`APN_COUNT_N4`, `APN_COUNT_N5` as literal strings),
  `section6.jl:87-88` ("infeasible to compute"), `test/test_section6.jl:17-19`.
- **Symptom:** the counts are hard-coded string transcriptions with no derivation; the test
  only guards against a digit-drop regression.
- **Root cause:** Section 6's apparatus — the group `G` and its action (eqs (7)–(9)), the
  order formula (10), Lemma 7, Corollary 8, Algorithm 3 — is not implemented.
- **The derivation was verified during review.** With
  `|G| = (2ⁿ·∏(2ⁿ−2ⁱ)) · (∏(2ⁿ−2ⁱ)) · (2ⁿ)^{n+1}`:
  - `|G|₄ = 6 818 690 079 129 600`; stabiliser orders 5760, 384 ⇒
    `Σ |G|/|G_s| = 18 940 805 775 360` — **exact match** to Table 4.
  - `|G|₅ = 3 435 534 046 222 638 435 532 800`; stabiliser orders
    4960, 4960, 160, 160, 155, 155, 155 ⇒
    `Σ |G|/|G_s| = 110 823 678 910 407 691 468 800` — **exact match**.
  - Percentages match too: `1.027×10⁻⁴ %` and `7.583×10⁻²⁴ %` vs the paper's `≈1.0×10⁻⁴` and
    `≈7.6×10⁻²⁴`.
- **Resolution plan:**
  1. Add `g_order(n)` implementing eq. (10).
  2. Add `const STABILISER_ORDERS = Dict(4 => [5760, 384], 5 => [4960,4960,160,160,155,155,155])`
     transcribed from Section 6's text.
  3. Add `apn_count_from_orbits(n) = sum(div(g_order(n), s) for s in STABILISER_ORDERS[n])`
     and assert equality with the Table 4 value for n=4 and n=5 — turning two transcriptions
     into two derivations.
  4. Optionally implement Algorithm 3 (or use `self_affine_equivalences` / `ea_equivalences`
     on the n=4 representatives) to compute 5760 and 384 from scratch, closing the loop.

#### Bk-5 — Section 8 entirely missing, and fully reproducible

- **Location:** `report.jl:35` lists `Section 8: the counting recurrences` as a known gap.
- **Symptom:** Lemma 10, Prop 11 (eqs 17–18), Prop 12, and identities (20)–(24) are absent.
- **Root cause:** declared out of scope; no technical obstacle exists.
- **Every piece was verified reproducible during review:**
  - Prop 11's recurrences give `A(1..16) = 0,0,0,1,1,3,7,14,14,18,26,39,55,77,105,140` and
    `Δ(1..16) = 0,0,0,1,0,2,4,7,0,4,8,13,16,22,28,35` — exactly sequences (20) and (21), and
    matching brute-force enumeration of 2-dim affine subspaces in `[0;k−1]`.
  - `A(2ⁿ) = C(2ⁿ,3)/4` verified for n = 1..6: 0, 1, 14, 140, 1240, 10416.
  - Eq. (22) `Δ(2^k) = (1/6)(2^k − 3/2)² − 1/24` verified for k = 1..6: 0, 1, 7, 35, 155, 651.
  - Eq. (23) `Δ(2^k + j) = Δ(j) + (j−1)·2^k/2` verified for k=4, j = 1..15.
- **Resolution plan:**
  1. Add `section8.jl` with `A(k)`, `Delta(k)` (Prop 11 recurrences), and a brute-force
     `count_affine_subspaces(M)`.
  2. Assert the recurrences match brute force for all `k ≤ 16`, and assert sequences (20)/(21).
  3. Assert `A(2^n) == binomial(2^n,3) ÷ 4` and eqs (22)/(23).
  4. Assert Prop 12 (`#A(M) ≤ A(#M)`) exhaustively over all 256 subsets `M ⊆ F₂³` plus a
     random sample for `F₂⁴`.
  5. Add Prop 2's probability model `P(k) = 1 − ((2ⁿ−1)/2ⁿ)^{Δ(k)}` and the Fig. 1 comparison
     for n=6.

#### Bk-6 — The paper's algorithmic contribution (Sections 2, 3, 5, 6) is unimplemented

- **Location:** `lemma1.jl:22-39` (`check_lemma1`) is the closest thing present.
- **Symptom:** Algorithm 1 (stateful filter `φ_APN` with the `(c,a)` table, linear rather than
  quadratic in `deg s̃`), Algorithm 2 (`φ_π` CCZ-equivalence backtrack), Algorithm 3
  (stabiliser generator search), the template/left-refinement formalism of Sect. 2, and
  Note 9's explicit generators `h₁, h₂, h₃` are all absent. `check_lemma1` is the naive
  `O(2^{3n})` triple loop — a correct characterisation check, but not a reproduction of
  Algorithm 1.
- **Root cause:** the reproduction targets the paper's *results* rather than its *methods*.
- **Resolution plan:**
  1. Implement Algorithm 1 as a stateful filter.
  2. Use it to re-derive the n=3 count 688 128 by backtracking (this approach was confirmed
     during review to yield 688 128 in under a second), replacing the brute-force
     `count_apn_n3`.
  3. Verify Note 9's `h₁, h₂, h₃` directly as EA self-equivalences of Table 3 no. 1 — they are
     explicit permutations.

#### Bk-7 — x¹⁵ is mislabelled "Kasami"

- **Location:** `helpers.jl:80` (docstring `x⁷ (Welch), x¹¹, x¹⁵ (Kasami)`) and
  `theorem3.jl:44` (`labels = [..., "x¹⁵ (Kasami)"]`).
- **Symptom:** factually wrong family attribution.
- **Root cause:** at n=5 the Kasami exponent `2^{2k}−2^k+1` with k=2 is **13**, whose
  cyclotomic coset is `{11,13,21,22,26}` — so **x¹¹** is Kasami. `x¹⁵` is the **Inverse**
  function `2^{2t}−1` with t=2 (its coset `{15,23,27,29,30}` also contains the Dobbertin
  exponent 29). Confirmed by Γ-rank: x¹¹ → 330, x¹⁵ → **496**, i.e. different CCZ classes, so
  this is not a cyclotomic-coset naming nicety. The mislabel is a direct consequence of
  `helpers.jl:26-28` bypassing the exported family constructors via a raw `power_sbox`.
- **Resolution plan:**
  1. Relabel `x¹¹ → Kasami (k=2)` and `x¹⁵ → Inverse (= Dobbertin coset)` at `helpers.jl:80`
     and `theorem3.jl:44`.
  2. Replace raw `power_sbox` calls with `gold_apn(5,1)`, `gold_apn(5,2)`, `welch_apn(5)`,
     `kasami_apn(5,2)` (yields x¹³, linearly equivalent to x¹¹), `inverse_apn(5)`.
  3. **Cross-cutting catalog defect (separate go-ahead required — outside this paper dir):**
     `packages/VBFCatalog/data-raw/apn_catalog/n5_apn.toml:24-33` has the same error. The entry
     is named `n5_Kasami_x15` with description `"Kasami APN x^15 = x^(2^4 - 2^2 + 1)"`, but
     `2⁴ − 2² + 1 = 13`, not 15. The stored LUT *is* `x¹⁵` (verified byte-for-byte), i.e. the
     Inverse function. This propagates into `papers/2003/Biryukov_200300/section3.jl:41` and
     `tests/test_section3.jl:5`. Recommend renaming to `n5_Inverse_x15` with an alias, matching
     the existing `n7_Inverse_x126` / `n9_Inverse_x510` convention.

#### Bk-8 — Theorem 3's inverse-relation claims are missing

- **Location:** `theorem3.jl:40-66`.
- **Symptom:** the paper's Theorem 3 states "No. 1 is equivalent to its inverse, and no. 2
  (resp. 3) is equivalent to the inverse of no. 4 (resp. 5)". None of the three claims is
  checked.
- **Root cause:** Table 1 is not loaded (Bk-3), so the referenced functions do not exist in
  the reproduction.
- **Resolution plan:**
  1. Load Table 1 per Bk-3.
  2. Assert `are_affine_equivalent(T1[1], compositional_inverse(T1[1]))`.
  3. Assert `are_affine_equivalent(T1[2], compositional_inverse(T1[4]))` and
     `are_affine_equivalent(T1[3], compositional_inverse(T1[5]))`. All five are permutations,
     so `affine_representative` decides them exactly.

#### Bk-9 — Theorem 3's n=4 statement is decidable in-repo but declared out of scope

- **Location:** `theorem3.jl:30-31` — *"Note: completeness (no other APN functions exist for
  n=4) requires the full backtrack search — out of scope here."*
- **Symptom:** a provable statement is left unproven.
- **Root cause:** the note overlooks that Theorem 6 (already verified at `theorem6.jl:24`)
  gives a **single** CCZ class at n=4, and `VBF` exports `is_ccz_equivalent_to_permutation`.
- **Resolution plan:**
  1. Assert `!is_ccz_equivalent_to_permutation(F1)`.
  2. Combine with the single-CCZ-class fact — together these are a complete proof that no APN
     permutation exists in `F(F₂⁴,F₂⁴)`.
  3. Replace the "out of scope" note with the proof.

#### Bk-10 — `count_apn_n3` docstring promises a warning that is never emitted

- **Location:** `section6.jl:57` (*"Pass `limit` to stop early (returns partial count with a
  warning)"*) vs `section6.jl:64` (a bare `break`).
- **Symptom:** a truncated run is indistinguishable from a complete one.
- **Root cause:** the warning was documented but not implemented.
- **Resolution plan:**
  1. Emit `@warn "count_apn_n3 truncated at limit=$limit; result is a partial count"` before
     the `break`; or
  2. drop the promise from the docstring.

---

## Items reproduced exactly

| Paper item | Repo location | Verification |
|---|---|---|
| **Lemma 1** (APN ⟺ 2-dim affine subspace sums ≠ 0) | `lemma1.jl:22-39` | Agrees with the DDT criterion on all tested functions |
| **Table 2** (n=4 EA-canonical LUTs) | `helpers.jl:71-75` | Both LUTs APN; degrees 2 and 3 — match the paper |
| **Theorem 3**, n=4 part (Table-2 functions are non-permutations) | `theorem3.jl:21-32` | Confirmed |
| **Theorem 3**, n=5 part (x³,x⁵,x⁷,x¹¹,x¹⁵ are APN permutations) | `theorem3.jl:40-52` | Confirmed |
| **Theorem 5**, n=4 (2 EA classes; F1 ≅ x³; F2 ≇ x³) | `theorem5.jl:21-52` | Degrees 2 vs 3 separate them soundly |
| **Theorem 6**, n=4 (single CCZ class) | `theorem6.jl:21-27` | Consistent |
| **Theorem 6**, n=5 (3 CCZ classes) | `theorem6.jl:34-65` | Γ-rank separates x¹⁵ (496) from the rest (330); the remaining split relies on the repo's oracle (not independently re-derivable) |
| **Table 4**, n=1, n=2 exact counts (4, 192) | `section6.jl:28-50` | Confirmed by independent backtracking enumeration |
| Table 4, n=3 = 688 128 | `section6.jl:19` (transcribed) | Confirmed by independent enumeration |
| Table 4, n=4, n=5 digit strings | `section6.jl:20-21` | Confirmed — and also derivable, see Bk-4 |
| Budaghyan eqs (5) and (6) | `helpers.jl:36-62` | Correct transcriptions of Budaghyan Theorems 2 and 1 |

---

## Test results

`make -C papers/2008/Brinkmann_200812 test` → **could not run**: `make: julia: No such file
or directory`. No Julia toolchain exists in the review environment.

All Table 2 / Table 4 / Lemma 1 assertions were re-derived independently and **confirmed**.
The Theorem 5 pairwise-EA assertion is **not** re-derivable as sound for 2 of 21 pairs — see
Bk-1.

---

## Catalog status

| Claimed-new function | Status | Evidence |
|---|---|---|
| **Section 7 / Table 5 row 13** — "a new CCZ equivalence class that was previously unknown" (n=6, degree 3) | **present** | Matches `reprs6_13` in `packages/VBFCatalog/BFA_catalog.sqlite` on every computed invariant: Γ-rank **1300** (unique among all 21 n=6 entries), Δ-rank **152**, algebraic degree **3**, extended Walsh spectrum `((0;1008),(8;2688),(16;336))`. LUTs differ (different class representatives), so a LUT-level dedup would miss it — the equivalence rests on the invariant tuple. |
| Table 5 rows 1–12, 14 | **present** | Γ-ranks map 1:1 onto catalog entries: 1102 → `n6_Gold_x3`/`reprs6_0`; 1146 → `reprs6_1`; 1158 → `reprs6_2`; 1166 → `n6_Kim`/`reprs6_3`; 1168 → `reprs6_5`; 1170 → `reprs6_{6,7,8,9}`; 1172 → `reprs6_{10,11}`; 1174 → `reprs6_12` |
| Table 2 / Table 3 (n=4, n=5) | **present** | All CCZ-equivalent to `n4_Gold_x3` (single n=4 class) or to `n5_Gold_x3` / `n5_Gold_x5` / `n5_Kasami_x15` (the three n=5 classes) |

**No catalog-gap record required** — nothing genuinely new is missing.

There is, however, a **provenance gap**. `reprs6_13` already covers the paper's new class but
carries `bib_key = NULL`, `algebraic_form = NULL`, and
`notes = "sboxU quadratic-APN CCZ-class representative (reprs6)"` — no attribution to the
paper that first reported it. Recommended action (needs a separate go-ahead, and is **not** a
new class):

- either add `bib_key = "Brinkmann_200812"`, `algebraic_form`, and `source` to the existing
  `reprs6_13` row plus a `ccz_equivalent_to` cross-reference,
- or add a named TOML entry in
  `packages/VBFCatalog/data-raw/apn_catalog/n6_apn.toml` with
  `ccz_equivalent_to = "reprs6_13"`.

The Table 5 row-13 LUT (re-verified APN, `differential_uniformity == 2`):

```
[0,0,0,1,0,2,4,7,0,4,6,3,8,14,10,13,0,8,16,25,5,15,17,26,32,44,54,59,45,35,63,48,
 0,16,26,36,34,48,60,0,45,57,49,11,7,17,31,39,43,28,14,23,12,57,45,54,38,21,5,24,9,56,46,49]
```

---

## Library-reuse note

| Helper | Line | Verdict |
|---|---|---|
| `power_sbox` | `helpers.jl:26-28` | Thin wrapper over `gf_monomial_lut`, but for the exponents used it **duplicates** `gold_apn(5,1)`, `gold_apn(5,2)`, `welch_apn(5)`, `kasami_apn(5,2)`, `inverse_apn(5)`. Bypassing them caused Bk-7. |
| `formula5_n4` | `helpers.jl:36-45` | **Cross-paper duplicate** of `papers/2005/Budaghyan_200506/theorem2.jl:24` (`theorem2_lut(4, 1)`) |
| `formula6_n5` | `helpers.jl:53-62` | **Cross-paper duplicate** of `papers/2005/Budaghyan_200506/theorem1.jl:24` (`theorem1_lut(5, i)`) |
| `check_lemma1` | `lemma1.jl:22-39` | Legitimately paper-specific. Keep — but see Bk-6 |
| `table2_luts` | `helpers.jl:71-75` | Paper data; correct. Extend with Tables 1, 3, 5 (Bk-3) |
| `count_apn_n{1,2,3}` | `section6.jl:28-69` | Paper-specific enumeration; should use the Algorithm-1 filter |
| report emitters | throughout | Uses `print_section`, `print_check`, `print_kv` — good. `report.jl:18-21` hand-rolls a header instead of `print_banner` (minor) |

**Promote-to-core candidate (second consumer confirmed):** `formula5_n4` / `formula6_n5` here
and `theorem1_lut` / `theorem2_lut` in `Budaghyan_200506` are the *same* two families used by
two independent papers. Add `bcp_trace_ab(m, i)` (m odd) and `bcp_trace_apn(m, i)` (m even) to
`packages/VBF/src/constructions/apn_quadratic_families.jl`, next to the existing `bcp_apn`,
with hypothesis validation and tests.
