# Bracken et al. (2011) — A few more quadratic APN functions

## Scoped feasibility review (2026-10-10)

**F071: Partial.** Finite comparisons against sourced earlier-family representatives are feasible. Table 3’s literal `x³+Tr(x³)` differs from the introduction’s `x³+Tr(x⁹)`; at even n the literal entry is an invertible output-linear transform of Gold. Preserve both readings. Other field-dependent rows need reconciliation. Prior-family coverage and complete equivalence classification of the n=12/n=15 parameter grids remain unresolved; APN grid verification alone does not classify them.

The bounded commands and remaining requirements are documented here.
This current assessment supersedes conflicting historical scope descriptions below.

F071 additional evidence: both admissible n=12 Frobenius representatives (s=5 and11) are tested; a bounded coefficient-grid command now exposes 241 admissible pairs per s. Table 2 now builds the literal u^290 term with the correct power index. `make family_separation` independently computes distinct full ortho-derivative signatures for all four Table 2 representatives, proving all six pairwise CCZ inequivalences. This does not compare them to every earlier construction or establish global novelty.

F071 follow-up: all four admissible n=15 exponents `s=1,4,7,13` were checked
with fixed verified primitive `u` and the declared polynomial basis. Each full
subfield coefficient grid contains **993** admissible `(v,w)` pairs, and every
constructed function passed the exact quadratic-APN predicate. This exhausts
those four fixed-parameter grids; it neither classifies their equivalence classes
nor compares every earlier construction. Source/input hashes and execution logs
are retained by VBFRepro.

```sh
bin/vbfrepro run Bracken_201103 --target parameter_sweep --param k=5 \
  --param s=1 --param full_search=true --param timeout_seconds=300 \
  --timeout-seconds 360
# Repeat with s=4,7,13.
```

Current audit application (2026-10-10, Julia 1.13.1): `make test` and `make report` ran successfully. The suite now passes 43 assertions (including newly added regressions where applicable). VBFRepro retained source/input hashes and logs under `data/repro/runs/Bracken_201103/` for the recorded runs. The older “no Julia” review below is historical and is superseded by these executions. The paper tests pin the source representatives’ APN properties, degrees and exact little-endian encoding hashes. These regressions do not establish novelty against the reference corpus.


- **Citation:** C. Bracken, E. Byrne, N. Markin, G. McGuire, "A few more quadratic APN
  functions", *Cryptogr. Commun.* 3:43–53, 2011.
- **Reproduction path:** `packages/VBFRepro/src/201103-bracken-quadratic-apns/`
- **Paper source:** `input/Bracken et al. - 2011 - A few more quadratic APN functions.tex`
- **Verdict:** **Partial** — Section 2 (Theorem 2.1) is faithfully implemented and every
  instance it builds really is APN, but Section 3 (the entire novelty argument) is only
  partially reproduced: the paper's exact Table-2 coefficients are mislabelled, the paper's own
  n=6 equivalence conclusions are never checked despite the target already being in the catalog,
  and the central n=12 CCZ-inequivalence claim is declared out of scope on grounds that are
  demonstrably wrong — it is computable in seconds with the repo's own `ortho_derivative`.

Claim levels for the APN result:

| Level | Status |
|---|---|
| formula reproduced | **yes**, exactly |
| APN property verified | **yes** (n=6, n=12) |
| parameter family validated | **no** — one (v,w) per family, one `s` per `k`, two dimensions |
| novelty/equivalence claim checked | **no** — self-declared UNVERIFIED, but feasible |
| full claim reproduced | **no** |

---

## Issue Catalog

### Paper Issues

Flaws in the original publication / its OCR'd source. Not ours to fix.

