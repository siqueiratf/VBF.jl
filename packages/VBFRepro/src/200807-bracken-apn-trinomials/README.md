# Bracken et al. (2008) — New families of quadratic almost perfect nonlinear trinomials and multinomials

- **Citation:** C. Bracken, E. Byrne, N. Markin, G. McGuire, "New families of quadratic almost
  perfect nonlinear trinomials and multinomials", *Finite Fields Appl.* 14(3):703–714, 2008.
- **Reproduction path:** `packages/VBFRepro/src/200807-bracken-apn-trinomials/`
- **Paper source:** `input/Bracken et al. - 2008 - New families of quadratic almost perfect nonlinear trinomials and multinomials.tex`
- **Verdict:** **Good** — every claim that is tested checks out. All seven reproduction issues
  below are resolved: the LUT builders now validate their hypotheses, the parameter labels
  name the values actually built, Lemma 2(i) is tested in GF(2^k), the coverage strings state
  the true fraction of the parameter space (with a `full_search` flag that sweeps all 150 528
  Family-1 tuples), Theorem 4 has its own weaker-hypothesis builder, Theorem 6's statement is
  reproduced in the forward direction plus the weight-enumerator necessary condition, and
  `dillon_T2` delegates to `kim_apn()`.

---

## Issue Catalog

### Paper Issues

Flaws in the original publication / its OCR'd source. Not ours to fix.

1. **Family (2)'s exponent `2^{-k}` is only meaningful mod `2^{3k}−1`**, but the tex writes
   `x^{2^{-k}+2^{k+s}}` without saying so. (The repo handles this correctly at
   `helpers.jl:83,91`.)
2. **Typos in the Theorem 3 proof:** `α = u^{-2^k} v q^{2^{k+s}}-1` should be
   `q^{2^{k+s}-1}`; `L_{a^{-2}}` should be `L_{a^{-2^k}}`.
3. **Dillon's T2 `x³ + θx²⁴ + x¹⁰` is only APN under the Conway modulus**, and the paper never
   states which field polynomial it uses. Under `x⁶+x+1` the function has `du = 4`; under the
   Conway polynomial `x⁶+x⁴+x³+x+1` it has `du = 2`. (The repo documents this correctly at
   `theorem6.jl:43`.)

### Reproduction Issues

Defects introduced in our implementation.

#### Br-1 [RESOLVED] — LUT builders accept invalid parameters and silently return non-APN functions

- **Location:** `helpers.jl:56-74` (`family1_lut`), `helpers.jl:88-99` (`family2_lut`),
  `theorem1.jl:41-48` (`theorem1_sbox`), `theorem3.jl:42-47` (`theorem3_sbox`).
- **Symptom (demonstrated):**

  | call | result |
  |---|---|
  | `family1_lut(3,1,b=1,c=4,[0,0])` (b is a cube) | **du = 8**, not APN |
  | `family1_lut(3,1,b=3,…)`, `b=5`, `b=8`, `b=13` | **du = 8** |
  | `family1_lut(3,1,b=2,c=0/1/14/15)` (c ∈ GF(8)) | **du = 8** |
  | `family2_lut(2,5,u=2,v=1)` (3 ∤ k+s = 7) | not APN |
  | `family2_lut(2,1,u=1,v=1)` (u not primitive) | not APN |
  | `family2_lut(2,1,u=2,v=4)` / `v=7` (v ∉ GF(4)) | not APN |

- **Root cause:** the only guards are two `@assert` lines inside the *report* function
  (`theorem1.jl:64-65`). `family1_lut`, `family2_lut` and `theorem3_sbox` validate nothing, and
  `theorem4.jl` / `theorem6.jl` call `theorem1_sbox` / `theorem3_sbox` directly, bypassing the
  asserts entirely. Compare `bcp_apn`
  (`packages/VBF/src/constructions/apn_quadratic_families.jl:81-99`), which throws
  `ArgumentError` on every hypothesis violation.
