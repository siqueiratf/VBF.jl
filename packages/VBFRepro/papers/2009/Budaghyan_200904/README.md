# Budaghyan, Carlet & Leander (2009) — Constructing new APN functions from known ones

- **Citation:** L. Budaghyan, C. Carlet, G. Leander, "Constructing new APN functions from known
  ones", *Finite Fields Appl.* 15:150–159, 2009.
- **Reproduction path:** `packages/VBFRepro/papers/2009/Budaghyan_200904/`
- **Paper source:** `input/Budaghyan et al. - 2009 - Constructing new APN functions from known ones.tex`
- **Verdict:** **Mostly complete** — every implemented claim is numerically exact, including the
  Corollary 4 Δ-ranks and the bit-identical Proposition 3 polynomials. What remains is one claim
  never implemented (Proposition 1(3)), one theorem whose hypotheses are never checked
  (Theorem 2), the paper's own computer-checked cases (Theorem 3 at n=8, 10), and a search that
  cannot support the completeness statement it sits next to.

---

## Issue Catalog

### Paper Issues

Flaws in the original publication. Not ours to fix.

1. **Proposition 1(2) as stated is false for `F∘A`.** If `A` is affine 2-to-1 with kernel
   `{0,c}`, then `D_c(F∘A) ≡ 0`, so `Δ_{F∘A}(c,0) = 2ⁿ`. Verified at n=5 with `A(x) = x+x²`:
   full `du(F∘A) = 32`, while `du` restricted to `a ∉ ker A` is 4. Only `A∘F` is genuinely
   4-uniform (verified du = 4). The reproduction handles this correctly via `du_off_kernel` and
   documents it at `proposition1.jl:74-75`, but it is a paper erratum, not merely a code note,
   and should be recorded as such.

### Reproduction Issues

Defects introduced in our implementation.

#### BCL04-1 — Proposition 1(3) is not implemented

- **Location:** `proposition1.jl:78`.
- **Symptom:** claim (3) emits only a `print_kv` note ("bounded; shares mechanism with (2)"). No
  affine 2-to-1 map `L` of `GF(2ⁿ)²` is ever built or measured, so the claim contributes nothing
  to `ok`/`all_ok` and `test/test_proposition1.jl` passes without exercising it.
- **Root cause:** the graph-side 2-to-1 case was deferred with a prose note.
- **Resolution plan:**
  1. Build an affine 2-to-1 `L` on `GF(2ⁿ)²` (e.g. `L(x,y) = (x, y + ℓ(x))` composed with a
     rank-`(2n−1)` linear map).
  2. Compute `L(G_F)` as a relation and derive the induced `F′`, or measure the 4-uniformity of
     the multiset directly.
  3. Assert `du ≤ 4` off the collapsing direction, fold into `ok2`/`all_ok`, and add a test
     assertion.

#### BCL04-2 — Theorem 2's own hypotheses are never verified

- **Location:** `theorem2.jl:37-55` (and the note at line 55).
- **Symptom:** the file named `theorem2.jl` checks only Corollary 2's *conclusion*. Neither
  condition (1) `φ_f = ℓ_a∘φ_F` nor condition (2) `ℓ_a(u) ≠ u` is tested, so Theorem 2 is
  asserted rather than reproduced.
- **Root cause:** there is no `theorem2_conditions` counterpart to the existing
  `theorem1_conditions`.
- **Resolution plan:**
  1. Add `theorem2_conditions(F, f_lut, ell; n, m)` mirroring `theorem1_conditions`, with
     `ℓ_a : GF(2ⁿ) → GF(2ᵐ)` and condition (2) `ℓ_a(u) ≠ u` for every `u ∈ GF(2ᵐ)*`.
  2. Derive the explicit `ℓ_a` for `F = x³`, `f = tr_{n/m}(x^{2^m+2})` (m=2, n=4 and m=4, n=8)
     and check both conditions.
  3. Add them to `theorem2_report`'s `ok` and to `test/test_theorem2.jl`.