1. **Table 3 row 6 misprints Family 6 as `x³ + Tr(x³)`** (`.tex` l.488), but Section 1 item 6
   (l.126) defines it as `x³ + Tr(x⁹)`. Confirmed computationally: at n=12, `x³+Tr(x³)` has
   ortho-derivative DDT spectrum `{0:9832095, 2:6220305, 6:716625, 8:4095}` — *identical to Gold
   `x³`*, hence CCZ-equivalent to it, with Δ-rank 7,550 rather than the tabulated 7,846.
   `x³+Tr(x⁹)` has a distinct spectrum `{0:10137531, 2:5156403, 4:1240776, 6:208725, 8:26694,
   10:2466, 12:360, 14:156, 16:9}`. The table entry should read `x³+Tr(x⁹)`.
2. **Family 5's Table-3 instance is under-specified** (l.486). `x³+x⁶⁵+ux¹²⁹+u⁶⁴x⁶⁶+u³x¹³⁰+x¹⁹²`
   gives `du = 64` (not APN) under the natural reading of `u` as the primitive element with the
   repo's n=12 modulus. The coefficients depend on the `θ, π` of the Section-1 Family-5
   definition and on the field representation, neither of which the paper pins down.
   Unverifiable as printed.
3. **Family 7 is stated in two non-identical forms.** The intro (l.133-136) writes
   `u x^{2^{-k}+2^{k+s}} + u^{2^k} x^{2^s+1} + v x^{2^{k+s}+2^s}`, while Section 3 (l.420)
   identifies Family 7 with Theorem 2.1 at `v=0`, i.e. with `u` and `u^{2^k}` swapped.
   Reconcilable (`u^{2^k}` is also primitive) but not literally the same polynomial.
4. **Typo in the Theorem 2.1 proof** (l.363): `a^{2^{k-s}}` lost its minus sign relative to the
   displays immediately above (l.352) and below (l.366), both of which read `a^{-2^{k-s}}`.
   Does not affect the argument.
5. **Broken sentence** at l.465: "…while the fourth has delta rank 7,816. with different delta
   ranks. Hence the fourth APN function…". Copy-editing or extraction artifact.
6. **Abstract begins mid-sentence** (l.44-46): the subject clause is missing. Extraction
   artifact of the provided `.tex`, not a mathematical error.

### Reproduction Issues

Defects introduced in our implementation.

#### Br11-1 — The novelty claim is declared out of scope, but is computable in-repo

- **Location:** `section3.jl:104-107`, `report.jl:29-32`.
- **Symptom:** the `NOVELTY-GAP` banner asserts "Family 7 vs Family 8W are NOT separated in this
  repo: Δ-rank PROVABLY cannot split them … A rigorous split needs Feulner canonical form /
  automorphism group — out of scope." The paper's headline result (Families 8 and 8W are new;
  7/8/8W are pairwise inequivalent) is therefore left unverified.
- **Root cause:** the reasoning stops at `delta_rank`'s `n ≤ 7` guard
  (`packages/VBF/src/invariants/design_ranks.jl:75-81`) and never considers `ortho_derivative` /
  `apn_ea_mugshot`. All these functions are **quadratic APN**, where CCZ ⟺ EA (Yoshiara) — a
  fact stated verbatim in the repo's own docstring
  (`packages/VBF/src/invariants/mugshot.jl:119-120`) and already used as the fast path in
  `packages/VBF/src/equivalence/ccz/api.jl:116-119`. The ortho-derivative DDT spectrum at n=12
  takes seconds and separates all ten relevant functions pairwise:

  | Function | Ortho-derivative DDT spectrum (n=12) |
  |---|---|
  | Fam 8 (v=1, w=u²⁷³) | `{0:10160080, 2:5110679, 4:1265103, 6:206094, 8:28707, 10:2205, 12:224, 14:28}` |
  | Fam 8W (v=1, w=0) | `{0:10174892, 2:5089266, 4:1263759, 6:213654, 8:29127, 10:2226, 12:196}` |
  | Fam 7 (v=0, w=u²⁷³) | `{0:10164763, 2:5104071, 4:1265488, 6:206493, 8:29757, 10:2296, 12:245, 16:7}` |
  | Fam 1 (v=0, w=0) | `{0:10149615, 2:5124105, 4:1267560, 6:201285, 8:29295, 10:1260}` |
  | Gold `x³` | `{0:9832095, 2:6220305, 6:716625, 8:4095}` |
  | Gold `x³³` | `{0:10077795, 2:5225220, 4:1253070, 6:212940, 8:4095}` |
  | Fam 2 `x³+u⁷x⁵²⁸` | `{0:10241910, 2:5003460, 4:1263465, 6:219555, 8:34335, 10:5670, 12:3150, 14:945, 20:630}` |
  | Fam 6 `x³+Tr(x⁹)` | `{0:10137531, 2:5156403, 4:1240776, 6:208725, 8:26694, 10:2466, 12:360, 14:156, 16:9}` |

  This reproduces the paper's whole Section-3 claim **and goes strictly beyond it**: it splits
  Family 7 from Family 8W, which the paper's Δ-rank explicitly could not do (both 7,900) and for
  which Feulner needed a canonical-form computation.
