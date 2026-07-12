# Budaghyan_202008 — Constructing APN Functions Through Isotopic Shifts

**Paper:** L. Budaghyan, M. Calderini, C. Carlet, R. Coulter, I. Villa,
*Constructing APN Functions Through Isotopic Shifts*, IEEE Trans. Inf. Theory
66(8):5299–5309, 2020.

**Reproduction:** `papers/Budaghyan_202008/` — `helpers.jl`, `section4.jl`,
`section5.jl`, `section6.jl`, `section7.jl`, `table1.jl`, `report.jl`.

**Verdict:** **Partial** (upgraded after the R1–R10 fix pass). The paper's
headline object — the new quadratic APN function over F₂⁹ — is reproduced
*exactly*, is genuinely APN, and is now **checked to be genuinely new in-repo**:
all 8 Table I rows are built from the paper's own expressions and are pairwise
CCZ-inequivalent (8/8 distinct ortho-derivative mugshots, 0 collisions), and the
new function is also distinct from every quadratic n=9 catalog entry. Theorem
VI.3 is now reproduced as a genuine **iff** — its conditions (i),(ii),(iii) are
constructed and tested in both directions at n=6, 8 and 9 (0 mismatches over
332 379 q-polynomials). Still absent: the Γ-rank column (impossible in-repo,
honestly so), Section VII-D's coverage claim, the n=8 isotopic-shift derivation
(R8), and roughly a dozen of the paper's other numbered results.

---

## Issue Catalog

### Paper Issues

**None found.** No claim checked against the `.tex` failed. (Nor does the
reproduction allege any — see the failure-pattern audit.)

### Reproduction Issues

**R1. [RESOLVED] `print_check` shadows the VBF export and throws on failure,
making every test assertion decorative.**

- **Resolution:** Deleted the local `print_check` (and `print_header`);
  `helpers.jl` now uses `VBF.print_check`, which returns instead of throwing.
  The `@test`s now genuinely gate. **Mutation-verified:** stubbing
  `section4.jl`'s `ok_zero = false` makes the suite report *"4 passed, 1 failed"*
  — the `@test` observes the `false` — where previously it would have aborted
  inside the check function before the NamedTuple was returned. A leftover
  `@assert` in `section7.jl` (same abort-instead-of-gate pattern) was removed for
  the same reason.
- **Location:** `papers/Budaghyan_202008/helpers.jl:144`
- **Symptom:** The local `print_check` is `passed || error(...)` and fully shadows
  `VBF.print_check` (confirmed: `parentmodule(...) == Main`), with a different
  argument order *and* different semantics.
- **Root cause:** Because a failing check `error()`s **before** the NamedTuple is
  returned, every `@test r.ok_*` in the test files can only ever observe `true`.
  A regression cannot be caught by the suite — it aborts instead, and the
  `@test`s never run.
- **Resolution plan:**
  1. Delete the local `print_check`; use `VBF.print_check` (which returns rather
     than throws).
  2. Re-run the suite and confirm the `@test`s now actually gate the results.

**R2. [RESOLVED] The novelty check is under-scoped — the paper's central claim.**

- **Resolution:** `table1_entries()` now builds **all 8 Table I rows** from the
  paper's own expressions (rows 4–6 via `gf_trace`/`gf_relative_trace`, row 7 via
  `terms_to_lut`), and `section7_check_n9_inequivalence` compares the new
  function against **all 7 known rows** *and* all 5 quadratic n=9 catalog entries.
  Result: **8/8 distinct mugshots, 0 collisions**; new ≠ each of the 7 known rows;
  new ≠ each of the 5 catalog quadratics. Soundness recorded in the code: mugshot
  *inequality* certifies EA-inequivalence, and all 8 rows are quadratic APN, for
  which EA = CCZ (Yoshiara) — so this settles CCZ-inequivalence. Mugshot
  *equality* is never used to claim equivalence, and `are_ccz_equivalent`'s
  best-effort `false` is not used as evidence. The 4 non-quadratic n=9 catalog
  entries are power maps, excluded by the same Yoshiara result (the paper's own
  argument). **Mutation-verified:** dropping rows 4–7 from `table1_entries` makes
  the suite fail (`known_checked == 7`, `known_distinct == 7`, `nonvacuous`).
