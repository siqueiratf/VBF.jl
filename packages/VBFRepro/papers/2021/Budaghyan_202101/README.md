# Budaghyan_202101 — Generalized Isotopic Shift Construction for APN Functions

**Paper**: Budaghyan, Calderini, Carlet, Coulter, Villa. "Generalized isotopic shift
construction for APN functions." *Designs, Codes and Cryptography* **89**(1):19-32, 2021.

**Reproduction path**: `packages/VBFRepro/papers/2021/Budaghyan_202101/`

**Verdict**: Partial

Everything the reproduction transcribes is correct: all 12 polynomials of Table 1 and all
17 of Table 3 are term-for-term faithful and independently confirmed APN of algebraic
degree 2, and pinning the field moduli (285 for n=8, 529 for n=9) is a genuine
reproducibility improvement over the paper. What is missing is the *derivation*: Theorem
3.1 — the paper's central result — is never built, its three helper functions are dead
code, and the entire novelty apparatus (Γ-rank, Δ-rank, `|M_{G_F}|`, Table 2) is absent, so
the reproduction verifies "APN" but never "new". Propositions 3.1, 3.3, 3.4 and Remarks
3.1, 3.5 are not reproduced at all.

> All numeric claims below were re-derived in the repository's own Julia API on 2026-08-15;
> the earlier independent Python derivation agreed on every value, including all 15 SHA-256
> LUT fingerprints bit-for-bit.

---

## Paper Issues

### 1. Remark 3.2's `N₁ = 86` is not the number of 1-dimensional subspaces

- **Location**: Section 3.3, Remark 3.2, read against Proposition 3.2's own definition
  ("`Nᵢ` = number of `F₂`-vector subspaces of `F_{2ⁿ}` contained in `S(F)` of dimension
  `i`").
- **Computed counter-evidence** (Table-1 row 1, modulus 285, `ζ = 2`): `|S(F)| = 86`, and
  `0 ∈ S(F)` always, since `W_F(a,0) = 0` for `a ≠ 0`. So the number of 1-dimensional
  subspaces `{0,b} ⊆ S(F)` is **85**, not 86. `N₂ = 340` ✔ and `N₃ = 4` ✔ both match. The
  paper reports `|S(F)|` where its own definition calls for the subspace count.
- **Severity**: cosmetic — the discriminating invariant in Remark 3.2 is `N₃` (4 versus 8).

### 2. Tables 1 and 3 are modulus-sensitive and the modulus is never stated

- **Location**: Tables 1 and 3; `ζ` is described only as "one of its primitive elements".
- **Computed counter-evidence**: enumerating all 16 degree-8 irreducible moduli for which
  `ζ = 2` has order 255, **only 8 of 16** make all 12 Table-1 entries APN (285, 301, 355,
  357, 391, 425, 463, 501). The other 8 (299, 333, 351, 361, 369, 397, 451, 487) give
  `du ∈ {2, 8, 16}`. Under the AES modulus 283, `ord(2) = 51` and the table is meaningless.
- **Severity**: a reproducibility gap in the publication, not a mathematical error. The
  repository pinning `MOD8 = conway_polynomial(8) = 285` and `MOD9 = 529`
  (`theorem3_1.jl:18-21`) is the correct call and should be counted as a reproduction
  strength.

---

## Reproduction Issues

### 1. Theorem 3.1 — the paper's central theorem — is neither built nor tested

- **Location**: `theorem3_1.jl:109-135`; helpers `helpers.jl:23` (`fm_polynomial_lut`),
  `helpers.jl:47` (`gen_shift_lut`), `helpers.jl:121` (`nonlinear_gold_shift_lut`).
- **Symptom**: `theorem3_1_report` prints
  `Condition: gcd(i,m)=1; verified via DDT (APN iff du=2)` (`theorem3_1.jl:113`) and then
  only checks `differential_uniformity == 2` on transcribed ζ-polynomials. The theorem's
  actual content — the `d`, `d′`, `U`, `W` coset construction of Section 3.1 and the three
  `∀v ∈ W` conditions — is nowhere implemented. Worse, `fm_polynomial_lut`, `gen_shift_lut`
  and `nonlinear_gold_shift_lut` are **dead code**: `grep` shows they are defined and never
  called anywhere in the paper directory. So `F(x) = x·L₁(x)^{2^i} + x^{2^i}·L₂(x)` is never
  evaluated, and the tables are transcribed rather than derived.
- **Root cause**: only the tables' output was ported; the construction was left unwired.
- **Evidence that this is closable cheaply** (both checks performed during this review):
  - Table-3 row 2 was reconstructed exactly from Eq. (3) with
    `L₁ = ζ¹⁴⁶x⁸ + ζ³⁶⁵x⁶⁴` and `L₂ = x + ζ²¹⁹x⁸ + ζ²⁹²x⁶⁴` (all coefficients in
    `F_{2³} = ⟨ζ⁷³⟩`), `i = 1` — it reproduces the LUT **pointwise**. All Table-1
    coefficients are multiples of 17 (`F_{2⁴}`) and all Table-3 coefficients are multiples
    of 73 (`F_{2³}`), matching Sections 3.2 and 3.4.
  - The three `W`-conditions were implemented for `n = 9, k = m = 3, i = 1`
    (`d = gcd(7,73) = 1`, `d′ = 1`, `W = U = ⟨ζ⁷⟩` of order 73) and run on 61 `(L₁,L₂)`
    tuples with subfield coefficients: **0 mismatches** against the DDT test (4 APN). Cost
    is `73² = 5329` field operations per candidate.
- **Resolution plan**:
  1. Implement `W` and `d′` per Section 3.1.
  2. Implement `theorem3_1_condition(n, k, m, i, A, B)` with the three bullets.
  3. Use `gen_shift_lut(n, i, fm_polynomial_lut(...), fm_polynomial_lut(...))` to *derive*
     Tables 1 and 3, and assert LUT equality against the transcribed ζ-polynomials.
  4. Assert `condition ⟺ du == 2` over a sweep of subfield `(L₁, L₂)`.

### 2. The Γ-rank / Δ-rank / `|M_{G_F}|` columns — the paper's entire novelty evidence — are absent

- **Location**: `theorem3_1.jl:98-107` (`table3_build` returns only `du`/`apn`); no Table-2
  file exists.
- **Symptom**: Table 3's "new" verdicts rest on CCZ-invariants (Γ-rank, Δ-rank,
  `|M_{G_F}|`) and on MAGMA code equivalence. None of the three is computed, and Table 2
  (the 12 previously known n=9 APN functions with their invariants) is not reproduced at
  all. The reproduction therefore verifies "APN" but never "new".