- **Resolution plan:**
  1. In `family1_lut`, validate: `isodd(k) && isodd(s)`, `gcd(k,s)==1`,
     `!gf_is_dth_power(b, 3, 2k; modulus)`, `!in_subfield(c, k, 2k; modulus)`,
     `all(r_i -> in_subfield(r_i, k, 2k; modulus), r)`; throw `ArgumentError` otherwise.
  2. In `family2_lut`, validate: `gcd(s, 3k)==1`, `k % 3 != 0`, `(k+s) % 3 == 0`, `u` primitive
     (order `2^{3k}−1`), `in_subfield(v, k, 3k; modulus)`.
  3. Add negative tests to `test/test_theorem1.jl` / `test/test_theorem3.jl`
     (`@test_throws ArgumentError family1_lut(3,1,1,4)` etc.), mirroring
     `Budaghyan_200506/test/test_theorem1.jl:26-28`.
  4. Add a separate, explicitly-labelled "hypotheses are necessary" check that builds the
     invalid instances via a `validate=false` keyword and shows `differential_uniformity == 8`.
- **Resolution:** `helpers.jl` gained `family1_validate` / `family2_validate` (plus
  `is_primitive_element`), called from `family1_lut` / `family2_lut` behind a
  `validate::Bool = true` keyword; every hypothesis violation now raises `ArgumentError`.
  `theorem1_necessity_report` / `theorem3_necessity_report` build the rejected tuples with
  `validate=false` and print the resulting `du`. Negative tests added to
  `test/test_theorem1.jl` and `test/test_theorem3.jl`.
  Two review claims were corrected against measurement: `c ∈ {1,14,15}` gives `du = 16`
  (not 8), and `u = 8` is **not** a counterexample — at n=6 `u` primitive is *sufficient but
  not necessary*, 72 of the 108 non-primitive `(u,v)` pairs are still APN (exactly
  `ord(u) ∈ {7, 21}`). That is now recorded by `theorem3_nonprimitive_n6`, and the
  primitivity violation is demonstrated with `u = 6` (order 9, `du = 16`) instead.

#### Br-2 [RESOLVED] — Parameter labels do not match the parameters actually used

- **Location & symptom:**

  | Location | Label says | Actually built |
  |---|---|---|
  | `theorem1.jl:27` | `pentanomial (r1=ω^9, r2=1)` | `r = [1, 0]` → r₁ = 1 (ω⁹ = **24**), r₂ = 0 → a **quadrinomial**, not a pentanomial |
  | `theorem4.jl:30` | `pentanomial (r=[ω⁹,0])` | `r = [1, 0]` |
  | `theorem3.jl:29` | `v=ω²¹` | `v = 1` (ω²¹ = **59**) |
  | `theorem3.jl:32` | `v=ω²⁷³` | `v = 1` (ω²⁷³ = **1971**) |
  | `test/test_theorem1.jl:20` | `r=[ω^9, 0]` | `[1, 0]` |
  | `test/test_theorem1.jl:24-25` | `r=[ω^9, 1]` | `[1, 1]` |

- **Root cause:** `theorem1.jl:44-45` and `theorem3.jl:45` index into
  `filter(!iszero, subfield_elements(n, k; modulus))`, which is sorted by **integer value**, so
  index 1 is always the element `1` — never a power of ω. Concretely
  `subfield_elements(6,3) = [1,14,15,22,23,24,25]` and `subfield_elements(6,2) = [1,58,59]`.
- **Resolution plan:**
  1. Either restate the labels with the actual integer values, or
  2. change the selection to `gf_pow(2, e, n; modulus)` for an explicit exponent `e` and keep
     the ω-notation labels.
  3. Add a genuine pentanomial case `r = [subf[2], subf[3]]` (both nonzero) so the "up to k+2
     nonzero coefficients" claim from the paper's Section 1 is actually exercised.
