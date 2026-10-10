# Budaghyan_202011 — A New Family of APN Quadrinomials

**Paper:** L. Budaghyan, T. Helleseth, N. Kaleyski, *A New Family of APN
Quadrinomials*, IEEE Trans. Inf. Theory 66(11):7081–7087, 2020.

**Reproduction:** `packages/VBFRepro/src/202011-budaghyan-quadrinomials/` — `helpers.jl`, `observation1.jl`,
`proposition1.jl`, `lemma3.jl`, `theorem2.jl`, `lemma4.jl`, `corollary1.jl`,
`table3.jl`, `report.jl`.

**Verdict (after the fix pass):** **Good.** Observation 1, Proposition 1,
Lemma 3, Theorem 2, Lemma 4 and Corollary 1 are all implemented and
non-vacuously tested. The paper's central claim is now actually checked: all 13
rows of Table III are built (including `B(x)`, Kasami, both F3 reps, both F4 reps
and the six Taniguchi/F12 reps) and C₃/C₇ are shown pairwise-distinct from every
**quadratic** row by ortho-derivative mugshot — which, by Yoshiara, settles
CCZ-inequivalence for those rows. Separation from the two **non-quadratic** power
maps (Kasami x⁵⁷, Dobbertin x³³⁹) remains *not* invariant-backed in-repo, and the
code now says so explicitly instead of leaning on a struct tag. The paper erratum
(Corollary 1 item 8) is recorded with its `du = 32` evidence.

**Test suite:** 36/36 → **238/238 pass** (~57 s). Nine mutants injected against
the new assertions; **all nine killed** (see "Non-vacuity evidence" below).

**Previous verdict (pre-fix):** *Partial* — `B(x)` was never constructed, plus one
fabricated "paper typo", one wrong transcribed Γ-rank, one tautological test, a
mislabeled theorem, and a real paper erratum that went unnoticed.

---

## Issue Catalog

### Paper Issues

**P1. Corollary 1 item 8 is wrong — and the paper contradicts itself.**
**[RECORDED — `corollary1.jl`, `test/test_corollary1.jl`]**

Corollary 1 item 8 claims `(a,b,c) = (β,β²,1)`, `i = n−1`, `k` odd yields an APN
function. Computed at n=10: **`du = 32`** — not APN — for both k=1 and k=3.

The paper's own prose immediately after Lemma 4 (tex:446) says *"When k is odd,
the case of i = n−1 does allow non-trivial solutions"*, and **Lemma 4's list
omits `n−1`**. So the corollary contradicts the lemma it is derived from.

*Now implemented, not silenced.* `corollary1_items(n)` carries all eight cases
with item 8 tagged `erratum = true`; `corollary1_report` prints the measured
`du = 32` for k ∈ {1,3} together with the two in-paper corroborations (Lemma 4's
i-list, tex:446). `test_corollary1.jl` asserts `du == 32` at n=10 for k=1 and
k=3, asserts the erratum reproduces at n=14 (i=13, k=1), and — for non-vacuity —
asserts that the *even-k* sibling (item 5, same i = n−1) **is** APN and that odd-k
items 6 and 7 **are** APN, so "du ≠ 2" is not trivially satisfied for odd k.

### Reproduction Issues

**R1. FABRICATED paper-issue claim.** **[RESOLVED]**

- **Location:** `packages/VBFRepro/src/202011-budaghyan-quadrinomials/table3.jl:36-39`, and the printed note at
  `table3.jl:55-56`
- **Symptom:** The code states: *"The paper's TeX lists `x^5 | Gold | 136492`. x^5
  is NOT APN over GF(2^10) … likely TeX conversion artifact."*
- **Root cause:** The tex line 473 reads `$x^{9}$ & Gold & 136492`. The string
  `x^5` appears **nowhere** in the tex. The erratum is invented, and it defames
  the paper in a committed source comment.
- **Resolution:** Re-verified independently against `input/*.tex`
  (`grep 'x\^{ *5 *}\|x\^5'` → **no match**; tex:473 is `$x^{9}$ & Gold & 136492`).
  Both the docstring claim and the printed note are **deleted**. `table3.jl` was
  rewritten and contains no reference to `x^5`.

