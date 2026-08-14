# Budaghyan et al. (2005) — New Classes of Almost Bent and Almost Perfect Nonlinear Polynomials

- **Citation:** L. Budaghyan, C. Carlet, A. Pott, "New Classes of Almost Bent and Almost Perfect
  Nonlinear Polynomials", 2005 (later *IEEE Trans. Inform. Theory* 52(3):1141–1152, 2006).
- **Reproduction path:** `papers/2005/Budaghyan_200506/`
- **Paper source:** `input/Budaghyan et al. - 2005 - New Classes of Almost Bent and Almost Perfect Nonlinear Polynomials.tex`
- **Verdict:** **Mostly complete** — the strongest of the four reproductions reviewed. All four
  theorems are correctly implemented and independently verified, including the paper's own
  statement-vs-proof discrepancy in Theorem 4. Remaining work is an audit note the test
  parameters cannot actually exercise, thin parameter coverage for Theorem 4, and the missing
  Propositions/Example 1.

---

## Issue Catalog

### Paper Issues

Flaws in the original publication / its OCR'd source. Not ours to fix.

1. **Theorem 4's statement disagrees with its own proof**, in two places:
   (a) the statement omits the standalone `+ tr_{m/n}(x)` term; (b) it writes the last bracket
   exponent as `2ⁱ+1` where the derivation gives `2ⁱ/(2ⁱ+1)`. The reproduction already
   documents this correctly at `theorem4.jl:11-21` and demonstrates it at `theorem4.jl:147-173`
   (448/512 mismatches at m=9, n=3, with the statement form still AB).
2. **OCR-level typos in the Theorem 3 proof:** `x^{s^{s+2}(2^i+1)}`, and `tr_{m/3}(x^{2^s})`
   with an `s`-vs-`i` inconsistency. Neither affects the verified result.

### Reproduction Issues

Defects introduced in our implementation.

#### Bu-1 — The "wrong last exponent" verdict is asserted but never exercised

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

#### Bu-2 — Theorem 4's "number of divisors of m" claim is untested

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

#### Bu-3 — Propositions 1–6, Remarks 1–3 and Example 1 are entirely missing

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

#### Bu-4 — Prop 4's hypothesis is only tested at `c = 1`

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

#### Bu-5 — Theorem 3's actual novelty claim is not checked

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

#### Bu-6 — Theorems 1 and 2's `gcd(i,m) = s > 1` remark cannot be tested

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
| **Theorem 1** `F'(x)=x^{2ⁱ+1}+(x^{2ⁱ}+x)tr(x^{2ⁱ+1}+x)`, m>3 odd | `theorem1.jl:24-39` | (m,i) ∈ {(5,1),(5,2),(7,1),(7,2),(7,3)}: du=2, linearity=2^{(m+1)/2}, deg=3, deg(tr F')=2 — all match |
| **Theorem 2** `F'(x)=x^{2ⁱ+1}+(x^{2ⁱ}+x+1)tr(x^{2ⁱ+1})`, m≥4 even | `theorem2.jl:24-39` | (4,1),(4,3),(6,1),(6,5),(8,1),(8,3): du=2, deg=3, deg(tr F')=2 |
| **Theorem 3** `F' = F₂∘F₁⁻¹`, 6∣m | `theorem3.jl:36-92` | m=6, i∈{1,5}: du=2, deg=4 |
| Theorem 3 explicit closed form (tex l.588-590 / l.666-669) | `theorem3.jl:106-123` | Matches `F₂∘F₁⁻¹` on all 64 points, i∈{1,5} |
| Theorem 3 `F₁⁻¹ = F₁⁵` formula | `theorem3.jl:51-66` | Matches the permutation inverse on all 64 points |
| Theorem 3 F₈ computer check (`(u^{2ⁱ+1}w)²+(u^{2ⁱ+1}w)⁴ ≠ u`) | `theorem3.jl:208-233` | 0 violations |
| **Theorem 4** `F' = F₂∘F₁⁻¹`, m odd, n∣m | `theorem4.jl:44-73` | m=9, n=3, i∈{1,2}: du=2, linearity=32=2^{(9+1)/2}, deg=5=n+2, deg(tr F')=4 |
| Theorem 4 derivation closed form (tex l.762-770) | `theorem4.jl:129-134` | 0 mismatches vs `F₂∘F₁⁻¹` |
| Theorem 4 statement-vs-derivation divergence | `theorem4.jl:147-173` | 448/512 mismatches; statement form still AB (du=2, lin=32) — exactly as reported |
| Remark 4 (no linear L makes F'+L a permutation, m=5) | `remark4.jl:35-80` | Consistent with the paper's argument; not re-run exhaustively |
| Prop 4 criterion applied | `theorem{1,2,4}.jl` | `deg(tr F') ∉ {0,1,deg F'}` confirmed in all cases (at c=1 only — see Bu-4) |

---

## Test results

`make -C papers/2005/Budaghyan_200506 test` → **could not run**: `make: julia: No such file or
directory`. No Julia toolchain exists in the review environment.

All theorem claims were re-verified independently; every assertion in
`test/test_theorem{1,2,3,4}.jl` that could be re-derived **holds**.

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
| `boolean_alg_degree` | `helpers.jl:26-36` | Duplicates `algebraic_degree` internals for a raw truth table. Already carries a correct `TODO(promote-to-core)` at `helpers.jl:15-19`. **Promote-to-core candidate:** `truth_table_algebraic_degree(tt)` in `packages/VBF/src/invariants/` |
| `trace_component_tt` | `helpers.jl:43-49` | Legitimately paper-specific (trace form, not dot-product component). Correctly reuses `gf_trace`. See Bu-4 for the missing `c` argument |
| `inverse_permutation_lut` | `theorem3.jl:72-83` | **Duplicates** `compositional_inverse(::SBox)`. TODO already present at `theorem3.jl:68-71`. Fix: `compositional_inverse(SBox{m}(lut)).lut` |
| inline LUT inversion | `theorem4.jl:66-72` | **Third** copy of the same inversion, not even routed through `inverse_permutation_lut`. Fix: call the shared helper, or core |
| `_apply_linear` | `remark4.jl:17-25` | **Duplicates** `F2LinearMap` application. Fix: build an `F2LinearMap` from the basis and apply it |
| hand-rolled LCG PRNG | `remark4.jl:62-63` | **Reuse violation.** Fix: `Random.Xoshiro(seed)` (or `random_linear_function`). A hand-rolled `s*6364136223846793005+…` generator is unreviewable and non-reproducible across refactors |
| `paper_banner` | `helpers.jl:53-57` | Correctly delegates to `print_banner`. Good |

**Cross-paper duplication:** `theorem1_lut` (`theorem1.jl:24`) and `theorem2_lut`
(`theorem2.jl:24`) are re-implemented as `formula6_n5` and `formula5_n4` in
`papers/2008/Brinkmann_200812/helpers.jl:36-62`. **Promote-to-core candidate:** a
`bcp_trace_apn(m, i)` / `bcp_trace_ab(m, i)` pair in
`packages/VBF/src/constructions/apn_quadratic_families.jl`, next to the existing `bcp_apn`
(which is the *different* BCP binomial family).
