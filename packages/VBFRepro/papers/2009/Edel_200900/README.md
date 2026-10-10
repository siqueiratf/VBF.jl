# Edel & Pott (2009) — A new almost perfect nonlinear function which is not quadratic

Current audit application (2026-10-10, Julia 1.13.1): `make test` and `make report` ran successfully. The suite now passes 42 assertions (including newly added regressions where applicable). VBFRepro retained source/input hashes and logs under `data/repro/runs/Edel_200900/` for the recorded runs. The older “no Julia” review below is historical and is superseded by these executions. The paper tests pin the source representatives’ APN properties, degrees and exact little-endian encoding hashes. These regressions do not establish novelty against the reference corpus.


- **Citation:** Y. Edel, A. Pott, "A new almost perfect nonlinear function which is not
  quadratic", *Adv. Math. Commun.* 3(1):59–81, 2009.
- **Reproduction path:** `packages/VBFRepro/papers/2009/Edel_200900/`
- **Paper source:** `input/Edel e Pott - 2009 - A new almost perfect nonlinear function which is not quadratic.tex`
- **Verdict:** **Partial** — the n=6 core is excellent and exactly right (all 14 Table-5
  representatives, all 28 Table-6 rank values, and the Theorem-11 invariants match the paper
  exactly). But four of the paper's six data tables are absent, all of Section 2's theory is
  unimplemented, and the paper's **second** new APN function (Table 7 no. 14.3) is missing
  entirely — even though it is fully recoverable from the LaTeX and was verified reproducible
  during this review.

---

## Issue Catalog

### Paper Issues

Flaws in the original publication. Not ours to fix.

1. **Internal numbering contradiction.** Theorem 11 says the new function is "(entry **2.11** in
   Table 5)"; line 612 says "In Table 5, the Example **2.12** is new (see Theorem 11)"; Remark 2
   lists "the function no. **2.12** in Table 5" among the non-quadratic ones. Computationally,
   **2.11 is the new non-quadratic one** (degree 3, Γ=1300, Δ=152) and **2.12 is quadratic**
   (degree 2, Γ=1166, Δ=94). The reproduction picks 2.11 (correct) but does not record the
   discrepancy.
2. **Theorem 11's switching base contradicts Table 5.** Theorem 11 says the function "is a
   switching neighbour of Function **2.4** in Table 5", but Table 5 row 2.11 is written as
   "(No. **2.3**) + u¹⁹(…)". Verified: 2.11 vs 2.3 differ in exactly one value (`{0,46}` — a
   genuine narrow-sense switching neighbour); 2.11 vs 2.4 differ in **eight** values
   (`{0,1,4,5,42,43,46,47}`) → **not** a narrow-sense switching neighbour. The Table-5 form is
   correct and the Theorem-11 prose is wrong. The reproduction silently follows Table 5.
3. **LaTeX conversion artifacts.** Table captions are shifted by one throughout (the "Table 3"
   caption appears on both the n=5 function table and the n=5 invariant table; "Table 4:
   Invariants of switching classes in Table 3" sits on the n=6 *function* table; "Table 5: …"
   appears as loose body text). Table 7's rows 10.1/10.2 and 14.1/14.2/14.3 are merged into
   unnumbered multi-line cells. Source-quality only — but any Table 7/9 reproduction must
   reconstruct the row boundaries, which was confirmed possible and unambiguous by cross-checking
   against Table 8.

### Reproduction Issues

Defects introduced in our implementation.

#### EP-1 — The paper's second new APN function (Table 7 no. 14.3) is entirely absent

- **Location:** no `table7.jl` / `table8.jl` exists; `report.jl:8-15` includes only the n=6 files.
- **Symptom:** the paper's stated contributions are "In Table 5, the Example 2.12 [sic — 2.11] is
  new … and in Table 7, the Example 14.3 is new". Only one of the two new functions is
  reproduced. Table 7 also carries the Theorem-10(3) consequence, "Our new function 14.3 in
  Table 7 is inequivalent to all polynomials with coefficients in F₂".