- **Resolution plan:**
  1. Build the four n=12 subfamily SBoxes with the paper's exact Table-2 coefficients (after
     Br11-2).
  2. Build the Table-3 comparison functions at n=12: `gold_apn(12,1)`, `gold_apn(12,5)`,
     `kasami_apn(12,5)` (`x⁹⁹³`), Family 2 `x³+u⁷x⁵²⁸`, Family 6 `x³+Tr(x⁹)`.
  3. Compute `apn_ea_mugshot` (or `ddt(ortho_derivative(F))` spectra) for every quadratic member
     and assert pairwise inequality.
  4. State the conclusion at its correct strength: distinct ortho-derivative invariant ⇒
     EA-inequivalent ⇒ (quadratic APN, Yoshiara) CCZ-inequivalent; cite
     `packages/VBF/src/invariants/mugshot.jl:119-120`.
  5. Rewrite the `NOVELTY-GAP` banners at `section3.jl:98-108` and `report.jl:28-32` — they
     currently understate what the repo can prove. Keep a `[loaded]` marker for the numeric
     Δ-rank values only.
  6. Note `x⁹⁹³` is Kasami, not quadratic, so it needs the non-quadratic `apn_ea_mugshot` branch
     or a separate argument.

#### Br11-2 — n=12 Table-2 labels do not match the functions actually built

- **Location & symptom:**

  | Location | Label says | Actually built |
  |---|---|---|
  | `section3.jl:64-65` | `u¹⁶x⁷⁶⁸ + ux³³ + x²⁵⁷ + u²⁹⁰x⁵⁴⁴` (Family 8, paper l.455) | `theorem1_sbox(4,5,1,5)` sets `w = subfield_elem(12,4,4) = u¹⁰⁹²`, so the fourth coefficient is `w·u¹⁷ = u¹¹⁰⁹`, not `u²⁹⁰` |
  | `section3.jl:68-69` | `u¹⁶x⁷⁶⁸ + ux³³ + u²⁹⁰x⁵⁴⁴` (Family 7, paper l.457) | `theorem1_sbox(4,5,0,1)` sets `w = subfield_elem(12,4,0) = 1`, giving `u¹⁷x⁵⁴⁴` |

- **Root cause:** off-by-one against the `subfield_elem(n,k,idx-1)` power-indexing convention at
  `theorem1.jl:42-43`. The paper's `u²⁹⁰x⁵⁴⁴` requires `w = u²⁹⁰⁻¹⁷ = u²⁷³`, i.e. `w_idx = 2`
  (`u²⁷³` generates `GF(16)*` because `273 = 4095/15`).
- **Resolution plan:**
  1. Set `w_idx = 2` at `section3.jl:65` and at `section3.jl:69`.
  2. Do the same at `theorem1.jl:28` for the Family-7 case.
  3. Assert the identity in a test: rebuild the LUT from the literal exponent list
     `[(u¹⁶,768), (u,33), (1,257), (u²⁹⁰,544)]` via `terms_to_lut` and `@test` it equals the
     built SBox.
  4. Keep a second, non-paper `(v,w)` instance if wanted, but label it as such.
  5. Informational: `w = u¹⁰⁹²` and `w = u²⁷³` have identical ortho-derivative spectra, so they
     are EA-equivalent — only the fidelity of the printed label is harmed, not the mathematics.