- **Resolution:** plan step 2. `theorem1_sbox(k, s, r_exp)` and `theorem3_sbox(k, s, v_exp)`
  now take **ω-exponents** (`nothing` ⇒ coefficient 0) and evaluate `gf_pow(2, e, n; modulus)`;
  no code indexes `subfield_elements` for a coefficient any more. Labels carry both notations,
  e.g. `r=[ω⁹=24, ω¹⁸=15]`, `v=ω²¹=59`, `v=ω²⁷³=1971`, and the old `[1,0]` case is now
  correctly called a **quadrinomial**. Plan step 3: the genuine pentanomial `r = [ω⁹, ω¹⁸]`
  (both nonzero) was added to `THEOREM1_CASES`, to Theorem 4's bent sweep and to the tests.

#### Br-3 [RESOLVED] — Lemma 2(i) is tested in the wrong field

- **Location:** `theorem3.jl:59-62` and `test/test_theorem3.jl:12-13`.
- **Symptom:** the label reads `all θ ∈ GF(4)* are 7th powers in GF(4) [7∤(2²−1)=3]`, but the
  code calls `gf_is_dth_power(θ, 7, n; modulus)` with `n = 6` — i.e. it tests 7th-power-ness in
  **GF(64)**, not GF(4). Both statements happen to be true, so the test passes for the wrong
  reason.
- **Root cause:** `n` is passed where `k` is meant.
- **Resolution plan:**
  1. Either fix the label to say "7th powers in GF(2^{3k})" — which is the fact the proof
     actually uses, via `7 | 2^{2k}+2^k+1` for `3∤k` — or
  2. evaluate the subfield membership in GF(2^k) by mapping through `subfield_elements`.
- **Resolution:** plan step 2. `lemma2_report` now checks
  `Set(gf_pow(θ, 7, n; modulus) for θ in subfield_elements(n, k; modulus)) == Set(subfield_elements(n, k; modulus))`
  — i.e. `x ↦ x⁷` is a bijection **of GF(2^k)**, which is Lemma 2(i) as stated and as used in
  the Theorem 3 proof (`v ∈ F_{2^k}` is a 7th power *in* `F_{2^k}`). The label was corrected to
  match, and `test/test_theorem3.jl` mirrors the check with a comment naming the different
  (also true, but unused) GF(2^{3k}) statement that was being tested before.

#### Br-4 [RESOLVED] — Reported completeness is false

- **Location:** `theorem1.jl:75-76`, `theorem3.jl:105-106`, `report.jl:24-26`.
- **Symptom:** the report prints `completeness: n=6 exhaustive over listed (k,s,r) tuples` and
  `[exact] Theorem 3 — Family 2 APN (n=6 and n=12 exhaustive)`. Actual coverage at n=6:
  - Family (1): **3 tuples out of 150 528** valid ones — 42 (non-cube b) × 56 (c ∉ GF(8)) × 64
    (r₁,r₂ ∈ GF(8)).
  - Family (2): **2 tuples out of 144** — u=2 with v ∈ {0,1}, against 36 (primitive u) × 4
    (v ∈ GF(4)).
- **Root cause:** "exhaustive over the listed tuples" is tautological, and `report.jl` then
  abbreviates it to plain "exhaustive".
- **Resolution plan:**
  1. Add `theorem3_exhaustive_n6()` iterating all 144 (u,v) pairs — all 144 were independently
     verified APN during review; this runs in well under a second.
  2. Add `theorem1_exhaustive_n6(; limit)` over all 150 528 tuples behind a `full_search` flag,
     with a bounded random sample as the default (400/400 sampled tuples verified APN).
  3. Reword the `completeness` strings to state the exact fraction of the parameter space
     covered.
- **Resolution:** all three steps. `theorem3_sweep_n6()` iterates all 36 primitive `u` × 4
  `v ∈ GF(4)` = **144/144 APN**. `theorem1_sweep_n6(; full_search, sample, seed)` reports
  `tested/total` against the true `42·56·64 = 150 528`; the default is a seeded 400-tuple
  sample and `full_search=true` sweeps all 150 528 (verified: **150528/150528 APN**, 8.5 s).
  `theorem1_valid_parameters_n6()` exposes the three factor sets, asserted at 42/56/8 in the
  tests. The `completeness` strings and `report.jl`'s scope block now state exact fractions
  (n=12 Family 2 is 2 of 27 648 = 0.007%); `make report_full` / `make theorem1_full` run the
  exhaustive variant.

