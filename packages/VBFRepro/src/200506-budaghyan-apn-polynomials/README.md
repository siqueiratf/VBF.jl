# Budaghyan et al. (2005) — New Classes of Almost Bent and Almost Perfect Nonlinear Polynomials

- **Citation:** L. Budaghyan, C. Carlet, A. Pott, "New Classes of Almost Bent and Almost Perfect
  Nonlinear Polynomials", 2005 (later *IEEE Trans. Inform. Theory* 52(3):1141–1152, 2006).
- **Reproduction path:** `packages/VBFRepro/src/200506-budaghyan-apn-polynomials/`
- **Paper source:** `input/Budaghyan et al. - 2005 - New Classes of Almost Bent and Almost Perfect Nonlinear Polynomials.tex`
- **Verdict:** **Complete** — all four theorems, Remark 4, Example 1 and Propositions 3–6 are
  implemented and independently verified, including the paper's own statement-vs-proof
  discrepancy in Theorem 4 (now exercised at the n ≥ 5 parameters where *both* halves of it are
  observable). All six reproduction issues below are resolved; see each `[RESOLVED]` note.

---

## Issue Catalog

### Paper Issues

Flaws in the original publication / its OCR'd source. Not ours to fix.

1. **Theorem 4's statement disagrees with its own proof**, in two places:
   (a) the statement omits the standalone `+ tr_{m/n}(x)` term; (b) it writes the last bracket
   exponent as `2ⁱ+1` where the derivation gives `2ⁱ/(2ⁱ+1)`. The reproduction documents this
   in the `theorem4.jl` header and demonstrates it in `theorem4_paper_formula_check`: (a) alone
   at m=9, n=3 (448/512 mismatches, statement form still AB) and (a)+(b) at m=15, n=5
   (32734/32768 mismatches, statement form neither AB nor APN). Pointer updated under Bu-1;
   the defect itself is the authors'.
2. **OCR-level typos in the Theorem 3 proof:** `x^{s^{s+2}(2^i+1)}`, and `tr_{m/3}(x^{2^s})`
   with an `s`-vs-`i` inconsistency. Neither affects the verified result.

### Reproduction Issues

Defects introduced in our implementation.

#### Bu-1 — The "wrong last exponent" verdict is asserted but never exercised [RESOLVED]

**Resolution.** `theorem4_bracket_exponents(n, i)` (`theorem4.jl`) now returns both
printed exponents reduced mod `2ⁿ−1` plus a `differ` flag, and
`theorem4_paper_formula_check` reports them, reports the count of points with
`tr_{m/n}(x) ≠ 0` (the reach of typo (a) alone), and emits a verdict string
conditioned on `differ`. `theorem4_report` and `test/test_theorem4.jl` now run
`m=15, n=5, i ∈ {1,2}`, where the exponents genuinely differ. The measured
outcome makes claim (b) observable for the first time:

| m | n | i | statement exp | derivation exp | mismatches | statement form AB? |
|---|---|---|---|---|---|---|
| 9 | 3 | 1 | 3 | 3 | 448/512 (= all `tr≠0` points) | yes (lin 32, du 2) |
| 9 | 3 | 2 | 5 | 5 | 448/512 (= all `tr≠0` points) | yes (lin 32, du 2) |
| 15 | 5 | 1 | 3 | 11 | 32734/32768 (> the 31744 `tr≠0` points) | **no** (lin 896 ≠ 256, du 16) |
| 15 | 5 | 2 | 5 | 7 | 32734/32768 (> the 31744 `tr≠0` points) | **no** (lin 896 ≠ 256, du 16) |

At n=3 the mismatch count equals the `tr_{m/n}(x) ≠ 0` count exactly, so the
divergence there is entirely typo (a) — asserted as
`fc.mism_stmt == fc.tr_nonzero`. At n=5 it strictly exceeds it and the statement
form is neither AB nor APN, which is the evidence for typo (b).

- **Location:** `theorem4.jl:11-21` (header), `theorem4.jl:169-170` (`print_kv "verdict"`),
  `theorem4.jl:207-209`, `test/test_theorem4.jl:18-28`.
