# Budaghyan_202101 — Generalized Isotopic Shift Construction for APN Functions

**Paper**: Budaghyan, Calderini, Carlet, Coulter, Villa. "Generalized isotopic shift
construction for APN functions." *Designs, Codes and Cryptography* **89**(1):19–32, 2021.

**Reproduction path**: `papers/2021/Budaghyan_202101/`

**Verdict**: Partial

The published outputs are verified, but the construction that produces them is not. Every
entry of Table 1 (12 functions over `F_{2⁸}`) and Table 3 (17 over `F_{2⁹}`) is confirmed
APN, and Theorem 3.2 is reproduced for 8 of its cases. What is missing is Theorem 3.1
itself: the reproduction never builds `F(x) = x·L₁(x)^{2^i} + x^{2^i}·L₂(x)` from
coefficients, so the tables are transcribed rather than derived, and the theorem's actual
iff-criterion (the `d`, `d′`, `U`, `W` coset conditions) is nowhere implemented. Propositions
3.1, 3.3, 3.4 and Remark 3.5 are absent, Table 2 is absent, and the Γ-rank / Δ-rank /
`|M_{G_F}|` invariants — the paper's *entire* evidence for the "fifteen new" claim — are
never computed.

> **Environment note**: Julia is not installed in the review environment, so `make test`
> could not be executed. Claims marked "independently confirmed" below were re-derived from
> scratch in Python.

---

## Paper Issues

### P1. Remark 3.2's `N₁ = 86` is not the number of 1-dimensional subspaces

- **Location**: Section 3.3, Remark 3.2 — "we got `N₁ = 86`, `N₂ = 340` and `N₃ = 4` for the
  new function".
- **Definition used** (Proposition 3.2): `Nᵢ` is the number of `F₂`-vector subspaces of
  `F₂ⁿ` contained in `S(F)` of dimension `i`.
- **Counter-evidence** (`F` = Table 1 row 1 over `GF(2⁸)`, modulus 285, `ζ = 2`):
  `|S(F)| = 86` and `0 ∈ S(F)` (always, since `W_F(a,0) = 0` for `a ≠ 0`), so the number of
  1-dimensional subspaces `{0,b} ⊆ S(F)` is `|S(F)| − 1 = **85**`, not 86. `N₂ = 340` ✔ and
  `N₃ = 4` ✔ both match. The paper reports `|S(F)|` where its own definition calls for the
  subspace count — an off-by-one that presumably also affects the quoted `N₁ = 86` for
  function 1.9.
- **Severity**: cosmetic. The discriminating invariant is `N₃` (4 vs 8), which is unaffected.
  The reproduction already documents this at `proposition3_2.jl:66-67` and
  `test/test_proposition3_2.jl:5-7`, and handles it correctly.

### P2. Tables 1 and 3 are modulus-sensitive, and the paper never states the modulus

- **Location**: Table 1 (`GF(2⁸)`) and Table 3 (`GF(2⁹)`), where `ζ` is described only as
  "one of its primitive elements".
- **Counter-evidence**: all 12 Table-1 entries are APN under the Conway modulus
  `x⁸+x⁴+x³+x²+1` (285) with `ζ = 2`. Under the AES modulus `x⁸+x⁴+x³+x+1` (283), `ζ = 2`
  has order 51 — not primitive — so the table is meaningless there. Under other primitive
  moduli (e.g. 487, 361, where `ord(2) = 255`) the entries give `du ∈ {2,8,16}`: rows 1.7,
  1.10, 1.12, 1.16 and 1.3 give `du = 8`, rows 1.17 and 3.1 give `du = 16`. The tables hold
  only for a specific `(modulus, ζ)` pair that the publication does not record.
- **Note**: this is a reproducibility gap in the publication, not an error. The reproduction
  pins `MOD8 = conway_polynomial(8) = 285` and `MOD9 = primitive_polynomial(9) = 529`
  (`theorem3_1.jl:18-21`), which is the right call and worth counting as a reproduction
  strength.

---

## Reproduction Issues

### 1. Theorem 3.1's construction (Eq. 3) is never exercised — Tables 1 and 3 are transcribed, not derived

- **Location**: `theorem3_1.jl:25-107`; dead helpers at `helpers.jl:23`
  (`fm_polynomial_lut`) and `helpers.jl:47` (`gen_shift_lut`)