#### Br11-3 — `bracken_lut` silently accepts parameters that violate Theorem 2.1

- **Location:** `helpers.jl:36-52`.
- **Symptom:** the hypotheses `(s,3k)=1`, `(3,k)=1`, `3 ∣ (k+s)`, `u` primitive, `v,w ∈ GF(2^k)`,
  `vw ≠ 1` are stated only in the docstring (`helpers.jl:28-29`); nothing is checked. Negative
  controls, all silently accepted:

  | call | result |
  |---|---|
  | `k=2, s=5` (3 ∤ k+s) | **du = 8**, not APN |
  | `k=2, s=3` (gcd(s,3k) = 3) | **du = 8** |
  | `k=2, s=1, v=w=1` (vw = 1) | **du = 4** |

- **Root cause:** no argument validation. Compare `bcp_apn`
  (`packages/VBF/src/constructions/apn_quadratic_families.jl:81-99`), which throws
  `ArgumentError` on every hypothesis violation.
- **Resolution plan:**
  1. Add `gcd(s,3k)==1`, `k%3!=0`, `(k+s)%3==0` checks throwing `ArgumentError`.
  2. Add `in_subfield(v,3k,k) && in_subfield(w,3k,k)` (core export) and
     `gf_mul(v,w,3k;modulus) != 1`.
  3. Optionally check `u` is primitive (order `2^{3k}−1`) — cheap at these sizes.
  4. Add a test asserting the three negative controls above are rejected, converting the
     theorem's hypotheses from prose into executable content.

#### Br11-4 — Equivalence conclusions stated more strongly than the evidence supports

- **Location:** `section3.jl:133`, `test/test_section3.jl:12-13`.
- **Symptom:** `print_check("n=6 Family 1 Δ-rank == Gold x^3 (CCZ-equiv)", …)` and the test
  comment "Families 7 and 8W CCZ-equivalent to same function at n=6". Equal Δ-ranks are a
  *necessary* condition only; they never establish equivalence. The repo's own
  `design_ranks.jl:14-19` docstring warns about exactly this inference.
- **Root cause:** invariant equality conflated with equivalence.
- **Resolution plan:**
  1. Reword the labels to "Δ-rank consistent with CCZ-equivalence".
  2. Prove it at n=6 with `are_ccz_equivalent(F, gold_apn(6,1))` and
     `are_ccz_equivalent(F, load_apn_function("n6_Kim"))` — the quadratic-APN fast path makes
     this cheap.
  3. Add the `n6_Kim` comparison the paper explicitly asserts (Section 3, l.440-446) but which
     the repo never makes, despite `n6_Kim` already being in the catalog.

#### Br11-5 — Parameter-family coverage is one point per family

- **Location:** `theorem1.jl:18-30`; `theorem1.jl:65` prints
  `completeness: exhaustive over listed (k,s,subfamily) tuples`, which is true but circular.
- **Symptom:** only `(k,s) ∈ {(2,1), (4,5)}` and one `(v,w)` per family. `s=11` is equally legal
  for `k=4`; `k=5` (n=15) is the next dimension. Independently verified coverage that the repo
  does not exercise:

  | sweep | result |
  |---|---|
  | `k=2, s=1` (n=6), all (v,w) | 13/13 APN (3 pairs with `vw=1` correctly skipped) |
  | `k=4, s=5` (n=12), all (v,w) | 241/241 APN |
  | `k=4, s=11` (n=12), all (v,w) | 241/241 APN — an `s` the repo omits entirely |
  | `k=5, s=1` (n=15), sampled | 5/5 APN — a dimension the repo omits |