- **Symptom:** the repo states the Theorem-4 *statement* form is a typo in two ways — (a)
  missing `+ tr_{m/n}(x)`, (b) last bracket raised to `2ⁱ+1` instead of `2ⁱ/(2ⁱ+1)`. Only (a)
  is observable at the tested parameters, so claim (b) is asserted on evidence the tests cannot
  produce.
- **Root cause:** the bracket lies in `F_{2ⁿ}`, so exponents reduce mod `2ⁿ−1`. At **n=3** the
  two exponents coincide:

  | m | n | i | statement exp | derivation exp | |
  |---|---|---|---|---|---|
  | 9 | 3 | 1 | 3 | 3 | **EQUAL** |
  | 9 | 3 | 2 | 5 | 5 | **EQUAL** |
  | 15 | 5 | 1 | 3 | 11 | differ |
  | 15 | 5 | 2 | 5 | 7 | differ |

  The 448/512 divergence at m=9, n=3 comes *entirely* from the missing `+ tr_{m/n}(x)`
  (512 − 64 = 448 points where `tr_{m/3}(x) ≠ 0`).
- **Resolution plan:**
  1. Add `theorem4_paper_formula_check(; m=15, n=5, i=1)` (and `i=2`) so the exponent
     discrepancy is actually observed.
  2. Add an assertion in the check that
     `invmod(2ⁱ+1, 2ⁿ−1)·2ⁱ mod (2ⁿ−1) != (2ⁱ+1) mod (2ⁿ−1)` for the parameters used, to
     justify claim (b); skip or annotate when they coincide.
  3. Reword the `n=3` verdict string to say that the divergence there is from the dropped
     linear term only, and that the exponent typo requires `n ≥ 5`.

#### Bu-2 — Theorem 4's "number of divisors of m" claim is untested [RESOLVED]

**Resolution.** New `theorem4_divisors_check(; m = 15, i = 1, ns = (3, 5))` in
`theorem4.jl`, wired into `theorem4_report` and `test/test_theorem4.jl`. It
builds F' for n ∈ {3,5} at m=15, asserts both are AB (linearity = 256 =
2^{(15+1)/2}) with algebraic degrees 5 and 7 = n+2, and adds Theorem 1's F' as
the n=1 member (degree 3), the paper's own reading of the n=1 case ("Theorem 1
gives the case n = 1", tex l.777). Pairwise EA-inequivalence is concluded from
the *distinct algebraic degrees* {3, 5, 7}, all ≥ 2 — algebraic degree is an
EA-invariant there, so this is a sound proof requiring no oracle and no capped
search. Result: ≥ 3 pairwise-EA-inequivalent functions inside a single Gold
CCZ-class at m=15 (4 divisors). AB at m=15 needed a streaming linearity — see
the library-reuse note.

- **Location:** `theorem4.jl:205-214`; the note at line 214 explicitly skips m=15.
- **Symptom:** the paper concludes that "the number of functions CCZ-equivalent to a Gold AB
  function and EA-inequivalent to it is not smaller than the number of divisors of m". That
  needs ≥ 2 admissible `n` for a single `m`, but only `(m,n) = (9,3)` is tested.
- **Root cause:** the m=15 case was skipped for cost, leaving the headline corollary
  unexercised.
- **Resolution plan:**
  1. Add m=15 with n ∈ {3,5}.
  2. Assert both are AB with algebraic degrees `n+2` ∈ {5,7}.
  3. Assert the two are pairwise EA-inequivalent — distinct algebraic degree makes this sound.

#### Bu-3 — Propositions 1–6, Remarks 1–3 and Example 1 are entirely missing [RESOLVED]

**Resolution.** New `propositions.jl` (+ `test/test_propositions.jl`, a
`make propositions` target, and a `propositions_report` call in `report.jl`)
implements the resolution plan's three ordered items:

