# Kalgin_202000 — The Classification of Quadratic APN Functions in 7 Variables

**Paper:** K. Kalgin, V. Idrisova, *The classification of quadratic APN functions
in 7 variables*, Cryptogr. Commun. 14, 691–715.

**Reproduction:** `packages/VBFRepro/papers/Kalgin_202000/` — `helpers.jl`, `proposition2.jl`,
`section4.jl`, `section5.jl`, `table3.jl`, `report.jl`.

**Verdict:** **Partial → repaired.** The headline artifacts (the new n=7 function,
Table 3) were correct and verified. The review found a **real correctness bug**
(mugshot equality used as an EA-equivalence *decision*) that made every
"EA-classes found" number a lower bound and caused the repro to invent a
shortfall and blame the paper for it, plus a fully tautological §5 test.
**R1–R8 are all fixed** (see below); tests went from **164 → 1272**, all passing.

> **Note on sources:** the `.tex` in `input/` is a **lossy OCR conversion** whose
> §5 digit groups are mangled (e.g. `Case ( 100003264 )`). The **PDF** gives the
> true rows and was used as ground truth for §5. Anyone re-reviewing this paper
> should do the same.

---

## Issue Catalog

### Paper Issues

**None found.** Every claim checked against the PDF held up — including the §4
coverage claim that the repro disputes (see R2), the §3 five-variable
differentially-4-uniform `G` (`du = 4` confirmed), the §6.1 quadratic-part claims
(Dillon n=6, Kasami n=8, inverse n=9 — all `Δ(F⁽²⁾) = 8`), and §6.2's explicit
n=6 example.

### Reproduction Issues

**R1. [RESOLVED] Mugshot equality is used as an EA-equivalence *decision* — every
class count is wrong.**

> **Fix:** `helpers.jl` now exposes `are_ea_equivalent_quadratic(F, G)` (non-empty
> `ea_mappings_from_ortho_derivative` ⟺ EA-equivalent, a complete decision for
> quadratic APN) and `dedup_ea` uses `apn_ea_mugshot` **only to bucket**, splitting
> every bucket with that exact decision. `section4.jl`'s inlined dedup is gone:
> the search is now `cyclic_raw_qam_solutions` (no dedup) + `dedup_ea`.
> The n=5 count changes 1 → 2, as predicted. *Mutation-tested:* reverting
> `dedup_ea` to mugshot-only makes `test_section4.jl` fail (4 assertions).

- **Location:** `packages/VBFRepro/papers/Kalgin_202000/helpers.jl:44-52` (`dedup_ea`),
  `packages/VBFRepro/papers/Kalgin_202000/section4.jl:86` (inlined in `cyclic_apn_search`)
- **Symptom:** `dedup_ea`'s docstring says *"Deduplicate … by EA-class
  (apn_ea_mugshot)"*, and `section4.jl:86` does
  `sig ∉ seen_sigs && (push!(seen_sigs, sig); push!(results, f))`.
- **Root cause:** VBF's own docstring
  (`packages/VBF/src/invariants/mugshot.jl:108`) states: *"Equal mugshots are
  necessary but not sufficient for EA-equivalence."* Concrete failure: **Gold `x³`
  and `x⁵` over GF(2⁵) have identical mugshots**, yet `are_ea_equivalent = false`
  and `are_ccz_equivalent = false`. Every "CCZ-classes found" number the
  reproduction prints is therefore a **lower bound, not a count**.
- **Resolution plan:**
  1. Bucket by `apn_ea_mugshot`, then **confirm within each bucket** using
     `are_ea_equivalent` / `ea_mappings_from_ortho_derivative` (both VBF exports).
  2. This alone changes the n=5 result from 1 → 2 and makes every reported count
     sound.

**R2. [RESOLVED] The repro invents a shortfall that does not exist, and blames the
paper.**

> **Fix:** the false note is deleted. `section4_report` now asserts the *verified*
> statement — the cyclic T covers **all** quadratic-APN CCZ-classes for n=3 (1/1),
> n=4 (1/1) and n=5 (2/2) — and additionally checks that the two n=5 classes are
> EA-equivalent to Gold x³ and Gold x⁵ respectively. `test_section4.jl` pins the
> raw solution counts (1, 4, 12), the single shared mugshot at n=5, and the 2
> confirmed classes.