- **Root cause:** no sweep helper.
- **Resolution plan:**
  1. Add `theorem1_sweep(k, s; limit)` ranging over all `v,w ∈ GF(2^k)` with `vw ≠ 1`, asserting
     `differential_uniformity == 2`.
  2. Add `(4,11)` to `THEOREM1_CASES`.
  3. Add an opt-in n=15 (`k=5, s=1`) case behind a `full_search`/`limit` knob, per the AGENTS.md
     rule on expensive searches.

#### Br11-6 — n=6 explicit polynomial forms from Section 3 are never instantiated

- **Location:** `section3.jl:43-45` documents a deliberate deviation.
- **Symptom:** the paper displays `ux³ + vu⁵x¹⁰ + vx¹⁷ + u⁴x²⁴` with a *single* coefficient `v`
  feeding both the `x¹⁰` and `x¹⁷` terms; the repo uses independent `v,w` and never builds the
  literal form. Verified: the literal form is APN precisely for `v ∈ {u²¹, u⁴²}` (`v=1` gives
  `vw=1` → `du=4`), with Δ=96, Γ=1166 and the same ortho-derivative fingerprint as Families
  7/8W/8.
- **Root cause:** a deliberate generalisation that lost the paper's own witness.
- **Resolution plan:**
  1. Additionally instantiate the paper's literal single-`v` form — one line.
  2. Use it as the visible demonstration of the `vw ≠ 1` hypothesis.

#### Br11-7 — Table 3 comparison functions are transcribed constants, never built

- **Location:** `section3.jl:81-92` (`TABLE3_PAPER_DELTA_RANKS_N12`).
- **Symptom:** a bare `Dict` of integers with no function attached, so none of `x³`, `x³³`,
  `x⁹⁹³`, Family 2 (`x³+u⁷x⁵²⁸`), Family 5, Family 6 (`x³+Tr(x⁹)`) is even APN-checked at n=12.
  The five `TABLE3_…` assertions in `test/test_section3.jl:26-30` are arithmetic on transcribed
  constants. The `[loaded]` marker is honest labelling, but the functions themselves are absent.
- **Root cause:** Δ-rank at n=12 is genuinely infeasible (`2²⁴ × 2²⁴`), and the whole table was
  demoted with it.
- **Resolution plan:** build the functions (Br11-1.2) and verify APN-ness and pairwise
  inequivalence via ortho-derivative invariants; keep `[loaded]` for the Δ-rank *numbers* only.

#### Br11-8 — Dead variables with wrong comments

- **Location & symptom:**

  | Location | Comment claims | Actual value |
  |---|---|---|
  | `section3.jl:38` | `v6 = subfield_elem(6,2,0)  # u^21, generator of GF(4)*` | `gf_pow(2, 0·21) = 1`; variable never used |
  | `section3.jl:61-62` | `w12 = subfield_elem(12,4,0)  # w = u^273 ∈ GF(16)` | `1`; neither `v12` nor `w12` is used (lines 64-72 call `theorem1_sbox` directly) |
  | `test/test_theorem1.jl:20-21` | `v6 # u^21 ∈ GF(4)`, `w6 # u^42 ∈ GF(4)` | `1` and `u²¹` |

- **Root cause:** confusion between the *index* `i` and the *exponent* `i·norm` in
  `subfield_elem` (`helpers.jl:68-72`) — the same off-by-one as Br11-2. The tests themselves are
  sound; only the annotations are wrong.
- **Resolution plan:**
  1. Delete the unused `v6`, `v12`, `w12`, or wire them into a real `bracken_lut` call so the
     docstring at `section3.jl:55-56` becomes literally true.
  2. Fix the four comments.
  3. Add `@test in_subfield(v6, 6, 2)` / `@test in_subfield(w6, 6, 2)` so the `v,w ∈ GF(2^k)`
     hypothesis is asserted, not just commented.
  4. Drop the stale `kasami_apn` mention in the "VBF API used" header at `section3.jl:13` —
     `kasami_apn` is never called anywhere in this directory.