**R2. Wrong transcribed Γ-rank — a row-shift error.** **[RESOLVED]**

- **Location:** `packages/VBFRepro/src/202011-budaghyan-quadrinomials/table3.jl:44`
- **Symptom:** Sets `x^9 → gamma_rank_paper = 186416`. The paper says
  **Γ(x⁹) = 136492** (tex:473); **186416 is Kasami x⁵⁷'s** rank (tex:475).
- **Root cause:** Transcription slipped one row. Undetected because
  `test_table3.jl` only asserts the C₃/C₇ literals.
- **Resolution:** `x^9 → 136492`. **Every** Γ-rank in the table was then
  re-checked against the tex line by line, and each is now asserted in
  `test_table3.jl` with its tex line number: 125042 (tex:471), 136492 (473),
  186416 (475), 280604 (477), 151216 (479), 153896 (481), 153896 (483), 164098
  (485), 169984 (489), 166068 (491), 166168 (493), plus the five F12 values
  (487) as an unordered set — the paper gives 5 ranks for 6 reps, so no rank can
  be pinned to an individual representative.

**R3. Mislabeled theorem — and it collides with a real, different result.**
**[RESOLVED]**

- **Location:** `packages/VBFRepro/src/202011-budaghyan-quadrinomials/theorem4.jl`, `theorem4_report`,
  `test/test_theorem4.jl`, the `make theorem4` target, and the report line
- **Symptom:** All say "Theorem 4". The paper has **no Theorem 4** — the result
  implemented is **Theorem 2** (tex:256).
- **Root cause:** Worse than cosmetic: a **Lemma 4 does exist** (tex:433, the
  odd-k case) and is a *different, unimplemented* result. The name actively
  misleads a reader into thinking Lemma 4 is covered.
- **Resolution:** `git mv theorem4.jl → theorem2.jl` and
  `test/test_theorem4.jl → test/test_theorem2.jl`; `theorem4_i_values` →
  `theorem2_i_values`, `theorem4_report` → `theorem2_report`; `make theorem4` →
  `make theorem2`; report line updated. The real Lemma 4 now lives in
  `lemma4.jl` (see R9), so the collision is gone rather than merely renamed away.

**R4. TAUTOLOGICAL TEST — asserts literals against the literals they came from.**
**[RESOLVED]**

- **Location:** `packages/VBFRepro/src/202011-budaghyan-quadrinomials/test/test_table3.jl:19-23`
  ```julia
  gamma_ranks = Dict(f.name => f.gamma_rank_paper for f in funcs)
  @test gamma_ranks["C_3"] == 166068
  @test gamma_ranks["C_3"] != gamma_ranks["C_7"]  # → CCZ-inequivalent
  ```
- **Symptom:** Nothing is computed. The values are transcribed from the paper and
  then asserted against themselves, and the `# → CCZ-inequivalent` comment
  presents a transcription as a *result*.
- **Resolution:** Both. The `gamma_ranks[C_3] != gamma_ranks[C_7] # → CCZ-inequivalent`
  assert is **gone**; the surviving Γ-rank asserts are explicitly labelled
  *transcription checks against the tex*, not results. The CCZ claim is now
  carried by a **computed** invariant: all 15 quadratic Table III rows are shown
  to have pairwise-distinct ortho-derivative mugshots. Non-vacuity is asserted in
  the same test — C₃, C₇ and B(x) all share the **same extended Walsh spectrum**,
  so the coarser invariant separates none of them and the ortho-derivative is
  demonstrably doing the work; and the Frobenius conjugate of C₃ (a different LUT,
  same EA class) is asserted to have the **same** mugshot, so the check is not
  "everything differs".

**R5. The novelty claim — the paper's whole point — is never checked, and `B(x)`
is never built.** **[RESOLVED]**

- **Location:** `packages/VBFRepro/src/202011-budaghyan-quadrinomials/helpers.jl:70-77` (`build_ci_sbox`),
  `packages/VBFRepro/src/202011-budaghyan-quadrinomials/table3.jl`