- **Location:** `packages/VBFRepro/papers/Kalgin_202000/section4.jl:167-171`
- **Symptom:** It prints *"standard T for n=5 covers 1 CCZ-class(es); **paper §4
  claims all 3** via general construction"*.
- **Root cause:** Three things are wrong at once. The paper **never states 3**.
  The true number of n=5 quadratic APN CCZ-classes is **2**. And the "1" is
  produced by R1, not by the construction. Recomputing exhaustively with a sound
  test: the standard `T` for n=5 yields **12 raw QAM solutions spanning exactly 2
  EA-classes — both Gold x³ and x⁵**, i.e. *all* n=5 classes. **The paper's claim
  ("for n = 3, 4 and 5 this construction covered all CCZ-classes") is correct**:
  n=3 → 1/1, n=4 → 1/1, n=5 → 2/2.
- **Resolution plan:** Delete the note. Replace with the verified statement above.
  *(The other paper-attributed notes were re-checked and are accurate — e.g. §3's
  "g₆=null … only 1 CCZ-class (class 11)".)*

**R3. [RESOLVED] VACUOUS TEST — `test_section5.jl` is entirely tautological.**

> **Fix:** §5 now *computes* two things.
> 1. **First-row normalisation** (`normalize_first_row`, `section5.jl`): §5's own
>    opening claim, built explicitly as the linear map `L = B⁻¹` sending the first
>    row's 6 independent entries to `e₁…e₆`. Verified on Gold x³/x⁵/x⁹ and on the
>    new n=7 function: the result has first row `(0,1,2,4,8,16,32)`, is still a
>    QAM, and has the same σ (so `L` really is an EA-transformation). It also
>    *derives* `row2[1] = 1` instead of asserting it.
> 2. **Proposition-1 conditions on each case** (`row_offdiag_independent`,
>    `first_two_rows_compatible`): zero diagonal, symmetry, Theorem 1 (no zero
>    off-diagonal) and F₂-independence of each row's 6 off-diagonal entries —
>    the latter being exactly Proposition 1 at `x = e_i`, derived in the docstring.
>    Four **mutation tests** show the checks bind (`…,32,20` → dependent, `…,32,0`
>    → zero entry, asymmetric row, nonzero diagonal are all rejected).
>    The *counts* (3,2,0,220,263) remain transcription and are now labelled
>    `[LOADED]`; 488 is corroborated independently by the catalog's n=7 corpus size.
>    `test_proposition2.jl`'s filler asserts are gone: `Q_zero` is now checked to be
>    **rejected** by Proposition 2 (it violates Theorem 1), against an `alpha` that
>    is accepted.

- **Location:** `packages/VBFRepro/papers/Kalgin_202000/test/test_section5.jl`
- **Symptom:** Every assertion compares hardcoded literals to hardcoded
  expectations (`counts == [3,2,0,220,263]`, `total == 488`, `row2[2] == 0`).
  **It would pass verbatim if §5 were fabricated.**
- **Root cause:** §5 is transcribed, not computed — which the report *does* label
  honestly as `[LOADED] … NOT recomputed`. The test, however, presents
  transcription as verification.
- **Resolution plan:** At minimum, verify the 5 rows are QAM-extendable /
  consistent with Proposition 1. Ideally derive them via the paper's P1/P2
  lexicographic minimisation. **Needs a decision — see Open Questions.**
  Also: `test/test_proposition2.jl:16-17` has filler asserts
  (`@test Q_zero isa Matrix{Int}`, `@test size(Q_zero) == (n+1,n+1)`) with a
  comment conceding *"just check it runs"*.

**R4. [RESOLVED] The novelty check is far weaker than the repo supports.**

