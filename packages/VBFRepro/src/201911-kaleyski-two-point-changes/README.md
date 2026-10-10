# Kaleyski_201911 — Changing APN Functions at Two Points

Current audit application (2026-10-10): F023: `conjecture22_report` now returns a SearchOutcome per selected catalog region, records available members and selected IDs, and accepts full_search, max_evaluations and timeout_seconds. Samples/interrupted runs are BudgetHit. Exhaustion covers only the explicitly named catalog members, never all APNs or the conjecture globally.


**Paper:** N. Kaleyski, *Changing APN functions at two points*, Des. Codes
Cryptogr. 88(8), 2019.

**Reproduction:** `packages/VBFRepro/src/201911-kaleyski-two-point-changes/` — `helpers.jl`, `theorem17.jl`,
`table1.jl`, `table2.jl`, `conjecture21.jl`, `conjecture22.jl`, `report.jl`.

**Verdict:** **Partial.** The arithmetic that is implemented is correct —
Theorem 17's biconditional is confirmed in both directions (the non-vacuous n=4
positive case included), and all 20 Table 2 values match the paper.

*Status after the R1–R9 fix pass:* Observation 7 is now fully implemented (all
three affine maps), so Conjecture 22 is tested over **all** swap pairs
(exhaustive at n=5, n=6; sampled at n=7, n=8 — 42520 swaps, 0 APN), no catalog
function is discarded, Conjecture 21 covers n=4..10 and checks both S₁ and S₂,
and the test suite is no longer vacuous (804 assertions; a hardcoded
`holds = false` now fails). Still missing: Example 9, Table 1's row-by-row
content (needs Edel–Pott representatives — Open Question 1), the
Walsh-derivation chain (Props 12–16) and the paper's main power-function theorem
(Prop 26). The original README's self-assessment ("Mostly complete", "Paper
Issues: None found") was not supportable and is superseded by this file.

---

## Issue Catalog

### Paper Issues

**P1. Example 9's degree claim is false.**

The paper (Example 9) states, for `F(x) = x³ + (x²+x+1)·Tr(x³)` over F₁₆:
*"All APN functions obtained by swapping two values of F have algebraic degree
2."*

Computed exhaustively — twice, once with VBF and once with an independent
hand-rolled GF(2⁴)/Möbius/DDT implementation — under **both** n=4 primitive
polynomials. With modulus `x⁴+x+1`, `F` has `du(F)=2, deg(F)=3` (matching the
paper), and there are exactly three APN swaps:

| swap `(u₁,u₂)` | algebraic degree |
|---|---|
| (0, 1) | 2 |
| (0, 6) | **3** |
| (0, 7) | **3** |

Two of the three have degree 3, so the claim is false. This collapses the
example's purpose: it exists to show swapping is *strictly weaker* than a
general two-point change (swap ⇒ degree 2 only; general change ⇒ degree 3). In
fact swapping also reaches degree 3.

The charitable reading — "the paper means only the (0,1) swap" — does not save
it: `swap(F,0,6)` is EA-equivalent (via the paper's own Observation 7, with
`A₂(x)=6x`) to the (0,1)-swap of `F'(x)=F(6x)`, which is a valid normalized
EA-representative of `F` (`F'(0)=0, F'(1)=1`), and algebraic degree is
EA-invariant.