- **Root cause:** scope limited to n=6 — `helpers.jl:19-21` hard-codes `EP_N = 6`.
- **Evidence it is reproducible:** building 2.1, 2.2, 10.1, 10.2, 11.1, 12.1, 13.1, 14.1, 14.2,
  **14.3**, 8.1, 9.1 and 1.2 over `p(x) = x⁷+x+1`, `u = x`, **every single Γ/Δ pair matched
  Table 8 exactly** (14.3 → Γ = 4046, Δ = 212).
- **Resolution plan:**
  1. Generalise `helpers.jl` to carry Table 2's per-`n` moduli (n=5 → 37, n=6 → 91, n=7 → 131,
     n=8 → 285, n=9 → 529) rather than the single `EP_N`/`EP_MODULUS` pair.
  2. Add `table7.jl` building 1.1, 1.2, 2.1, 2.2, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1, 9.1, 10.1, 10.2,
     11.1, 12.1, 13.1, 14.1, 14.2, **14.3**, with row boundaries as reconstructed:
     14.1 = `x³+x⁶+x³⁴+x⁴⁰+x⁷²`, 14.2 = `(14.1) + tr(u¹⁰⁵x³+u⁸⁴x⁵+u¹²³x⁹)`,
     14.3 = `(14.1) + u²⁷(tr(u²⁰x³+u⁹⁴x⁵+u⁶⁶x⁹))`.
  3. Add `table8.jl` asserting Γ/Δ against the published values — all 13 entries built during
     review matched exactly, so this will pass.
  4. Add the Theorem-10(3) consequence for 14.3: `|M| = 2⁷` is not divisible by `n = 7`, hence
     14.3 is inequivalent to every polynomial with coefficients in F₂.
  5. Add `table3.jl`/`table4.jl` (n=5, cheap) and at minimum `table9.jl` (n=8 functions + APN +
     degree; Γ/Δ at n=8 is Magma territory and should be reported as published values).

#### EP-2 — Theorem 11's switching-neighbour claim is not checked

- **Location:** `theorem11.jl:39-72`.
- **Symptom:** the report verifies APN/degree/ranks but never verifies the relation that makes
  the construction a *switching* construction — the whole point of the paper.
- **Root cause:** `theorem11_function()` builds only the composite eq. (9).
- **Resolution plan:**
  1. Add `theorem11_base()` returning `x³+u¹⁷(x¹⁷+x¹⁸+x²⁰+x²⁴)`; assert it is APN (verified true).
  2. Assert `setdiff(unique(base.lut .⊻ F.lut), [0])` is a single element (verified: `18 = u¹⁴`),
     i.e. a narrow-sense switching neighbour with `u = u¹⁴`.
  3. Cross-validate with core: assert `F ∈ switching_neighbors(base)[18]`.
  4. Add a report note on Paper Issue 2 (Theorem-11 prose says 2.4; Table 5 and the arithmetic
     say 2.3).

#### EP-3 — "same class as 2.11" is asserted from an invariant fingerprint

- **Location:** `theorem11.jl:24-30, 57-60`; `report.jl:39`; docstring `theorem11.jl:36`;
  `test/test_theorem11.jl:10`.
- **Symptom:** `_ep_fingerprint` equality is reported as "shares CCZ-invariant fingerprint of
  Table-5 rep 2.11 (**same class**)", and `test_theorem11.jl:10` asserts `r.same_class` as if it
  were a decision. Equal invariants are necessary, not sufficient.
- **Root cause:** no decisive equivalence test for a *non-quadratic* pair — `ortho_derivative` is
  undefined there, and `are_ccz_equivalent` on two degree-3 n=6 functions is expensive though
  feasible.
- **Resolution plan:**
  1. Rename the field/label to `same_fingerprint` and change the printed text to "consistent with
     (necessary for) being the Table-5 2.11 class".
  2. Add an opt-in `are_ccz_equivalent(F, rep211)` behind `full_search` to settle it, and record
     the result.