> **Fix:** the one-function mugshot comparison is replaced by
> `n7_sigma_classification(F7)` (`section4.jl`), which computes σ for **all 488**
> n=7 quadratic-APN representatives in the catalog and reports
> `total = 488`, `matches = [550]` (`reprs7_487`), `mismatches = 487`. Since σ is a
> CCZ-invariant, the 487 σ-**mismatches** are a rigorous inequivalence certificate
> — that *is* the paper's claim. The single σ-match is not treated as proof: it is
> settled with `are_ea_equivalent_quadratic` and confirmed to be F7's own class.
> The check is written in terms of σ-mismatch, not `:known`; `classify_ccz` is only
> asserted to return `:sigma_match`. *Mutation-tested:* making the σ comparison
> always match breaks 3 assertions.

- **Location:** `packages/VBFRepro/papers/Kalgin_202000/section4.jl:184-188`,
  `packages/VBFRepro/papers/Kalgin_202000/test/test_section4.jl:53`
- **Symptom:** Checks only `apn_ea_mugshot(F7) != apn_ea_mugshot(gold7)` — a
  single comparison against one function.
- **Root cause:** The repo ships a 488-entry n=7 σ-index plus `classify_ccz` /
  `is_novel`, none of which is used.
- **Resolution plan:** Replace with `classify_ccz(F7)` / `is_novel(F7)` against the
  σ-index, and assert σ-uniqueness among the 488 — which is exactly the paper's
  claim, and it holds (see Catalog status).

**R5. [RESOLVED] Unflagged null result presented as a finding.**

> **Fix:** the n=4 → n=5 line in `section3_report` is now an explicit
> `[PASS] EXPECTED NULL` check covering **both** `g₅ = null` and
> `g₅ = all-quadratic`, with the evidence stated inline: the search enumerates all
> 2²⁰ = 1,048,576 α vectors (the `limit` never binds, so it is exhaustive), and
> neither of the 2 n=5 CCZ-classes is reachable from Gold n=4. `test_proposition2.jl`
> asserts both emptiness results **and** that the same code does find extensions
> when they exist — so the test cannot pass by `section3_search` being broken.

- **Location:** `packages/VBFRepro/papers/Kalgin_202000/section4.jl`
- **Symptom:** `n=4 Gold → n=5, g_5=null: CCZ-classes: 0` is printed with no
  comment and no pass/fail.
- **Root cause:** The 0 is *correct* (confirmed exhaustively over all 2²⁰ α, for
  both `g₅=null` and `g₅=allquad`), but it reads as a result rather than an
  expected null.
- **Resolution plan:** Label it as an expected null with the confirming evidence.

**R6. [RESOLVED] `report.jl` mislabels unimplemented work as "[EXACT]".**

> **Fix:** the scope block is rewritten. §3's Proposition 1 is now genuinely
> implemented (`proposition1_apn`, as stated in the paper) so `[EXACT]` is earned;
> the n=5→6 line is labelled `[SUBST]` (VBF's `extend_quadratic_apn` is the
> Beierle–Leander–Perrin tree search, a *different* algorithm, and the sample is
> bounded); §4's cyclic-T line now states the corrected 1/1, 1/1, 2/2 coverage;
> §5 is split into `[PARTIAL]` (normalisation + Proposition-1 checks, computed) and
> `[LOADED]` (the counts, transcribed); a new `[ABSENT]` line lists what is not
> attempted (§3's pruned all-13 search, §5's P1/P2 minimisation, Props 4–6,
> Thms 2–3, Cors 1–2).

- **Location:** `packages/VBFRepro/papers/Kalgin_202000/report.jl:25-26`
- **Symptom:** §3 is labelled *"[EXACT] Proposition 2 criterion"* — the criterion
  is **never implemented** (it is silently delegated to `is_qam`). §4 is labelled
  *"[EXACT] cyclic T matrix construction (n≤5)"* — the n=5 count is wrong (R1/R2).