The paper's *second* Example 9 claim is correct and confirmed: `u₁=α⁴=3,
u₂=α²=4, v=1` gives `du=2, deg=3`.

### Reproduction Issues

**R1. [RESOLVED] `normalize_apn` implements only half of Observation 7.** *(root
cause of R2, R3, R4)*

*Fixed: `helpers.jl:96` `normalize_apn(s, u1=0, u2=1)` now applies all three of
Observation 7's maps — the input map `A₂(x) = x(u₁+u₂) + u₁` alongside the output
scaling `A₁` and shift `A`. `(0,1)` makes `A₂` the identity, so the previous
behaviour is preserved exactly. Validated end-to-end: over every genuine pair of
n=4 x³ (105), n=5 x³ (496) and n=6 `reprs6_13` (1976), Eq. 29 on
`normalize_apn(F,u₁,u₂)` agrees with `differential_uniformity(swap(F,u₁,u₂))==2`
— **0 mismatches**.*

- **Location:** `packages/VBFRepro/src/201911-kaleyski-two-point-changes/helpers.jl:42-55`
- **Symptom:** Only the output maps (`A₁` scaling, `A` shift) are applied. The
  input affine map `A₂(x) = x(u₁+u₂) + u₁` — the mechanism that carries an
  arbitrary `(u₁,u₂)` swap onto the normalized `(0,1)` swap — is absent.
- **Root cause:** Observation 7 has three components; the implementation ships
  two. Without `A₂` the reproduction is permanently pinned to whichever single
  LUT the catalog happens to store.
- **Resolution plan:**
  1. Add the input map `A₂(x) = x(u₁+u₂) + u₁` to `normalize_apn`, taking
     `(u₁,u₂)` as arguments.
  2. Return the normalized representative together with the applied maps so
     callers can swap at an arbitrary pair.
  3. Re-run `test/runtests.jl`; the existing assertions must still pass.

**R2. [RESOLVED] Conjecture 22 is tested at exactly one swap point, not over all
pairs.**

*Fixed: `conjecture22.jl:60` now loops over swap pairs — exhaustively for
n ≤ `exhaustive_max_n` (default 6), sampled above that (`pair_samples`, default
16, plus `(0,1)`; all-pairs at n=7 is ≈3.9M swaps). Fresh run: n=5 → 1488 genuine
swaps, n=6 → 31623, n=7 → 8372 sampled, n=8 → 1037 sampled; **0 APN swaps
anywhere**. `total_swaps` = 42520.*

- **Location:** `packages/VBFRepro/src/201911-kaleyski-two-point-changes/conjecture22.jl:50-69`
- **Symptom:** The code loads one catalog representative, applies output-only
  normalization, and evaluates Eq. 29 **once** — i.e. only the `(0,1)` swap. The
  previous README's claim that it "confirms Conjecture 22 for all 546 catalog
  APN" means 548 *swaps*, not 548 × C(2ⁿ,2) ≈ millions of them.
- **Root cause:** R1 (no `A₂`, so no way to reach other pairs).
- **Resolution plan:**
  1. After R1, loop over all `(u₁,u₂)` with `F(u₁) ≠ F(u₂)`.
  2. Exhaustive for n=5 and n=6; sampled for n=7 and n=8 (cost note below).
  3. Assert zero APN swaps. Verified during review: n=5 → 1488 genuine swaps, 0
     APN; n=6 → 31623 genuine swaps, 0 APN; n=4 control → 15 APN swaps, as the
     paper's Observation 27 requires.

**R3. [RESOLVED] `is_swap_degenerate` discards 26 catalog functions entirely.**

*Fixed: the skip branches are gone. `is_swap_degenerate(s, u1, u2)` is now a
property of the **pair**, and `first_genuine_pair` / `genuine_pairs`
(`helpers.jl:36,56`) find the pairs where a swap is not a no-op. `table1.jl:98`
normalises each `F(0)=F(1)` function at its first genuine pair;
`conjecture22.jl` swaps all 26 of them at real pairs. All **574** catalog APN
functions for n=5..8 are now covered (the "548" in the old artifacts was the
non-degenerate subset, 574 − 26).*

- **Location:** `packages/VBFRepro/src/201911-kaleyski-two-point-changes/conjecture22.jl:55-58`,
  `packages/VBFRepro/src/201911-kaleyski-two-point-changes/table1.jl:76-80`
- **Symptom:** `F(0)=F(1)` causes the whole function to be dropped (n=6: 1,
  n=7: 8, n=8: 17 = **26** functions), contributing zero evidence toward
  Conjecture 22.
- **Root cause:** `F(0)=F(1)` makes only the **(0,1)** swap a no-op. The
  function still has ~2^(2n−1) other legitimate swap pairs. R1 again.
- **Resolution plan:**
  1. After R1, choose any `(u₁,u₂)` with `F(u₁) ≠ F(u₂)` and normalize through
     `A₂` instead of skipping the function.
  2. Remove the degenerate-skip branch; assert all 548 functions are covered.

**R4. [PARTIALLY RESOLVED] Table 1 never exhibits the S₁≠S₂ asymmetry that
defines it.**

*Step 1 done: with `A₂` in place the asymmetry is reachable and appears.
`table1.jl:113` now normalises each function at `rep_samples` further genuine
pairs and counts the representatives with S₁ ≠ S₂. Exhaustive check over all
pairs: n=5 → **465 / 1488** representatives have S₁ ≠ S₂; n=6 → **1048 / 31623**.
`reprs6_13` yields (S₁,S₂) = (54,66) and (66,54) — the paper's own n=6 "2.1" row.
The report's sampled scan reports 19 asymmetric representatives.*

*Step 2 (reproduce Table 1 row-by-row against the real Edel–Pott representatives,
or stop calling it Table 1) is **still open** — see Open Questions 1. Interim: the
file header now states plainly that this is not a row-by-row reproduction of
Table 1 and that what is reproduced is Observation 18's premise (S₁+S₂ > 12).*

- **Location:** `packages/VBFRepro/src/201911-kaleyski-two-point-changes/table1.jl:14-18`
- **Symptom:** The paper's Table 1 is full of asymmetric rows (n=6 "2.1" →
  54/66; n=6 "2.9" → 66/90; n=7 "1.2" → 126/382; n=8 "4.1" → 318/766), and the
  paper explicitly remarks *"the two values may differ in the general case."*
  Scanning all catalog reps gives **0/548** with `S₁ ≠ S₂` (n=5: 0/3, n=6: 0/15,
  n=7: 0/485, n=8: 0/45).
- **Root cause:** R1. S₁/S₂ are not EA-invariant — they depend on the chosen
  normalized representative, and without `A₂` only one representative is ever
  reachable.
- **Resolution plan:**
  1. After R1, recompute S₁/S₂ across representatives and confirm asymmetric
     cases appear.
  2. The file's current caveat ("exact numerical S1/S2 values will differ") is
     too weak — the qualitative content is missing too. Either reproduce Table 1
     against the real Edel–Pott representatives, or stop describing the output
     as Table 1. **Needs a decision — see Open Questions.**

**R5. [RESOLVED] The Theorem 17 test suite is vacuous and cannot detect a broken
implementation.**

*Fixed: `test/test_theorem17.jl:11-31` adds the n=4 positive case — `F = x³` over
F₁₆ gives S₁=6, S₂=6, 6·Δ(1,0)=12, so Eq. 29 **holds** and `swap(F,0,1)` is APN
(`differential_uniformity == 2`, computed independently of Eq. 29). Both halves
of the biconditional are asserted over **every** genuine pair at n=4 (105 pairs,
15 APN swaps — Observation 27) and at n=5 (496 pairs, 0 APN swaps).
`theorem17.jl:52` now cross-checks every demo row against ground truth via
`swap_is_apn`. **Non-vacuity verified**: stubbing `theorem17_holds` to return
`holds = false` fails 16 assertions (it previously passed 47/47).*

- **Location:** `packages/VBFRepro/src/201911-kaleyski-two-point-changes/test/test_theorem17.jl:8,16`,
  `packages/VBFRepro/src/201911-kaleyski-two-point-changes/test/test_table1.jl:13`,
  `packages/VBFRepro/src/201911-kaleyski-two-point-changes/theorem17.jl:39`
- **Symptom:** Every assertion has the form `@test !r.holds` /
  `@test row.condition_fails`, and `theorem17.jl:39` hard-asserts
  `@assert !r.holds`. Across all 548 catalog functions Eq. 29 holds **0 times**.
  **A `theorem17_holds` that hardcoded `holds = false` would pass 47/47 tests.**
- **Root cause:** The only discriminating case is n ≤ 4, where Eq. 29 genuinely
  holds — and it is never tested. (It does hold; verified during review.)
- **Resolution plan:**
  1. Add the n=4 positive case: `F = x³` over F₁₆ gives `S₁=6, S₂=6,
     6·Δ(1,0)=12`, so Eq. 29 **holds** and `G = swap(F,0,1)` **is APN**.
  2. Assert both halves of the biconditional (condition ⇔ `G` is APN).
  3. Keep the existing negative assertions; they are correct, just insufficient.

**R6. [RESOLVED] `conjecture21.jl` silently excludes all of n=5.**

*Fixed: `helpers.jl:127` `power_exponent(s)` is a mathematical monomial test —
`F(0)=0`, `F(1)=1`, and `F(g·x) = F(g)·F(x)` on the generator `g=2`, then
`k = log_g F(g)`; `O(2ⁿ)`. `conjecture21.jl:40` uses it instead of the TOML key.
Power APN found: **28** (the 24 with `monomial_exponent` plus `n4_Gold_x3`,
`n5_Gold_x3`, `n5_Gold_x5`, `n5_Kasami_x15`). Coverage is now n ∈ [4,5,6,7,8,9,10]
and all 28 match `formula34(n)`. Kept paper-local per scope; the core
`is_power_function` promotion is still an open library-reuse item.*

*Aside for the catalog maintainer: `n8_Kasami_x57`'s LUT is `x⁶` under the
canonical modulus, not `x⁵⁷` (6 ∉ the cyclotomic coset of 57 mod 255). Still a
power APN (`x⁶` is linear-equivalent to `x³`), so Conjecture 21 is unaffected —
but the name does not match the data.*

- **Location:** `packages/VBFRepro/src/201911-kaleyski-two-point-changes/conjecture21.jl:37`
- **Symptom:** Dimensions actually covered are `[6,7,8,9,10]`. The paper states
  it verified Conjecture 21 for `1 ≤ n ≤ 10`.
- **Root cause:** The power-function filter tests
  `haskey(apn_catalog_metadata(name), "monomial_exponent")` — a **TOML-encoding
  proxy, not a mathematical test**. `packages/VBFCatalog/data/apn/n5_apn.toml`
  stores its three power APN (`n5_Gold_x3`, `n5_Gold_x5`, `n5_Kasami_x15`) as raw
  `lut` with no `monomial_exponent` key, so n=5 is skipped without a word.
- **Resolution plan:**
  1. Replace the metadata proxy with a mathematical power-function test (see
     Library-reuse note — this wants an `is_power_function` in core).
  2. Confirm coverage becomes `[5,6,7,8,9,10]`.

**R7. [RESOLVED] Conjecture 21 checks S₁ only.**

*Fixed: `conjecture21.jl:53` computes S₂ from the same DDT and requires
`s1 == expected && s2 == expected`; the printed table gained an S₂ column.
`test/test_conjecture21.jl` (new, wired into `runtests.jl`) asserts
`row.s1 == row.s2 == formula34(row.n)` for all 28 power functions.*

- **Location:** `packages/VBFRepro/src/201911-kaleyski-two-point-changes/conjecture21.jl:50`
- **Symptom:** Only `compute_s1` is called. Conjecture 21 asserts that *both*
  `Σ_y Δ_F(y, F(y)+1)` and `Σ_y Δ_F(y+1, F(y))` equal the `x³` value.
- **Root cause:** Half the claim is simply not evaluated. (No correctness bug —
  S₂ was verified during review to match for all 24 power functions — but it is
  an unchecked half.)
- **Resolution plan:** Compute `compute_s2` alongside and assert both.

**R8. [RESOLVED] Stale artifacts and inaccurate README claims.**

*Fixed: `results/report.toml` regenerated from a fresh `paper_report(;
save_results=true)`. `total_checked` is now **574**, not 548 — 548 was the count
of *non-degenerate* functions under the old skip-the-degenerate code; after R3
all 574 catalog APN for n=5..8 are checked (574 = 548 + 26). New keys:
`total_swaps = 42520`, `theorem17_biconditional_ok`, `theorem17_positive_case`,
`table1_asymmetric_reps`, `conjecture21_power_fns`. The 27-vs-26 and "S1+S2 > 12"
prose claims were already corrected by this README; `table1.jl` now does assert
Observation 18's premise (`test_table1.jl:28`).*

- **Location:** `packages/VBFRepro/src/201911-kaleyski-two-point-changes/results/report.toml`, and the previous
  `README.md`
- **Symptom / expected:**
  - `report.toml` says `total_checked = 550`; a fresh run gives **548**.
  - Previous README said 27 degenerate functions (n=7: 9); the actual count is
    **26** (n=7: **8**).
  - Previous README said Table 1 "verifies `S1+S2 > 12` (Observation 18 logic)";
    `table1.jl` contains no such check — it tests `!r.holds`.
  - Previous README cited a 550-function biconditional cross-check that exists
    in no committed file.
- **Root cause:** Artifacts and prose drifted from the code.
- **Resolution plan:**
  1. Regenerate `results/report.toml` (550 → 548).
  2. This README supersedes the stale claims; keep it in sync on re-review.

**R9. [RESOLVED] `print_header` duplicates core `print_banner`.**

*Fixed: `helpers.jl:12` `print_header` now delegates to core `print_banner`.*

- **Location:** `packages/VBFRepro/src/201911-kaleyski-two-point-changes/helpers.jl:11-16`
- **Symptom:** Hand-rolls a 72-wide `=`-ruled banner.
- **Root cause:** Duplicates `print_banner(io, lines...; width=72)` at
  `packages/VBF/src/io/report.jl:33`.
- **Resolution plan:** Call `print_banner`. (Cosmetic; other papers already do.)

---

## Items reproduced exactly (context)

| Paper item | Evidence |
|---|---|
| Formula (34) / Example 19 | `helpers.jl` `formula34`; DDT-verified n=2..10 |
| **Table 2** (n=1..20) | all 20 values checked against the LaTeX table — **all match** |
| Theorem 17 / Eq. (29) | `helpers.jl` `theorem17_holds`; biconditional cross-checked against `differential_uniformity(swap(F,u₁,u₂))` |
| **Observation 7** | `helpers.jl` `normalize_apn(s,u₁,u₂)` — all three maps `A₁, A₂, A` (R1) |
| Conjecture 21 (S₁ **and** S₂, n=4..10) | 28 catalog power APN, all match `formula34(n)` (R6, R7) |
| Observation 27 (n=4 half) | 15 APN swaps of `x³` over F₁₆; `test_conjecture22.jl` control |

Independently strengthened during review (all passed): Theorem 17 end-to-end
(built `G = swap(F,0,1)`, compared `differential_uniformity(G)==2` against
Eq. 29 for all 548 catalog APN n=5..8 → **0 mismatches**); Theorem 17 at n=4
(non-vacuous, holds); Conjecture 22 exhaustively over all pairs at n=5 and n=6
(**0 APN swaps**, with the n=4 control finding the expected 15). All of this is
now *in the committed suite* rather than a review-time side-check.

## Not reproduced

Example 9; Proposition 4 (the four APN conditions); Corollary 5; Proposition 6;
Observation 8; the entire Walsh-derivation chain
(Lemma 10, Observation 11, **Props 12, 13, 14**, Observation 15, **Prop 16**) —
all are concrete numeric identities over Walsh spectra, directly checkable with
`walsh_transform`/`lat`; **most of Section 6** (Observations 23–25 and
**Proposition 26** — *"swapping two points of any power function cannot give APN
for n ∉ {1,2,4}"*, the paper's main hard theorem; Observation 27's n=4 half *is*
now covered); Observation 20's positive half. Section 7 (Props 28–30) is
reasonably skipped as purely theoretical.

## Test results (as run)

All Julia run through a 2 GiB-capped cgroup wrapper; `make` bypassed (its
`JULIA ?= julia` would escape the cap). No OOM; nothing skipped for memory.

| Command | Result |
|---|---|
| `test/runtests.jl` (before fixes) | PASS 47/47 — but vacuous (R5) |
| `test/runtests.jl` (after fixes) | **PASS 804/804** in 4.6 s (653 + 9 + 27 + 99 + 16) |
| non-vacuity check | `theorem17_holds` stubbed to `holds = false` → **16 failures** (n=4 positive case + the 15 APN swaps) |
| `report.jl` | all 6 flags `true`; `total_checked = 574` functions, `total_swaps = 42520` |

Conjecture 22 coverage: n=5 (1488 swaps) and n=6 (31623 swaps) exhaustive over
all pairs; n=7 (8372) and n=8 (1037) sampled — all-pairs at n=7 is ≈3.9M swaps
and at n=8 ≈1.5M, skipped for CPU time only. Raise `exhaustive_max_n` to force
them.

## Catalog status

**N/A — no new APN functions claimed.** This is a non-existence/characterization
paper; all APN inputs are pre-existing (power functions; Edel–Pott switching
classes). Example 9's degree-3 APN `G` over F₁₆ is not a novelty claim — every
APN function over F₁₆ is CCZ-equivalent to `x³`, and `n4_apn.toml` already
carries `n4_Gold_x3`. **No catalog-gap records.**

Unrelated observations for the catalog maintainer: (a) `n5_apn.toml` and
`n4_apn.toml` store power functions as `lut` without `monomial_exponent`, unlike
n6–n10 — that inconsistency is what broke R6 (now worked around paper-locally);
(b) `n8_Kasami_x57`'s LUT is `x⁶`, not `x⁵⁷`, under the canonical modulus.

## Library-reuse note

- `print_header` → core `print_banner` (R9). **Done.**
- **Promote-to-core candidate (still open):** a mathematical
  `is_power_function(sbox)` / exponent-recovery predicate. Core has
  `known_apn_monomials` and `gf_monomial_lut` but no way to *ask* whether a given
  LUT is a monomial. Implemented paper-locally for now as
  `helpers.jl::power_exponent` / `is_power_function` (multiplicativity on the
  generator, `O(2ⁿ)`); it belongs in `packages/VBF/src/`.
- Correctly paper-local (not flagged): `is_swap_degenerate`, `normalize_apn`,
  `genuine_pairs`, `first_genuine_pair`, `swap_points`, `swap_is_apn`,
  `compute_s1`, `compute_s2`, `theorem17_holds`, `formula34`.

## Open questions (need a decision before fixing)

1. **Table 1 normalization is under-determined in the paper.** S₁/S₂ are not
   EA-invariant — they depend on the chosen normalized representative. Kaleyski's
   Table 1 uses Edel–Pott's specific polynomial representatives, but the paper
   never states which normalization was applied to reach `F(0)=0, F(1)=1`.
   Exactly reproducing Table 1 needs (a) the Edel–Pott LUTs from [10] and (b) a
   normalization decision. Reproduce against the real Edel–Pott representatives,
   or accept a structural surrogate that stops claiming to be Table 1?
2. **Should Example 9 be reproduced at all**, given P1? Recommended: reproduce it
   *as a paper-issue witness* (compute the three APN swaps and their degrees),
   since that is a genuine, defensible finding.


### F023 complete finite catalog sweeps (2026-10-10)

The full n=7 sweep checked **4,033,320 genuine swaps across 500 functions**;
the n=8 sweep checked **2,271,970 genuine swaps across 70 functions**.
No APN swap was found. Every selected catalog function must now pass a full
APN precondition check before the theorem test; invalid metadata aborts the run.
VBFRepro records the catalog SHA-256, implementation/input hashes, parameters,
logs and execution status. This is evidence for the specified catalog snapshot,
not a proof of Conjecture 22 over every APN function.

```sh
bin/vbfrepro run Kaleyski_201911 --target conjecture22 --param 'ns=[7,8]' \
  --param full_search=true --param timeout_seconds=900 --timeout-seconds 960
```