- **Symptom**: `grep -rn 'gen_shift_lut\|fm_polynomial_lut\|nonlinear_gold_shift_lut'
  papers/2021/Budaghyan_202101` shows these functions are **defined but never called** from
  any `.jl` file or test. `table1_build`/`table3_build` construct LUTs from hard-coded
  `ζ`-exponent term lists copied out of the tables and check only
  `differential_uniformity == 2`. Nothing ever chooses `L₁(x) = Σ Aⱼ x^{2^{jm}}`,
  `L₂(x) = Σ Bⱼ x^{2^{jm}}` with coefficients in `F_{2^m}` and computes
  `F(x) = x·L₁(x)^{2^i} + x^{2^i}·L₂(x)`. The paper's actual claim — that these polynomials
  are *derived from Theorem 3.1* (Table 1 caption, Table 3 caption, Sections 3.2 and 3.4) —
  is therefore unverified.
- **Root cause**: the construction pipeline was skipped in favour of re-checking published
  outputs.
- **Resolution plan**:
  1. In `theorem3_1.jl`, for `n=8` (`k=4, m=2`) and `n=9` (`k=m=3`), sweep
     `(A₀..A_{k−1}, B₀..B_{k−1}) ∈ F_{2^m}^{2k}`. For `n=9`, `8¹²` is too large — restrict to
     the paper's subfield-`F_{2³}` coefficients as it states and screen with
     `is_quadratic_apn_rank`.
  2. Build `F` via `gen_shift_lut(n, i, fm_polynomial_lut(...), fm_polynomial_lut(...))` and
     expand to the univariate form
     `(A₀^{2^i}+B₀)x^{2^i+1} + Σⱼ[Aⱼ^{2^i}x^{2^{i+jm}+1} + Bⱼx^{2^{jm}+2^i}]`, which the
     paper gives explicitly.
  3. Assert each Table 1 / Table 3 entry is EA-equivalent (via `apn_ea_mugshot`) to some
     swept instance.
  4. Delete or exercise the dead helpers.

### 2. Theorem 3.1's stated iff-criterion is not implemented

- **Location**: `theorem3_1.jl:109-113` — the report prints
  `"Condition: gcd(i,m)=1; verified via DDT (APN iff du=2)"`.
- **Symptom**: Theorem 3.1's content is three explicit conditions over `v ∈ W`, where `W` is
  the coset representative set built from `d = gcd(2^m−1, (2^{km}−1)/(2^m−1))`, `d′`,
  `U = ⟨ζ^{d′(2^m−1)}⟩` and `W = {ζ^s y : y ∈ U, 0 ≤ s ≤ d′−1}`. None of `d`, `d′`, `U`, `W`
  or the three bullet conditions appear anywhere in the reproduction. Checking `du == 2`
  verifies APN-ness but **not the theorem**.
- **Root cause**: the theorem was reduced to its corollary ("the results are APN").
- **Resolution plan**:
  1. Implement `coset_decomposition(n, k, m)` returning `d, d′, U, W`.
  2. Implement `theorem3_1_condition(n, i, L1, L2)` as the three bullets.
  3. Assert `theorem3_1_condition ⟺ differential_uniformity == 2` exhaustively over the
     `n=6` (`k=3, m=2`) and `n=8` (`k=4, m=2`) coefficient spaces.

### 3. Propositions 3.1, 3.3, 3.4 and Remark 3.5 are entirely missing