#### Br-5 [RESOLVED] — Theorem 4 never tests its own (weaker) hypothesis

- **Location:** `theorem4.jl:31`, which calls `theorem1_sbox` — and that hard-codes `b = 2`
  (non-cube).
- **Symptom:** Theorem 4 requires only `c ∉ F_{2^k}` and `r_j ∈ F_{2^k}`; it imposes **no**
  condition on `b`. Independently verified: `Tr(vf)` is bent for `b ∈ {1,3,8}` (all cubes) even
  though the function then has `du = 8`. The reproduction cannot distinguish Theorem 4's
  hypotheses from Theorem 1's.
- **Root cause:** Theorem 4 reuses Theorem 1's builder rather than having its own.
- **Resolution plan:**
  1. Add `theorem4_sbox(k, s, b, c, r)` that does *not* require `b` non-cube.
  2. Assert bentness holds while `differential_uniformity ≠ 2` — a sharp demonstration that
     Theorem 4 ⊅ Theorem 1.
- **Resolution:** both steps. `theorem4.jl` gained `theorem4_sbox(k, s, b, c, r)`, which
  validates *Theorem 4's* hypotheses only (`c ∉ GF(2^k)`, `r_j ∈ GF(2^k)`, `|r| ≤ k−1`; nothing
  about `b`, nothing about the parity of `k, s`) and then calls
  `family1_lut(...; validate = false)`. `theorem4_strictly_weaker_report` shows, for the cubes
  `b ∈ {1, 3, 8}` that `family1_lut` rejects, that `Tr(v·f)` is bent for **all** 7
  `v ∈ GF(8)*` while `du = 8 ≠ 2`. `test/test_theorem4.jl` asserts all three facts per `b`
  (`@test_throws` on the Theorem 1 builder, bentness, `du ≠ 2`) and that
  `theorem4_sbox` with the non-cube `b = ω` reproduces `theorem1_sbox` exactly.

#### Br-6 [RESOLVED] — Theorem 6 (the paper's actual theorem) is not reproduced

- **Location:** `theorem6.jl:8,56` state it as a comment only; `theorem6.jl:113-114` and
  `report.jl:30` declare it out of scope ("requires Magma").
- **Symptom:** only the *downstream computational consequences* are checked. The statement
  `f ≅_CCZ g ⟺ [Ĉ_f] = [Ĉ_g]` is never touched.
- **Root cause:** the "requires Magma" justification is only partly true. Full code equivalence
  is hard, but the **forward** direction and the paper's own remark ("the weight distribution is
  the same thing as the Walsh spectrum") are cheap, and `VBF` exports
  `code_weight_enumerator`.
- **Resolution plan:**
  1. Build `Ĥ_f` (the `(2n+1) × 2ⁿ` matrix with columns `(1, x, f(x))ᵀ`) and
     `Ĉ_f = Null(Ĥ_f)` for the n=6 instances.
  2. Verify the forward direction constructively: for a known CCZ pair `(F1, T1)`, exhibit
     `X = [[1,0],[γ,M]]` from the `ccz_matrix` / `are_ccz_equivalent` certificate and assert
     `X·Ĥ_{F1}` is a column permutation of `Ĥ_{T1}`.
  3. Assert `code_weight_enumerator(Ĉ_f) == code_weight_enumerator(Ĉ_g)` for all
     CCZ-equivalent pairs and `≠` for T1 vs T2 — this reproduces the paper's own remark and is
     a necessary condition for Theorem 6.