#### BCL04-3 — Theorem 3's computer-checked cases n=8, n=10 are absent

- **Location:** `theorem3.jl:22`, `test/test_theorem3.jl:8`, `Makefile:63-65`.
- **Symptom:** the paper says explicitly "For n = 8, 10 CCZ-inequivalence of F and G is checked
  by a computer" — precisely the computational part of Theorem 3 — and no target or test covers
  either dimension. `theorem3_report` defaults to n=7.
- **Root cause:** default `n = 7`; no other invocation exists.
- **Resolution plan:**
  1. `delta_rank` is capped at n ≤ 7, so use `apn_ea_mugshot` for n=8 and n=10 — both sides are
     quadratic APN, so EA ⟺ CCZ by Yoshiara.
  2. Add `theorem3_report(io; n = 8)` and `n = 10` to `report.jl` behind `full_search`, plus a
     fast n=8 assertion in `test/test_theorem3.jl`.
  3. Record in the report text that n=8, 10 are the paper's own computer-checked cases.

#### BCL04-4 — The §2.1 search cannot support the paper's completeness claim

- **Location:** `section2_1.jl:114-166`.
- **Symptom:** at n=5, r=1 the kernel has dimension 20 (independently confirmed, and all 20 basis
  vectors give APN functions), but that dimension is dominated by EA-trivial solutions. The
  report prints only `kernel dimension` with no classification, so a reader may mistake it for
  the paper's classification result — which is that, up to dimension 15, the *only* functions of
  this shape besides `x³+tr(x⁹)` are `x⁵+tr(x³)` (n=5) and `x⁹+tr(x³)` (n=8).
- **Root cause:** the EA-trivial subspace is not quotiented out, and only one `(n,r)` pair is run.
- **Resolution plan:**
  1. Quotient the kernel by the EA-trivial subspace (vectors whose `g` makes `F+g` EA-equivalent
     to `F`), e.g. by bucketing kernel vectors with `apn_ea_mugshot(F+g)`.
  2. Report the number of *inequivalent* solutions per `(n, r)` and confirm the paper's list at
     n=5 and n=8.
  3. Add `n_max`/`r` sweep options and state explicitly that the paper's dimension-15 sweep is
     out of scope.

#### BCL04-5 — Proposition 3(3),(4) report an unverified `matches = true`

- **Location:** `proposition3.jl:83` and `proposition3.jl:93`.
- **Symptom:** `push!(rows, (; case = 3, n, du, deg = dg, matches = true))` hard-codes a field
  that reads as "the paper's explicit polynomial was checked" for the two cases where nothing was
  compared. The paper's closed forms
  `(x + tr_{n/3}(x⁶+x¹²) + tr(x)·tr_{n/3}(x³+x¹²))³ + tr(…)` and the `x^{1/3}`/inverse form of
  case (4) are never built.
- **Root cause:** only the graph construction was implemented for these two cases.
- **Resolution plan:**
  1. Either implement `prop3_3_explicit` / `prop3_4_explicit` (case (4) needs a cube-root table
     and `gf_inv`) and compare, or
  2. change the field to `matches = missing` and print "explicit closed form not reproduced", so
     the report stops overstating.

#### BCL04-6 — Smaller omissions

- **Remark 3** (the `F+tr(G)` construction also yields new non-quadratic APN functions) is not
  reproduced.
- **Helper duplication**: `graph_affine_map` and `ortho_signature` re-implement core — see the
  Library-reuse note.

---

## Items reproduced exactly

All independently re-verified; **every numeric claim in the reproduction matched**.