- **Symptom:** `build_ci_sbox` hardcodes `(a,b,c) = (β,β²,1)`, so **Corollary 1
  item 1 — `B(x) = x³ + βx³⁶`, with `(a,b,c) = (β,0,0)` — cannot even be
  expressed**. `B(x)` is the paper's central comparison object. Table III is
  reproduced at 5 of ~13 rows; Kasami x⁵⁷, both F3 reps, both F4 reps and all six
  F12 reps are absent.
- **Root cause:** The builder was written for one parameter set, not the family.
- **Resolution plan:**
  1. Generalise `build_ci_sbox` to take `(a,b,c)`.
  2. Build `B(x)`, and add Kasami (`kasami_apn`), the two F3 and two F4 reps, and
     `taniguchi_apn_representatives(5)` — which returns **exactly** the paper's six
     CCZ-inequivalent F12 representatives.
  3. Compare via ortho-derivative mugshot. Verified during review: C₃, C₇, B,
     Gold x³, Gold x⁹, F3×2, F4×2 and F12×6 are **pairwise mugshot-distinct**, so
     the paper's claim holds.
  4. State plainly that separation from **Kasami x⁵⁷ and Dobbertin x³³⁹ is
     unverifiable in-repo** — it needs Γ-rank, and `gamma_rank` is guarded to
     n ≤ 7 (a dense 2²⁰×2²⁰ F₂ matrix is ~137 GB). Note C₃ and Kasami x⁵⁷ have the
     **identical extended Walsh spectrum**, so the repo's tooling genuinely cannot
     separate them (see R6).
- **Resolution:** All four steps done.
  1. `build_ci_sbox(n, i, k; a, b, c, modulus)` now takes the GF(4) coefficients;
     a zero coefficient drops its term. Defaults stay `(β, β², 1)`.
  2. `B(x) = x³ + β·x³⁶` is `build_ci_sbox(10, 3, 2; b=0, c=0)` — asserted equal
     to `x³ + α³⁴¹x³⁶` rebuilt straight from the Table III row, `du = 2`, `deg = 2`.
     `table3_functions()` now returns **17 S-boxes** (13 table rows, with F12
     expanded to its six reps): `gold_apn(10,1)`, `gold_apn(10,3)`,
     `kasami_apn(10,3)`, `dobbertin_apn(10)`, both F3 trinomials, both F4 trace
     forms, `taniguchi_apn_representatives(5)` (returns **exactly six**, matching
     tex:485), `B(x)`, `C₃`, `C₇`. Every one is asserted APN.
  3. `novelty_report` + `test_table3.jl`: the 15 quadratic rows have **15 distinct**
     ortho-derivative mugshots (0 collisions).
  4. **CRITICAL CAVEAT, now stated in code** (`table3.jl` header + the second half
     of `novelty_report`, and asserted in `test_table3.jl`): separation from
     **Kasami x⁵⁷ and Dobbertin x³³⁹ is NOT invariant-backed here.** C₃ and C₇ have
     the *identical* extended Walsh spectrum as x⁵⁷ (asserted), and `apn_ea_mugshot`
     would "separate" them only through its quadratic/non-quadratic **struct tag**,
     which certifies nothing. Both are non-quadratic **power** maps (deg 4, deg 5),
     so Yoshiara's power-function theorem excludes them on degree — but that is a
     **literature appeal, not a computation**, and the code says so. Γ-rank at n=10
     is out of reach: `gamma_rank` guards n ≤ 7 (asserted: `@test_throws
     ArgumentError gamma_rank(c3)`), and a dense 2²⁰×2²⁰ F₂ matrix is ~137 GB.

**R6. Semi-vacuous mugshot comparison.** **[RESOLVED]**

- **Location:** `packages/VBFRepro/src/202011-budaghyan-quadrinomials/table3.jl`, via
  `packages/VBF/src/invariants/mugshot.jl:110`
- **Symptom:** `apn_ea_mugshot` tags quadratic vs non-quadratic in *different
  struct variants*, so `C_3 ≠_EA x^339` PASSes on the **tag**, not on any
  invariant.
- **Root cause:** The check appears to establish inequivalence but is decided by a
  type tag. Critically, **C₃ and Kasami x⁵⁷ have identical extended Walsh
  spectra** — so had Kasami been included, its PASS would also have been
  tag-driven only.