- **Resolution:** steps 1 and 2 as written; step 3 was **wrong on the T1/T2 half** and was
  implemented in the corrected form.
  - Step 1: `paper_code_matrix(F) = ccz_matrix(F)` (documenting that core packs the graph as
    `(x ≪ n) | f(x)`, so the `x`/`f(x)` row blocks are swapped relative to the paper — an
    irrelevant relabelling for both `Null` and column permutation), plus `code_dimension(F)`,
    which confirms `Ĥ_f` is 13×64 of rank 13 and `dim Ĉ_f = 51` for all six n=6 functions.
  - Step 2: `theorem6_forward_certificate(F, G)` takes the linear part `M` from
    `ea_mappings_from_ortho_derivative` (complete on quadratic APN), recovers the translation
    `γ` by matching the two graphs, assembles `X = [[1,0],[γ,M]]`, and
    `theorem6_forward_holds` asserts `X·Ĥ_F` is a column permutation of `Ĥ_G`. Verified for
    Family 1 → T1, Family 2 v≠0 → T2 and Family 2 v=0 → Gold.
  - Step 3, corrected: the plan's `≠` for T1 vs T2 **cannot hold** — the repo already verifies
    that T1 and T2 both have Gold's Walsh spectrum, and the paper's own Section 5 remark says
    the weight distribution *is* the Walsh spectrum. So the enumerators are necessarily
    **equal**. The reproduction therefore asserts equality for the CCZ-equivalent pairs *and*
    equality across all six functions, and states the consequence: the weight enumerator is
    only a necessary condition and cannot separate the CCZ-inequivalent T1 and T2 — which is
    exactly why the paper needed Magma's full code-equivalence test.
    `weight_distribution_matches_walsh(F)` rebuilds the whole distribution from `lat(F)` via
    `weight = 2^{n−1} − (−1)^ε·W_f(a,b)/2` and compares it with
    `code_weight_enumerator(ccz_matrix(F))`, proving the paper's remark instead of quoting it.
    (`Ĉ_f` itself has 2⁵¹ codewords; the MacWilliams identity makes its enumerator equivalent
    to the computed dual's.)
  - The remaining out-of-scope piece is now stated precisely in `report.jl` and in the
    `scope` line: only the **converse** needs binary code permutation-equivalence (Leon's
    algorithm), which `packages/VBF/src/equivalence/ccz/linear_code.jl` documents as
    deliberately unimplemented. The blanket "requires Magma" claim is gone.

#### Br-7 [RESOLVED] — `dillon_T2()` re-derives a function already in core

- **Location:** `theorem6.jl:45-51`.
- **Symptom:** the LUT produced is **byte-identical** to the catalog entry `n6_Kim`
  (`packages/VBFCatalog/data-raw/apn_catalog/n6_apn.toml:36`) — confirmed equal on all 64
  entries. `VBF` already exports `kim_apn()`.
- **Root cause:** the paper's polynomial form was implemented from scratch without checking for
  an existing equivalent.
- **Resolution plan:**
  1. Call `kim_apn()` (or `load_apn_function("n6_Kim")`).
  2. `@assert` LUT equality against the paper's polynomial form, so the identity is documented
     rather than accidentally re-derived.
- **Resolution:** both steps. `dillon_T2()` now returns `kim_apn()` after
  `@assert Int.(F.lut) == paper_form`, where `paper_form` is `x³ + θx²⁴ + x¹⁰` under
  `conway_polynomial(6)`. The docstring states "T2 is the Kim function". `test/test_theorem6.jl`
  asserts both `dillon_T2() == kim_apn()` and the polynomial identity.

---

## Items reproduced exactly

| Paper item | Repo location | Verification |
|---|---|---|
| **Theorem 1** Family (1) APN | `helpers.jl` (`family1_lut`), `theorem1.jl` (`theorem1_sbox`) | k=3 s=1 trinomial / quadrinomial / pentanomial and k=3 s=5, k=5 s=1 all APN; `theorem1_sweep_n6(full_search=true)`: **150 528 / 150 528** valid (b,c,r₁,r₂) tuples APN |
| **Theorem 1** hypotheses are necessary | `theorem1.jl` (`THEOREM1_VIOLATIONS`) | 10 single-hypothesis violations, all rejected by `family1_lut` and all non-APN (du ∈ {4, 8, 16}) |
| **Lemma 2** (i)–(iv) 7th-power facts | `theorem3.jl` (`lemma2_report`) | Hold at k=2, n=6; (i) now evaluated inside GF(2^k) as the paper states it |
| **Theorem 3** Family (2) APN | `helpers.jl` (`family2_lut`), `theorem3.jl` (`theorem3_sbox`) | n=6: all 36 primitive `u` × all 4 `v ∈ GF(4)` are APN (**144/144**); n=12 (k=4,s=5) both subfamilies APN |
| **Theorem 3** hypotheses | `theorem3.jl` (`THEOREM3_VIOLATIONS`, `theorem3_nonprimitive_n6`) | 6 violations rejected and non-APN; `u` primitive is sufficient but **not necessary** at n=6 (72/108 non-primitive pairs still APN, exactly ord(u) ∈ {7,21}) |
| **Theorem 4** Tr(v·f) bent | `helpers.jl` (`trace_component_is_bent`), `theorem4.jl` | Bent for all 7 `v ∈ GF(8)*` on all three Family-1 shapes; and — via `theorem4_sbox`, which drops the non-cube condition — for b ∈ {1,3,8} where du = 8 |
| Sect. 5: Walsh spectra = Gold x³ at n=6 | `theorem6.jl` (`theorem6_report`) | Confirmed for T1, T2, Family 1, Family 2 (v=0 and v≠0) |
| Sect. 5: Family (1) ≅_CCZ Dillon T1 = x³+θ¹¹x⁶+θx⁹ | `theorem6.jl` | `are_ccz_equivalent`; OD DDT spectra identical `((2,1008),(4,378),(8,63))`, Γ-rank 1146 both |
| Sect. 5: Family (2), v≠0 ≅_CCZ Dillon T2 = x³+θx²⁴+x¹⁰ | `theorem6.jl` | OD spectra identical `((2,1428),(4,168),(8,63))`; Γ-rank 1166 both |
| Sect. 5: Family (2), v=0 ≅_CCZ Gold x³ | `theorem6.jl` | OD spectrum `((2,1764),(8,63))` = Gold |
| Sect. 5: Family (1), Family (2) v≠0 ≇_CCZ any power map | `theorem6.jl` | OD spectra differ from Gold's |
| Sect. 5: T1 ≇_CCZ T2 | `theorem6.jl` | OD spectra differ |
| **Theorem 6**, forward direction | `theorem6.jl` (`theorem6_forward_certificate`, `theorem6_forward_holds`) | `X = [[1,0],[γ,M]]` built from the CCZ certificate; `X·Ĥ_f` is a column permutation of `Ĥ_g` for all three equivalent pairs |
| Sect. 5 remark: weight distribution = Walsh spectrum | `theorem6.jl` (`weight_distribution_matches_walsh`) | Distribution rebuilt from `lat(F)` matches `code_weight_enumerator(ccz_matrix(F))` for all six n=6 functions; all six equal Gold's |
| `Ĥ_f` / `Ĉ_f` shape | `theorem6.jl` (`paper_code_matrix`, `code_dimension`) | 13×64, rank 13, `dim Ĉ_f = 51` for all six |
| T2 needs the Conway modulus | `theorem6.jl` (`dillon_T2`) | Confirmed: under `x⁶+x+1` T2 has du = 4; under `x⁶+x⁴+x³+x+1`, du = 2. T2 = `kim_apn()`, asserted |

---

## Test results

`julia --project=<repo_root> packages/VBFRepro/src/200807-bracken-apn-trinomials/test/runtests.jl` (Julia 1.12.6):

```
theorem1_test |   38     38  1.5s
theorem3_test |   31     31  1.0s
theorem4_test |   24     24  0.6s
theorem6_test |   51     51 10.0s
```

**144 / 144 pass, 0 fail.** `make report` and `make report_full` both run clean; the exhaustive
Family-1 sweep (`make theorem1_full`) reports 150 528 / 150 528 tuples APN in 8.5 s.

---

## Catalog status

| Claimed-new family | n=6 representative | Status | Evidence |
|---|---|---|---|
| Family (1), Theorem 1 | k=3, s=1, b=2, c=4, r=0 | **present** as `reprs6_1` in `packages/VBFCatalog/BFA_catalog.sqlite` | OD-derivative DDT spectrum `((2,1008),(4,378),(8,63))` — exact match and unique among all 21 n=6 catalog entries; Γ-rank 1146 matches |
| Family (2), v≠0, Theorem 3 | k=2, s=1, u=ω, v=ω²¹=59 | **present** as `n6_Kim` | `are_ccz_equivalent(F2_v, kim_apn()) == true`; Γ-rank 1166; OD spectrum `((2,1428),(4,168),(8,63))`. *Correction:* the byte-identity with `n6_Kim` holds for **Dillon's T2** `x³+θx²⁴+x¹⁰` under the Conway modulus (asserted in `dillon_T2`), **not** for `family2_lut(2,1,2,v)` under that modulus — measured: none of the four `v ∈ GF(4)` gives the Kim LUT, they are CCZ-equivalent to it |
| Family (2), v=0 (BCFL binomial) | k=2, s=1, u=2, v=0 | **present** as `n6_Gold_x3` / `n6_BCP_k2_s1` | OD spectrum `((2,1764),(8,63))` = Gold; Γ-rank 1102 |

**No catalog-gap records.** `packages/VBFCatalog/data-raw/apn_catalog/n6_apn.toml:39-44`
already documents this decision explicitly and correctly.

---

## Library-reuse note

| Helper | Location | Verdict |
|---|---|---|
| `trace_component_is_bent` | `helpers.jl` | **Legitimately paper-specific.** The docstring's reasoning (trace form vs dot-product form differ by a dual-basis change) is correct; `bent_components` is not a drop-in. Correctly reuses `walsh_transform`, `gf_mul`, `gf_trace`. Keep |
| `family1_lut` / `family2_lut` | `helpers.jl` | Paper-specific families, but they hand-roll the term loop; could use `terms_to_lut` / `polynomial_to_lut`. **Promote-to-core candidate:** `bbmm_family1_apn(k,s,b,c,r)` and `bbmm_family2_apn(k,s,u,v)` in `packages/VBF/src/constructions/apn_quadratic_families.jl`, alongside `bcp_apn`/`bcl_apn`/`taniguchi_apn` — the Br-1 validation (`family1_validate` / `family2_validate`) is now written in the shape core would need. Left paper-local: promoting it is a core API decision, not a reproduction fix |
| `is_primitive_element` / `_prime_divisors` | `helpers.jl` | Added for Br-1. VBF exports no multiplicative-order or primitivity predicate; **promote-to-core candidate** as `gf_multiplicative_order` / `gf_is_primitive` next to `gf_is_dth_power` |
| `dillon_T1` | `theorem6.jl` | Paper-specific reference function; no core equivalent. Keep |
| `dillon_T2` | `theorem6.jl` | **Fixed (Br-7):** now returns `kim_apn()` and asserts the polynomial identity |
| `paper_code_matrix` | `theorem6.jl` | One-line alias for `ccz_matrix`; exists only to carry the row-layout note. Reuses core |
| `code_dimension` / `code_weight_distribution` | `theorem6.jl` | Thin wrappers over `rank_f2` / `code_weight_enumerator`. Reuses core |
| report emitters | throughout | Correctly uses `print_banner`, `print_section`, `print_check`, `print_kv`. Good |
| field arithmetic | throughout | Correctly uses `gf_mul`, `gf_pow`, `gf_trace`, `gf_is_dth_power`, `in_subfield`, `subfield_elements`, `primitive_polynomial`, `conway_polynomial`. Good |