#### Br11-9 — Hand-rolled polynomial evaluation duplicates `terms_to_lut`

- **Location:** `helpers.jl:47-51`.
- **Symptom:** the four-term `Σ cᵢ·gf_pow(x,eᵢ)` comprehension reimplements the exported
  `terms_to_lut` (`packages/VBF/src/representations/univariate.jl:331`), which additionally
  supports `monomial_power_table` amortisation.
- **Root cause:** the term loop was written from scratch.
- **Resolution plan:** build `terms = [(c1,e1), …, (c4,e4)]` and return
  `terms_to_lut(terms, n, modulus)` with a shared `powtab`. This matters for the Br11-5 sweeps,
  where `powtab` reuse across 241 `(v,w)` pairs at n=12 is a large constant-factor win.

---

## Items reproduced exactly

| Paper item | Repo location | Verification |
|---|---|---|
| **Theorem 2.1** quadrinomial `F(x) = u^{2^k}x^{2^{-k}+2^{k+s}} + u x^{2^s+1} + v x^{2^{-k}+1} + w u^{2^k+1} x^{2^{k+s}+2^s}` | `helpers.jl:36-52` | All four exponents and coefficients match term-for-term; `2^{-k} ≡ 2^{2k}` for `n=3k` is handled correctly |
| **Theorem 2.1** APN conclusion, n=6 (k=2, s=1) | `theorem1.jl:21-24`, `test/test_theorem1.jl:8-24` | All four subfamilies confirmed `du = 2` |
| **Theorem 2.1** APN conclusion, n=12 (k=4, s=5) | `theorem1.jl:26-29`, `test/test_theorem1.jl:35-38` | All four confirmed `du = 2` |
| Section 3 four-subfamily decomposition (Fam 1 / 7 / 8W / 8 by `v,w` zero-patterns) | `helpers.jl:31-32`, `theorem1.jl:18-30` | Structure fully reproduced |
| Section 3, n=6: Family 1 separated from Families 7/8W/8 by Δ-rank | `section3.jl:127-128`, `test/test_section3.jl:11` | Confirmed: Δ = 94 vs 96 |
| Section 3, n=6: Family 1 matches Gold `x³` | `section3.jl:131-133` | Δ = 94, Γ = 1102 both; od-dspec `{0:2205, 2:1764, 8:63}` identical (but see Br11-4 on strength of the claim) |
| Table 3 (n=12 Δ-ranks) numeric values | `section3.jl:81-92` | Transcribed only, explicitly flagged `[loaded]` — honest labelling |

---

## Test results

`make -C packages/VBFRepro/src/201103-bracken-quadratic-apns test` → **could not run**: `make: julia: No such file or
directory`, exit 127. No Julia toolchain exists in the review environment.

Every assertion in `test/test_theorem1.jl` and `test/test_section3.jl` was independently
re-derived and **holds**: 8× `differential_uniformity == 2` at n=6, 4× at n=12,
`gf_mul(v6,w6,6) = u²¹ ≠ 1`, `dr["1"] = 94`, `dr["7"] = dr["8W"] = dr["8"] = 96`,
`delta_rank(gold_apn(6,1)) = 94`.

Verification was done by re-implementing the repo's exact `gf_mul` / `gf_pow` / `delta_rank` /
`gamma_rank` semantics in C and Python, cross-checked against the core docstring examples
(`delta_rank(gold_apn(5,1)) == 42`, `gamma_rank(gold_apn(5,1)) == 330` — both matched). These
results should be re-confirmed under Julia before being relied on.

---

## Catalog status

Checked against `packages/VBFCatalog/data-raw/apn_catalog/n6_apn.toml` (`n6_Gold_x3`,
`n6_Kasami_x48`, `n6_Kim`) and `n12_apn.toml` (`n12_CalderiniLiVilla2023_F1`,
`n12_CalderiniLiVilla2023_F2`), by Δ-rank + Γ-rank + ortho-derivative differential and Walsh
spectra — conclusive for CCZ on the quadratic-APN class by Yoshiara.