- **Resolution plan:** Do not rely on the tag for cross-degree comparisons; say
  explicitly which separations are invariant-backed and which are not.
- **Resolution:** The comparison is now **split by degree**. Quadratic rows →
  mugshot, labelled *invariant-backed* (Yoshiara: CCZ = EA for quadratic APN).
  Non-quadratic rows → **no computational inequivalence claim is made at all**;
  the report prints the extended-Walsh comparison showing x⁵⁷ is IDENTICAL to C₃
  and therefore inseparable in-repo. No PASS anywhere is decided by a struct tag.

**R7. Proposition 1 is overclaimed as a biconditional.** **[RESOLVED]**

- **Location:** `packages/VBFRepro/src/202011-budaghyan-quadrinomials/proposition1.jl:10` (and the report line)
- **Symptom:** States *"E_i trivial ↔ C_i is APN"*. The paper's Proposition 1 is
  **one-directional**: *if* E_i has only trivial solutions, *then* C_i is APN.
- **Root cause:** The biconditional happens to hold at n=10, k=0 — but it is false
  in general: at k=1, `i=1` gives an APN `C_i` that is **not** a Theorem-2 value
  (verified: du=2).
- **Resolution plan:** Soften to the paper's one-directional statement; keep the
  empirical biconditional as a separate, clearly-labelled observation.
