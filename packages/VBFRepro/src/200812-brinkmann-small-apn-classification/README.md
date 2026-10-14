# Brinkmann & Leander (2008) — On the classification of APN functions up to dimension five

- **Citation:** M. Brinkmann, G. Leander, "On the classification of APN functions up to
  dimension five", *Des. Codes Cryptogr.* 49(1–3):273–288, 2008.
- **Reproduction path:** `packages/VBFRepro/src/200812-brinkmann-small-apn-classification/`
- **Paper source:** `input/Brinkmann e Leander - 2008 - On the classification of APN functions up to dimension five.tex`
- **Verdict:** **Reproduced** — Lemma 1, Algorithm 1, Tables 1–5, Theorems 3/5/6, Note 9 and
  Section 8 all reproduce; every EA/affine/CCZ claim is decided by a sound route, with no
  best-effort verdict read as a result. Remaining gap: the *completeness* half of the
  classifications (Algorithm 2's CCZ backtrack and Algorithm 3's stabiliser search) — see
  Bk-6.

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

#### Bk-1 — "All 7 functions pairwise EA-inequivalent" is not soundly established [RESOLVED]

> **Resolved.** `helpers.jl` gained `ea_verdict(F, G; class_F, class_G)`, which queries
> `are_ea_equivalent` with `on_inconclusive = :missing` and, when that is undecided, falls
> back to **CCZ separation** (EA ⊆ CCZ, so distinct CCZ classes prove EA-inequivalence).
> The CCZ class map comes from `n5_ccz_class` / `n5_ccz_reps`, which uses *only* sound
> outcomes: positive CCZ witnesses against x³/x⁵ (one side quadratic APN ⇒ exact
> ortho-derivative test) and the Γ-rank CCZ-invariant for x¹⁵. A direct
> `are_ccz_equivalent(x⁷, x¹¹)` is deliberately **not** used — for two non-quadratic
> permutations that call runs the Canteaut–Perrin enumeration on a Heggebakk backend and
> its `false` can be unsound. `theorem5.jl` now prints the class map and, per pair, which
> route decided it. It was **19/21 by the EA oracle, 2/21 by CCZ separation, 0 undecided**.
> Since the native EA refinement in VBF (commit `ab7e75a`), the EA oracle decides all
> **21/21** directly, and the CCZ separation independently agrees on (x⁷, x¹¹) and (f6(1), f6(2)).
> `theorem3.jl` switched its n=5 pairwise test to `are_affine_equivalent`, which is the
> relation Theorem 3 is actually stated in and is exact for permutations — all 10 pairs
> decided. Same change in `test/test_theorem3.jl` and `test/test_theorem5.jl`.

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

#### Bk-2 — Stale root-cause comment about `are_ea_equivalent` [RESOLVED]

> **Resolved.** Re-ran against current core: `are_ea_equivalent(F2, formula5_n4())` returns a
> sound `true` (the non-permutation pair routes to the complete inner-affine enumeration,
> exhaustive for n=4 well within the 10⁷ cap). The CCZ workaround and the stale note were
> deleted; `theorem5.jl` now asserts the EA equivalence directly, plus `F1 ≁ formula5_n4()`
> as a negative control. `test/test_theorem5.jl` asserts both.

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

#### Bk-3 — Tables 1, 3 and 5 are not loaded, although all three reconstruct cleanly [RESOLVED]

> **Resolved.** Added `table1.jl`, `table3.jl`, `table5.jl` and `section7.jl`, each carrying
> its OCR reconstruction rule in the file header. All assertions in the plan hold:
> Table 1 — 5 permutations of `0..31`, all APN, degrees 4,3,3,2,2, each affine equivalent to
> its stated `Aff.` power function, and pairwise affine-inequivalent;
> Table 3 — 7 APN, degrees 2,2,3,3,4,3,3, all vanishing on the affine standard basis, `EA`
> column reproduced for the 5 power rows and `CCZ` column reproduced for all 7;
> Table 5 — 14 APN, **all 14 Γ-ranks reproduce the paper exactly**, row 3 CCZ-equivalent to
> `gold_apn(6,1)`, row 13 the unique Γ=1300 / degree-3 row.
> Tests: `test/test_table1.jl`, `test/test_table3.jl`, `test/test_section7.jl`.
> `report.jl` no longer lists Table 1 / Table 3 / Section 7 as gaps.

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

#### Bk-4 — Table 4 n=4,5 declared "infeasible" but exactly derivable from Section 6 [RESOLVED]