- **Resolution plan:** Correct both labels. (§5's `[LOADED]` label is honest.)

**R7. [RESOLVED] Field pinning is correct but unasserted.**

> **Fix:** `helpers.jl` defines `const PAPER_MODULUS_N7 = 0b10000011` and errors at
> load time if `primitive_polynomial(7)` ever stops matching it (with a message
> explaining that §4's `a^i` coefficients would then be read in the wrong field).
> `test_proposition2.jl` asserts both. Checked for the sibling-paper hazard: no
> code here assumes the primitive element is 2 at n=8, and the only n=8 object used
> (Kasami, §6.1) is built from `kasami_apn(8, 3)` — `gcd(k,8)=1` forces `k=3`, and
> the test asserts VBF's default `k=2` throws.

- **Location:** `packages/VBFRepro/papers/Kalgin_202000/helpers.jl`
- **Symptom:** The paper pins `x⁷+x+1`, and `primitive_polynomial(7) = 131 =
  0b10000011 = x⁷+x+1`. Correct today, but nothing asserts the repo default
  matches the paper.
- **Resolution plan:** Add `@assert primitive_polynomial(7) == 0b10000011`.

**R8. [RESOLVED — cheap items added] Missing items.**

> **Fix (all now implemented + tested):**
> - **Theorem 1** — `beth_ding_all_terms_present` (`proposition2.jl`), checked on
>   every APN matrix n=3..7, *and* shown non-vacuous: zeroing any single
>   off-diagonal entry of the Gold n=5 matrix breaks APN (10 cases).
> - **Proposition 1** — `proposition1_apn`, implemented **as stated**
>   (`x·M·aᵀ ≠ 0 ∀ x,a ≠ 0, x ≠ a`), no longer silently delegated to `is_qam`.
>   Cross-checked against `is_qam` *and* the DDT on the Gold matrices and on 300
>   random symmetric matrices, with a non-vacuity guard asserting the random sample
>   contains both QAMs and non-QAMs (it does: 19 vs 581 at the review's seed).
> - **Examples 1 and 2** — `example1_matrix`, `example2_matrix`; APN/quadratic
>   confirmed, Example 2 shown to be the construction-(1) extension of Example 1
>   (`build_extended_qam(G, zero_extra_qam(3), α, 3) == ℱ`). Both matrices are
>   pinned against the paper's **ANF** via an independent reconstruction in the
>   test, not against a copy of themselves.
> - **Proposition 3** + its 5-variable `G` — `proposition3_example_matrix`;
>   `Δ_G = 4` (bound attained, G not APN). Also pinned against the ANF *and* shown
>   to be a completion of §4's cyclic `T(5)` with `t₃₅ = 5, t₄₅ = 31`.
>   (`Δ_G = 4` alone does **not** pin the data — corrupting entry (4,5) to 30 keeps
>   `Δ_G = 4`; the ANF cross-check catches it. Mutation-tested.)
> - **§6.1** — `quadratic_part_claims_6_1` (`table3.jl`): Dillon n=6, Kasami n=8
>   (`k=3`), inverse n=9 all give `Δ(F⁽²⁾) = 8`, each also spelled out literally.
>   Proposition 4 spot-checked (`Δ(F⁽²⁾) ≤ 4` for n=4). Note `Δ(F⁽²⁾)` is
>   representation-independent: a basis change is linear and linear maps preserve
>   the degree-2 homogeneous part.
> - **§6.2's n=6 example** — `switching_example_n6`: `Δ(C)=2, deg(C)=3,
>   Δ(C⁽²⁾)=2`, and `C ⊕ C⁽²⁾` touches only bit 0 (h is a single cubic term on
>   `c₁`). *Mutation-tested:* changing that term to `x₂x₃x₄` breaks the suite.
>
> **Still absent (out of scope, unchanged):**
- **Proposition 4** (only spot-checked, not proved exhaustively), **Theorem 2**
  (Edel–Pott switching — core exports
  `switching_neighbors`), **Proposition 5**, **Corollary 1**, **Proposition 6**,
  **Remark 3**, **Corollary 2**, **Theorem 3** — none implemented.
- **§4 coverage claims** for n=6 (11/13), n=7 (7 classes), n=8 (1 class); the
  "**remove exactly one** e_n" variant (n=6 → all 13) is not expressible —
  `kalgin_T` is all-or-nothing.
- **§5 n=8**: the 11 second-row cases are not transcribed at all.
- **Open Question Q1** counterexample (n=6 APN #11).

The **§3 headline claim** (the 5-var `G` + all-quadratic `g₆` → all 13 CCZ-classes
of n=6) is not attempted: `section3_search` is **unpruned**, so n=5→6 costs
64⁵ ≈ 1.07e9 leaves and cannot run. The paper's own algorithm prunes
incrementally — that pruning is the missing piece.

---

## Core-library issue surfaced by this review

*(Not paper-local — belongs in `packages/`, its own commit.)*

**C1. Does core's `search_qam` carry the same under-count as R1?**

- **Location:** `packages/VBF/src/constructions/qam_search.jl`
- **Symptom:** Core's `search_qam` **also dedups by `apn_ea_mugshot`** — the same
  necessary-but-not-sufficient invariant that makes R1 wrong. Since Gold x³ and x⁵
  collide at n=5, core may be under-counting classes in exactly the same way.
- **Resolution plan:** Audit `search_qam` (and any other core dedup path keyed on
  `apn_ea_mugshot`) and confirm mugshot buckets with `are_ea_equivalent` before
  collapsing them. **Still not fixed — explicitly out of scope for the R1–R8 pass,
  which is paper-local. Owned by the core pass.**

---

## Items reproduced exactly (context)

| Paper item | Evidence |
|---|---|
| **§4 new n=7 APN function** (28-term polynomial) | all 28 coefficients match the PDF; `differential_uniformity = 2`, `algebraic_degree = 2` |
| **§4 cyclic matrix `T`** (`kalgin_T`) | index-by-index match with the paper's `T`; `remove_e_n` correctly targets the `i+j = n+2` sub-diagonal |
| **§6 Table 3** (n=4,5,6 stacked cubic APN) | all LUTs transcribed exactly; `F` APN/cubic, `F⁽²⁾` APN/quadratic, `quadratic_part(F) == F⁽²⁾` |
| §5 five second-row cases + counts (3,2,0,220,263 → 488) | rows: **checked** against Theorem 1 / Proposition 1 (R3 fixed); counts: **transcription** (still `[LOADED]`); 488 corroborated by the catalog's n=7 corpus |
| §5 first-row normalisation | **computed** (`normalize_first_row`) — Gold x³/x⁵/x⁹ and F7 all normalise to `(0,1,2,4,8,16,32)`, stay QAMs, keep their σ |
| §3 Proposition 1 | **implemented as stated** (`proposition1_apn`) and cross-checked against `is_qam` + the DDT on Gold n=3..7 and 600 random matrices (R6/R8 fixed) |
| §3 Proposition 2 (as `is_qam` on the extended QAM) | mathematically sound (independently verified: **1,052,672 α vectors, 0 disagreements**) |
| §3 Theorem 1, Examples 1-2, Proposition 3's `G` | **implemented + tested**, data pinned against the paper's ANF (R8) |
| §6.1 quadratic parts, §6.2 n=6 example | **implemented + tested** — `Δ(F⁽²⁾) = 8` for Dillon/Kasami/inverse; `Δ(C)=2, deg=3, Δ(C⁽²⁾)=2` (R8) |

## Failure-pattern audit (explicitly checked)

| Pattern | Verdict (at review) | Now |
|---|---|---|
| **Vacuous tests** | **PRESENT** — R3 (`test_section5.jl` fully tautological; `test_proposition2.jl` filler asserts) | **FIXED** — §5 computes the normalisation + Proposition-1 conditions; 4 mutation tests guard them; the filler asserts are replaced by an accept/reject pair |
| **False paper-issue claims** | **PRESENT** — R2 | **FIXED** — note deleted, verified statement asserted |
| **Copy-paste stubs** | **ABSENT** | ABSENT |
| **Field-representation fragility** | **Effectively absent** — correct today, but unasserted (R7) | **FIXED** — load-time check + test; n=8 Kasami `k=3` asserted |
| **Overclaiming report** | **PRESENT (mild)** — R6 | **FIXED** — `[EXACT]`/`[SUBST]`/`[PARTIAL]`/`[LOADED]`/`[ABSENT]` |

## Test results (after the R1–R8 fixes)

All Julia run through a 2 GiB-capped cgroup wrapper. **No OOM, no exit 137,
nothing skipped for memory.**

| Command | Before | After |
|---|---|---|
| `test/runtests.jl` | 164/164 (2.4 s) | **1272/1272 PASS** (17 s) — proposition2 1084, section4 47, section5 88, table3 53 |
| `report.jl` | clean (4.4 s) | clean (51 s) — the extra time is the exact EA decision at n=6/7 and the 488-rep σ scan |

**Non-vacuity evidence (mutation tests — each mutant makes the suite fail):**

| Mutation | Detected by |
|---|---|
| `dedup_ea` reverted to mugshot-only (the R1 bug) | `test_section4.jl` — 4 failures (n=5 → 1 class) |
| `row_offdiag_independent` → `return true` | `test_section5.jl` — 3 failures |
| Proposition 3's matrix entry `31` → `30` | `test_proposition2.jl` — 2 failures (ANF + T(5) cross-checks; note `Δ_G = 4` still holds, so the Δ-check alone would **not** have caught it) |
| §6.2's cubic term `x₂x₃x₅` → `x₂x₃x₄` | `test_table3.jl` — 2 failures |
| σ comparison in `n7_sigma_classification` → always match | `test_section4.jl` — 3 failures |

**Not attempted — combinatorially infeasible, not memory-bound:** exhaustive
cyclic search at n=6 (modified `T`: 64⁶ ≈ 6.9e10 leaves) and n=7 (128⁹ ≈ 1.4e19
leaves); these need the paper's incremental Proposition-2 pruning, which the repro
does not implement. The §5 P1/P2 minimisation (which produced the 488) likewise
was not run — the paper used a supercomputer.

## Catalog status

**The new n=7 function is `not-new` w.r.t. the repo's indexed corpus — but the
paper's actual claim is VERIFIED.**

- `classify_ccz(F7)` → **`(:known, "functions", 550)`** = `reprs7_487` — the 488th
  (0-indexed 487) representative of the BFA/sboxU n=7 quadratic-APN list.
  `is_novel(F7)` → **`false`**.
- The earlier "CCZ-inequivalent to all `n7_apn.toml` entries" finding is **true but
  vacuous**: that TOML holds only **8 monomials** (Gold x³/x⁵/x⁹, Kasami x¹³/x⁵⁷,
  Welch x¹¹, Niho x³⁹, Inverse x¹²⁶), while the known n=7 list has **488** classes.
  Inequivalence to 8 monomials is not evidence of novelty. Against
  `BFA_catalog.sqlite` + `ccz_sigma_index` (which *do* hold all 488), the function
  is **present**.
- **The paper's claim nonetheless holds rigorously**: F7's σ-hash
  `8456e28c…` occurs **exactly once** among the 488 classes. σ-mismatch is a
  rigorous CCZ-inequivalence certificate, so F7 is provably CCZ-inequivalent to the
  other **487** — precisely what the paper asserts. (F7 is *not* part of the single
  σ-collision pair that exists among the 488.)

Levels reached: formula reproduced → APN verified → novelty/equivalence claim
checked (**by this review, not by the repro**). Not reached: the §5 completeness
proof.

### Catalog-gap record — curated TOML only, **NOT a world-novelty claim**

```
target file: packages/VBFCatalog/data-raw/apn_catalog/n7_apn.toml
name           = "n7_KalginIdrisova_new"
n = 7, m = 7, is_permutation = false
lut = [0,0,0,1,0,2,4,7,0,4,8,13,16,22,28,27,0,8,16,25,32,42,52,63,75,71,83,94,123,117,103,104,
       0,16,32,49,107,121,79,92,46,58,6,19,85,67,121,110,96,120,80,73,43,49,31,4,5,25,61,32,94,64,98,125,
       0,32,127,94,85,119,46,13,112,84,7,34,53,19,70,97,79,103,32,9,58,16,81,122,116,88,19,62,17,63,114,93,
       12,60,83,98,50,0,105,90,82,102,5,48,124,74,47,24,35,27,108,85,61,7,118,77,54,10,113,76,56,6,123,68]
algebraic_form = "a^100x + a^88x^2 + a^89x^3 + a^107x^4 + a^57x^5 + a^98x^6 + a^56x^8 + a^9x^9 + a^58x^10 + a^60x^12 + a^109x^16 + a^47x^17 + a^44x^18 + a^27x^20 + a^91x^24 + a^71x^32 + a^96x^33 + a^101x^34 + a^7x^36 + a^12x^40 + a^34x^48 + a^66x^64 + a^4x^65 + a^4x^66 + a^73x^68 + a^73x^72 + a^56x^80 + a^20x^96 in GF(2^7), modulus x^7 + x + 1"
bib_key        = "Kalgin_202000"
source         = "Kalgin & Idrisova, Cryptogr. Commun. 14:691-715, section 4 ('we have found a new CCZ-class for n = 7')."
```

**Evidence and caveat for the updater:** this function is **equivalent to existing
corpus row `functions.id = 550`** (`reprs7_487`). Its σ-hash
`8456e28c87f69bf4d198a39dda0a1d065384efe6258eb68949199b9b08d412ca` is unique among
the 488 n=7 classes. Add it as the **named representative of an already-indexed
class**, *not* as a novel discovery. (It was independently found by
Beierle–Leander, as the paper itself notes in §2.3.)

## Library-reuse note

| Helper | Issue | Status |
|---|---|---|
| `helpers.jl:12-17` `print_header` | duplicates the core report emitter (same `"="×72` frame) | **open** — cosmetic; `print_banner` would replace it |
| `helpers.jl:44-52` `dedup_ea` | **correctness bug**, not merely reuse (R1) | **FIXED** — mugshot buckets + `ea_mappings_from_ortho_derivative` confirmation |
| `section4.jl:86` dedup | same bug, inlined | **FIXED** — inlined dedup removed; search split into `cyclic_raw_qam_solutions` + `dedup_ea` |
| `proposition2.jl:152` `extend_quadratic_apn` | core's function is the **Beierle–Leander–Perrin** tree search — a *different* algorithm from Kalgin §3, substituted without labelling | **LABELLED** (`[SUBST]` in `report.jl` + section note); §3's pruned search still not implemented |

**Correctly paper-specific (not violations):** `kalgin_T`, `unknown_positions`,
`build_extended_qam`, `zero_extra_qam`, `allquad_extra_qam`, and the §5 / Table-3
data. Note core's `qam_from_cyclic` / `qam_cyclic_orbits` is a *different* "cyclic"
notion (Frobenius-orbit QAM over GF(2ᵐ), Ivković–Nikova), **not** Kalgin's
standard-basis anti-diagonal `T` — re-implementing was correct.

**Promote-to-core candidate:** `quadratic_part` (`helpers.jl:27-34`). A generic
"homogeneous degree-k part of a vectorial Boolean function" has no core
equivalent, is needed by §6 here, and would serve other papers. Belongs in
`packages/VBF/src/`, generalised to arbitrary degree.

## Open questions (still need a human decision)

1. **§5 scope — still open.** Deriving the 5 second-row cases via the paper's own
   P1/P2 lexicographic minimisation was **not** attempted: the search space is
   `|GL(2,2)| × |GL(5,2)| × 2¹⁰ ≈ 6.1e10` matrices `P`, times the `L` search per
   `P`. R3 was instead closed by computing §5's *first-row normalisation* and
   checking every case against the Proposition-1 / Theorem-1 necessary conditions.
   If a full derivation of the cases is wanted, that is a separate work item.
2. **`extend_quadratic_apn` substitution — still open, now labelled.** §3's n=5→6
   line still uses VBF's Beierle–Leander–Perrin tree search instead of Kalgin's
   pruned Proposition-2 search. It is now explicitly marked `[SUBST]` in the report
   and in the section note, and the sample is bounded at 50 (the exact EA decision
   costs ~0.8 s per pair at n=6). Implementing §3's pruning would also unlock the
   "all 13 CCZ-classes of n=6" claim — not done.
3. **σ-index incompleteness (C1) — out of scope here, unchanged.** Core's
   `search_qam` dedups on `apn_ea_mugshot` and is exposed to the same under-count
   this paper's R1 had. Owned by the core pass, not fixed here.
4. **Catalog record.** The `n7_KalginIdrisova_new` TOML record below was **not**
   written (out of scope for this pass). It remains a record for whoever updates
   `packages/VBFCatalog/data-raw/apn_catalog/n7_apn.toml`.
