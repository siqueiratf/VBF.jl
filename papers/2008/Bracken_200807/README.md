# Bracken et al. (2008) — New families of quadratic almost perfect nonlinear trinomials and multinomials

- **Citation:** C. Bracken, E. Byrne, N. Markin, G. McGuire, "New families of quadratic almost
  perfect nonlinear trinomials and multinomials", *Finite Fields Appl.* 14(3):703–714, 2008.
- **Reproduction path:** `papers/2008/Bracken_200807/`
- **Paper source:** `input/Bracken et al. - 2008 - New families of quadratic almost perfect nonlinear trinomials and multinomials.tex`
- **Verdict:** **Partial** — every claim that is tested checks out, but the LUT builders accept
  invalid parameters and silently return non-APN functions, four parameter labels are wrong,
  one lemma is tested in the wrong field, the reported "exhaustive" coverage is a tiny fraction
  of the parameter space, and the paper's own Theorem 6 is unreproduced.

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

#### Br-1 — LUT builders accept invalid parameters and silently return non-APN functions

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

#### Br-2 — Parameter labels do not match the parameters actually used

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

#### Br-3 — Lemma 2(i) is tested in the wrong field

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

#### Br-4 — Reported completeness is false

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

#### Br-5 — Theorem 4 never tests its own (weaker) hypothesis

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

#### Br-6 — Theorem 6 (the paper's actual theorem) is not reproduced

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

#### Br-7 — `dillon_T2()` re-derives a function already in core

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

---

## Items reproduced exactly

| Paper item | Repo location | Verification |
|---|---|---|
| **Theorem 1** Family (1) APN | `helpers.jl:56-74`, `theorem1.jl:41-48` | k=3, s=1 trinomial APN (du=2); 400/400 random valid (b,c,r₁,r₂) tuples at n=6 are APN |
| **Lemma 2** (i)–(iv) 7th-power facts | `theorem3.jl:50-82` | Hold at k=2, n=6 (but see Br-3 for the field used) |
| **Theorem 3** Family (2) APN | `helpers.jl:88-99`, `theorem3.jl:42-47` | n=6: all 36 primitive `u` × all 4 `v ∈ GF(4)` are APN (144/144) |
| **Theorem 4** Tr(f) bent | `helpers.jl:34-42`, `theorem4.jl` | Bent for all v ∈ GF(8)*, both instances; also bent for 60/60 random broader parameter draws |
| Sect. 5: Walsh spectra = Gold x³ at n=6 | `theorem6.jl:82-91` | Confirmed |
| Sect. 5: Family (1) ≅_CCZ Dillon T1 = x³+θ¹¹x⁶+θx⁹ | `theorem6.jl:96,102` | Ortho-derivative DDT spectra identical: `((2,1008),(4,378),(8,63))`; Γ-rank 1146 both |
| Sect. 5: Family (2), v≠0 ≅_CCZ Dillon T2 = x³+θx²⁴+x¹⁰ | `theorem6.jl:97,103` | OD spectra identical: `((2,1428),(4,168),(8,63))`; Γ-rank 1166 both |
| Sect. 5: Family (2), v=0 ≅_CCZ Gold x³ | `theorem6.jl:98,104` | OD spectrum `((2,1764),(8,63))` = Gold |
| Sect. 5: Family (1), Family (2) v≠0 ≇_CCZ any power map | `theorem6.jl:99-100,105-106` | OD spectra differ from Gold's |
| Sect. 5: T1 ≇_CCZ T2 | `theorem6.jl:101,107` | OD spectra differ |
| T2 needs the Conway modulus | `theorem6.jl:43,45-51` | Confirmed: under `x⁶+x+1` T2 has du = 4; under `x⁶+x⁴+x³+x+1`, du = 2 |

---

## Test results

`make -C papers/2008/Bracken_200807 test` → **could not run**: `make: julia: No such file or
directory`. No Julia toolchain exists in the review environment.

Every assertion in `test/test_theorem{1,3,4,6}.jl` that could be independently re-derived
**holds**, including all six CCZ claims (via ortho-derivative DDT spectra and Γ-ranks, which
are necessary conditions).

---

## Catalog status

| Claimed-new family | n=6 representative | Status | Evidence |
|---|---|---|---|
| Family (1), Theorem 1 | k=3, s=1, b=2, c=4, r=0 | **present** as `reprs6_1` in `packages/VBFCatalog/BFA_catalog.sqlite` | OD-derivative DDT spectrum `((2,1008),(4,378),(8,63))` — exact match and unique among all 21 n=6 catalog entries; Γ-rank 1146 matches |
| Family (2), v≠0, Theorem 3 | k=2, s=1, u=2, v=1 | **present** as `n6_Kim` | LUT byte-identical under the Conway modulus; Γ-rank 1166; OD spectrum `((2,1428),(4,168),(8,63))` |
| Family (2), v=0 (BCFL binomial) | k=2, s=1, u=2, v=0 | **present** as `n6_Gold_x3` / `n6_BCP_k2_s1` | OD spectrum `((2,1764),(8,63))` = Gold; Γ-rank 1102 |

**No catalog-gap records.** `packages/VBFCatalog/data-raw/apn_catalog/n6_apn.toml:39-44`
already documents this decision explicitly and correctly.

---

## Library-reuse note

| Helper | Line | Verdict |
|---|---|---|
| `trace_component_is_bent` | `helpers.jl:34-42` | **Legitimately paper-specific.** The docstring's reasoning (trace form vs dot-product form differ by a dual-basis change) is correct; `bent_components` is not a drop-in. Correctly reuses `walsh_transform`, `gf_mul`, `gf_trace`. Keep |
| `family1_lut` / `family2_lut` | `helpers.jl:56-99` | Paper-specific families, but they hand-roll the term loop; could use `terms_to_lut` / `polynomial_to_lut`. **Promote-to-core candidate:** `bbmm_family1_apn(k,s,b,c,r)` and `bbmm_family2_apn(k,s,u,v)` in `packages/VBF/src/constructions/apn_quadratic_families.jl`, alongside `bcp_apn`/`bcl_apn`/`taniguchi_apn` — with the Br-1 validation built in |
| `dillon_T1` | `theorem6.jl:29-36` | Paper-specific reference function; no core equivalent. Keep |
| `dillon_T2` | `theorem6.jl:45-51` | **Duplicates `kim_apn()`.** Fix target: `kim_apn()` (see Br-7) |
| report emitters | throughout | Correctly uses `print_banner`, `print_section`, `print_check`, `print_kv`. Good |
| field arithmetic | throughout | Correctly uses `gf_mul`, `gf_pow`, `gf_trace`, `gf_is_dth_power`, `in_subfield`, `subfield_elements`, `primitive_polynomial`, `conway_polynomial`. Good |