| Paper item | Repo location | Verification |
|---|---|---|
| **Theorem 1** (ℓ_a conditions ⇒ `F+f` APN) | `theorem1.jl` | conditions (1)+(2) hold for `F=x³`, `f=tr(x⁹)`, `ℓ_a(y)=tr(a⁶y+a³y²+a⁻³y⁴)` at n=3…7; `du(F+f) = 2` each |
| **Remark 2** (Dillon, `F+ℓ∘F`) | `theorem1.jl:95-108` | confirmed |
| **Corollary 1** (`x³+tr(x⁹)` APN ∀n) | `corollary1.jl` | du=2, deg=2 for n=3…9 |
| **Proposition 2** (trinomial `F ~EA G`) | `proposition2.jl` | n=6, m=3: du(F)=du(G)=2, ord(α=2)=63, witness **u=23**, `L(F(x))=G(x)` ∀x |
| **Corollary 2** (`F, F′` APN; `F′=F^{2^m}`) | `corollary2.jl` | m=2/n=4 and m=4/n=8: du=2 both, `F′=F^{2^m}` exact |
| **§2.1 examples** | `section2_1.jl` | n=5 `x⁵+tr(x³)` du=2; n=8 `x⁹+tr(x³)` du=2; n=7 `x⁹+tr(x³)` du=4 (negative case) |
| **§2.1 `T_i^r` oracle** | `section2_1.jl:70-104` | `g_in_kernel` agrees with APN-ness on all 6 test rows |
| **Theorem 3** (CCZ-inequiv to Gold, n=7) | `theorem3.jl` | Γ-rank(`x³+tr x⁹`) = 4026 vs Gold 3610/3708/3610 → inequivalent |
| **Corollary 3** | `corollary3.jl` | confirmed |
| **Corollary 4** (Δ-ranks) | `corollary4.jl` | **Δ(x³+tr x⁹) = 212, Δ(x¹³) = 338, Δ(x²³) = 436** — exact match |
| **Proposition 3(1),(2)** | `proposition3.jl` | n=7 and n=6: du=2, deg=3, and the graph image is **bit-identical** to the paper's explicit polynomials |

---

## Test results

`make -C packages/VBFRepro/papers/2009/Budaghyan_200904 test` → **could not run**: `julia` is not installed on this
host (`make: julia: No such file or directory`; no `julia` on PATH, no juliaup, not in pacman).

Every claim above was re-derived independently in pure Python (GF(2ⁿ) arithmetic matching
`VBF.PRIMITIVE_POLYNOMIALS`, DDT/degree/Walsh, ortho-derivatives, and a bit-packed F₂
design-rank routine matching `VBF._design_2rank`). **Every numeric claim in the reproduction
matched.** Re-confirm under Julia before relying on the LUTs below.

---

## Catalog status

| Claimed-new function | Status |
|---|---|
| `x³+tr(x⁹)` on GF(2⁷) — Corollary 4, CCZ-inequivalent to all power maps and all then-known families | **missing** — catalog gap |
| `x⁹+tr(x³)` on GF(2⁸) — §2.1(2), CCZ-inequivalent to power maps and to `x³+tr(x⁹)` | **missing** — catalog gap |
| `x³+tr(x⁹)` on GF(2⁶) | **not-new** — OD differential spectrum `{0:2205, 2:1764, 8:63}` and (Γ,Δ) = (1102, 94), identical to `n6_Gold_x3`. Consistent with the paper claiming inequivalence only for n ≥ 7 |

Both files already flag these ("catalog-gap candidate" at `section2_1.jl:54` and
`corollary4.jl:51`) but nothing has been actioned.

### Catalog-gap records

**Record 1 — `n7_BudaghyanCarletLeander2009_x3_tr_x9`**
- target: `packages/VBFCatalog/data-raw/apn_catalog/n7_apn.toml`
- `n = 7`, `m = 7`, `is_permutation = false`, `bib_key = "Budaghyan_200904"`
- `algebraic_form = "x^3 + Tr(x^9) in GF(2^7), modulus x^7 + x + 1 (=131)"`
- `source`: Corollary 1 / Corollary 4; reproduced by
  `packages/VBFRepro/papers/2009/Budaghyan_200904/corollary1.jl` (`apn_x3_tr_x9(7)`)