#### EP-4 — Theorem 10 conflates two group orders without saying so

- **Location:** `theorem10.jl:20-36` — the `EP_MULTIPLIER_ORDER_N6` comment reads "Published
  |M(G_F)| = Table-6 column |Aut(dev(G_F))|/2^{2n}".
- **Symptom:** Theorem 10 is stated in terms of `v = |M(G_F)|`, but Table 6's columns are
  `|Aut(dev(G_F))|/2^{2n}` and `|Aut(dev(D_F))|/2^{2n}`. The identification is legitimate only
  via the paper's own observation ("In the cases n ≤ 7, the automorphism groups of dev(G_F) have
  been always the groups generated by the multipliers plus the translations") plus Lemma 3(3) —
  an *empirical* remark tied to open Problem 2, not a theorem.
- **Root cause:** the caveat exists in the paper but not in the code.
- **Resolution plan:**
  1. Extend the comment/`print_kv` to state that `|M(G_F)| = |Aut(dev(G_F))|/2^{2n}` is being
     used, justified by the paper's n ≤ 7 observation and Lemma 3(3), and that Problem 2 leaves
     this open in general.
  2. Add the Table-10 `|M(G_F)|` column for n=8 as a separate constant, so the n=8 tables can use
     the paper's *directly published* multiplier orders when they are added.

#### EP-5 — Theorem 7's report ignores the 2.11 result in its return value

- **Location:** `theorem7.jl:31-43`.
- **Symptom:** the loop computes `d` for 2.11 and prints the headline check, but `all_quad_ok`
  deliberately excludes 2.11 and the returned NamedTuple has no field carrying it. `report.jl:42`
  then prints "Theorem 7 — 2.11 Δ-rank 152 > 128 ⇒ not crooked" gated on `r_thm7.all_quad_ok`,
  which is about the *other thirteen* functions.
- **Root cause:** the 2.11 result is printed but not plumbed through.
- **Resolution plan:**
  1. Add `delta_2_11` and `not_crooked_2_11 = d > bound6` to the returned NamedTuple.
  2. Gate the `report.jl:42` summary line on `r_thm7.not_crooked_2_11 && r_thm7.all_quad_ok`.
  3. Assert both in `test/test_theorem7.jl`.

#### EP-6 — Missing paper items

1. **All of Section 2's theory**: Lemma 1 (APN ⟺ group-algebra identity), Lemma 2 (CCZ ⇒
   isomorphic designs), Lemma 3 (multiplier/translation group relations), Proposition 1 (CCZ
   preserves APN/AB), Definitions 1–6, **Theorem 4** (quadratic ⇒ `M(G_F)` contains an
   elementary abelian 2ⁿ), **Corollary 5**, **Corollary 6** (Kasami x¹³, x⁵⁷ not CCZ quadratic).
2. **Proposition 3** (switching-neighbour characterisation) — used implicitly by
   `_recover_switch` (`theorem9.jl:20-27`) but has no file and is never stated or tested.
3. **Table 3 / Table 4 (n=5)** — the complete n=5 classification with Γ/Δ ranks (330/42, 330/42,
   496/232). Cheap to compute; absent.
4. **Table 9 / Table 10 (n=8)** — absent, including the eleven entries marked "new" (1.4–1.10,
   1.13, 1.14, 1.16, 1.17) and the 17-member EA switching class of `x³` the paper highlights.
5. **Table 11 / Table 12 (n=9)** — absent.
6. **Table 2 (moduli)** — only n=6 (`EP_MODULUS = 91`) is encoded; the n=5,7,8,9 moduli go unused
   because those tables are missing.
7. **Remark 2** (which entries are non-quadratic across Tables 3, 5, 7, 11) — only the Table-5
   part is covered.
8. **`|M(G_F)|` computation** — not computed (Magma-only), and correctly labelled as such.

---

## Items reproduced exactly

All independently re-verified; **everything the tests assert matched**.