- **Location**: no files.
- **Symptom**:
  - **Proposition 3.1** (four necessary kernel conditions (i)–(iv) on `L₁`, `L₂`) — no
    implementation, no test.
  - **Proposition 3.3** (for `n` even or `k > 1`, no isotopic shift `F_L` with
    `L ∈ F_{2^k}[x]` can be APN; in particular quadratic `F` with `n` even and `L ∈ F₂[x]`) —
    no implementation, though it is directly testable at `n = 4, 6, 8`.
  - **Proposition 3.4** (`G_{i,L}` is linear-equivalent to `G_{i,M}` with
    `M(x) = Σ(cⱼζ^{k(j−1)})^{2^t}x^j`) — no implementation.
  - **Remark 3.5** ("for `n` even it seems impossible to obtain APN as isotopic shifts of
    Gold by non-linear monomials; searched `n = 4,6,8,10`") — no implementation; this is a
    cheap exhaustive sweep for `n = 4, 6`.
- **Root cause**: not ported.
- **Resolution plan**: add `proposition3_1.jl`, `proposition3_3.jl`, `proposition3_4.jl` and
  a `remark3_5.jl` sweep at `n ∈ {4,6}` (with `n=8` behind `full_search`).

### 4. Table 2 and the Γ-rank / Δ-rank / `|M_{G_F}|` columns of Tables 2–3 are not reproduced

- **Location**: `theorem3_1.jl` (no Table 2), `report.jl`
- **Symptom**: Table 2 lists 12 previously-known `n=9` APN functions with their Γ-rank,
  Δ-rank and `|M_{G_F}|`; Table 3 gives the same three invariants for all 17 new/derived
  functions. The reproduction verifies **only** `du == 2`. Those three invariants are the
  paper's entire evidence for CCZ-inequivalence, and hence for "fifteen new".
- **Root cause**: `VBF`'s `delta_rank`/`gamma_rank` are documented as supporting `n ≤ 7`
  (`packages/VBF/src/invariants/design_ranks.jl:108`), so `n = 9` is out of reach with core
  as it stands.
- **Resolution plan**:
  1. Add `table2_build()` with LUTs for all 12 entries (`x³, x⁵, x¹⁷, x¹³, x²⁴¹, x¹⁹, x²⁵⁵,
     Tr(x⁹)+x³, Tr₃⁹(x¹⁸+x⁹)+x³, Tr₃⁹(x³⁶+x¹⁸)+x³, x³+x¹⁰+ζ⁴³⁸x¹³⁶,
     ζ³³⁷x¹²⁹+ζ⁴²⁴x⁶⁶+ζ²x¹⁷+ζx¹⁰+ζ³⁴x³`). The last two are confirmed APN under modulus 529.
  2. Substitute the ortho-derivative EA-mugshot (`apn_ea_mugshot`) for the unreachable
     Γ/Δ-ranks — a valid CCZ-invariant for quadratic APN (Yoshiara) and cheap at `n = 9`.
  3. Raise the `delta_rank` `n ≤ 7` guard, or record explicitly in the report why the columns
     are skipped.

### 5. Wrong venue in `report.jl`

- **Location**: `report.jl:21`
- **Symptom**: prints `Venue: IEEE Trans. Inform. Theory (2021)`. The paper is *Designs,
  Codes and Cryptography* **89**(1):19–32, 2021 (`bibliography.bib:914`, key
  `Budaghyan_202101`). IEEE T-IT is the *earlier* companion paper [6], "Constructing APN
  functions through isotopic shifts" (2020).
- **Root cause**: confusion with the companion paper.
- **Resolution plan**: change to `Des. Codes Cryptogr. 89(1):19–32 (2021)`.

### 6. Theorem 3.2 is reproduced for only 3 of 5 families, and only with `a = 1`

- **Location**: `theorem3_2.jl:93-135`, `:154`
- **Symptom**: implemented cases are Gold `(n,i,j) ∈ {(5,2,1),(7,3,2),(9,4,1)}`, Inverse
  `n ∈ {5,7}`, Welch `t` **odd** `(7,3,2),(11,5,3)` and Kasami `t` **odd** `(7,3,2)`.
  Missing: Kasami `t` even, Welch `t` even, and **all Niho** cases — line 154 says
  `"Niho: similar algebraic argument; omitted"`, though the paper gives both the `t` odd and
  `t` even constructions explicitly. Also `a` is fixed to 1, whereas the paper's `L(x) = a·x^d`
  allows any `a ≠ 0`.
- **Root cause**: partial port.
- **Resolution plan**: add the four missing sub-cases (Kasami `t` even with `t=2i`, Welch `t`
  even with `t=2i`, Niho `t` odd `t=2i−1` and `t` even `t=2i`) and parametrise `a`.

### 7. Proposition 2.1 is stated but never verified; Remark 3.1 is only transcribed

- **Location**: `proposition2_1.jl:63-67`; `proposition3_2.jl:70-71`
- **Symptom**: Proposition 2.1 (over `F_{2⁶}`, any quadratic APN is an isotopic shift of any
  other, by a permutation `L` and a 2-to-1 `L′`) is printed as "Computational result from
  [6] … Not independently verified here". `n = 6` is small — 13 quadratic APN classes and
  `|GL(6,F₂)| ≈ 2²⁹` — so a randomized or structured search would give strong evidence.
  Remark 3.1/3.2's comparison function (Edel–Pott no. 1.9, `N₃ = 8`) is taken verbatim from
  the paper (`proposition3_2.jl:71`: `"TODO: not in VBFCatalog; N_3=8 taken from paper"`), so
  the inequivalence conclusion is not independently established.
- **Root cause**: both were treated as citations rather than claims to check.
- **Resolution plan**:
  1. Add a seeded randomized search over linear permutations / 2-to-1 maps `L` for
     Proposition 2.1, with `max_evaluations`.
  2. Add the Edel–Pott 1.9 `n=8` LUT to the reproduction (or the catalog) and compute its
     `N₃` to close Remark 3.2.

### 8. `zeta_poly_lut` silently accepts a non-primitive `ζ`

- **Location**: `helpers.jl:74-90`
- **Symptom**: `zeta::Int = 2` is accepted with an arbitrary `modulus` and no check that
  `ord(ζ) = 2ⁿ−1`. With `primitive_polynomial(8) = 283`, `ord(2) = 51` and every Table 1
  entry silently becomes a different, non-APN function.
- **Root cause**: missing precondition guard.
- **Resolution plan**: add `ord(zeta) == 2^n − 1 || error(...)` at the top of `zeta_poly_lut`.

---

## Items Reproduced Exactly

| Item | Evidence |
|------|----------|
| **Remark 2.1** | `x⁵` over `GF(2⁶)` (mod 67, `ord(2)=63`) has `du = 4` (not APN) ✔; with `L(x)=ζx⁸`, `F_L = F(x+L)+F(x)+F(L)` equals `ζx¹² + ζ⁴x³³` **exactly** ✔ and has `du = 2` ✔ |
| **Table 1** — all 12 `n=8` entries | All `du = 2` under Conway modulus 285 with `ζ = 2` (`ord(2)=255`) |
| **Table 3** — all 17 `n=9` entries | All `du = 2` under modulus 529 with `ζ = 2` (`ord(2)=511`); 15 labelled "new" + 1 "eq. to [6]" + 1 "eq. to 8.1", matching the paper's "fifteen new APN functions" |
| **Remark 3.2** `N₂`, `N₃` | `N₂ = 340`, `N₃ = 4` for Table 1 row 1 (`N₁ = 85` vs the paper's 86 — see P1) |
| **Theorem 3.2** — 8 implemented cases | All `G_{i,L}` are APN (`du=2`), one exponent is a power of 2 (linear) and the other is Frobenius-equivalent to the target: Gold `(5,2,1)` `e_nl=17→3`; `(7,3,2)` `66→5`; `(9,4,1)` `257→3`; Inverse `n=5` `29→30`, `n=7` `125→126`; Welch `(7,3,2)` `49→11`, `(11,5,3)` `193→35`; Kasami `(7,3,2)` `101→57` |
| **Proposition 3.2 / `S(F)`** | `s_of_f` correctly reproduces `S(F) = {b : ∃a, W_F(a,b)=0}`; `|S(F)| = 86` including 0 |
| Table 3 labels "eq. to [6]" and "eq. to 8.1" | Ortho-derivative EA-invariants confirm row 1 ≡ Table 2's `ζ³³⁷x¹²⁹+ζ⁴²⁴x⁶⁶+ζ²x¹⁷+ζx¹⁰+ζ³⁴x³` and row 12 ≡ Table 2's `x³+x¹⁰+ζ⁴³⁸x¹³⁶` (8.1) |

## Test Results

| Command | Result |
|---------|--------|
| `make -C papers/2021/Budaghyan_202101 test` | **Not run** — `julia` is not installed in the review environment |
| Independent check of `test_proposition2_1` assertions (`du_F==4`, closed form, `du_FL==2`) | **All pass** |
| Independent check of `test_theorem3_1` assertions (all 12 + all 17 entries APN) | **All pass** |
| Independent check of `test_proposition3_2` assertions (`N1==85`, `N2==340`, `N3==4`, `S_size==86`) | **All pass** |
| Independent check of `test_theorem3_2` assertions (8 cases: `apn_G`, `ea_ok`) | **All pass** |

## Catalog Status

The paper claims **15 new APN functions over `F_{2⁹}`** (Table 3). Each was verified APN and
fingerprinted by its ortho-derivative differential spectrum plus ortho-derivative Walsh
spectrum — valid as a CCZ separator because for quadratic APN, CCZ = EA (Yoshiara 2012).

All 15 have **pairwise distinct** fingerprints, distinct from each other and from **every**
entry of `packages/VBFCatalog/data-raw/apn_catalog/n9_apn.toml` (`n9_Gold_x3`, `n9_Gold_x5`,
`n9_Gold_x17`, `n9_Kasami_x13`, `n9_Kasami_x241`, `n9_Welch_Niho_x19`, `n9_Inverse_x510`,
`n9_Budaghyan2009_eq7`, `n9_Budaghyan2009_eq8`), and distinct from Table 2's `8.1` and `[6]`
functions. (`n9_Kasami_x13/x241`, `n9_Welch_Niho_x19` and `n9_Inverse_x510` are non-quadratic
and cannot be CCZ-equivalent to a quadratic APN unless EA-equivalent to a Gold function,
which the fingerprints exclude.) This also independently corroborates the Table 3 rows that
share Γ/Δ-rank pairs (rows 2&7, 5&6, 8&10, 9&13, 15&17) — the finer invariant separates all
of them.

**Per-function verdict: `missing` (genuine catalog gap) for all 15.**

### Catalog-gap records

- **Target file**: `packages/VBFCatalog/data-raw/apn_catalog/n9_apn.toml`
- **Common fields**: `n = 9`, `m = 9`, `is_permutation = false` (verified for all 17 rows),
  `modulus = 529` (`x⁹+x⁴+1`), `bib_key = "Budaghyan_202101"`,
  `source = "Budaghyan, Calderini, Carlet, Coulter, Villa, 'Generalized Isotopic Shift
  Construction for APN Functions', Des. Codes Cryptogr. 89(1):19–32 (2021), Table 3."`
- **`ζ` convention**: `ζ = 2` (the class of `x`), primitive since `ord(2) = 511` under
  modulus 529.
- **Equivalence evidence**: ortho-derivative differential + Walsh spectra pairwise distinct
  across all 15 and against all 9 existing `n9` catalog entries;
  `differential_uniformity == 2` verified for each.

| proposed `name` | Table 3 row | `algebraic_form` (modulus `x⁹+x⁴+1`, `ζ` = class of `x`) |
|---|---|---|
| `n9_Budaghyan2021_tab3_r02` | 2 (i=1) | `ζ²¹⁹x¹²⁹ + ζ²⁹²x⁶⁶ + ζ²⁹²x¹⁷ + ζ²¹⁹x¹⁰ + x³` |
| `n9_Budaghyan2021_tab3_r03` | 3 (i=1) | `ζ³⁶⁵x¹²⁹ + ζ²⁹²x⁶⁶ + ζ³⁶⁵x¹⁷ + ζ⁷³x¹⁰ + x³` |
| `n9_Budaghyan2021_tab3_r04` | 4 (i=1) | `ζ³⁶⁵x¹²⁹ + ζ³⁶⁵x⁶⁶ + ζ¹⁴⁶x¹⁷ + ζ³⁶⁵x¹⁰ + x³` |
| `n9_Budaghyan2021_tab3_r05` | 5 (i=1) | `ζ³⁶⁵x¹²⁹ + ζ²¹⁹x⁶⁶ + ζ²⁹²x¹⁷ + ζ⁷³x¹⁰ + x³` |
| `n9_Budaghyan2021_tab3_r06` | 6 (i=1) | `ζ⁷³x¹²⁹ + ζ³⁶⁵x⁶⁶ + ζ⁷³x¹⁷ + ζ⁷³x¹⁰ + x³` |
| `n9_Budaghyan2021_tab3_r07` | 7 (i=1) | `ζ³⁶⁵x¹²⁹ + ζ⁴³⁸x⁶⁶ + ζ²⁹²x¹⁰ + x³` |
| `n9_Budaghyan2021_tab3_r08` | 8 (i=1) | `ζ³⁶⁵x¹²⁹ + x⁶⁶ + ζ⁴³⁸x¹⁰ + x³` |
| `n9_Budaghyan2021_tab3_r09` | 9 (i=1) | `ζ⁷³x¹²⁹ + ζ²⁹²x⁶⁶ + x¹⁰ + x³` |
| `n9_Budaghyan2021_tab3_r10` | 10 (i=1) | `ζ⁷³x¹²⁹ + x⁶⁶ + ζ²¹⁹x¹⁷ + x³` |
| `n9_Budaghyan2021_tab3_r11` | 11 (i=2) | `ζ¹⁴⁶x²⁵⁷ + ζ⁴³⁸x⁶⁸ + ζ⁴³⁸x¹² + x⁵` |
| `n9_Budaghyan2021_tab3_r13` | 13 (i=2) | `ζ⁷³x²⁵⁷ + ζ¹⁴⁶x⁶⁸ + x³³ + x⁵` |
| `n9_Budaghyan2021_tab3_r14` | 14 (i=2) | `ζ³⁶⁵x²⁵⁷ + ζ⁴³⁸x⁶⁸ + ζ³⁶⁵x³³ + ζ⁴³⁸x¹² + x⁵` |
| `n9_Budaghyan2021_tab3_r15` | 15 (i=2) | `ζ¹⁴⁶x²⁵⁷ + ζ²¹⁹x⁶⁸ + ζ⁷³x³³ + x¹² + x⁵` |
| `n9_Budaghyan2021_tab3_r16` | 16 (i=2) | `ζ⁷³x²⁵⁷ + ζ²¹⁹x⁶⁸ + ζ³⁶⁵x³³ + x⁵` |
| `n9_Budaghyan2021_tab3_r17` | 17 (i=4) | `ζ²⁹²x³ + ζ¹⁴⁶x⁸⁰ + ζ⁷³x²⁴ + x¹⁷` |

**Secondary gaps** (not claimed new by this paper, but absent and notable):

- Table 2's `8.1` (`x³ + x¹⁰ + ζ⁴³⁸x¹³⁶`, the previously-unclassified `n=9` example) —
  **missing** from `n9_apn.toml`; APN verified (`du=2`, modulus 529), fingerprint distinct
  from all existing entries. Proposed `n9_EdelPott_8_1`.
- Table 2's `[6]` function `ζ³³⁷x¹²⁹+ζ⁴²⁴x⁶⁶+ζ²x¹⁷+ζx¹⁰+ζ³⁴x³` — **missing**; APN verified;
  fingerprint distinct. Proposed `n9_Budaghyan2020_isoshift`.
- Table 2's `1.2` = `Tr₁⁹(x⁹) + x³` — **missing** (`n9_apn.toml` has `eq7`/`eq8`, which are
  Table 2's 1.4 and 1.3, but not 1.2).

**Cross-paper observation**: Table 1's `n=8` row 1.3
(`ζ¹⁵³x¹²⁹+ζ²²¹x⁷²+ζ¹⁷⁰x³³+ζ¹⁰²x²⁴+x¹²+x⁹+ζ¹³⁶x³`) has the **same ortho-derivative
fingerprint** as the existing catalog entry `n8_Taniguchi2025_ex4_2`. If `n=8` Table 1
entries are ever added, 1.3 must be flagged **not-new / duplicate**. The other 11 Table-1
entries have fingerprints distinct from every `n8_apn.toml` entry.

## Library-Reuse Note

| Helper (`helpers.jl:line`) | VBF symbol to call | Verdict |
|---|---|---|
| `zeta_poly_lut` (:74) | `terms_to_lut(terms, n, modulus)` with `coef = gf_pow(zeta, k, n; modulus)` | **duplicate** — the body is `terms_to_lut` plus `ζ`-exponent decoding; keep only the decoding layer |
| `fm_polynomial_lut` (:23) | `terms_to_lut` with exponents `2^{jm}` | **duplicate**, and dead code |
| `gen_shift_lut` (:47) | — | paper-specific (Eq. 3), but dead code |
| `nonlinear_gold_shift_lut` (:121) | — | paper-specific (Eq. 4), but dead code; `theorem3_2.jl:67-69` re-implements it inline instead of calling it |
| `isotopic_shift_lut` (:97) | — | legitimately paper-specific (Eq. 1) |
| `s_of_f` (:108) | correctly wraps `walsh_zeroes` | fine |
| `paper_banner` (:135) | correctly wraps `print_banner` | fine |

Promote-to-core candidates:

- `isotopic_shift(F_lut, L_lut)` — `F_L(x) = F(x+L(x)) + F(x) + F(L(x))` is a general
  construction used by at least three papers in this repo (Budaghyan_202101,
  Calderini_202100 §3, and the 2020 T-IT companion); belongs in
  `packages/VBF/src/constructions/`.
- Raise `delta_rank`/`gamma_rank` beyond `n ≤ 7` (or add a documented `n ≤ 9` path) so
  Tables 2 and 3's invariants become reproducible.
- An `is_primitive_element(ζ, n; modulus)` guard in
  `packages/VBF/src/representations/finite_field.jl` would prevent issue-8-class bugs across
  all `ζ`-exponent papers.