- **Root cause**: Γ- and Δ-rank require F₂ ranks of `2¹⁸ × 2¹⁸` matrices at n=9.
- **Resolution plan**:
  1. Add Table 2 as data (all 12 functions; cheap and independently useful).
  2. Substitute the ortho-derivative CCZ-invariants (`apn_ea_mugshot`, or the
     ortho-derivative differential and Walsh spectra) as the in-repo novelty evidence — this
     review verified they separate all 17 Table-3 rows and correctly match rows 1 and 12 to
     their claimed counterparts.
  3. Document Γ-/Δ-rank as unverifiable in-repo, with the reason.

### 3. The `N₁` mismatch is papered over instead of asserted

- **Location**: `proposition3_2.jl:66-67` prints `N_1 in {85,86} (convention differs by 1)`.
- **Symptom**: the report's check is `r.N1 in (85,86)` — an assertion that cannot fail
  either way. (`test/test_proposition3_2.jl:8` does correctly assert `== 85`, so report and
  test disagree on strictness.)
- **Root cause**: the paper-versus-definition discrepancy (paper issue 1) was absorbed into
  a permissive check rather than recorded.
- **Resolution plan**:
  1. Make the report assert `N₁ == 85`.
  2. Print the paper's `86` as `|S(F)|` on a separate line, with the paper-issue-1
     explanation.

### 4. Remark 3.2's second half (function 1.9 with `N₃ = 8`) is not computed

- **Location**: `proposition3_2.jl:70-72` — `fn 1.9 status: TODO: not in VBFCatalog`.
- **Symptom**: the whole point of Remark 3.2 is `N₃ = 4 ≠ 8 = N₃(1.9)`. Only one side is
  computed; the other is quoted from the paper. `n8_apn.toml` indeed has no Edel–Pott
  Table-9 entries.
- **Root cause**: the comparison function was never brought into the repository.
- **Resolution plan**:
  1. Transcribe Edel–Pott function 1.9 from [16, Table 9] into the paper directory (or the
     catalog) and compute `N₃` in-repo.
  2. Failing that, state explicitly that the inequivalence claim is un-reproduced.