| Paper item | Repo location | Verification |
|---|---|---|
| **Proposition 2** (`x³+tr(x⁹)` APN ∀n) | `proposition2.jl` | du=2 for n=2…9 |
| **Table 5** (all 14 n=6 representatives) | `helpers.jl:106-125`, `table5.jl` | all 14 built from the paper's switching formulas; **all du=2**; exactly one degree-3 entry (2.11), rest degree 2 |
| **Table 6** (Γ-rank, Δ-rank, Walsh class) | `table6.jl` | **all 14 rows match the paper exactly** — Γ: 1102/1146/1166/1168/1170/1172/1158/1170/1170/1170/1172/1174/**1300**/1166; Δ: 94/94/96/96/96/96/96/96/96/96/96/96/**152**/94; only 2.6 non-classical |
| **Theorem 7** (Δ ≤ 2^{n+1} necessary for crooked) | `theorem7.jl` | all quadratic reps Δ ≤ 128; 2.11 has Δ=152 > 128 |
| **Corollary 8** (n=7 Kasami) | `theorem7.jl` (gated) | Δ(x¹³) = **338**, Δ(x⁵⁷) = **436**, both > 256 |
| **Theorem 9** (switching iff criterion) | `theorem9.jl` | 2.3 → 2.11 is a narrow-sense switch with **u = u¹⁹ = 46** (difference set exactly `{0,46}`); constraint holds; perturbation breaks APN |
| **Theorem 11 / eq. (9)** | `theorem11.jl` | du=2, **algebraic degree 3**, **Γ-rank 1300**, **Δ-rank 152**, classical Walsh — all match Table 6 row 2.11 |
| **Theorem 10** reasoning | `theorem10.jl` | divisibility arithmetic on the paper's published orders is correct (8 ∤ by 63 or 64; 24192 divisible by 378) |

---

## Test results

`make -C packages/VBFRepro/papers/2009/Edel_200900 test` → **could not run**: no `julia` on this host.

Everything the tests assert was re-derived in pure Python (GF(2ⁿ) arithmetic matching
`VBF.PRIMITIVE_POLYNOMIALS`, DDT/degree/Walsh, and a bit-packed F₂ design-rank routine matching
`VBF._design_2rank`) and **all of it matched**, including the complete Table-6 sweep (14 rows ×
Γ, Δ, Walsh class) and the Theorem-11 eq. (9) invariants. Re-confirm under Julia before relying
on the LUTs below.

---

## Catalog status

| Claimed-new function | Status |
|---|---|
| Theorem 11 / Table-5 2.11 on GF(2⁶) — the first non-quadratic APN CCZ-inequivalent to power maps | **missing** — catalog gap |
| Table-7 no. 14.3 on GF(2⁷) — declared new, inequivalent to all F₂-coefficient polynomials | **missing** — catalog gap |
| Table-9 n=8 entries marked "new" (1.4–1.10, 1.13, 1.14, 1.16, 1.17) | **unverifiable here** — the reproduction does not build them, and Γ/Δ at n=8 needs a 2¹⁶×2¹⁶ F₂ rank (Magma territory). Not assumed present |

### Catalog-gap records

**Record 4 — `n6_EdelPott2009_nonquadratic`** (highest value: the catalog currently has no
non-quadratic APN entry at any dimension from these papers)
- target: `packages/VBFCatalog/data-raw/apn_catalog/n6_apn.toml`
- `n = 6`, `m = 6`, `is_permutation = false`, `bib_key = "Edel_200900"`
- `algebraic_form`: Table 5 entry 2.11 =
  `(No. 2.3) + u^19( tr(u^11 x^3 + u^7 x^5 + u^38 x^7 + u^61 x^11 + u^23 x^13) + tr_{8/2}(u^54 x^9) + tr_{4/2}(u^42 x^21) )`,
  where `No. 2.3 = (x^3 + u x^24 + x^10) + tr(u^34 x^3 + u^48 x^5) + tr_{8/2}(u^9 x^9)`;
  GF(2⁶) with `p(x) = x⁶+x⁴+x³+x+1` (=91), `u = x`. Equivalent representative: eq. (9) of
  Theorem 11.