- **Resolution:** `proposition1.jl` now states the paper's implication only
  (*E_i trivial ⇒ C_i APN*), and `check_proposition1` returns `sufficient` and
  `converse` as **separate** fields. The section header is *"E_i trivial ⇒ C_i is
  APN"*; the converse is printed under a header that says outright *"Observation
  (ours, NOT the paper's claim)"*. `test_proposition1.jl` asserts `sufficient`
  under the Proposition 1 heading and `converse` only under the observation, plus
  the non-vacuity facts (hypothesis true for exactly 4 of 9 i-values; conclusion
  false for 5 of 9). The concrete counterexample to reading Theorem 2's i-list as
  exhaustive is asserted: at **k=1, i=1** the quadrinomial is APN (`du = 2`) even
  though `1 ∉ {3,5,7,9}`, while at k=0 the same i gives `du = 32`.
  *Correction to the review's framing:* the **generalised** biconditional
  (E_i^(k) trivial ⟺ C_i^(k) APN) does in fact hold at n=10 for every k ∈ 0..3 we
  swept — the APN i-set moves with the parity of k ({3,5,7,9} even, {1,3,5,7} odd)
  and the E_i^(k) trivial set moves with it. So the overclaim is real, but the
  failure is *"Theorem 2's list ≠ the APN set for odd k"*, not a counterexample to
  the criterion itself. Both facts are now in the code and the tests.

**R8. Latent integer overflow.** **[RESOLVED]**

- **Location:** `packages/VBFRepro/src/202011-budaghyan-quadrinomials/helpers.jl:69`
- **Symptom:** `Int64(2^(i+m) + 2^m)` evaluates `2^(i+m)` in 64-bit **before**
  widening. For `i+m ≥ 63` — reachable within the paper's own claimed experimental
  range n ≤ 46 (e.g. `i = n−1` ⇒ `i+m = 3n/2−1 = 68`) — this silently wraps.
  `make theorem4 n=…` exposes it.
- **Resolution:** Both halves of the plan. The hand-rolled LUT is gone
  (`build_ci_sbox` now calls `terms_to_lut`, R10), and the exponent math is
  extracted into `ci_exponents(n, i, k)`, computed in **`Int128`** with `i, k`
  first reduced mod n. `test_observation1.jl` asserts every exponent stays in
  `[1, 2ⁿ−1]` for `(n,i,k)` ∈ {(46,45,0), (46,45,3), (46,23,1), (62,61,5)} and
  pins the n=46, i=45 value against the correct `Int128` result — a regression that
  the old `Int64` expression fails (mutant 6, killed).

**R9. Coverage: only n=10, only even k.** **[RESOLVED]**

- **Symptom:** Lemma 4 (odd k, `i ∈ {m+2, m, (m+2)⁻¹}`) is entirely missing —
  verified during review to hold (k=1: `i ∈ {3,5,7}` all APN). Lemma 1 and Lemma 3
  (P(N) has exactly roots `{0,1,S,S+1}`) are not implemented; Lemma 3 is trivially
  testable. Only n=10 is ever exercised — the family also holds at **n=14**
  (exactly four APN i-values, `{3,5,7,13}`), which the repo never tests.
- **Resolution:**
  - **Lemma 4** → `lemma4.jl`. `system_Ei_trivial(n, i; k)` was generalised to
    raise the second equation to `2^k`, so it now expresses system (16)/(17) as
    well as (2). Verified for k ∈ {1,3}: `i ∈ {m+2, m, (m+2)⁻¹} = {7,5,3}` all give
    trivial E_i^(k) *and* APN C_i. The **exclusion of i = n−1** (tex:446) is
    asserted as real: non-trivial solutions **and** `du = 32`.
  - **Lemma 3** → `lemma3.jl`. Exhaustive over every `S ∈ GF(2^m)\{0,1}` and every
    `N ∈ GF(2^m)`, for m ∈ {5,7} and every `i` with `gcd(i,m)=1`: the root set is
    **exactly** `{0,1,S,S+1}` — four roots, not "at least four" (a P that vanished
    identically would pass a containment check; that mutant is killed).
  - **n=14 regression** → `theorem2.jl:apn_i_values` + `test_theorem2.jl`:
    `apn_i_values(14) == [3,5,7,13]` == Theorem 2's four values at m=7. Also
    `apn_i_values(10; k=2) == [3,5,7,9]` (even-k branch).
  - **Corollary 1** → `corollary1.jl` (all 8 items; see P1).
  - **Lemma 1** is still *not* implemented — see "Still open" below.

**R10. Helpers duplicate core exports.** **[RESOLVED]**

| Helper | Location | Duplicates |
|---|---|---|
| `print_header` | `helpers.jl:16` | `print_banner` |
| `build_ci_sbox` (hand-rolls the LUT from `gf_pow`/`gf_mul`/`⊻`) | `helpers.jl:70-77` | `terms_to_lut` / `polynomial_to_lut` — also removes R8 |
| `_x339_dobbertin_n10` | `table3.jl:20-23` | `dobbertin_apn` |
| `_x9_gold_n10` | `table3.jl:25-28` | `gold_apn(10, 3)` (the file already uses `gold_apn(10,1)` for x³) |

Available but unused: `kasami_apn`, `taniguchi_apn_representatives(5)`,
`gamma_rank`. Legitimately paper-specific (do **not** flag): `beta_in_gfn`,
`in_beta_coset`, `system_Ei_trivial`. **Promote-to-core candidates: none.**

- **Resolution:** All four replaced, and the three "available but unused" core
  functions are now used.
  - `print_header` **deleted**; callers use `print_banner(PAPER_BANNER...)`
    (`PAPER_BANNER` is now just the two title strings, not a re-implemented banner).
  - `build_ci_sbox` builds its term list and calls **`terms_to_lut`** — the
    `gf_pow`/`gf_mul`/`⊻` comprehension is gone (this also removes R8).
  - `_x339_dobbertin_n10` → **`dobbertin_apn(10)`**; `_x9_gold_n10` →
    **`gold_apn(10, 3)`**; both helpers deleted.
  - Newly used: **`kasami_apn(10,3)`**, **`taniguchi_apn_representatives(5)`**
    (memoised — it costs ~40 s), **`gamma_rank`** (as the asserted n ≤ 7 guard),
    plus `gf_trace` for the F4 rows.
  - No changes were made under `packages/VBF/`.

**R11. Report phrasing.** **[RESOLVED]** `report.jl:22` / `table3.jl:53-54` say
*"Γ-rank … needs Magma"*. VBF **does** export `gamma_rank`/`delta_rank`
(`packages/VBF/src/invariants/design_ranks.jl:90`), guarded to n ≤ 7. The
infeasibility at n=10 is real, but the note should cite the repo's own guard
rather than imply the capability is absent.

- **Resolution:** The word *Magma* no longer appears anywhere in the paper folder.
  `observation1.jl`, `table3.jl` and `report.jl` now say: VBF exports `gamma_rank`
  but guards it to n ≤ 7 (`invariants/design_ranks.jl`), and the n=10 incidence
  matrix is 2²⁰×2²⁰ over F₂ (~137 GB dense). `test_table3.jl` asserts the guard
  fires (`@test_throws ArgumentError gamma_rank(c3)`) instead of asserting nothing.

---

## Non-vacuity evidence (mutation testing)

Nine bugs were injected one at a time into a scratch copy and the suite re-run.
**All nine were killed** — no assertion in the new suite passes for free:

| # | Injected bug | Guards |
|---|---|---|
| 1 | `gamma_rank_paper(x⁹) := 186416` (the original row-shift) | R2 |
| 2 | `build_ci_sbox` ignores `(a,b,c)` — B(x) inexpressible | R5 |
| 3 | `corollary1_du` always returns 2 (item-8 erratum silenced) | P1 |
| 4 | `lemma3_roots` returns the whole field (i.e. P ≡ 0) | R9 |
| 5 | `system_Ei_trivial` always returns `true` | Prop 1 / Thm 2 / Lem 4 |
| 6 | `ci_exponents` back to the wrapping `Int64` `2^(i+m)` | R8 |
| 7 | only 1 of the 6 F12 representatives returned | R5 |
| 8 | `lemma4_i_values` reverted to Theorem 2's list (`m−2` for `m+2`) | R9 |
| 9 | mugshot replaced by a constant in the novelty check | R4 / R6 |

---

## Still open (not addressed by this pass)

- **Lemma 1** (tex:211) is still unimplemented. It is a purely auxiliary step
  inside the Theorem 2 proof and is not needed for any claim we reproduce.
- **Γ-rank at n=10** cannot be computed in-repo (see R11). The Table III ranks
  remain transcribed. Consequence: CCZ-inequivalence of C₃/C₇ from **Kasami x⁵⁷
  and Dobbertin x³³⁹** is not established by any computation performed here — see
  the caveat in R5/R6, which is now written into `table3.jl` and asserted.
- **F3/F4 field representation.** The paper pins no primitive polynomial, so the
  F3/F4 rows (α³¹, α⁻¹) are representation-dependent. Under the repo default
  `0x409` (α = 2) all four are APN — asserted — but a different modulus could
  change them. Noted in the `table3.jl` header.

---

## Failure-pattern audit (explicitly checked)

| Pattern | Verdict (pre-fix) | Verdict (post-fix) |
|---|---|---|
| **False paper-issue claims** | **PRESENT — fabricated** (R1). And the *real* erratum (P1) was missed. | **CLEARED** — fabrication deleted (R1); the real erratum is implemented with evidence (P1). |
| **Vacuous / tautological tests** | **PRESENT** (R4, R6). | **CLEARED** — 9/9 mutants killed; the tautological Γ-rank assert is gone. |
| **Copy-paste stubs** | **ABSENT** — each of the four claim files is genuinely distinct. | **ABSENT** — the four new files (lemma3, lemma4, corollary1, theorem2) are distinct too. |
| **Field-representation fragility** | β is derived intrinsically as the order-3 element (β³=1, β≠1), and Observation 1 / Prop 1 / Thm 2 are stated purely in terms of β, so results are representation-independent. Traps: `beta_in_gfn` assumes α=2 is primitive for `primitive_polynomial(n)`; the Table III F3/F4 rows use α³¹ and α⁻¹, which **are** representation-dependent. `B′(x) = x³+α¹¹x³⁴¹` (tex:169) is **not APN** under the repo default (du=8), and the tex is internally inconsistent about B′ (tex:95 gives a different form). | **UNCHANGED, now documented.** The F3/F4 rows are built (and APN) under the repo default `0x409`; the `table3.jl` header states the dependence. B′ is deliberately **not** included in Table III — the paper does not list it there. |
| **Overclaiming** | **PRESENT** (R7, R11). | **CLEARED** — Prop 1 is one-directional (R7); the Γ-rank note cites VBF's own n ≤ 7 guard (R11); the non-quadratic separation is explicitly labelled *not invariant-backed* (R5/R6). |

## Items reproduced (context)

| Paper item | Evidence |
|---|---|
| **Observation 1** (tex:172) — C₃ = x³+βx³⁶+β²x⁹⁶+x¹²⁹, C₇ = x³+βx¹²⁹+β²x⁹⁶+x³⁶ | Both polynomials rebuilt from the tex independently of `build_ci_sbox` — **match bit-for-bit** (asserted in `test_observation1.jl`); `du = 2`, `deg = 2` |
| **Proposition 1** (tex:184) — system E_i (2) | The coset test (`y^(2^m) == β·y` ⟺ `y ∈ β·F₂ᵐ`) is correct for m odd; `system_Ei_trivial` is exhaustive over `a ∈ F*`, `x ∉ F₂`. Stated one-directionally (R7) |
| **Lemma 3** (tex:244) — P(N) has exactly the roots {0,1,S,S+1} | Exhaustive over all S and all N, for m ∈ {5,7} and every i with gcd(i,m)=1 |
| **Theorem 2** (tex:256) — `i ∈ {m−2, m, (m−2)⁻¹ mod n, n−1}` | Fully reproduced. **Non-vacuous**: the complement `i ∈ {1,2,4,6,8}` has non-trivial E_i solutions *and* is non-APN. Exhaustiveness re-checked at **n=14**: APN i-values = {3,5,7,13} |
| **Lemma 4** (tex:433) — odd k, `i ∈ {m+2, m, (m+2)⁻¹}` | k ∈ {1,3}: all three give trivial E_i^(k) and APN C_i. The omission of i = n−1 is asserted to be real (non-trivial solutions, du = 32) |
| **Corollary 1** (tex:454) — the eight claimed cases | Items 1–7 APN (du = 2), item 8 **not** APN (du = 32) — a paper erratum (P1) |
| **Table III** (tex:465) — all known APN classes over F₂¹⁰ | All 13 rows built (17 S-boxes with F12 expanded); every one asserted APN. Γ-ranks transcribed, each pinned to its tex line |
| **Novelty claim** (tex:172 / Corollary 1 closing) | C₃, C₇ pairwise-mugshot-distinct from all 15 quadratic rows, **including B(x)** — CCZ-conclusive by Yoshiara. **Not** established against x⁵⁷ / x³³⁹ (see R5/R6) |

## Test results (as run)

All Julia run through a 2 GiB-capped cgroup wrapper. **Nothing hit the OOM cap.**

| Command | Result |
|---|---|
| `test/runtests.jl` (pre-fix) | 36/36 pass, 3.8 s — but see R4/R6 |
| `test/runtests.jl` (post-fix) | **238/238 pass**, 57 s — observation1 22, proposition1 17, lemma3 73, theorem2 26, lemma4 23, corollary1 28, table3 49 |
| `report.jl` (post-fix) | runs clean, **every check PASS, 0 FAIL**, 51 s |
| mutation run (9 injected bugs) | **9/9 mutants killed** |

The dominant cost (~44 s) is `taniguchi_apn_representatives(5)`, which enumerates
the F12 class representatives; it is memoised per process.

Γ-rank at n=10 **not attempted** — not an OOM event: VBF's `gamma_rank` guards
n ≤ 7, and a dense 2²⁰×2²⁰ F₂ matrix is ~137 GB.

## Catalog status

`packages/VBFCatalog/data-raw/apn_catalog/n10_apn.toml` has exactly 4 entries
(`n10_Gold_x3`, `n10_Gold_x9`, `n10_Kasami_x57`, `n10_Dobbertin_x339`). All four
were loaded and compared against C₃/C₇ by ortho-derivative mugshot and exact LUT:
**no match on any**.

- **C₃ — missing (genuinely new; catalog gap)**
- **C₇ — missing (genuinely new; catalog gap)**
- **B(x) = x³+βx³⁶ — missing** (adjacent gap: Corollary 1 item 1 of *this* paper,
  though originally Edel–Kyureghyan–Pott 2006)

### Catalog-gap records

```
target: packages/VBFCatalog/data-raw/apn_catalog/n10_apn.toml

name           = "n10_BudaghyanHellesethKaleyski_C3"
n = 10, m = 10, is_permutation = false
algebraic_form = "x^3 + b*x^36 + b^2*x^96 + x^129 in GF(2^10), b = a^341 (primitive in GF(4)), modulus x^10 + x^3 + 1"
bib_key = "Budaghyan_202011"
source  = "Budaghyan, Helleseth, Kaleyski, IEEE Trans. Inf. Theory 66(11):7081-7087, 2020, Observation 1 / Corollary 1 item 2 (i = m-2 = 3, k = 2)."
lut     = 1024 entries; deterministic under modulus 0x409, beta = 237.
          fingerprint (first 16): 0,1,955,465,198,666,994,981,525,322,856,636,362,120,160,985
          regenerate: include("packages/VBFRepro/src/202011-budaghyan-quadrinomials/helpers.jl"); Int.(build_ci_sbox(10,3,2).lut)
evidence: du=2, deg=2; mugshot differs from all 4 existing n=10 entries and from
          B, Gold x3/x9, F3(2), F4(2), Taniguchi F12(6).

name           = "n10_BudaghyanHellesethKaleyski_C7"
n = 10, m = 10, is_permutation = false
algebraic_form = "x^3 + b*x^129 + b^2*x^96 + x^36 in GF(2^10), b = a^341, modulus x^10 + x^3 + 1"
bib_key = "Budaghyan_202011"
source  = "...Observation 1 / Corollary 1 item 3 (i = (m-2)^-1 mod n = 7, k = 0)."
lut     = 1024 entries; fingerprint (first 16): 0,1,170,465,450,666,522,40,451,153,420,388,933,422,160,985
          regenerate: Int.(build_ci_sbox(10,7,0).lut)
evidence: as above; also mugshot(C7) != mugshot(C3).
```

**Caveat for the catalog updater:** separation from `n10_Kasami_x57` and
`n10_Dobbertin_x339` is **not** invariant-backed here (see R6 — C₃ and Kasami x⁵⁷
share an extended Walsh spectrum, and the mugshot "separation" is a type tag).
Both are non-quadratic power maps, so Yoshiara excludes them on degree — but say
so explicitly rather than leaning on the mugshot.

**Fingerprints re-verified after the `build_ci_sbox` rewrite** (R5/R8/R10): the
LUTs are byte-identical to the ones recorded above — `build_ci_sbox(10,3,2)` and
`build_ci_sbox(10,7,0)` still produce the same first-16 prefixes, so both
regeneration recipes remain valid. These records are **records only**; this pass
made **no** change under `packages/VBFCatalog/`.

### APN-claim verdict levels

| Level | Pre-fix | Post-fix |
|---|---|---|
| formula reproduced | **yes** | **yes** |
| APN property verified | **yes** | **yes** |
| parameter family validated | **partial** (n=10 only, even k only) | **yes** — n=10 **and n=14**; even k (Theorem 2) **and odd k** (Lemma 4); all 8 Corollary 1 items |
| novelty / equivalence claim checked | **no** | **partial** — CCZ-inequivalence to every **quadratic** known class over F₂¹⁰ (incl. B(x)) is computed and invariant-backed; separation from the two **non-quadratic power** maps is not (needs Γ-rank at n=10) |
| full claim reproduced | **no** | **partial** — everything except the Γ-rank-dependent half of the novelty claim |

## Open questions

*(Both were decided by the fix pass; recorded here for the reader.)*

1. **Was `theorem4.jl` named against a different numbering** (e.g. counting all
   numbered statements)? Even if intentional, it collides with the paper's real
   Lemma 4 and should be renamed (R3).
   → **Renamed to `theorem2.jl`.** No numbering scheme in the tex yields "Theorem
   4" for this result, and the real Lemma 4 now occupies `lemma4.jl`.
2. **Should the reproduction assert the Corollary 1 item 8 discrepancy (P1) as a
   documented paper erratum** (with the du=32 evidence), or reproduce Corollary 1
   verbatim and let the check fail loudly?
   → **Documented as an erratum.** `corollary1_items` tags item 8
   `erratum = true`; the report prints `du = 32` as *evidence*, not as a FAIL, and
   cites the paper's own self-contradiction (Lemma 4's i-list; tex:446). The suite
   stays green while still asserting the paper is wrong — silencing it would have
   lost the finding, and failing loudly would have made a correct reproduction
   look broken.