> **Resolved.** `section6.jl` gained `g_order(n)` (eq. (10), `BigInt`), `stabiliser_orders(n)`
> (Section 6's text; a function rather than a `Dict` const so the file stays re-includable)
> and `apn_count_from_orbits(n) = Σ |G|/|G_s|`. Both derivations match Table 4 to the digit:
> `|G|₄ = 6 818 690 079 129 600` ⇒ `18 940 805 775 360`, and
> `|G|₅ = 3 435 534 046 222 638 435 532 800` ⇒ `110 823 678 910 407 691 468 800`.
> The digit-string constants are kept as an independent cross-check. Step 4 (recomputing the
> stabiliser orders from scratch) is partly closed too: `algorithm1.jl` derives the first n=5
> order, `|⟨h₁,h₂,h₃⟩| = 4960`, from Note 9's generators. Tests in `test/test_section6.jl`.

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

#### Bk-5 — Section 8 entirely missing, and fully reproducible [RESOLVED]

> **Resolved.** Added `section8.jl` with `subspace_counts(kmax)` (Prop 11's recurrences (17)
> and (18) for `A(k)` and `Δ(k)`), a brute-force `count_affine_subspaces(M)`,
> `conflict_probability(n, Δk)` (Prop 2, eq. (3)) and `measure_conflicts(n)` (Knuth random
> dives through the Algorithm-1 tree). Asserted: recurrence vs brute force for all `k ≤ 16`,
> `A(k) = Σ Δ(j)` for `k ≤ 64`, sequences (20)/(21), `A(2ⁿ) = C(2ⁿ,3)/4` for `n ≤ 6`, eq. (22)
> exactly over the rationals, eq. (23) for `k ≤ 5`, and Prop 12 over all 256 subsets of `F₂³`
> plus a random sample from `F₂⁴`. The Fig. 1 comparison for n=6 reproduces: model
> `2⁶·P(k)` tracks the measured conflict counts from below (e.g. k=24: 40.27 vs 44.71;
> k=32: 58.43 vs 62.04; k=17 and k=33: both exactly 0). Tests: `test/test_section8.jl`.

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

#### Bk-6 — The paper's algorithmic contribution (Sections 2, 3, 5, 6) is unimplemented [PARTIALLY RESOLVED]

> **Steps 1–3 of the plan are done; Algorithm 2 and Algorithm 3 remain out of scope.**
> Added `algorithm1.jl`:
> * **Algorithm 1** as the stateful filter it is in the paper — `APNFilter` holds the
>   `(c,a) ↦ TRUE` table, `filter_push!` is one `φ_APN` step (linear in `deg s̃`, one
>   read/store per determined position) and `filter_pop!` its undo for backtracking.
> * `count_apn_backtrack(n)` re-derives Table 4's computable rows by left-refining
>   backtrack, never building a DDT: **n=1 → 4, n=2 → 192, n=3 → 688 128 in ≈0.2 s**
>   (vs ~2 min for the brute-force `count_apn_n3`, which is kept as an independent check).
> * **Note 9's `h₁, h₂, h₃`** de-mangled from the OCR cycle notation (Paper Issue 5) and
>   verified as EA self-equivalences of Table 3 no. 1: each is an affine bijection of `F₂⁵`
>   and `is_ea_self_equivalence` *constructs* the witnessing `(β, γ)` rather than trusting an
>   oracle. `|⟨h₁,h₂,h₃⟩| = 4960` — the paper's first n=5 stabiliser order.
> Tests: `test/test_algorithm1.jl`.
>
> **Still open (needs a decision):** Algorithm 2 (the `φ_π` CCZ-equivalence backtrack) and
> Algorithm 3 (the stabiliser generator *search*, as opposed to verifying the generators the
> paper prints), plus the template / left-refinement formalism of Sect. 2 as a reusable
> abstraction. These are substantial new search machinery, not a fix; deciding whether they
> belong in a paper directory or in `packages/VBF/src` is a scope call for a human.

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

#### Bk-7 — x¹⁵ is mislabelled "Kasami" [RESOLVED — steps 1 & 2; step 3 needs go-ahead]

> **Resolved in this paper directory.** `helpers.jl`'s `n5_power_sboxes` now builds x³, x⁵
> and x⁷ from the exported constructors `gold_apn(5,1)`, `gold_apn(5,2)`, `welch_apn(5)`,
> and its docstring states the correct attribution: x¹¹ is **Kasami** (the Kasami exponent at
> k=2 is 13, and 11 is in its coset {11,13,21,22,26}) and x¹⁵ is **Inverse** (coset
> {15,23,27,29,30}, which also holds the Dobbertin exponent 29). The paper's own exponents
> 11 and 15 are kept — they are Table 1's `Aff.` column — and the family claim is *proved*
> rather than asserted: `theorem3.jl` checks `are_affine_equivalent(x¹¹, kasami_apn(5,2))`
> and `are_affine_equivalent(x¹⁵, inverse_apn(5))`, both PASS, and records the Γ-rank split
> 330 vs 496. New `n5_power_labels()` carries the labels; `theorem3.jl:44`'s
> `"x¹⁵ (Kasami)"` is gone. Tests in `test/test_theorem3.jl`.
>
> **Step 3 not done — needs a separate go-ahead.** The catalog entry
> `packages/VBFCatalog/data/apn/n5_apn.toml` `n5_Kasami_x15` carries the same
> mislabel, and renaming it touches `packages/VBFRepro/src/200300-biryukov-equivalence` and requires a catalog
> rebuild + gate run. Out of scope for a paper-local fix.

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
     `packages/VBFCatalog/data/apn/n5_apn.toml:24-33` has the same error. The entry
     is named `n5_Kasami_x15` with description `"Kasami APN x^15 = x^(2^4 - 2^2 + 1)"`, but
     `2⁴ − 2² + 1 = 13`, not 15. The stored LUT *is* `x¹⁵` (verified byte-for-byte), i.e. the
     Inverse function. This propagates into `packages/VBFRepro/src/200300-biryukov-equivalence/section3.jl:41` and
     `tests/test_section3.jl:5`. Recommend renaming to `n5_Inverse_x15` with an alias, matching
     the existing `n7_Inverse_x126` / `n9_Inverse_x510` convention.

#### Bk-8 — Theorem 3's inverse-relation claims are missing [RESOLVED]

> **Resolved.** With Table 1 loaded (Bk-3), `theorem3_n5_report` now asserts all three
> claims via `compositional_inverse` + `are_affine_equivalent` (exact, all five are
> permutations): no. 1 ≅ its own inverse, no. 2 ≅ inverse of no. 4, no. 3 ≅ inverse of
> no. 5. All three PASS. Tests in `test/test_theorem3.jl`.

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

#### Bk-9 — Theorem 3's n=4 statement is decidable in-repo but declared out of scope [RESOLVED]

> **Resolved.** `theorem3_n4_report` asserts `!is_ccz_equivalent_to_permutation(F)` for both
> Table 2 representatives (both PASS) and the "out of scope" note is replaced by the proof:
> the predicate is exact (exhaustive Walsh-zero subspace enumeration, Canteaut–Perrin's
> complementary-pair criterion), Theorem 6 gives a single n=4 CCZ class, and being CCZ
> equivalent to a permutation is a CCZ-class property — so no APN function in `F(F₂⁴,F₂⁴)`
> is CCZ, let alone affine, equivalent to a permutation. Tests in `test/test_theorem3.jl`.

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

#### Bk-10 — `count_apn_n3` docstring promises a warning that is never emitted [RESOLVED]

> **Resolved.** `section6.jl` now emits
> `@warn "count_apn_n3 truncated at limit=…; result is a partial count, not #APN(3)"`
> (with the partial count attached) before the `break`, so a truncated run cannot be
> mistaken for a complete one. `test/test_section6.jl` asserts the warning is emitted
> via `@test_logs (:warn,)`.

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
| **Lemma 1** (APN ⟺ 2-dim affine subspace sums ≠ 0) | `lemma1.jl` | Agrees with the DDT criterion on all tested functions |
| **Algorithm 1** (stateful filter `φ_APN`) | `algorithm1.jl` | `count_apn_backtrack` gives 4 / 192 / 688 128 for n = 1, 2, 3 without ever building a DDT |
| **Table 1** (n=5 canonical APN permutations) | `table1.jl` | 5 permutations of 0..31, all APN, degrees 4,3,3,2,2, each affine equivalent to its `Aff.` power function |
| **Table 2** (n=4 EA-canonical LUTs) | `helpers.jl` `table2_luts` | Both LUTs APN; degrees 2 and 3 — match the paper |
| **Table 3** (n=5 EA-canonical LUTs) | `table3.jl` | 7 APN, degrees 2,2,3,3,4,3,3; `EA` and `CCZ` columns both reproduce |
| **Theorem 3**, n=4 (no APN permutation) | `theorem3.jl` `theorem3_n4_report` | Proved: `!is_ccz_equivalent_to_permutation` on both reps + Theorem 6's single CCZ class |
| **Theorem 3**, n=5 (5 affine classes + inverse relations) | `theorem3.jl` `theorem3_n5_report` | All 10 pairs decided by `are_affine_equivalent`; all three inverse relations hold |
| **Theorem 5**, n=4 (2 EA classes; F1 ≅ x³; F2 ≅ BCP eq. (5)) | `theorem5.jl` `theorem5_n4_report` | Decided by the complete non-permutation EA enumeration |
| **Theorem 5**, n=5 (≥7 EA classes) | `theorem5.jl` `theorem5_n5_report` | All 21 pairs decided by the EA oracle; CCZ separation independently confirms (x⁷, x¹¹) and (f6(1), f6(2)) |
| **Theorem 6**, n=4 (single CCZ class) | `theorem6.jl` | Consistent |
| **Theorem 6**, n=5 (3 CCZ classes) | `theorem6.jl`, `helpers.jl` `n5_ccz_reps` | Γ-rank separates x¹⁵ (496) from the rest (330); x³ vs x⁵ is the exact ortho-derivative test (both quadratic APN) |
| **Table 4**, n=1, 2, 3 (4, 192, 688 128) | `algorithm1.jl`, `section6.jl` | Computed two independent ways (Algorithm-1 backtrack and brute force) |
| **Table 4**, n=4, n=5 | `section6.jl` `apn_count_from_orbits` | Derived from eq. (10) + orbit-stabiliser; matches the paper to the digit |
| **Note 9** (`h₁,h₂,h₃`, `|H| = 4960`) | `algorithm1.jl` | Each generator verified in `H` with a constructed `(β, γ)`; group order 4960 |
| **Table 5 / Section 7** (14 n=6 CCZ classes) | `table5.jl`, `section7.jl` | All 14 APN; **all 14 Γ-ranks reproduce the paper exactly**; row 3 ≅ `gold_apn(6,1)`; row 13 unique at Γ=1300 |
| **Section 8** (Prop 11, (20)–(24), Prop 12, Prop 2 / Fig. 1) | `section8.jl` | Recurrences match brute force; all identities exact; Fig. 1 model tracks the measurement |
| Budaghyan eqs (5) and (6) | `helpers.jl` `formula5_n4`, `formula6_n5` | Correct transcriptions of Budaghyan Theorems 2 and 1 |

---

## Test results

`julia --project=<repo_root> packages/VBFRepro/src/200812-brinkmann-small-apn-classification/test/runtests.jl` (Julia 1.12.6):

| testset | pass | fail |
|---|---|---|
| lemma1_test | 6 | 0 |
| algorithm1_test | 21 | 0 |
| table1_test | 32 | 0 |
| table3_test | 44 | 0 |
| theorem3_test | 32 | 0 |
| theorem5_test | 38 | 0 |
| theorem6_test | 8 | 0 |
| section6_test | 17 | 0 |
| section7_test | 50 | 0 |
| section8_test | 864 | 0 |
| **total** | **1112** | **0** |

`make -C packages/VBFRepro/src/200812-brinkmann-small-apn-classification report` → **110 `[PASS]`, 0 `[FAIL]`**, no
inconclusive-equivalence warnings, and no pair left `UNDECIDED`.

*(An earlier review of this paper could not run the suite — no Julia toolchain existed in
that environment — which is why the Bk-1 unsoundness went unmeasured.)*

---

## Catalog status

| Claimed-new function | Status | Evidence |
|---|---|---|
| **Section 7 / Table 5 row 13** — "a new CCZ equivalence class that was previously unknown" (n=6, degree 3) | **present** | Matches `reprs6_13` in `packages/VBFCatalog/data/catalog.sqlite` on every computed invariant: Γ-rank **1300** (unique among all 21 n=6 entries), Δ-rank **152**, algebraic degree **3**, extended Walsh spectrum `((0;1008),(8;2688),(16;336))`. LUTs differ (different class representatives), so a LUT-level dedup would miss it — the equivalence rests on the invariant tuple. |
| Table 5 rows 1–12, 14 | **present** | Γ-ranks map 1:1 onto catalog entries: 1102 → `n6_Gold_x3`/`reprs6_0`; 1146 → `reprs6_1`; 1158 → `reprs6_2`; 1166 → `n6_Kim`/`reprs6_3`; 1168 → `reprs6_5`; 1170 → `reprs6_{6,7,8,9}`; 1172 → `reprs6_{10,11}`; 1174 → `reprs6_12` |
| Table 2 / Table 3 (n=4, n=5) | **present** | All CCZ-equivalent to `n4_Gold_x3` (single n=4 class) or to `n5_Gold_x3` / `n5_Gold_x5` / `n5_Kasami_x15` (the three n=5 classes). Note the catalog key `n5_Kasami_x15` is misnamed — that entry is the **Inverse** function, see Bk-7 step 3 |

**No catalog-gap record required** — nothing genuinely new is missing.

There is, however, a **provenance gap**. `reprs6_13` already covers the paper's new class but
carries `bib_key = NULL`, `algebraic_form = NULL`, and
`notes = "sboxU quadratic-APN CCZ-class representative (reprs6)"` — no attribution to the
paper that first reported it. Recommended action (needs a separate go-ahead, and is **not** a
new class):

- either add `bib_key = "Brinkmann_200812"`, `algebraic_form`, and `source` to the existing
  `reprs6_13` row plus a `ccz_equivalent_to` cross-reference,
- or add a named TOML entry in
  `packages/VBFCatalog/data/apn/n6_apn.toml` with
  `ccz_equivalent_to = "reprs6_13"`.

The Table 5 row-13 LUT (re-verified APN, `differential_uniformity == 2`):

```
[0,0,0,1,0,2,4,7,0,4,6,3,8,14,10,13,0,8,16,25,5,15,17,26,32,44,54,59,45,35,63,48,
 0,16,26,36,34,48,60,0,45,57,49,11,7,17,31,39,43,28,14,23,12,57,45,54,38,21,5,24,9,56,46,49]
```

---

## Library-reuse note

| Helper | File | Verdict |
|---|---|---|
| `power_sbox` | `helpers.jl` | Thin wrapper over `gf_monomial_lut`. **Fixed (Bk-7):** `n5_power_sboxes` now uses `gold_apn(5,1)`, `gold_apn(5,2)`, `welch_apn(5)`; `power_sbox` is kept only for x¹¹ and x¹⁵, the paper's own Table 1 exponents, whose family attribution is *proved* against `kasami_apn(5,2)` / `inverse_apn(5)` |
| `formula5_n4` | `helpers.jl` | **Cross-paper duplicate** of `packages/VBFRepro/src/200506-budaghyan-apn-polynomials/theorem2.jl` (`theorem2_lut(4, 1)`) — still open, see promote-to-core below |
| `formula6_n5` | `helpers.jl` | **Cross-paper duplicate** of `packages/VBFRepro/src/200506-budaghyan-apn-polynomials/theorem1.jl` (`theorem1_lut(5, i)`) — still open |
| `ea_verdict`, `n5_ccz_class` | `helpers.jl` | New (Bk-1). Thin sound-routing wrappers over `are_ea_equivalent` / `are_ccz_equivalent` / `gamma_rank`; no math is reimplemented |
| `check_lemma1` | `lemma1.jl` | Legitimately paper-specific. Keep |
| `APNFilter` / `count_apn_backtrack` | `algorithm1.jl` | The paper's own Algorithm 1; genuinely paper-specific |
| `outer_linear_for` | `algorithm1.jl` | Mirrors the private `_ea_outer_exists` in `packages/VBF/src/equivalence/ea/api.jl`, but constructs the witness `β` rather than only testing existence, which is what Note 9 needs. **Promote-to-core candidate** if a second consumer appears |
| `table{1,2,3,5}_luts` | `table1.jl`, `helpers.jl`, `table3.jl`, `table5.jl` | Paper data; all four tables now loaded (Bk-3) |
| `count_apn_n{1,2,3}` | `section6.jl` | Kept as an independent brute-force cross-check of the Algorithm-1 backtrack |
| `subspace_counts` / `count_affine_subspaces` | `section8.jl` | Paper-specific combinatorics (Prop 11 / Prop 12); no core equivalent |
| report emitters | throughout | Uses `print_banner`, `print_section`, `print_check`, `print_kv` — the hand-rolled header in `report.jl` was replaced by `print_banner` |

**Promote-to-core candidate (second consumer confirmed):** `formula5_n4` / `formula6_n5` here
and `theorem1_lut` / `theorem2_lut` in `Budaghyan_200506` are the *same* two families used by
two independent papers. Add `bcp_trace_ab(m, i)` (m odd) and `bcp_trace_apn(m, i)` (m even) to
`packages/VBF/src/constructions/apn_quadratic_families.jl`, next to the existing `bcp_apn`,
with hypothesis validation and tests.