- **Location:** `papers/Budaghyan_202008/section7.jl:49-75`,
  `papers/Budaghyan_202008/table1.jl:26-51`
- **Symptom:** `section7.jl:54` compares the new function against exactly three
  catalog names (`n9_Gold_x3`, `n9_Gold_x5`, `n9_Gold_x17`) and then prints
  *"new function ≠ all catalog n=9 Gold APNs"*. The paper claims inequivalence to
  **all** known APN over F₂⁹ — Table I rows 1–7. Rows 4, 5, 6, 7 are never
  compared. `table1.jl` has the same gap (4 of 8 rows).
- **Root cause:** The comparison set was drawn from what the catalog happened to
  contain, not from what the paper claims.
- **Resolution plan:**
  1. Build Table I rows 4, 5, 6, 7 from the paper's expressions (`gf_trace` and
     `gf_relative_trace` are both VBF exports).
  2. Compare all 8 rows pairwise by `apn_ea_mugshot`.
  3. Verified during review: **8/8 distinct, 0 collisions**. Cheap — seconds at
     n=9.

**R3. [RESOLVED] VACUOUS TEST — Theorem V.1's `is_2to1` branch is never
evaluated.**

- **Resolution:** The short-circuited guard is gone. `section5_check_theoremV1`
  now scans **all 1-term and 2-term linear `L` at n=6 (59 913 maps)** and
  classifies *every* one of them — `is_permutation_map(L)` and `is_2to1(L)` are
  both evaluated unconditionally, so neither can be skipped. It checks
  Theorem V.1(i) on `L`, **V.1(ii) on `M(x) = L(x) + x`** (previously never
  checked at all, including the "injective on 𝒱(·)" half of both), and the
  contrapositive: no `L` with dim ker ≥ 2 yields an APN shift.
  Observed: **890 APN shifts, all with `L` a permutation; 0 with `L` 2-to-1** —
  stated explicitly in the check's output and pinned by an assertion, rather than
  shipped as a green vacuous test. The scan space itself supplies the
  discriminating power: **23 814 of the scanned maps are 2-to-1** (so `is_2to1`
  returns `true`) and **9 639 have dim ker ≥ 2** (so it returns `false` on a
  non-permutation). Non-vacuity guards (`n_2to1 > 0`, `n_neither > 0`,
  `apn_count > 0`) are asserted first. **Mutation-verified both ways:** hardcoding
  `is_2to1 = false` fails 3 assertions; hardcoding it `true` fails 5.
  Still true, and now said out loud: a *positive* 2-to-1 case (an APN shift whose
  `L` is 2-to-1) does not exist among 1-term or 2-term `L` at n=6 — that branch of
  V.1(i) is exercised only negatively here.
- **Location:** `papers/Budaghyan_202008/section5.jl:86`,
  `papers/Budaghyan_202008/test/test_section5.jl:11`
- **Symptom:**
  ```julia
  if kernel_size(L) != 1 && !is_2to1(L)
      violations += 1
  end
  ```
  The test config (`n=6, i=1`, 1-term `L`) only ever produces APN shifts with `L`
  a **permutation** (`kernel_size == 1`), so the first conjunct is always false
  and `is_2to1` is **never called**. `@test r.violations == 0` would still pass if
  `is_2to1` were hardcoded to `false`.
- **Root cause:** No discriminating positive case exists in the searched space —
  exhaustive 2-term `L` over GF(2⁶) yields **828 APN shifts, all with `L` a
  permutation, 0 with `L` 2-to-1**. A positive case requires general linear `L`
  (the paper's Sec. VII-D says both occur). Theorem V.1(ii) (the `M(x)=L(x)+x`
  half) is never checked at all.