1. **Example 1** — `example1_check(; m)`, exhaustive at m=5 and m=7. Verifies
   `L` is a permutation with `L(1)=1`, `L⁻¹(x)=x+x²+tr(x)`, `F₁(x)=x+tr(x)+L(x³)`
   is a permutation equal to `L((x+1)³)+1`, `F₁⁻¹(x)=[L⁻¹(x+1)]^{1/3}+1` against
   the true permutation inverse, that `𝓛` permutes `F_{2^m}²` with **both**
   components depending on **both** variables, and that
   `F' = L⁻¹(x+1) + L⁻¹([L⁻¹(x+1)]^{1/3})`. That closed form is itself the
   EA-decomposition `A₁∘x^{1/3}∘A₂ + A_drift` (`A₁ = L⁻¹`, `A₂(x) = L⁻¹(x+1)`),
   so the EA-equivalence to `(x³)⁻¹` is a *constructed witness*, not an oracle
   verdict — which matters, since `are_ea_equivalent` on that degree-3 n=5
   permutation pair does not terminate in reasonable time.
2. **Prop 5 / Prop 6** — `prop5_check` / `prop6_check` (sampled at m ∈ {5,6,7,8})
   and `prop5_exhaustive_check` / `prop6_exhaustive_check` at m=4: the criterion
   is compared against `is_permutation` over **all 2¹⁶ linear maps** in one
   factor (2·65536 pairs for Prop 5, 65536 for Prop 6; 16 permutations each, so
   the "⟸" half is not vacuous). Prop 6 needs the adjoint `L*`, built by
   `adjoint_lut` and separately verified against its defining identity
   `tr(v·L(x)) = tr(L*(v)·x)`. The sampled pools always seed in known
   permutation instances (`L=0`, `L'=0`, and Theorem 3's
   `L(y)=tr_{m/3}(y²+y⁴)`), because uniformly random `(L, L')` essentially never
   yields one.
3. **Prop 3** — `prop3_check(; m = 5, i)`: both one-variable shapes of `L₁` are
   built as `2m`-bit linear maps, `F'` is read off the graph image via core
   `ccz_equivalent_function` (never from the formula), and the EA-witness
   `M₂∘F∘L⁻¹ + M₁∘L⁻¹` (resp. `M₁∘F⁻¹∘L⁻¹ + M₂∘L⁻¹`) is verified pointwise. The
   contrapositive uses Theorem 1's own `𝓛` (a=1), whose graph image is checked
   to be exactly `theorem1_lut`, together with the Prop 4 witness set.

**Deliberately still out:** Propositions 1 and 2 and Remarks 1–3. Prop 1 (the
transversality characterisation) and Prop 2 (CCZ preserves `Δ_F`, `Λ_F`) are the
derivation apparatus the four theorems are *built from* — every theorem check
exercises them end-to-end — and Remarks 1–3 are expository. `propositions_report`
prints a `[SCOPE]` note saying so.

- **Location:** no implementation exists; `report.jl` does not list them.
- **Symptom:** the paper's supporting apparatus is absent, including one item of real value.
- **Root cause:** scope decision favouring the four theorems.
- **Resolution plan (ordered by value):**
  1. **Example 1** — the most valuable omission: it exhibits an `L = (L₁,L₂)` where *both*
     components depend on both variables, yet `F'` is EA-equivalent to `(x³)⁻¹`. It is a
     concrete counterexample to the naive converse of Prop 3, fully specified
     (`L(y)=Σ_{j=0}^{n-s} y^{2^{2j+s}}`, `L⁻¹(x)=x+x²+tr(x)`,
     `F₁⁻¹(x)=[L⁻¹(x+1)]^{1/3}+1`) and directly checkable at m=5,7.
  2. **Prop 5** (permutation criterion for `L(x^{2ⁱ+1}) + L'(x)`) and **Prop 6** (the `m` even
     criterion with `L*(v) = u^{2ⁱ+1}` and `tr_{m/2}(v/u) ≠ 0`) — cheaply checkable at m=6,8 by
     brute force over `L`.
  3. **Prop 3** (EA ⟺ `L₁` depends on one variable) — checkable by construction at m=4,5.