### 5. Theorem 3.2 covers 4 of 5 proof cases; the Niho case is missing

- **Location**: `theorem3_2.jl:93-135`; `theorem3_2.jl:154` states
  `Niho: similar algebraic argument; omitted (large exponent computation)`.
- **Symptom**: `theorem3_2_cases()` covers case 5 (Gold, 3 parameters), case 2 (Inverse,
  n=5,7), case 3 (Welch, **t odd only**) and case 1 (Kasami, **t odd only**, a single n=7
  instance). Case 4 (Niho) is absent entirely, as are the `t`-even branches of cases 1
  and 3.
- **Root cause**: assumed cost; the assumption is wrong.
- **Counter-evidence**: the missing branches were run during this review and all pass
  instantly —
  - Niho `t` odd (`n=7, t=3, i=2, L = a·x^{2⁷−2²}`): `du = 2`, `e_nl = 116`,
    Frobenius-equivalent to the Niho exponent 39 ✔
  - Niho `t` even (`n=9, t=4, i=2, L = a·x^{2⁷+2⁸}`): `du = 2`, `e_nl = 388`,
    Frobenius-equivalent to 19 ✔
  - Kasami `t` even (`n=9, t=2, i=1, L = a·x⁶`): `du = 2`, `e_nl = 13 = target` ✔
- **Resolution plan**:
  1. Add the three missing branches with exactly these parameters.
  2. Drop the "omitted (large exponent computation)" note.

### 6. Propositions 3.1, 3.3, 3.4, Remarks 3.1 and 3.5, and Table 4 are entirely absent

- **Location**: no files.
- **Symptom**: missing are Proposition 3.1 (necessary kernel conditions (i)-(iv) on `L₁`,
  `L₂`), Proposition 3.3 (an isotopic shift by `L ∈ F_{2^k}[x]` is never APN for `n` even
  or `k > 1`), Proposition 3.4 (`G_{i,L} ~lin G_{i,M}` for
  `M(x) = Σ(c_j ζ^{k(j−1)})^{2^t} x^j`), Remark 3.1 (the Γ-rank = 14034 correction to [19]),
  Remark 3.5 (no APN monomial shifts for even `n = 4,6,8,10`), Problems 3.1/3.2, and
  Table 4 (known APN power functions — largely covered by core's `gold_apn`, `kasami_apn`,
  `welch_apn`, `niho_apn`, `inverse_apn`, `dobbertin_apn`).
- **Root cause**: not ported.
- **Resolution plan**: Proposition 3.1 (four kernel intersections) and Proposition 3.4 (a
  one-line linear-equivalence check) are cheap — add `proposition3_1.jl` and
  `proposition3_4.jl` first. Remark 3.5 is a bounded sweep at `n ∈ {4,6,8,10}` and directly
  exercises the already-dead `nonlinear_gold_shift_lut`.

### 7. Proposition 2.1 is stated but never verified; `report.jl` cites the wrong venue