- **Resolution plan:**
  1. Assert `kernel_size(L) == 1 || is_2to1(L)` directly, so `is_2to1` is actually
     exercised.
  2. Add the Theorem V.1(ii) check on `M(x) = L(x)+x`.
  3. Seek a real 2-to-1 positive case with general linear `L` (it does not exist
     among 1-term or 2-term `L` at n=6).

**R4. [RESOLVED] OVERCLAIMING — false counts in comments and report labels.**

- **Resolution:** All four corrected. The catalog count (**5** quadratic n=9
  entries) and the Table I count (**8 rows = 7 known + 1 new**) are no longer
  hardcoded in prose — they are *computed* and asserted (`length(cat_quadratic)
  == 5`, `n_entries == 8`), so they cannot silently rot again. `report.jl` now
  labels Proposition V.3 **"Partial (q = 2 only)"** and Lemma VI.6 **"Partial
  (cases (i), (ii), (iv) of 5)"**.
- **Location:** `papers/Budaghyan_202008/section7.jl:70-72`,
  `papers/Budaghyan_202008/table1.jl:24,72-74`,
  `papers/Budaghyan_202008/report.jl:18-19`
- **Symptom / actual:**
  - `section7.jl:70-72` says *"catalog has 3 n=9 quadratic APNs (Gold only); paper
    Table I lists 8 known + 1 new = 9 total"*. **Both halves are wrong.** The
    catalog has **5** quadratic n=9 entries (3 Gold + `n9_Budaghyan2009_eq7` +
    `n9_Budaghyan2009_eq8`, both `algebraic_degree = 2`), and Table I has **8 rows
    = 7 known + 1 new**.
  - `table1.jl:24` says *"The paper's full Table I has 9 entries"* — it has **8**.
  - `table1.jl:72-74` says *"remaining 5 are non-Gold quadratic APNs not yet in
    catalog"* — there are **4** non-Gold known rows, and **2 of them are already
    in the catalog**.
  - `report.jl:18-19` labels Proposition V.3 and Lemma VI.6 **"Exact"**; both are
    partial (q=2 only; 3 of 5 cases).
- **Resolution plan:** Correct all four; align the report labels with actual
  scope.

**R5. [RESOLVED] False docstring — contradicted by its own code three lines
later.**

- **Resolution:** The "finds at least 2 CCZ-classes" claim is deleted. The check
  now states what is true and asserts it: 1-term `L` yields **exactly 1** EA-class
  (Gold), as Lemma VI.6 predicts — `@test r6.nclasses == 1`.
- **Location:** `papers/Budaghyan_202008/section7.jl:104`
- **Symptom:** *"This bounded check finds at least 2 CCZ-classes (G_1 and number
  1.2/Kim)"*. It finds **1** (`distinct EA-classes found (1-term L): 1`), and the
  comment at `section7.jl:124-126` correctly says 1 is expected.
- **Resolution plan:** Delete the false claim.

**R6. [RESOLVED — relabelled] `section7_check_n6_monomial_coverage` is labelled
"Section VII-D" but tests nothing from Section VII-D.**

- **Resolution:** Relabelled honestly (the "implement the real claim" option was
  not taken — see Open Questions). Renamed to
  `section7_check_n6_1term_shift_classes`; its section header and docstring now
  say it tests **Lemma VI.6(i)**, and both the docstring and the printed output
  state that this is *not* Section VII-D and why: VII-D's claim needs a search
  over general linear `L` (~2³⁶ maps) plus the unimplemented Proposition VI.1
  normalisation.
- **Location:** `papers/Budaghyan_202008/section7.jl:106`
- **Symptom:** It asserts only `haskey(apn_mugshots, G1_mug)` — that the Gold
  class is reachable from a 1-term shift. That is Lemma VI.6(i), **true by
  construction**.
- **Root cause:** Section VII-D's real claim ("every quadratic APN over F₂⁶ is
  EA-equivalent to an isotopic shift of x³") needs a search over
  GL(6,2) ∪ 2-to-1 maps (~2³⁶ linear maps), likely infeasible without the
  Proposition VI.1 normalisation — which is also unimplemented.