#### Bu-4 — Prop 4's hypothesis is only tested at `c = 1` [RESOLVED]

**Resolution.** Option (a) of the plan. `trace_component_tt` takes a `c` keyword
(`helpers.jl`) and a new `prop4_witnesses(F_lut, m, deg_F)` returns the full
witness set `{c ∈ F*_{2^m} : d°(tr(cF)) ∉ {0,1,d°(F)}}`. `theorem1_check`,
`theorem2_check` and `theorem4_check` gained a `prop4_scan_c` keyword (on by
default for m ≤ 10) that scans every `c` and reports `n_witnesses`; the `c = 1`
line is still printed separately so the two are distinguishable. Measured
witness counts: 1/31 at m=5, 1/127 at m=7, 7/511 for Theorem 4 at m=9 — i.e.
`c = 1` happens to be a witness everywhere here, but that is now a *result*
rather than an assumption. The scan is skipped at m=15 (2¹⁵ truth tables per
`c`), which the report states explicitly.

- **Location:** `helpers.jl:43-49` (`trace_component_tt`, which computes `Tr(F(x))`), used at
  `theorem1.jl:58`, `theorem2.jl:56`, `theorem4.jl:192`.
- **Symptom:** Prop 4 requires "there exists `c ∈ F*_{2^m}` with
  `d°(tr(cF)) ∉ {0,1,d°(F)}`". The repo only ever checks `c = 1`, so a failure at `c = 1` would
  be reported as a failure of the criterion.
- **Root cause:** `trace_component_tt` takes no `c` argument.
- **Resolution plan:**
  1. Add a `c` argument to `trace_component_tt`.
  2. Either (a) scan all `c ∈ F*_{2^m}` and report the size of the witness set, or (b) document
     that `c = 1` suffices here because the paper's own proof uses it.

#### Bu-5 — Theorem 3's actual novelty claim is not checked [RESOLVED]

**Resolution.** New `theorem3_ea_inequivalence_check(; m = 6, i)` in
`theorem3.jl`, wired into `theorem3_report` and `test/test_theorem3.jl`. It runs
`are_ea_equivalent(F', G; on_inconclusive = :throw)` — never `:best_effort`,
whose guessed `false` would manufacture the claim — against 8 known n=6 APN: the
three `n6_apn.toml` entries (`n6_Gold_x3`, `n6_Kasami_x48`, `n6_Kim`) plus
`gold_apn(6,k)` / `kasami_apn(6,k)` for k ∈ {1,5} and `kim_apn()`. All 8 come
back EA-inequivalent, and the degree separation is reported as the sound
witness: `deg(F') = 4` while every known n=6 APN is quadratic, and algebraic
degree is an EA-invariant for degrees ≥ 2, so each pair is decided on an
invariant rather than on a capped search.

*Plan deviation:* the plan named `kasami_apn(6, 2)`, which does not exist —
`kasami_apn` requires `gcd(k, n) = 1`, so k=2 throws at n=6. The check
enumerates every valid k instead (k ∈ {1,5}), which covers the Kasami family at
n=6 in full.