- `lut = [0, 0, 8, 14, 64, 84, 120, 106, 13, 69, 39, 105, 72, 20, 82, 8, 96, 118, 36, 52, 62, 60,
  74, 78, 69, 27, 35, 123, 30, 84, 72, 4, 11, 51, 48, 14, 39, 11, 44, 6, 116, 4, 109, 27, 93, 57,
  116, 22, 44, 2, 91, 115, 30, 36, 89, 101, 123, 29, 46, 78, 76, 62, 41, 93, 81, 113, 29, 59, 13,
  57, 113, 67, 55, 95, 89, 55, 110, 18, 48, 74, 32, 22, 32, 16, 98, 64, 82, 118, 110, 16, 76, 52,
  41, 67, 59, 87, 103, 127, 24, 6, 87, 91, 24, 18, 115, 35, 46, 120, 70, 2, 43, 105, 81, 95, 98,
  106, 127, 101, 124, 96, 109, 43, 124, 60, 70, 20, 103, 51]`
- Evidence: `differential_uniformity = 2`, `algebraic_degree = 2`, **Δ-rank = 212**,
  **Γ-rank = 4026** (both CCZ-invariants). Existing `n7_apn.toml` entries have Δ-ranks 198
  (`n7_Gold_x3`, `n7_Gold_x5`, `n7_Gold_x9`), 338 (`n7_Kasami_x13`, `n7_Welch_x11`), 436
  (`n7_Kasami_x57`, `n7_Niho_x39`), 4928 (`n7_Inverse_x126`) — all recomputed here and all
  matching Edel–Pott Table 8. No existing entry has Δ-rank 212.

**Record 2 — `n8_BudaghyanCarletLeander2009_x9_tr_x3`**
- target: `packages/VBFCatalog/data-raw/apn_catalog/n8_apn.toml`
- `n = 8`, `m = 8`, `is_permutation = false`, `bib_key = "Budaghyan_200904"`
- `algebraic_form = "x^9 + Tr(x^3) in GF(2^8), modulus x^8 + x^4 + x^3 + x + 1 (=283)"`
- `source`: §2.1 item (2); also Edel–Pott (2009) Table 9 entry 1.11; reproduced by
  `packages/VBFRepro/papers/2009/Budaghyan_200904/section2_1.jl` (`gold_plus_trace(8, 9, 3)`)
- `lut = [0, 1, 54, 46, 99, 56, 132, 198, 238, 84, 125, 222, 176, 80, 242, 11, 194, 55, 141, 97,
  138, 37, 20, 162, 136, 198, 98, 53, 253, 233, 198, 203, 28, 169, 84, 248, 45, 194, 180, 66,
  174, 160, 67, 84, 162, 246, 158, 211, 195, 130, 242, 170, 217, 194, 57, 59, 213, 47, 65, 162,
  242, 82, 183, 14, 9, 160, 110, 222, 141, 126, 59, 209, 222, 204, 28, 23, 103, 47, 116, 37, 237,
  176, 243, 183, 66, 69, 141, 147, 158, 120, 37, 218, 12, 176, 102, 195, 43, 54, 50, 54, 253,
  186, 53, 107, 160, 6, 28, 163, 75, 183, 38, 195, 210, 59, 178, 66, 47, 156, 158, 52, 253, 175,
  56, 115, 61, 53, 41, 56, 170, 11, 243, 75, 156, 103, 20, 246, 45, 55, 209, 210, 38, 102, 11,
  82, 20, 65, 52, 120, 9, 6, 248, 238, 55, 217, 178, 69, 23, 163, 67, 238, 175, 186, 136, 132,
  203, 132, 61, 107, 116, 218, 246, 65, 45, 217, 126, 147, 12, 237, 82, 170, 67, 248, 204, 110,
  115, 41, 136, 203, 1, 1, 43, 50, 107, 98, 99, 115, 186, 233, 99, 41, 213, 103, 120, 211, 57,
  209, 69, 180, 243, 14, 130, 102, 9, 174, 169, 23, 233, 175, 61, 98, 46, 50, 43, 46, 80, 237,
  38, 130, 211, 52, 116, 138, 178, 180, 97, 126, 12, 80, 14, 75, 213, 156, 218, 138, 125, 110,
  163, 169, 147, 97, 57, 210, 6, 174, 125, 204]`