| Claimed function | n | Status |
|---|---|---|
| Family 8, n=6 form | 6 | **not-new** — equivalent to `n6_Kim` (`x³+x¹⁰+u·x²⁴`): Δ=96, Γ=1166, od-dspec `{0:2373, 2:1428, 4:168, 8:63}`, od-wspec `{0:1540, 8:2072, 16:364, 24:56}` identical on all four invariants. Matches the paper's own statement (l.440-446) |
| Family 8W, n=6 form | 6 | **not-new** — same, equivalent to `n6_Kim` |
| Family 7, n=6 form | 6 | **not-new** — same, equivalent to `n6_Kim` |
| Family 1, n=6 form | 6 | **not-new** — equivalent to `n6_Gold_x3` (Δ=94, Γ=1102, identical od fingerprints). Matches the paper (l.446) |
| **Family 8, n=12** (`u¹⁶x⁷⁶⁸+ux³³+x²⁵⁷+u²⁹⁰x⁵⁴⁴`) | 12 | **missing** — catalog gap |
| **Family 8W, n=12** (`u¹⁶x⁷⁶⁸+ux³³+x²⁵⁷`) | 12 | **missing** — catalog gap |
| Family 7, n=12 (`u¹⁶x⁷⁶⁸+ux³³+u²⁹⁰x⁵⁴⁴`) | 12 | **missing** — catalog gap; attributable to `Bracken_200807`, but this paper is its n=12 witness |
| Family 1, n=12 (`u¹⁶x⁷⁶⁸+ux³³`) | 12 | missing, but attributable to Budaghyan–Carlet–Felke–Leander, not proposed here |

Neither n=12 catalog entry matches any Bracken family:
`n12_CalderiniLiVilla2023_F1` has od-dspec
`{0:10231011, 2:5093109, 4:1162917, 6:228501, 8:42462, 10:2268, 12:6615, 16:1134, 20:3969, 22:1134}`;
`n12_CalderiniLiVilla2023_F2` has
`{0:10172943, 2:5089491, 4:1269000, 6:211509, 8:26829, 10:3006, 12:288, 16:18, 18:36}`. Both
differ from Families 8 / 8W / 7 (spectra in Br11-1), which also differ pairwise from each other.

### Catalog-gap records

Common to all three: target `packages/VBFCatalog/data-raw/apn_catalog/n12_apn.toml`; `n = 12`,
`m = 12`, `is_permutation = false`, `algebraic_degree = 2`, `differential_uniformity = 2`,
`bib_key = "Bracken_201103"` (already at `packages/VBFCatalog/data-raw/bibliography.bib:571`).
Field `GF(2^12)`, modulus `x¹²+x⁶+x⁴+x+1 = 4179` (= `primitive_polynomial(12)`), `u = 2`
(primitive, `ord(2) = 4095`), `k = 4`, `s = 5`, `u²⁷³ = 1971`, `u¹⁶ = 1328`, `u²⁹⁰ = 3747`.

1. **`n12_BrackenByrneMarkinMcGuire2011_Family8`** — Theorem 2.1 with `k=4, s=5, v=1, w=u²⁷³`.
   LUT recipe `terms_to_lut([(1328,768),(2,33),(1,257),(3747,544)], 12, 4179)`. Fingerprint:
   `lut[0:15] = [0, 2960, 2418, 1775, 3682, 723, 208, 2156, 3848, 959, 3349, 1455, 488, 2686,
   1077, 2990]`, legacy word-wise FNV-style hash (offset 1469598103934665603) over the LUT = `2335486592259839811`.
2. **`n12_BrackenByrneMarkinMcGuire2011_Family8W`** — `k=4, s=5, v=1, w=0`. LUT recipe
   `terms_to_lut([(1328,768),(2,33),(1,257)], 12, 4179)`. Fingerprint:
   `lut[0:15] = [0, 1331, 3385, 1212, 1168, 929, 348, 2779, 2575, 468, 932, 1225, 3879, 1790,
   3705, 2838]`, legacy word-wise hash = `18054150684828440259`. Its spectrum differs from Family 7's —
   this is the separation the paper's Δ-rank could not achieve.