- **Resolution plan:** Re-label honestly, or implement the real claim. **Needs a
  decision — see Open Questions.**

**R7. [RESOLVED] Theorem VI.3's conditions (i), (ii), (iii) are never
constructed.**

- **Resolution:** Implemented. `theorem_vi3_setup(n, m)` builds `d`, `d'`,
  `U = ⟨ζ^{d'(q−1)}⟩` and `W = {y·ζ^j}`; `theorem_vi3_conditions(L, setup, i)`
  evaluates (i), (ii), (iii) literally as stated. `section6_check_theoremVI3_iff`
  tests the **iff in both directions** — for every `L` in the scan, *APN ⟺
  conditions* — counting mismatches in either direction:

  | config | q-polynomials tested | APN | conditions hold | mismatches |
  |---|---|---|---|---|
  | n=6, m=3 (k=2, q=8) | 4 096 (exhaustive) | 764 | 764 | **0** |
  | n=6, m=2 (k=3, q=4) | 262 144 (exhaustive) | 2 204 | 2 204 | **0** |
  | n=8, m=4 (k=2, q=16) | 65 536 (exhaustive) | 1 172 | 1 172 | **0** |
  | n=9, m=3 (k=3, q=8) | 803 (sample + the paper's 3 sets) | 3 | 3 | **0** |

  Each config contains both APN and non-APN `L`, so both directions bite
  (asserted as `nonvacuous`). The n=6, m=2 config is the one with `d' = 3 > 1`, so
  the `W = {y·ζ^j}` coset construction is genuinely exercised and not just
  `W = U`. n=9's space is 2²⁷, so it is sampled — with the paper's own three
  Section VII-B parameter sets injected to supply the positives; they are exactly
  the 3 APN hits. **Mutation-verified:** forcing the conditions to hold always
  fails 6 assertions across all four configs.
  n=8 with m=2 (k=4, q=4) is *not* in the shipped set: its space is 2³², and a
  400-sample contains 0 APN positives, so it would test only one direction.
- **Location:** `papers/Budaghyan_202008/section6.jl:67-114`
- **Symptom:** The theorem is an **iff**, and neither direction is implemented —
  `d`, `d'`, `U`, `W` are never built. The reproduction only *instantiates* the
  theorem at one parameter set.
- **Resolution plan:** Construct the conditions and test the iff in both
  directions at n=6, 8, 9.

**R8. The n=8 co-headline claim is not reproduced.**

- **Location:** `papers/Budaghyan_202008/section7.jl:35`
- **Symptom:** The abstract's second result is that `x⁹+Tr(x³)` over F₂⁸ — known
  since 2006, previously unclassified — **arises as an isotopic shift `G_{3,L}`
  with k=4, m=2**. The file builds `x⁹+Tr(x³)` **directly** and checks `du==2`.
  That verifies a 2006 result, not this paper's claim.
- **Root cause:** The isotopic-shift construction is never performed.
- **Resolution plan:** Needs a search over 4-term F₄-polynomials `L` over F₂⁸.
  The paper reports the result but does **not** publish the parameters, so this
  means re-deriving the search, not transcribing it. **Needs a decision — see Open
  Questions.**

**R9. [RESOLVED] Field pinning is undocumented and unasserted.**

- **Resolution:** `section6_check_field_pinning` asserts
  `primitive_polynomial(9) == 529` (x⁹+x⁴+1) and that **ζ = 2 is primitive**
  (multiplicative order 511, and it is the smallest such element), with the
  dependency recorded in the docstring: every ζ^k the paper quotes is meaningless
  without this pair.
- **Stronger than reported:** `ζ = 2` is *not* safe in general, and the
  reproduction relied on it. `primitive_polynomial(8) = 283` is the **AES**
  polynomial, under which **2 has multiplicative order 51, not 255** — it is not
  primitive. This is now a *tested* counter-example (`fp.ord2_n8 == 51`), and
  `helpers.jl` gained `primitive_element(n; modulus)` + `multiplicative_order`,
  so ζ is **searched, never assumed**. This was not academic: the first draft of
  the Theorem VI.3 check (R7) built `W` from `ζ = 2` at n=8 and got the wrong
  subgroup (|W| = 17 instead of 85), producing 72 spurious "conditions hold but
  not APN" mismatches. With ζ searched, mismatches went to 0.
- **Location:** `papers/Budaghyan_202008/section6.jl:70`
- **Symptom:** `zeta = 2` is hardcoded with `modulus = primitive_polynomial(9)` =
  `529` = `x⁹+x⁴+1`. Nothing asserts that `2` is primitive, or that this modulus
  is the paper's (the paper never pins one).
- **Root cause:** The choice happens to be right — it is the Conway/Magma default
  and matches the modulus recorded in `n9_apn.toml`, and all three of the paper's
  `m=3` parameter sets give `du=2` under it (which would be an extraordinary
  coincidence otherwise). But a change to `primitive_polynomial(9)` would silently
  invalidate every `ζ^k` exponent in the paper.
- **Resolution plan:** Assert `primitive_polynomial(9) == 529` and that `ζ=2` is
  primitive, with a comment recording the dependency.

**R10. [RESOLVED] Helpers duplicate core exports.**

| Helper | Duplicated | Resolution |
|---|---|---|
| `print_check` | `VBF.print_check` (shadowed it) | **deleted** — core export used (R1) |
| `print_header` | `print_banner` | **deleted** — `report.jl` uses `print_banner` |
| `gold_lut` | `gold_apn(n,k; modulus)` | **deleted** — all call sites use `gold_apn(...).lut`, which also enforces `gcd(k,n)=1` |
| `linear_monomial_lut`, `linear_trinomial_lut` | `terms_to_lut` | **deleted** — call sites build `L` directly with `terms_to_lut([(b_j, 2^j), …], n, modulus)` |
| `zero_map_lut`, `identity_map_lut` | `zero_linear_map`, `identity_linear_map` | now thin wrappers over the core maps via a one-line `F2LinearMap → LUT` bridge (`linear_map_lut`) |
| `kernel_size`, `is_2to1` | `kernel_f2` / `is_permutation` | now thin over `kernel_f2` (`kernel_dimension`); `is_permutation_map` calls `VBF.is_permutation` |

Legitimately paper-specific (kept): `isotopic_shift_lut` (Definition I.1),
`is_zero_map`, `injective_on_image` (the 𝒱(·) half of Theorem V.1), and
`find_c_for_d`. Added (paper-local, deliberately — see Promote-to-core note):
`multiplicative_order`, `primitive_element` (R9).

---

## Failure-pattern audit (explicitly checked)

| Pattern | Verdict (at review) | After the fix pass |
|---|---|---|
| **Vacuous tests** | **PRESENT** — R3 (`is_2to1` never evaluated), and R1 makes *all* `@test`s decorative. | **FIXED.** Every new assertion is mutation-tested: stubbing `is_2to1` (either way), the VI.3 conditions, or the Table I row set makes the suite fail. Non-vacuity guards are asserted explicitly. |
| **False paper-issue claims** | **ABSENT.** No comment or docstring alleges a paper typo. | unchanged |
| **Copy-paste stubs** | **ABSENT.** | unchanged |
| **Field-representation fragility** | **Latent but benign** — R9. | **FIXED, and it was not benign** — ζ = 2 is not primitive at n=8; ζ is now searched. See R9. |
| **Overclaiming report/comments** | **PRESENT** — R4, R5, R6. | **FIXED.** Counts are computed and asserted, not asserted in prose. |

## Items reproduced exactly (context)

| Paper item | Evidence |
|---|---|
| Definition I.1 (isotopic shift `F_L`) | `helpers.jl:21` |
| Theorem IV.1 | `section4.jl:23`, incl. a positive counterexample (`L=x²` ⇒ `F_L ≠ 0`) |
| Corollary IV.2(ii) | `section4.jl:55`, with both a positive and a discriminating negative case |
| **Table I row 8 (the new APN)** | LUT-identical to the paper's explicit polynomial `ζ³³⁷x¹²⁹ + ζ⁴²⁴x⁶⁶ + ζ²x¹⁷ + ζx¹⁰ + ζ³⁴x³`; `du=2`, `deg=2`, not a permutation |

Confirmed during review but **not checked by the repo**: all three `m=3` parameter
sets from Section VII-B (`[ζ⁴²⁴,ζ,ζ³⁴]`, `[ζ²⁶³,ζ,ζ²⁷²]`, `[ζ⁵⁰⁸,ζ,ζ¹³²]`) give
`du=2`; and the `L` for row 8 **is a complete mapping**, i.e. Theorem VI.2 holds
on the instance.

## Not reproduced

*(Updated after the fix pass: Theorem VI.3's conditions and Table I rows 4–7 are
now reproduced — R7, R2.)*

**Section II:** Theorem II.1 (the motivating theorem). **Section III:** Eq. (3),
Theorem III.1, Corollary III.2, Eq. (4) — all cheap and directly testable.
**Section V:** Corollary V.2, Theorem V.4, Corollary V.5. **Section VI:**
Proposition VI.1 (the normalisation the *whole* computational search depends on),
Theorem VI.2, Corollary VI.4, Proposition VI.5, Lemmas VI.7–VI.10, and Lemma VI.6
cases (iii) and (v). **Section VII:** Remark VII.1, Conjecture VII.2 (not even
stated), Observation VII.3, VII-A (n=6..16), VII-C, VII-D (R6), VII-E, VII-F.
**Table I:** the entire Γ-rank column.

**Γ-rank is genuinely impossible in-repo — the omission is honest.**
`packages/VBF/src/invariants/design_ranks.jl:68-74` throws for `n > 7` ("compute
it with Magma"). So `report.jl:35`'s "Not run: Γ-rank" is **justified**, and
Table I's Γ-rank column is unverifiable here. This does not weaken the novelty
conclusion — the ortho-derivative mugshot already separates all 8 rows.

## Test results (as run)

All Julia run through a 2 GiB-capped cgroup wrapper; `make` bypassed (its
`JULIA ?= julia` would escape the cap). **No OOM; nothing skipped for memory.**

| Command | Result (at review) | Result (after fix pass) |
|---|---|---|
| `test/runtests.jl` | **PASS** — 18 assertions, 4.4 s — but decorative (R1) and one vacuous (R3) | **PASS** — section4 5/5, section5 21/21, section6 45/45, section7 14/14, table1 10/10 = **95 assertions, 17.7 s**, and they now gate |
| `report.jl` | all `[PASS]` | all `[PASS]` |

`test_section7.jl` now exists (the novelty claim had no test file at all). No
`results/*.toml` despite `make clean_results` — unchanged.

All Julia was run through a 2 GiB-capped cgroup wrapper; `make` was bypassed (its
`JULIA ?= julia` would escape the cap). No OOM; nothing skipped for memory.

## Catalog status

**The paper's claimed-new APN over F₂⁹ is MISSING from the catalog → real gap.**

Verdict levels *(updated after the fix pass)*: formula reproduced **yes** (and the
isotopic shift is checked LUT-identical to the paper's explicit Table I row-8
polynomial); APN verified **yes** (`du=2`, `deg=2`, not a permutation); parameter
family validated **yes** (all three Section VII-B `m=3` sets — `[ζ⁴²⁴,ζ,ζ³⁴]`,
`[ζ²⁶³,ζ,ζ²⁷²]`, `[ζ⁵⁰⁸,ζ,ζ¹³²]` — give `du=2` and satisfy Theorem VI.3);
novelty checked **yes, in-repo** (all 7 known Table I classes + all 5 quadratic
n=9 catalog entries, 0 collisions); full claim reproduced **no** (Γ-rank column
remains out of reach).

**This section is a RECORD, not a task:** the catalog write below is owned by a
separate task. No TOML was written by this fix pass.

### Catalog-gap record

```
target file: packages/VBFCatalog/data-raw/apn_catalog/n9_apn.toml
name              = "n9_Budaghyan2020_isotopic_shift"
n                 = 9
m                 = 9
is_permutation    = false
algebraic_form    = "z^337*x^129 + z^424*x^66 + z^2*x^17 + z*x^10 + z^34*x^3 in GF(2^9), z primitive, modulus x^9 + x^4 + 1; = isotopic shift G_{1,L} of the Gold map x^3 by the F_8-linear L(x) = a*x^(2^6) + b*x^(2^3) + c*x with [a,b,d] = [z^424, z, z^34], d = c^2 + c"
bib_key           = "Budaghyan_202008"
source            = "Budaghyan, Calderini, Carlet, Coulter, Villa, 'Constructing APN Functions Through Isotopic Shifts', IEEE Trans. Inf. Theory 66(8):5299-5309, 2020. Theorem VI.3 (k = m = 3); Table I, entry N.8 (Gamma-rank 48596)."
modulus           = 529
```

The full 512-entry LUT is in the review transcript. Equivalence evidence:
`apn_ea_mugshot` distinct from every quadratic n=9 catalog entry
(`n9_Gold_x3`, `n9_Gold_x5`, `n9_Gold_x17`, `n9_Budaghyan2009_eq7`,
`n9_Budaghyan2009_eq8`); the 4 non-quadratic entries (`n9_Kasami_x13`,
`n9_Kasami_x241`, `n9_Welch_Niho_x19`, `n9_Inverse_x510`) are power maps, excluded
by Yoshiara — exactly as the paper argues in Sec. VII-B. `bib_key
= "Budaghyan_202008"` already exists at
`packages/VBFCatalog/data-raw/bibliography.bib:828`.

### Secondary catalog gaps (block any complete in-repo novelty check at n=9)

- **Table I row 4**, `Tr₁⁹(x⁹) + x³` (Budaghyan–Carlet–Leander, Γ-rank 47890) —
  APN, quadratic, absent from `n9_apn.toml`.
- **Table I row 7**, `x³ + x¹⁰ + ζ⁴³⁸x¹³⁶` (Edel–Pott [15, Table 11] 8.1, Γ-rank
  48608) — APN, quadratic, absent.
- At **n=6**: `n6_apn.toml` has only 3 entries yielding **2** distinct quadratic
  EA-classes, because `n6_Gold_x3` and `n6_Kasami_x48` are EA-equivalent
  (`x⁴⁸ = (x³)^16` over GF(2⁶)). The paper's class "1.2"
  (`x³ + ζ⁻¹Tr(ζ³x⁹)`) is absent. *(This corroborates the same duplication found
  independently in the Calderini_202009 review.)*

## Library-reuse note

See R10 for the duplication table.

**Promote-to-core candidate:** `find_c_for_d` (`helpers.jl:114`) — solving the
Artin–Schreier equation `c² + c = d` over GF(2ⁿ) is a generic primitive VBF
lacks. The current implementation is an O(2ⁿ) linear scan and `error()`s when
`Tr(d)=1` rather than reporting "no solution". A proper `artin_schreier_solve` in
`packages/VBF/src/` (via `solve_f2`, with a `Tr(d)=0` solvability check) would
serve this and future papers.

## Open questions (need a decision before fixing)

1. **Is the n=8 claim in scope (R8)?** Reproducing it needs a search over 4-term
   F₄-polynomials `L` over F₂⁸, and the paper does **not** publish its parameters
   — so it means re-deriving the search, not transcribing it.
2. **Section VII-D (R6)** — implement the real claim (needs Proposition VI.1's
   normalisation, currently unimplemented, plus a ~2³⁶ search), or re-label the
   check honestly?
3. **Conjecture VII.2** is untestable, but should it at least be transcribed with
   the paper's supporting dimensions (n = 6, 8, 9, 12, 18)? Should the m=4 and m=6
   parameter sets from Section VII-B be attempted? n=12 is feasible; n=18 is not.