- `source`: Theorem 11 / Table 5 entry 2.11 — the first APN function shown not to be
  CCZ-equivalent to any quadratic function. Reproduced by
  `packages/VBFRepro/papers/2009/Edel_200900/helpers.jl` (`edelpott_table5()`, entry 2.11) and `theorem11.jl`.
- `lut = [0, 3, 52, 16, 25, 59, 54, 29, 10, 12, 35, 2, 17, 54, 35, 13, 55, 45, 1, 18, 50, 39, 49,
  3, 26, 5, 49, 39, 29, 13, 3, 52, 35, 6, 51, 31, 59, 17, 48, 61, 26, 58, 23, 62, 0, 47, 22, 30,
  4, 56, 56, 35, 46, 51, 39, 51, 26, 35, 59, 37, 50, 42, 38, 55]`
- Evidence: `differential_uniformity = 2`, `algebraic_degree = 3`, **Γ-rank = 1300**,
  **Δ-rank = 152**. Δ-rank is a CCZ-invariant; existing n=6 entries have Δ-rank 94
  (`n6_Gold_x3`), 94 (`n6_Kasami_x48`, flagged `ccz_equivalent_to = "n6_Gold_x3"`), 96
  (`n6_Kim`). Furthermore Δ = 152 > 2^{n+1} = 128, so by Edel–Pott Theorem 7 this function is not
  CCZ-crooked and therefore **not CCZ-equivalent to any quadratic function** — all three existing
  n=6 entries are quadratic, so inequivalence here is certain, not merely invariant-based.
- Second representative if wanted (Theorem 11 eq. (9), same `(du, deg, Γ, Δ) = (2, 3, 1300, 152)`):
  `[0, 19, 27, 52, 6, 19, 31, 54, 56, 16, 53, 51, 14, 32, 19, 19, 0, 31, 60, 31, 58, 35, 4, 33,
  49, 21, 27, 17, 59, 25, 1, 13, 2, 35, 14, 1, 28, 59, 0, 9, 15, 21, 7, 33, 33, 61, 43, 11, 19,
  62, 56, 59, 49, 26, 10, 15, 23, 1, 56, 18, 5, 21, 40, 4]`

**Record 5 — `n7_EdelPott2009_no14_3`**
- target: `packages/VBFCatalog/data-raw/apn_catalog/n7_apn.toml`
- `n = 7`, `m = 7`, `is_permutation = false`, `bib_key = "Edel_200900"`
- `algebraic_form`: Table 7 entry 14.3 = `(No. 14.1) + u^27( tr(u^20 x^3 + u^94 x^5 + u^66 x^9) )`,
  where `No. 14.1 = x^3 + x^6 + x^34 + x^40 + x^72`; GF(2⁷) with `p(x) = x⁷+x+1` (=131), `u = x`.
- `source`: Table 7 entry 14.3 — "in Table 7, the Example 14.3 is new"; "Our new function 14.3 in
  Table 7 is inequivalent to all polynomials with coefficients in F₂ (Theorem 10)". **Now reconstructed and tested by `table7.jl`; historical omission:** under `packages/VBFRepro/papers/2009/Edel_200900/` (no `table7.jl`).
- `lut = [0, 72, 8, 68, 9, 81, 49, 109, 10, 78, 8, 72, 108, 56, 94, 14, 41, 103, 36, 110, 119, 41,
  74, 16, 106, 40, 109, 43, 91, 9, 108, 58, 18, 108, 95, 37, 127, 17, 2, 104, 48, 66, 119, 1, 50,
  80, 69, 35, 102, 30, 46, 82, 92, 52, 36, 72, 13, 121, 79, 63, 88, 60, 42, 74, 68, 92, 41, 53,
  64, 72, 29, 17, 59, 47, 92, 76, 80, 84, 7, 7, 64, 94, 40, 50, 19, 29, 75, 65, 118, 100, 20, 2,
  74, 72, 24, 30, 57, 23, 17, 59, 89, 103, 65, 123, 110, 76, 76, 106, 97, 83, 115, 69, 96, 72, 77,
  97, 87, 111, 74, 118, 126, 90, 89, 121, 38, 18, 49, 1]`