- **Location**: `proposition2_1.jl:63-67`; `report.jl:21`.
- **Symptom**: Proposition 2.1 ("over `F_{2⁶}` any quadratic APN is an isotopic shift of any
  other") is printed as a claim with `Status: Computational result from [6]` — nothing is
  computed. Separately, `report.jl:21` prints
  `Venue: IEEE Trans. Inform. Theory (2021)`; this paper is *Designs, Codes and
  Cryptography* **89**(1):19-32, 2021. The IEEE T-IT paper is reference [6], the *previous*
  isotopic-shift paper.
- **Root cause**: a claim carried over as prose, plus a copy-paste of the wrong citation.
- **Resolution plan**:
  1. Fix the venue string.
  2. Sweeping all `2^{6·6}` linear maps is infeasible, but for a *single* fixed pair of
     quadratic APN `F`, `G` at `n = 6`, sweeping `L` over a structured or random subset
     until `F_L ~EA G` is a meaningful bounded check. Add that, or declare Proposition 2.1
     explicitly out of scope rather than leaving it as a bare claim.

### 8. Minor: wrong entry count in a comment; missing parameter guards; inlined duplicate

- `theorem3_1.jl:12` says `Table 3 (n=9, k=m=3): 16 APN polynomials`. The paper's Table 3
  and `TABLE3_ENTRIES` both have **17** rows.
- `zeta_poly_lut`, `gen_shift_lut` and `fm_polynomial_lut` enforce no parameter constraints
  (`n = km`, `m > 1`, `gcd(i,m) = 1`); `gen_shift_lut(9, 3, ...)` with `gcd(3,3) = 3` is
  accepted silently.
- `theorem3_2.jl:66-70` re-implements the `G_{i,L}` LUT inline instead of calling
  `nonlinear_gold_shift_lut` from `helpers.jl:121`.

---

## Items Reproduced Exactly

| Item | Evidence |
|------|----------|
| Table 1 (12 polynomials over `F_{2⁸}`) | All 12 transcribed **term-for-term correctly**; all 12 have `du = 2`, `deg = 2` under modulus 285 with `ζ = 2` (order 255) |
| Table 3 (17 polynomials over `F_{2⁹}`) | All 17 transcribed **term-for-term correctly**; all 17 have `du = 2`, `deg = 2` under modulus 529 with `ζ = 2` (order 511); the `new` count is 15, matching the abstract |
| Remark 2.1 | `x⁵` over `GF(2⁶)` has `du = 4`; `F_L` with `L(x) = ζx⁸` equals `ζx¹² + ζ⁴x³³` pointwise and has `du = 2`. The paper's `F_L = M(x³)` with `M(x) = ζx⁴ + ζ⁴x³²` was additionally verified, along with `M` being a linear permutation — the reproduction does *not* check this second half |
| Remark 3.2, `N₂` and `N₃` | `|S(F)| = 86`, `N₂ = 340`, `N₃ = 4` for Table-1 row 1 — matches the paper exactly |
| Theorem 3.2, cases 1/2/3/5 | All 8 repository cases verified: `G_{i,L}` is APN and reduces to the target power exponent up to Frobenius after removing the linear term |
| Table 3 row 1 ("eq. to APN in [6]") | Ortho-derivative differential spectrum is **identical** to the [6] function `ζ³³⁷x¹²⁹ + ζ⁴²⁴x⁶⁶ + ζ²x¹⁷ + ζx¹⁰ + ζ³⁴x³` from Table 2 |
| Table 3 row 12 ("eq. to 8.1") | Ortho-derivative spectrum **identical** to `x³ + x¹⁰ + ζ⁴³⁸x¹³⁶` (function 8.1 of Table 11 in [16]) |
| All 17 Table-3 rows pairwise distinct | 17 distinct ortho-derivative differential spectra ⇒ pairwise CCZ-inequivalent (quadratic APN ⇒ CCZ = EA, by Yoshiara) |

## Test Results

Reviewed 2026-08-15 on Julia 1.12.6, repository commit `bf15e59`, project fully instantiated.

**Command**: `make -C packages/VBFRepro/papers/2021/Budaghyan_202101 test`
**Exit code**: `0`
**Wall time**: 4 s (includes `Pkg.instantiate()`)

| Testset | Pass | Broken | Fail | Total | Time |
|---|---|---|---|---|---|
| `proposition2_1_test` | 3 | 0 | 0 | 3 | 0.3 s |
| `theorem3_1_test`     | 8 | 0 | 0 | 8 | 0.9 s |
| `proposition3_2_test` | 4 | 0 | 0 | 4 | 0.5 s |
| `theorem3_2_test`     | 17 | 0 | 0 | 17 | 0.4 s |
| **Total**             | **32** | **0** | **0** | **32** | **2.1 s** |

`test/runtests.jl` emits four independent top-level `@testset` summaries and no aggregate
roll-up, so the 32/32 total above is a sum of the four printed summaries, not a line the
runner prints.

| Additional in-repo verification (2026-08-15) | Result |
|---|---|
| Tables 1 & 3 `du`/`deg`, Remark 2.1 incl. the `M(x³)` decomposition, Remark 3.2 `Nᵢ`, all 8 Theorem-3.2 cases plus the 4 missing branches, Eq. (3) reconstruction of Table-3 row 2 via `gen_shift_lut`/`fm_polynomial_lut`, Remark 3.5 exhaustive at `n = 4, 6`, catalog separation of all 17 Table-3 rows | **All agree with the earlier Python derivation; 0 mismatches** |
| Theorem 3.1's three `W`-conditions on 61 `(L₁,L₂)` samples | **Not re-checkable in-repo** — no `W`/`d′` implementation exists (see reproduction issue 1) |

## Catalog Status

The paper claims **15 new APN functions over `F_{2⁹}`**.

- Table 3 row 1 ("eq. to APN in [6]"): **not-new** by the paper's own admission; also absent
  from the catalog.
- Table 3 row 12 ("eq. to 8.1"): **not-new**; also absent from the catalog.
- The 15 rows marked `new`: **missing**. The n=9 catalog
  (`packages/VBFCatalog/data-raw/apn_catalog/n9_apn.toml`, 9 entries) contains only Gold
  `x³/x⁵/x¹⁷`, Kasami `x¹³/x²⁴¹`, Welch/Niho `x¹⁹`, Inverse `x⁵¹⁰`, and
  `n9_Budaghyan2009_eq7`/`n9_Budaghyan2009_eq8`.

**Equivalence evidence for the 15**: each has a distinct ortho-derivative differential
spectrum, distinct from every quadratic catalog entry (`n9_Gold_x3`, `n9_Gold_x5`,
`n9_Gold_x17`, `n9_Budaghyan2009_eq7`, `n9_Budaghyan2009_eq8`) and from the `8.1` and `[6]`
functions; the non-quadratic catalog entries are excluded by algebraic degree (all 15 have
`deg = 2`).

### Catalog-gap records (15 entries)

Common fields for all 15:

```
n                 = 9
m                 = 9
is_permutation    = false            # verified: none is bijective
bib_key           = "Budaghyan_202101"
source            = "Budaghyan, Calderini, Carlet, Coulter, Villa, 'Generalized isotopic
                     shift construction for APN functions', Des. Codes Cryptogr.
                     89(1):19-32 (2021), Table 3 (row <k>), marked 'new'. Instance of
                     Theorem 3.1: F(x) = x*L1(x)^{2^i} + x^{2^i}*L2(x) with L1, L2
                     F_{2^3}-polynomials. LUT = terms_to_lut over GF(2^9) with modulus
                     x^9+x^4+1 (=529) and zeta = 2 (ord 511). Re-verified:
                     differential_uniformity = 2, algebraic_degree = 2."
target file       = packages/VBFCatalog/data-raw/apn_catalog/n9_apn.toml
```

Per-entry. `name` follows the existing `n<N>_<Author><Year>_<tag>` convention;
`algebraic_form` is the paper's exact polynomial; `lut` is the deterministic 512-entry
output of `zeta_poly_lut(9, terms; modulus = 529, zeta = 2)`, pinned here by its first six
values and by a SHA-256 prefix of the comma-joined LUT so the updater can verify.

| name | Table-3 row, `i` | `algebraic_form` (ζ = generator, modulus 529) | lut[0:6] | sha256-16 |
|------|------------------|----------------------------------------------|----------|-----------|
| `n9_Budaghyan2021_t3r2`  | 2, i=1  | `ζ^219 x^129 + ζ^292 x^66 + ζ^292 x^17 + ζ^219 x^10 + x^3` | 0,1,107,3,427,302 | `f0598ddca9b00d50` |
| `n9_Budaghyan2021_t3r3`  | 3, i=1  | `ζ^365 x^129 + ζ^292 x^66 + ζ^365 x^17 + ζ^73 x^10 + x^3` | 0,333,43,177,39,334 | `88ba82d0e4dec07d` |
| `n9_Budaghyan2021_t3r4`  | 4, i=1  | `ζ^365 x^129 + ζ^365 x^66 + ζ^146 x^17 + ζ^365 x^10 + x^3` | 0,336,266,486,28,392 | `2d1811514639364b` |
| `n9_Budaghyan2021_t3r5`  | 5, i=1  | `ζ^365 x^129 + ζ^219 x^66 + ζ^292 x^17 + ζ^73 x^10 + x^3` | 0,1,485,250,441,50 | `ea2448f53875fd05` |
| `n9_Budaghyan2021_t3r6`  | 6, i=1  | `ζ^73 x^129 + ζ^365 x^66 + ζ^73 x^17 + ζ^73 x^10 + x^3` | 0,332,495,356,165,378 | `3a64a9864928f486` |
| `n9_Budaghyan2021_t3r7`  | 7, i=1  | `ζ^365 x^129 + ζ^438 x^66 + ζ^292 x^10 + x^3` | 0,333,252,153,44,473 | `341368fed4578da9` |
| `n9_Budaghyan2021_t3r8`  | 8, i=1  | `ζ^365 x^129 + x^66 + ζ^438 x^10 + x^3` | 0,336,36,30,443,381 | `1c828404c73ae277` |
| `n9_Budaghyan2021_t3r9`  | 9, i=1  | `ζ^73 x^129 + ζ^292 x^66 + x^10 + x^3` | 0,332,239,87,498,148 | `dd0fe81c4ae07492` |
| `n9_Budaghyan2021_t3r10` | 10, i=1 | `ζ^73 x^129 + x^66 + ζ^219 x^17 + x^3` | 0,1,174,10,22,133 | `982e689b1792be0c` |
| `n9_Budaghyan2021_t3r11` | 11, i=2 | `ζ^146 x^257 + ζ^438 x^68 + ζ^438 x^12 + x^5` | 0,333,323,468,21,385 | `1c3331abaee060c7` |
| `n9_Budaghyan2021_t3r13` | 13, i=2 | `ζ^73 x^257 + ζ^146 x^68 + x^33 + x^5` | 0,28,490,158,342,429 | `b4749ff414384e1c` |
| `n9_Budaghyan2021_t3r14` | 14, i=2 | `ζ^365 x^257 + ζ^438 x^68 + ζ^365 x^33 + ζ^438 x^12 + x^5` | 0,1,508,505,189,349 | `ad7aa6362aba33c7` |
| `n9_Budaghyan2021_t3r15` | 15, i=2 | `ζ^146 x^257 + ζ^219 x^68 + ζ^73 x^33 + x^12 + x^5` | 0,333,284,318,312,449 | `e3f0d199026a5c08` |
| `n9_Budaghyan2021_t3r16` | 16, i=2 | `ζ^73 x^257 + ζ^219 x^68 + ζ^365 x^33 + x^5` | 0,29,27,261,495,453 | `9e928e96205bff32` |
| `n9_Budaghyan2021_t3r17` | 17, i=4 | `ζ^292 x^3 + ζ^146 x^80 + ζ^73 x^24 + x^17` | 0,1,506,375,241,205 | `c73b3da593f5389d` |

### Cross-paper catalog observation (read-only)

Table-1 row 12 of this paper (Edel–Pott function **1.3**,
`ζ¹⁵³x¹²⁹ + ζ²²¹x⁷² + ζ¹⁷⁰x³³ + ζ¹⁰²x²⁴ + x¹² + x⁹ + ζ¹³⁶x³` over modulus 285) has
**identical** extended Walsh spectrum `{0:16320, 16:43520, 32:5440}`, ortho-derivative
differential spectrum `{0:38592, 2:21426, 4:4590, 6:654, 8:18}`, ortho-derivative Walsh
spectrum and `|S(F)| = 86` to the catalog entry `n8_Taniguchi2025_ex4_2`. This is strong —
not conclusive — evidence that the Taniguchi 2025 Example 4.2 function is EA-equivalent to
Edel–Pott 1.3. Worth settling with the repository's `are_ccz_equivalent`.

## Library-Reuse Note

| Helper (`helpers.jl:line`) | VBF symbol to call | Verdict |
|---|---|---|
| `zeta_poly_lut` (:74) | `terms_to_lut(terms, n, modulus)` | **duplicate of the evaluation loop** — the ζ-exponent decoding is paper-specific, but the body should be `terms_to_lut([(gf_pow(2, ce, n; modulus), pw) for ...], n, modulus)` |
| `fm_polynomial_lut` (:23) | `terms_to_lut` with terms `[(A_j, 2^{jm})]` | **duplicate** *and* dead code |
| `gen_shift_lut` (:47), `nonlinear_gold_shift_lut` (:121) | — | paper-specific, but **dead code** (never called) |
| `isotopic_shift_lut` (:97) | — | paper-specific ✔ — **promote-to-core candidate**: the isotopic shift `F_L(x) = F(x+L(x)) + F(x) + F(L(x))` is the shared primitive of `Budaghyan_202000`, `Budaghyan_202101` and `Calderini_202100`'s family F11 |
| `s_of_f` (:108) | — | a thin, correct wrapper over `walsh_zeroes` (the `(a<<N)|b` packing was verified against `lat`) ✔ |

Good reuse elsewhere: `gf_mul`, `gf_pow`, `primitive_polynomial`, `conway_polynomial`,
`gf_monomial_lut`, `walsh_zeroes`, `subspace_count_signature`, `differential_uniformity`,
`SBox`, and the `print_*` family.

## Open Questions

- Is `packages/VBFCatalog` the right home for Edel–Pott's n=8 Table-9 functions (needed for
  reproduction issue 4)? If so, 11 more of this paper's Table-1 entries become candidate
  additions.
