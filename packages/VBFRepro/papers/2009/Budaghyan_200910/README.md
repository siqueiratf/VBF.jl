# Budaghyan, Carlet & Leander (2009) — On a construction of quadratic APN functions

- **Citation:** L. Budaghyan, C. Carlet, G. Leander, "On a construction of quadratic APN
  functions", *Proc. IEEE Information Theory Workshop (ITW)*, pp. 374–378, 2009.
- **Reproduction path:** `packages/VBFRepro/papers/2009/Budaghyan_200910/`
- **Paper source:** `input/Budaghyan et al. - 2009 - On a construction of quadratic APN functions.tex`
- **Verdict:** **Mostly complete** — all 12 claim files are present and every numeric assertion
  they make was independently reproduced, including the four frozen ortho-derivative anchors.
  What remains is Lemma 1 and Remark 1 missing entirely, one proposition asserting a stronger
  statement than the theorem, one proposition tested only at its trivial instance, an
  under-verified novelty claim, and three documentation defects — including the wrong journal in
  all 13 file headers.

---

## Issue Catalog

### Paper Issues

**None substantive found.** The abstract says F₂, F₃ hold "for any n divisible by 3" while
Corollaries 1 and 3 restrict to 6 ∣ n and Corollary 4 to 3 ∣ n. Verified that eqs (7),(8) are
APN at n = 3, 6, 9 for a=1 and a=α, so Corollary 4's 3 ∣ n scope is the correct one and there is
no contradiction — just an editorial inconsistency between Corollary 1/3 and Corollary 4.

### Reproduction Issues

Defects introduced in our implementation.

#### BCL10-1 — Wrong journal in every file header

- **Location:** `helpers.jl:3`, and identically in `proposition1.jl:3` … `proposition8.jl:3`,
  `corollary1.jl:3` … `corollary4.jl:3`, `report.jl:3` — 13 files.
- **Symptom:** headers read `IEEE Trans. Inf. Theory 55(9):4218-4229`. That is a *different* BCL
  paper ("Two classes of quadratic APN binomials"). The banner (`helpers.jl:24`) and
  `bibliography.bib` correctly say *Proc. IEEE ITW 2009, pp. 374-378*.
- **Root cause:** copy-paste of the wrong venue during scaffolding.
- **Resolution plan:** replace the venue line in all 13 files with
  `Proc. IEEE Information Theory Workshop (ITW) 2009, pp. 374-378`.

#### BCL10-2 — Factually wrong scope note in `proposition3.jl`

- **Location:** `proposition3.jl:16-17` — "the superfield demo runs at n=3 (class2/class3) and
  n=5,7 (L=trₙ)".
- **Symptom:** no n=5/n=7 case exists in `cases` (lines 79-82), and the claim is false: `x+tr_n(x³)`
  is **not** injective on `w+GF(2ⁿ) ⊂ GF(2^{2n})` for n=5 or n=7 (verified). A reader following
  the comment would conclude Proposition 3 applies to `L=tr` at odd n, which the paper never
  claims.
- **Root cause:** stale comment from an earlier draft.
- **Resolution plan:**
  1. Delete the "n=5,7 (L=trₙ)" clause; state that Prop 3's hypothesis is verified only for the
     paper's own examples F₁, F₂ (class2/class3), and that n=3 is the only feasible odd 3 ∣ n
     dimension (n=9 would need GF(2¹⁸)).
  2. Optionally add a *negative* check `!injective_on_superfield(:trace, 5)` documenting why
     `L=tr` is not a Prop-3 instance.

#### BCL10-3 — `injective_on_superfield` silently accepts 3 ∤ n

- **Location:** `proposition3.jl:39` (`for i = 0:((nn ÷ 3) - 1)`).
- **Symptom:** for `cls ∈ (:class2, :class3)` and n not divisible by 3, the `tr_n^3` sum is
  truncated to `⌊n/3⌋` terms, silently computing a *different* linear map. Confirmed to return
  `true` for `(:class2, 5)` and `(:class2, 7)` — meaningless answers.
- **Root cause:** no parameter validation.
- **Resolution plan:**
  1. Add `n % 3 == 0 || throw(ArgumentError(...))` to the `class2`/`class3` branches of
     `_L_super` / `injective_on_superfield`.
  2. Add a `@test_throws ArgumentError injective_on_superfield(:class2, 5)` regression.

#### BCL10-4 — Proposition 4 asserts an equivalence the theorem does not state

- **Location:** `proposition4.jl:50-51` — `ok = (!cond || perm) && (cond == perm)`.
- **Symptom:** Proposition 4 is a *sufficient* condition; `cond == perm` additionally asserts
  necessity. It happens to hold for the six listed classes (verified), so the test passes — but
  the reproduction is asserting something the paper does not claim, and it would break on the
  first `L` where the condition is only sufficient.