- **Location:** `theorem3.jl:242-255`, `theorem3.jl:158-169`.
- **Symptom:** the paper's claim is that `F'` has algebraic degree 4 and is therefore
  EA-inequivalent to *other known APN functions*, since for `6∣m` no known APN function has
  degree 4. The repo checks `deg == 4` and `are_ccz_equivalent(F', gold_apn(6,i))`, but never
  checks EA-inequivalence against the known-APN list — so the claim as stated is unverified.
- **Root cause:** the CCZ check was implemented in place of the EA comparison the claim needs.
- **Resolution plan:**
  1. At m=6, run `are_ea_equivalent(F', G)` with `on_inconclusive = :throw` against
     `gold_apn(6,1)`, `kasami_apn(6,2)`, `kim_apn()` and the `n6_apn.toml` entries.
  2. Report the degree separation as the sound witness.

#### Bu-6 — Theorems 1 and 2's `gcd(i,m) = s > 1` remark cannot be tested [RESOLVED]

**Resolution.** Both plan options, combined so the default stays strict.
`theorem1_lut` / `theorem2_lut` take a `require_coprime` keyword (default
`true`, so every existing caller and the `@test_throws` assertions are
unchanged); passing `false` unlocks `gcd(i,m) = s > 1`. A new `0 < i < m` guard
protects the relaxed path from degenerate exponents. `theorem1_gcd_remark_check`
and `theorem2_gcd_remark_check` then assert the remark directly:

| m | i | s | m/s | Walsh spectrum | 2^{(m+s)/2} | du | deg | deg(tr F') |
|---|---|---|---|---|---|---|---|---|
| 9 | 3 | 3 | 3 (odd) | {0, ±64} | 64 | 8 = 2ˢ | 3 | 2 |
| 9 | 6 | 3 | 3 (odd) | {0, ±64} | 64 | 8 = 2ˢ | 3 | 2 |
| 6 | 2 | 2 | 3 (odd) | {0, ±16} | 16 | 4 = 2ˢ | 3 | 2 |
| 10 | 2 | 2 | 5 (odd) | {0, ±64} | 64 | 4 = 2ˢ | 3 | 2 |
| 6 | 3 | 3 | 2 (even) | {0, ±8, ±64} | — | 8 | 2 | 0 |

The last row is kept as a negative control: with `m/s` even the spectrum is not
three-valued, F' degenerates to degree 2, and Prop 4 no longer applies — so the
remark's `m/s` odd hypothesis is doing real work.

- **Location:** `theorem1.jl:27` and `theorem2.jl:27`
  (`gcd(i,m)==1 || throw(ArgumentError(...))`).
- **Symptom:** the paper explicitly states (in the tex, after Theorem 2's proof) that "the
  proofs of Theorems 1 and 2 do not depend on `gcd(i,m)=1`… if `m/s` is odd they can be
  considered as the first polynomials with three-valued Walsh spectrum `{0, ±2^{(m+s)/2}}`".
  The builders reject those parameters outright, so the remark cannot be exercised.
- **Root cause:** the guard is stricter than the mathematics requires.
- **Resolution plan:**
  1. Relax the guard to a warning, **or**
  2. add a separate `theorem1_gcd_remark_check(m, i)` that builds the LUT for e.g.
     `(m,i) = (9,3)` (s=3, m/s=3 odd) and asserts
     `absolute_walsh_spectrum ⊆ {0, 2^{(9+3)/2}}`.

---

## Items reproduced exactly

| Paper item | Repo location | Verification |
|---|---|---|
| **Theorem 1** `F'(x)=x^{2ⁱ+1}+(x^{2ⁱ}+x)tr(x^{2ⁱ+1}+x)`, m>3 odd | `theorem1_lut` | (m,i) ∈ {(5,1),(5,2),(7,1),(7,2),(7,3)}: du=2, linearity=2^{(m+1)/2}, deg=3, deg(tr F')=2 — all match |
| **Theorem 2** `F'(x)=x^{2ⁱ+1}+(x^{2ⁱ}+x+1)tr(x^{2ⁱ+1})`, m≥4 even | `theorem2_lut` | (4,1),(4,3),(6,1),(6,5),(8,1),(8,3): du=2, deg=3, deg(tr F')=2 |
| **Theorem 3** `F' = F₂∘F₁⁻¹`, 6∣m | `theorem3_f1_lut` / `theorem3_lut` | m=6, i∈{1,5}: du=2, deg=4 |
| Theorem 3 explicit closed form (tex l.588-590 / l.666-669) | `theorem3_paper_explicit_lut` | Matches `F₂∘F₁⁻¹` on all 64 points, i∈{1,5} |
| Theorem 3 `F₁⁻¹ = F₁⁵` formula | `theorem3_paper_f1_inverse_lut` | Matches the permutation inverse on all 64 points |
| Theorem 3 F₈ computer check (`(u^{2ⁱ+1}w)²+(u^{2ⁱ+1}w)⁴ ≠ u`) | `theorem3_f8_check` | 0 violations |
| **Theorem 4** `F' = F₂∘F₁⁻¹`, m odd, n∣m | `theorem4_lut` | m=9, n=3, i∈{1,2}: du=2, linearity=32=2^{(9+1)/2}, deg=5=n+2, deg(tr F')=4 |
| Theorem 4 derivation closed form (tex l.762-770) | `theorem4_corrected_formula_lut` | 0 mismatches vs `F₂∘F₁⁻¹` |
| Theorem 4 statement-vs-derivation divergence | `theorem4_paper_formula_check` | m=9,n=3: 448/512 mismatches = exactly the `tr≠0` points, statement form still AB. m=15,n=5: 32734/32768, statement form neither AB nor APN (see Bu-1) |
| Theorem 4 divisor corollary (tex l.772) | `theorem4_divisors_check` | m=15, n ∈ {1,3,5}: degrees 3/5/7, all AB, pairwise EA-inequivalent (see Bu-2) |
| Remark 4 (no linear L makes F'+L a permutation, m=5) | `remark4_check` | Exhaustive over all 2²⁵ linear maps in `test_remark4.jl`; 0 violations |
| Theorems 1/2 `gcd(i,m)=s>1` remark | `theorem{1,2}_gcd_remark_check` | Three-valued Walsh spectrum `{0, ±2^{(m+s)/2}}` and du = 2ˢ at (9,3), (9,6), (6,2), (10,2); negative control at (6,3) (see Bu-6) |
| **Example 1** (`L₁,L₂` both on both variables, yet `F' ~EA (x³)⁻¹`) | `example1_check` | m=5,7: every sub-claim exhaustive; EA-equivalence exhibited as an explicit witness (see Bu-3) |
| **Prop 3** (`L₁` on one variable ⟺ EA-equiv to `F` or `F⁻¹`) | `prop3_check` | m=5, i ∈ {1,2}: both one-variable shapes verified via `ccz_equivalent_function`; Theorem 1's `𝓛` as contrapositive |
| **Prop 5** (permutation criterion for `L(x^{2ⁱ+1})+L'(x)`) | `prop5_check`, `prop5_exhaustive_check` | Exhaustive over 2·2¹⁶ linear maps at m=4 (16 permutations); sampled at m ∈ {5,6,7,8} |
| **Prop 6** (`m` even adjoint criterion) | `prop6_check`, `prop6_exhaustive_check` | Exhaustive over 2¹⁶ linear maps at m=4 (16 permutations); adjoint verified against `tr(v·L(x))=tr(L*(v)·x)` |
| **Prop 4** criterion applied | `theorem{1,2,4}.jl` | Scanned over **every** `c ∈ F*_{2^m}`: 1/31 witness at m=5, 1/127 at m=7, 7/511 at m=9 (see Bu-4) |
| Theorem 3 EA-inequivalence to known APN | `theorem3_ea_inequivalence_check` | m=6, i ∈ {1,5}: EA-inequivalent to all 8 known n=6 APN, `on_inconclusive = :throw`, degree 4 vs 2 witness (see Bu-5) |

---

## Test results

`julia --project=<repo root> packages/VBFRepro/src/200506-budaghyan-apn-polynomials/test/runtests.jl` (Julia 1.12.6):

| Testset | Pass | Total | Time |
|---|---|---|---|
| `theorem1_test` | 38 | 38 | 2.9 s |
| `remark4_test` | 6 | 6 | 4.4 s |
| `theorem2_test` | 34 | 34 | 0.8 s |
| `theorem3_test` | 36 | 36 | 10.0 s |
| `theorem4_test` | 55 | 55 | 21.2 s |
| `propositions_test` | 93 | 93 | 4.2 s |
| **total** | **262** | **262** | **~46 s** |

`make -C packages/VBFRepro/src/200506-budaghyan-apn-polynomials report` runs in ~48 s with no `[FAIL]` line.

---

## Catalog status

| Claimed-new function | Status |
|---|---|
| Theorem 1 family (AB, m odd) | **not-new** at CCZ level — the paper itself proves CCZ-equivalence to Gold `x^{2ⁱ+1}`; present as `n5_Gold_x3` / `n5_Gold_x5` / `n7_Gold_*` |
| Theorem 2 family (APN, m even) | **not-new** — CCZ-equivalent to Gold; present as `n4_Gold_x3`, `n6_Gold_x3`, `n8_Gold_x3` |
| Theorem 3 family (6∣m, deg 4) | **not-new** — verified at m=6: Γ-rank = 1102 = Γ-rank of `n6_Gold_x3`, consistent with CCZ-equivalence to Gold |
| Theorem 4 family (m odd, n∣m) | **not-new** — CCZ-equivalent to Gold by construction |

**No catalog-gap records.** The paper's novelty is up to **EA**, not up to CCZ, and
`packages/VBFCatalog/data-raw/apn_catalog/README.md` describes the TOML as a CCZ-class
canonical-representative set. Omitting these is the correct decision.

---

## Library-reuse note

| Helper | Line | Verdict |
|---|---|---|
| `boolean_alg_degree` | `helpers.jl` | Duplicates `algebraic_degree` internals for a raw truth table. Already carries a correct `TODO(promote-to-core)` above its definition. **Promote-to-core candidate:** `truth_table_algebraic_degree(tt)` in `packages/VBF/src/invariants/` |
| `trace_component_tt` | `helpers.jl` | Legitimately paper-specific (trace form, not dot-product component). Correctly reuses `gf_trace` / `gf_mul`. `c` argument added under Bu-4 |
| `linearity_streaming` / `sbox_linearity` | `helpers.jl` | **Added under Bu-2.** Core `linearity` materialises the full `2^m × 2^m` LAT — 8.6 GB at the m=15 Theorem 4 parameters. `sbox_linearity` routes to core `linearity` for m ≤ 12 and to the streaming form above it, so nothing changed for the existing small-m call sites. **Promote-to-core candidate:** a `materialise = false` option (or a streaming `lat` iterator) in `packages/VBF/src/spectra/linear.jl`. Carries a `TODO(promote-to-core)` |
| `adjoint_lut` | `propositions.jl` | **Added under Bu-3** for Prop 6. The adjoint of an F₂-linear map w.r.t. the trace form has no core equivalent; verified against its defining identity in `test_propositions.jl`. **Promote-to-core candidate:** `adjoint(::F2LinearMap)` next to `F2LinearMap` |
| `linear_map_lut`, `pair_linear_map` | `propositions.jl` | Thin adapters (`F2LinearMap` → `Vector{Int}`, and the `(x,y)`-packing convention of `FunctionGraph`). Both delegate to core rather than reimplementing |
| `inverse_permutation_lut` | `theorem3.jl` | **Duplicates** `compositional_inverse(::SBox)`. TODO already present above its definition. Fix: `compositional_inverse(SBox{m}(lut)).lut` |
| inline LUT inversion | `theorem4_lut` | **Third** copy of the same inversion, not even routed through `inverse_permutation_lut`. Fix: call the shared helper, or core |
| `_apply_linear` | `remark4.jl` | **Duplicates** `F2LinearMap` application. Fix: build an `F2LinearMap` from the basis and apply it |
| hand-rolled LCG PRNG | `remark4.jl` | **Reuse violation.** Fix: `Random.Xoshiro(seed)` (or `random_linear_function`). A hand-rolled `s*6364136223846793005+…` generator is unreviewable and non-reproducible across refactors |
| `paper_banner` | `helpers.jl` | Correctly delegates to `print_banner`. Good |

**Cross-paper duplication:** `theorem1_lut` and `theorem2_lut` are re-implemented as `formula6_n5` and `formula5_n4` in
`packages/VBFRepro/src/200812-brinkmann-small-apn-classification/helpers.jl:36-62`. **Promote-to-core candidate:** a
`bcp_trace_apn(m, i)` / `bcp_trace_ab(m, i)` pair in
`packages/VBF/src/constructions/apn_quadratic_families.jl`, next to the existing `bcp_apn`
(which is the *different* BCP binomial family).