3. **`n12_BrackenByrneMarkinMcGuire2011_Family7`** — `k=4, s=5, v=0, w=u²⁷³`. LUT recipe
   `terms_to_lut([(1328,768),(2,33),(3747,544)], 12, 4179)`. Fingerprint:
   `lut[0:15] = [0, 2961, 920, 2419, 2006, 2319, 723, 3440, 3686, 1761, 1517, 3088, 2750, 1905,
   1960, 2845]`, legacy word-wise hash = `1860369106084231363`. Prefer `bib_key = "Bracken_200807"` (the
   family's origin) with `source` citing this paper's Table 2 as the n=12 instance.

**Historical caveat (superseded by F060 Julia revalidation):** these LUT values came from a C re-implementation of `gf_mul`/`gf_pow` validated
against the VBF docstring examples, **not** from Julia. Regenerate with `terms_to_lut` and match
the fingerprints above before writing any TOML.

---

## Library-reuse note

| Helper | Line | Verdict |
|---|---|---|
| `bracken_lut` | `helpers.jl:36-52` | **Partially duplicates core.** Lines 39-46 (exponent/coefficient derivation from `k,s,u,v,w`) are legitimately paper-specific; lines 47-51 reimplement `terms_to_lut`. Fix target: `terms_to_lut(terms, n, modulus)` — see Br11-9 |
| `subfield_elem` | `helpers.jl:68-72` | **Not a duplication.** Genuinely different from `subfield_elements(n,k)` (`finite_field.jl:362`), which returns the whole subfield sorted by integer value including 0; the helper indexes `GF(2^k)*` by powers of the primitive element, which is what the paper's `u²⁷³`-style coefficients need. The file's own `TODO(promote-to-core)` at `helpers.jl:65-66` is the right call. **Promote-to-core candidate:** `subfield_generator(n, k; modulus)` returning `gf_pow(2, (2ⁿ−1)÷(2^k−1), n)`, or `subfield_elements(n, k; order=:powers)`. If promoted, design away the index/exponent confusion behind Br11-8 (index `i` ↦ `u^{i·norm}`, with a docstring example) |

Correctly reused elsewhere: `SBox`, `differential_uniformity`, `delta_rank`, `gold_apn`,
`gf_mul`, `gf_pow`, `primitive_polynomial`, and the report emitters `print_banner` /
`print_section` / `print_check` / `print_kv`. No re-implementation of DDT, Walsh, rank, or
report formatting.

**Underused and directly relevant to the gaps above:** `terms_to_lut`, `monomial_power_table`,
`in_subfield`, `ortho_derivative`, `apn_ea_mugshot`, `are_ccz_equivalent`, `kasami_apn`,
`gamma_rank`.

---

## Open questions

1. **`w_idx` convention** — was `theorem1.jl:28`'s `w_idx = 1` / `section3.jl:65`'s `w_idx = 5`
   a deliberate choice of a different family member, or the off-by-one of Br11-2? The labels
   quote the paper's `u²⁹⁰` exactly, which suggests the latter. Confirm before applying Br11-2.
2. **Family 5 at n=12** — should the reproduction search for admissible `θ, π` per Section 1
   item 5, or record it as unverifiable-as-printed (Paper Issue 2)?
3. **Δ-rank at n=12** is genuinely out of scope, so Table 3 stays `[loaded]`. Acceptable
   provided the equivalence conclusions are re-derived from ortho-derivative invariants
   (Br11-1) — the paper needs the Δ-ranks only to conclude inequivalence, and the
   ortho-derivative route reaches a strictly stronger conclusion.
4. **`Bracken_200807`** is reproduced at `packages/VBFRepro/src/200807-bracken-apn-trinomials/`; Family 7 originates
   there. That affects whether catalog record 3 is filed under this paper or deferred.