- **Root cause:** a consistency check was conflated with the theorem statement.
- **Resolution plan:**
  1. Make `ok = (!cond || perm)` the theorem-faithful assertion.
  2. Keep `cond == perm` as a separately-reported *observation* ("condition is also necessary on
     this sample"), outside `all_ok`.
  3. If one exists, add an `L` where `cond` is false but `x+L(x³)` is still a permutation, to
     exhibit the one-way nature — e.g. sweep random linear maps at n=6.

#### BCL10-5 — Proposition 7's hypothesis is never checked, and only one `L` is used

- **Location:** `proposition7.jl:26-31`.
- **Symptom:** the hypothesis "all coefficients of `L` lie in `GF(2^{n/2})`" is asserted only in
  prose. `L = tr_n` (coefficients all 1 ∈ F₂) is the single case tested — the weakest possible
  instance.
- **Root cause:** no coefficient extraction for a linear map given as a LUT.
- **Resolution plan:**
  1. Add `linearized_coefficients(Llut, n)` (solve for `λ_i` in `L(x) = Σ λ_i x^{2^i}`) and
     assert `all(in_subfield(λ, n÷2, n))`.
  2. Add `class2`/`class3` at n=6 (check their coefficients first) and at least one `L` whose
     coefficients are *not* in the subfield, to show the conclusion can fail there.

#### BCL10-6 — Corollary 4's novelty claim is under-verified and the catalog note is stale

- **Location:** `corollary4.jl:66-79`, `report.jl:55-57`.
- **Symptom:** two separate problems.
  1. `report.jl:55-57` still prints "n=9 eqs (7),(8) are catalog-gap candidates … **NOT written
     to VBFCatalog** by this reproduction", but
     `packages/VBFCatalog/data-raw/apn_catalog/n9_apn.toml` already contains
     `n9_Budaghyan2009_eq7` (line 91) and `n9_Budaghyan2009_eq8` (line 103) — confirmed present,
     with LUTs verified byte-identical to `apn_eq7(9,1)` / `apn_eq8(9,1)`.
  2. The claim "(7) and (8) are CCZ-inequivalent to **any function from previously known
     families**" is checked only against the Gold monomials by default. The `full_search` path
     adds `known_apn_monomials(9)` but no known *polynomial* families (Bracken–Byrne–Markin–
     McGuire, Budaghyan–Carlet trinomials/hexanomials, …).
- **Root cause:** the report note was not refreshed after the catalog was updated; the comparison
  set was limited to monomials.
- **Resolution plan:**
  1. Replace the stale note with a cross-reference to the two existing catalog entries.
  2. Extend the `full_search` comparison to the quadratic *polynomial* families available as core
     exports (`bcl_apn`, `bcp_apn`, `taniguchi_apn`), using `apn_ea_mugshot` first and
     `are_ea_equivalent` for colliding buckets.
  3. Load the n=9 catalog via `apn_catalog_names(9)` / `load_apn_function` and assert
     `apn_ea_mugshot` distinctness against every entry, so the claim is checked against the
     repo's own corpus.

#### BCL10-7 — Missing paper items

1. **Lemma 1** (`L′* = L*` restricted to `GF(2^{n/2})`) — no file, no check.
2. **Remark 1** (condition (2) only needs `u ∈ Im L`; for `L=tr` only `u=1`; and `x+tr_n(x³)` is
   bijective) — `proposition1.jl` is titled "(and Remark 1)" but implements none of it.
3. **§II.A closure remark** — "if `x+L(x³)` is a permutation then `x+a⁻¹L(a³x³)` is also a
   permutation for every a ≠ 0" is never verified.
4. **§II.B algebraic derivation (eqs 9–11)** — the injectivity proof of `F₂` over `w+F_{2ⁿ}` is
   not reproduced symbolically; only the n=3 numeric instance.
5. **"For n odd, all a give functions EA-equivalent to a=1"** — the paragraph after Corollary 4
   is not verified.
6. **Open Problem 1 / the backtracking search to n=14** — not run, and correctly documented as
   out of scope.

---

## Items reproduced exactly

All independently re-verified; **every assertion the tests make was reproduced**.

| Paper item | Repo location | Verification |
|---|---|---|
| **Proposition 1** (n even, perm ⇒ APN) | `proposition1.jl` | `trace`/`class2`/`class3` at n=6,8: `x+L(x³)` is a permutation, `x³+L(x⁹)` du=2, deg=2 |
| **Corollary 1** (eqs 4,5 for 6∣n) | `corollary1.jl` | n=6: du=2, deg=2 both |
| **Proposition 2** | `proposition2.jl` | n=6,8: perm ⇒ APN |
| **Corollary 2** (parametric) | `corollary2.jl` | n=6,8, a ∈ {1,α}, b ∈ {0,1,α}: all du=2, deg=2 |
| **Corollary 3** (eqs 6,7,8 APN + new class) | `corollary3.jl` | eq(6) du=2 at n=6,8,10 for a=1,α; eqs (7),(8) du=2 at n=6; OD signatures differ for a=1 vs a=α at n=6 **and** n=8 |
| Frozen OD anchors | `test/test_corollary3.jl:14-19` | all four exact: n=6 a=1 `{0:2205,2:1764,8:63}`; n=6 a=α `{0:2583,2:1008,4:378,8:63}`; n=8 a=1 `{0:38004,2:22614,4:4008,6:630,10:24}`; n=8 a=α `{0:38592,2:21426,4:4590,6:654,8:18}` |
| **Proposition 3** (superfield injectivity) | `proposition3.jl` | `class2`/`class3` at n=3 injective on `E = w+GF(2³) ⊂ GF(2⁶)` |
| **Corollary 4** (eqs 6,7,8 general n; n=9 pairwise) | `corollary4.jl` | eq(6) du=2 at n=5,7,9; eqs (7),(8) du=2 at n=3,9; the three n=9 OD signatures pairwise distinct and distinct from Gold k=1,2,4 |
| **Proposition 4** | `proposition4.jl` | all 6 cases: cond ⟺ perm (but see BCL10-4) |
| **Proposition 5** (adjoint, n even) | `proposition5.jl` | n=6 (trace, identity, class2, class3), n=8 (trace, identity): predicate ⟺ perm |
| **Proposition 6** (adjoint, n odd) | `proposition6.jl` | n=5,7 (zero, trace, identity): predicate ⟺ perm |
| **Proposition 7** | `proposition7.jl` | n=6,8 with L=tr: perm, `L\|GF(2^{n/2})=0`, `L²=0` |
| **Proposition 8** | `proposition8.jl` | n=5,6,8 × 3 candidates: predicate ⟺ perm |

---

## Test results

`make -C packages/VBFRepro/papers/2009/Budaghyan_200910 test` → **could not run**: no `julia` on this host.

All 13 claim files were re-derived in pure Python (GF(2ⁿ) arithmetic matching
`VBF.PRIMITIVE_POLYNOMIALS`, DDT/degree/Walsh, ortho-derivatives). **Every assertion the tests
make was reproduced**, including the four frozen ortho-derivative anchors in
`test/test_corollary3.jl:14-19`. Re-confirm under Julia before relying on the LUT below.

---

## Catalog status

| Claimed-new function | Status |
|---|---|
| eq (7) `x³+Tr_{9/3}(x¹⁸+x³⁶)` on GF(2⁹) | **present** — `n9_Budaghyan2009_eq7` (LUT verified byte-identical) |
| eq (8) `x³+Tr_{9/3}(x⁹+x¹⁸)` on GF(2⁹) | **present** — `n9_Budaghyan2009_eq8` (LUT verified byte-identical) |
| eq (6) with a=α on GF(2⁶) — Corollary 3 "new class" | **missing** — catalog gap |
| eq (6) with a=α on GF(2⁸) — Corollary 3 "new class" | **not-new (probable)** — needs a decisive check; see the blocking flag below |
| eqs (7),(8) at n=6 (a=1) | **not-new** — (Γ,Δ) = (1102, 94) and OD spectrum `{0:2205,2:1764,8:63}`, identical to `n6_Gold_x3`; consistent with the paper claiming novelty only at n=9 |

### Catalog-gap record — `n6_BudaghyanCarletLeander2009_eq6_alpha`

- target: `packages/VBFCatalog/data-raw/apn_catalog/n6_apn.toml`
- `n = 6`, `m = 6`, `is_permutation = false`, `bib_key = "Budaghyan_200910"`
- `algebraic_form = "x^3 + a^{-1} Tr(a^3 x^9) in GF(2^6) with a = alpha the primitive element
  (=2), modulus x^6 + x + 1 (=67)"`
- `source`: eq (6) with a = α. The paper states: "for n=6,8 the APN function `x³+tr_n(x⁹)` is
  CCZ-inequivalent to `x³+α⁻¹tr_n(α³x⁹)`. Hence, function (6) defines a new class of APN
  functions which includes the class of functions `x³+tr_n(x⁹)`." Reproduced by
  `packages/VBFRepro/papers/2009/Budaghyan_200910/helpers.jl` (`apn_eq6(6, 2)`).
- `lut = [0, 1, 8, 46, 34, 22, 59, 40, 57, 51, 23, 58, 17, 46, 46, 54, 36, 57, 22, 44, 58, 18,
  25, 22, 47, 57, 59, 10, 59, 24, 62, 58, 40, 24, 36, 51, 23, 18, 10, 40, 25, 34, 51, 47, 44, 34,
  23, 62, 18, 62, 36, 47, 17, 8, 54, 8, 17, 54, 1, 1, 24, 10, 25, 44]`
- Evidence: `differential_uniformity = 2`, `algebraic_degree = 2`, **Γ-rank = 1146**,
  **Δ-rank = 94**, OD differential spectrum `{0:2583, 2:1008, 4:378, 8:63}`. Existing n=6
  entries: `n6_Gold_x3` (Γ=1102, Δ=94, OD `{0:2205,2:1764,8:63}`), `n6_Kasami_x48` (identical to
  Gold, flagged `ccz_equivalent_to`), `n6_Kim` (Γ=1166, Δ=96, OD `{0:2373,2:1428,4:168,8:63}`).
  Γ-rank is a CCZ-invariant and 1146 matches none of them; the OD spectrum (conclusive for
  quadratic APN, since CCZ ⟺ EA) also matches none.

### Blocking flag for the catalog updater — probable novelty collision at n=8

eq (6) with `a = α` over GF(2⁸) (modulus 283) has OD differential spectrum
`{0:38592, 2:21426, 4:4590, 6:654, 8:18}` **and** OD absolute-Walsh spectrum
`{0:12162, 8:23208, 16:16346, 24:8400, 32:3910, 40:1008, 48:222, 56:24}` — both **byte-identical**
to the existing catalog entry `n8_Taniguchi2025_ex4_2` (`n8_apn.toml:56`; Taniguchi–Polujan–Pott–
Arshad 2025 Example 4.2, `x³ + a^85·Tr(x)·Tr_2^8(x)` over modulus 285). Their own Walsh spectra
also agree. Since both are quadratic APN (CCZ ⟺ EA), a full `apn_ea_mugshot` match is very strong
evidence of EA/CCZ-equivalence — though not a proof.

**Do not write a new n=8 entry** until `are_ea_equivalent` / `are_ccz_equivalent` is run in
Julia. If equivalence is confirmed, `n8_Taniguchi2025_ex4_2`'s `source` should gain a
cross-reference noting it is the a=α case of Budaghyan–Carlet–Leander (2009) eq (6), and
`bib_key = "Budaghyan_200910"` should be added as prior art.

---

## Library-reuse note

| Helper | Location | Verdict |
|---|---|---|
| `od_signature` | `helpers.jl:243-248` | **Duplicates core, and is weaker** — `apn_ea_mugshot` also carries the OD Walsh spectrum, which would have hardened every Corollary 3/4 inequivalence claim |
| `is_apn_lut` | `helpers.jl:233` | Trivial wrapper for `differential_uniformity(F) == 2`; harmless but redundant |
| `as_sbox`, `apply_L` | `helpers.jl:230,137` | Trivial wrappers over `SBox{n}(lut)` and indexing; acceptable |
| `adjoint_lut` | `helpers.jl:203-225` | **Promote-to-core candidate** — the adjoint of an F₂-linear map w.r.t. the trace form is fully generic (`gf_adjoint_lut(Llut, n; modulus)`, or an `F2LinearMap` transpose). Belongs in `packages/VBF/src/linalg/` |
| `_cube_roots` | `proposition5.jl:18-26` | **Promote-to-core candidate**: `gf_dth_root_table(n, d; modulus)`. Core has only the `gf_is_dth_power` predicate |
| `primitive_element(::Integer) = 2` | `helpers.jl:32` | Correct only because every `PRIMITIVE_POLYNOMIALS[n]` is primitive; the argument is ignored. Assert `ord(2) == 2ⁿ−1` or document the dependency |
| `apn_eq6/7/8`, `L_class_lut`, `perm_from_L`, `apn_from_L`, `apn_corollary2`, `satisfies_prop4`, `predicate_prop5/6/8`, `_L_super`, `injective_on_superfield` | various | Paper-specific, legitimate |

Correct reuse observed: `gf_mul`/`gf_pow`/`gf_inv`/`gf_trace`/`gf_relative_trace`,
`primitive_polynomial`, `subfield_elements`, `is_permutation`, `differential_uniformity`,
`algebraic_degree`, `ortho_derivative`, `differential_spectrum`, `sorted_pairs`, `gold_apn`,
`known_apn_monomials`, `are_ccz_equivalent`, and the report emitters.

Note: `apn_corollary2` accepts `n` without checking that it is even — see the cross-paper pattern
on missing parameter validation.

---

## Open questions

1. Is eq (6) with a=α at n=8 EA-equivalent to `n8_Taniguchi2025_ex4_2`? One `are_ea_equivalent`
   call in Julia settles it. This affects both papers' novelty bookkeeping.
2. Should `corollary4.jl`'s novelty comparison be widened to the repo's own n=9 catalog and the
   reproduced quadratic polynomial families, or is Gold-only the intended default scope?