- Evidence: `differential_uniformity = 2`, `algebraic_degree = 2`, **Γ-rank = 4046**,
  **Δ-rank = 212** (both recomputed, both matching the paper's Table 8). Existing `n7_apn.toml`
  entries have Δ-ranks 198/198/198/338/338/436/436/4928 — none is 212. Note this shares Δ = 212
  with the `Budaghyan_200904` gap record for `x³+tr(x⁹)` (Γ = 4026), but the Γ-ranks differ
  (4046 vs 4026), so they are **distinct CCZ classes** and both should be added.

**LUTs must be regenerated under Julia before any TOML write.**

---

## Library-reuse note

| Helper | Location | Verdict |
|---|---|---|
| `_switching_constraint` | `theorem9.jl:30-53` | **Duplication / missed reuse.** Core already owns this paper's construction: `switching_neighbors` (`packages/VBF/src/constructions/switching_neighbors.jl`) has a module docstring that **cites `Edel_200900`**, and its `_sn_add_equation!`/`_SNSystem` builds the identical constraint system. The paper file needs the *predicate* form (does a given `f` satisfy the constraints?), which core does not export. Clean fix: (a) cross-validate `2.11 ∈ switching_neighbors(2.3)[u]` here, and (b) **promote to core** an exported `switching_constraints(F, u) -> BitMatrix` or `is_switching_admissible(F, u, f) -> Bool` |
| `_recover_switch` | `theorem9.jl:20-27` | Paper-specific (Proposition 3 inverse); legitimate |
| `ep_tr82`, `ep_tr42` | `helpers.jl:31,33` | Correct as written — *not* `gf_relative_trace` (that is `GF(2ⁿ)→GF(2ᵏ)`; these are the *absolute* trace of an element already in a subfield, computed with GF(2⁶) arithmetic). **Promote-to-core candidate**: `gf_subfield_absolute_trace(x, k, n; modulus) = ⊕_{i<k} x^{2^i}`, a genuinely generic primitive core lacks |
| `_ep_fingerprint` | `theorem11.jl:24-30` | Justified: `apn_ea_mugshot` for non-quadratic `F` uses `abs_walsh`/`degree`/`sigma`/`thickness`, whereas the paper's invariants are Γ/Δ-rank. Keep — but consider adding `apn_ea_mugshot(F)` alongside for a stronger fingerprint |
| `ep_pow`, `ep_mul`, `ep_U`, `ep_tr`, `_lut`, `ep_is_classical` | `helpers.jl:23-33, 35, 166` | Acceptable field-fixing shorthand over `gf_pow`/`gf_mul`/`gf_trace`/`absolute_walsh_spectrum`; would need to become `n`-parameterised for EP-1 |
| `edelpott_table5`, `theorem11_function`, `EP_MULTIPLIER_ORDER_N6` | `helpers.jl:106-150`, `theorem10.jl:21-36` | Paper-specific, legitimate |

Correct reuse observed: `gf_pow`, `gf_mul`, `gf_trace`, `gf_monomial_lut`,
`primitive_polynomial`, `SBox`, `differential_uniformity`, `algebraic_degree`, `gamma_rank`,
`delta_rank`, `ddt`, `absolute_walsh_spectrum`, `are_ccz_equivalent`, and the report emitters.

---

## Open questions

1. Should Tables 3/4 (n=5), 7/8 (n=7), 9/10 (n=8), 11/12 (n=9) be added, or is the reproduction
   deliberately scoped to n=6? Given that Table 7 contains a second explicitly-new APN function
   and all its Table-8 invariants were confirmed reproducible during review, the recommendation
   is to add at least Tables 7/8.
2. For the n=8/n=9 tables, should the Γ/Δ ranks be recorded as published (Magma) values with a
   "not executed" label, matching how `theorem10.jl` handles `|M(G_F)|`?