- Evidence: `differential_uniformity = 2`, `algebraic_degree = 2` (quadratic ⇒ CCZ ⟺ EA by
  Yoshiara, so an ortho-derivative mismatch is conclusive). OD differential spectrum
  `{0:37980, 2:22272, 4:4716, 6:312}`, distinct from every quadratic n=8 catalog entry:
  `n8_Gold_x3` `{0:39780, 2:21930, 6:3570}`, `n8_Gold_x9` `{0:35700, 2:26520, 4:3060}`,
  `n8_Calderini2021_thm62` `{0:39150, 2:20463, 4:4920, 6:675, 8:54, 10:12, 12:6}`,
  `n8_Taniguchi2025_ex4_2` `{0:38592, 2:21426, 4:4590, 6:654, 8:18}`. `n8_Kasami_x57` has
  algebraic degree 4 and is not CCZ-quadratic (Edel–Pott Table 10 gives `|M(G_F)| = 2³·255`, not
  divisible by 2⁸, so Theorem 10(1) excludes it).

**LUTs must be regenerated under Julia before any TOML write** — they come from a Python
re-implementation, not from the repo's own code.

---

## Library-reuse note

| Helper | Location | Verdict |
|---|---|---|
| `graph_affine_map` | `helpers.jl:83-94` | **Duplicates core.** Every `corr` used (`tr(y)`, `tr_{n/3}(y²+y⁴)`, `tr_{n/3}(y+y⁴)`) is F₂-linear, so `L(x,y) = (x+corr(y), y)` is an `F2LinearMap` on F₂^{2n}. Fix target: build it once and call `ccz_equivalent_function` (with `FunctionGraph` / `graph_image_by`) |
| `ortho_signature` | `helpers.jl:106-111` | **Duplicates core, and is weaker** — `apn_ea_mugshot` also carries the OD Walsh spectrum, which would strengthen every inequivalence claim this paper makes |
| `compose_sbox` | `proposition1.jl:22-23` | **Promote-to-core candidate**: core `compose` exists only for `SBox ∘ F2LinearMap`; `compose(::SBox{N}, ::SBox{N})` is generic |
| `phi` (second-order derivative) | `helpers.jl:66-70` | **Promote-to-core candidate** (`second_order_derivative(F, a)`); paper-local for now, legitimate |
| `du_off_kernel` | `proposition1.jl:33-46` | Paper-specific, legitimate — and the right response to Paper Issue 1 |
| `gold_plus_trace`, `apn_x3_tr_x9`, `_Tir`, `g_in_kernel`, `dependence_search`, `x3_plus_reltrace*`, `prop3_*_explicit` | various | Paper-specific, legitimate |

Correct reuse observed: `gf_pow`/`gf_mul`/`gf_inv`/`gf_trace`/`gf_relative_trace`,
`primitive_polynomial`, `gf_monomial_lut`, `in_subfield`, `kernel_f2`,
`differential_uniformity`, `algebraic_degree`, `is_permutation`, `delta_rank`,
`ortho_derivative`, `differential_spectrum`, `are_ea_equivalent`, `are_ccz_equivalent`,
`gold_apn`, and the report emitters.

Note: `x3_plus_reltrace` accepts `m` without checking `m ∣ n` or that `m` is even — see the
cross-paper pattern on missing parameter validation.

---

## Open questions

1. Should Theorem 3's n=8 / n=10 checks be added as a `full_search` path, or is the n=7 default
   the intended scope?
