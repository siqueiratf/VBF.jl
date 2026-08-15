# Ichanska_202400 — Pushing the QAM Method for Finding APN Functions Further

**Paper**: Ichanska, Berg, Kaleyski, Yu. "Pushing the QAM method for finding APN functions
further." 2024.

**Reproduction path**: `papers/2024/Ichanska_202400/`

**Verdict**: Partial

Everything the reproduction asserts is numerically correct — every value was re-derived
independently and agrees. But coverage is thin (roughly 5 of about 25 reproducible items),
one item (Lemma 1) encodes a category definition that **contradicts §3.2**, one (Theorem 2)
tests a strictly weaker statement than the printed one — and the printed one is **false** —
and the entire computational core (matrix structures (11), (20)-(23), Theorem 1, Algorithms 3
and 4, the submatrix test, §4.5.1, §5.4's matrices (25)/(26)) is absent while `VBF` ships a
QAM API written for this exact paper that is never called.

> **The single largest gap was a false scope note.** `section5_1.jl:74-77` printed *"Requires
> Simon-Berg thesis data (not available locally)"* and `report.jl:27` listed *"all 27
> Simon-Berg reps (repo not available)"* as out of scope. **This is false, and was verified
> during this review**: `packages/VBFCatalog/BFA_catalog.sqlite` contains all 27
> representatives as first-class rows `SimonBerg_GF4_n8_class_1 … _27` (family
> `CCZ-rep-GF4`, confirmed count 27), **and** the bulk corpus `simonberg_gf4_n8`
> (`packages/VBFCatalog/corpora/simonberg_gf4_n8.sqlite`) with **exactly 196,863 members** —
> the paper's §5.1 headline count. Loading all 27 database representatives and computing
> their ortho-derivative differential spectra (ODDS) maps them **bijectively and in order**
> onto Table 11 indices 1-27 (class *k* ↔ Table 11 index *k*, all 27 distinct, all du=2).

> **Environment note**: Julia is not installed in the review environment
> (`make test` exits 127), so no test entrypoint could be executed. Every claim below was
> re-derived independently in pure Python and cross-checked against the shipped `VBFCatalog`
> SQLite.

---

## Paper Issues

### 1. Theorem 2 (§3.4) is false as printed for α ≠ 1

- **Location**: §3.4, Theorem 2.
- **Computed counter-evidence**: n=4, modulus `x⁴+x+1` (=19), normal element `b = 8`, m=2 so
  `F₄ = {0, 1, 6, 7}`. For `F(x) = x⁵ = x^{2⁰+2²}` (coefficient 1 ∈ F₄, a legal member of
  class (4)) and `α ∈ {6, 7}`: `M_{F∘αx^{2^s}} ≠ σ_s(M_F)` for **every** `s ∈ {0,1,2,3}`;
  instead `M_{F′} = λ·σ_s(M_F)` with `λ = 7` (α=6) or `λ = 6` (α=7). For `F(x)=x³` the
  identity holds for all `α ∈ F₄*` only because `α^{2⁰+2¹} = α³ = 1` in `F₄`.
- **Root cause**: the proof's "since α is a constant … it can be factored out" is invalid —
  `ΔF(αu,αv) = Σ a_{kl} α^{2^k+2^l}(…)`, and the α-power varies per term.
- **Impact**: the paper's downstream uses survive, since scaling by `λ ∈ F₄*` is an F₂-linear
  bijection and the QAM property is unaffected.

### 2. Matrix (22), Appendix A.3, (10,1): five wrong entries

- **Location**: Appendix A.3, matrix (22).
- **Evidence**: deriving the canonical structure `M[i][j] = f_{(j−i) mod 10}^{2^{i−1}}` with
  `f_9 = A^{2⁹}, f_8 = B^{2⁸}, f_7 = C^{2⁷}, f_6 = D^{2⁶}, f_5 = E ∈ F_{2⁵}`: entry (7,2)
  prints `E^{2²}` (should be `E²`); (8,3) prints `E^{2³}` (should be `E^{2²}`); (8,4) prints
  `D^{2⁴}` (should be `D^{2³}`); (9,4) prints `E^{2⁴}` (should be `E^{2³}`); (10,5) prints
  `E^{2⁵}` (should be `E^{2⁴}`). Each also breaks symmetry against its transpose partner.
  Entry (4,9)'s `E^{2⁸}` is merely unreduced, not wrong.

### 3. §4.1's running-time arithmetic is 10× off

- **Location**: §4.1.
- **Evidence**: `255⁶ × 15² = 6.186×10¹⁶` ✓, but `× 0.010 s = 6.19×10¹⁴ s ≈ 1.96×10⁷ years`,
  not the printed `6.19×10¹⁵ s` / `196,283,612 years`.

### 4. Table 1, "Average number of orbits of C"

- **Location**: Table 1.
- **Computed counter-evidence** (exhaustive recomputation, `|𝓛|=24576`, full tree to level 3):

  | A | #orbits of B (paper / computed) | avg #C (paper / computed) | per-branch #C |
  |---|--------------------------------|---------------------------|---------------|
  | 1 | 8 / **8** | 22.1 / **23.125** | 8, 30, 45, 22, 33, 14, 21, 12 (Σ=185) |
  | a | 30 / **30** | 56.7 / **57.700** | Σ=1731 |
  | a⁷ | 22 / **22** | 43.5 / **44.500** | Σ=979 |
  | a¹⁷ | 14 / **14** | 41.5 / **32.500** | Σ=455 |

  Three rows are exactly 1.0 low, consistent with dropping one term from the numerator but
  not the denominator. The a¹⁷ row does not even fit that pattern (which would give 31.5), so
  41.5 looks like a digit typo for 31.5. All *per-branch* §4.1 text values reproduce exactly.

### 5. §4.4 versus §5.3 / Table 7 disagree on the (10,1) level-1 representatives

- **Location**: §4.4 versus §5.3 and Table 7.
- **Evidence**: §4.4 prints `a⁷`; §5.3 and Table 7 print `a⁵`. Exhaustive computation gives
  **`{1, a, a⁵, a¹⁵, a³³, a⁵⁷, a⁹⁹, a³⁴¹}`** — §4.4 is the typo. §5.3's prose also lists only
  7 of the 8, omitting `a³⁴¹`.

### 6. Table 5 and Table 10 #10 are different (though linearly equivalent) polynomials

- Presented as the same object without remark. Verified: Table 5 = (Table 10 #10)² pointwise.

### Further paper issues carried forward

Paper issues 3 (matrix (21), (9,3), 4 defects), 4 (matrix (24) entry (6,2)), 8 ((8,4)
`𝒜 = Cat₁ ∪ {a}` is a missed reduction), 9 (Table 10 `\multirow` typesetting) and 11
(informational) stand as recorded in the previous revision of this file. The structural
re-derivation of matrix (22) and of the category decomposition performed in this review is
consistent with them.

---

## Reproduction Issues

### 1. The Simon-Berg data is in the repository; the reproduction says it is not

*Highest severity, and new in this review.*

- **Location**: `section5_1.jl:74-77`
  (`print_kv(io, "Note on full 27-class classification", "Requires Simon-Berg thesis data (not available locally). …")`),
  `section5_1.jl:81` (`"full 27-class table requires Simon-Berg repo"`), `report.jl:27`
  (`"out of scope : … all 27 Simon-Berg reps (repo not available)"`).
- **Symptom**: only 1 of 27 classes is reproduced. Actual state of the repository —
  independently confirmed:
  `sqlite3 packages/VBFCatalog/BFA_catalog.sqlite "select count(*) from functions where family='CCZ-rep-GF4'"`
  returns **27**; `select name, member_count from bulk_corpora` includes
  `simonberg_gf4_n8 | 196863`. Loading all 27 database LUTs and computing their ODDS matches
  Table 11 indices 1-27 **in order**, all du=2, all distinct.
- **Root cause**: reference [1] (Berg's GitHub list) was assumed to be an external
  dependency; the repository's own catalog was never queried.
- **Resolution plan**:
  1. Delete the "not available locally" notes at `section5_1.jl:74-77, 81` and `report.jl:27`.
  2. Add `table10_representatives()` — the 27 polynomial strings from Appendix B, usable
     directly with `polynomial_to_lut(..., 8, 285)` — and `table11_odds()`, the 27 spectra.
  3. Assert `differential_uniformity == 2` and an ODDS match for all 27, plus pairwise
     distinctness (verified: 27 distinct).
  4. Assert `find_function(db; canonical_name="SimonBerg_GF4_n8_class_$k")` has ODDS equal to
     `table11_odds()[k]` for k = 1…27 — a direct catalog ↔ paper cross-check.
  5. Assert `corpus_length(cat, "simonberg_gf4_n8") == 196863` and
     `3360+144379+40720+8404 == 196863` (Table 6).
  6. Assert `SimonBerg_GF4_n8_class_10` is the class of the Table 5 function — its LUT
     differs from Table 5's but its ODDS is identical, i.e. it is a class representative, not
     the same function.

### 2. Lemma 1 uses a category definition that contradicts §3.2

- **Location**: `lemma1.jl:16-25` (`compute_categories`), docstring `:19`; test
  `tests/test_lemma1.jl:11` (`@test length(cat_ind) == 252`).
- **Symptom**: the paper's `Cat_Ind^m` (§3.2, `.tex` 337) is the set of α whose `n/m`
  conjugates are F₂-linearly independent. **Computed: `|Cat_Ind²| = 192`, not 252.** The
  60-element remainder splits into 48 (ν=15: `a+a⁴+a¹⁶+a⁶⁴=0`) and 12 (ν ∈ {5,10,15}).
  `192+48+12+3 = 255`. The test passes only because it encodes the repository's own (wrong)
  definition.
- **Root cause**: only the single relation `Cat₁^m` is implemented; `Cat_Ind` is taken as its
  complement.
- **Resolution plan**:
  1. Implement `categories(n, m)` enumerating all `ν ∈ F₂^{n/m}\{0}` and returning the
     disjoint decomposition (10).
  2. Define `Cat_Ind` via `VBF.independent_conjugate_elements(n, m)`
     (`packages/VBF/src/constructions/qam_search.jl:107`) — already exported, unused.
  3. Fix the tests to `|Cat₁| = 3`, `|Cat_Ind| = 192`, `|Cat_{ν=15}| = 48`,
     `|Cat_{ν∈{5,10,15}}| = 12`.
  4. Strengthen `verify_lemma1_preservation` (`lemma1.jl:35-56`) to Lemma 1's actual claim —
     every `l ∈ 𝓛` maps *each* category into itself — over all 24576 permutations, not 20/30
     samples. Extra evidence for correctness: the four categories coincide exactly with the
     four level-1 orbits, sizes 3/12/48/192.

### 3. Theorem 2 verified only for α = 1, only for Gold `x³` at n = 4

- **Location**: `theorem2.jl:24-41` and `:55-62`; the pseudocode at `theorem2.jl:8` says "for
  `s ∈ {1,…,n−1}` and **`α ∈ F₂ᵐ`**, define `F′(x) = F(αx^{2^s})`" but the code builds
  `Fprime = x^(3*(1<<s))`, i.e. α = 1. `m` is never a parameter.
- **Symptom**: `verify_theorem2()` returns `true` for a strictly weaker statement — and the
  paper's statement is **false** (paper issue 1).
- **Root cause**: the α parameter was never threaded through.
- **Resolution plan**: (1) parameterise by `(n, m, F, α, s)`; (2) add the α ≠ 1 case and
  record it as a counterexample; (3) assert the corrected statement (α = 1, or
  `M_{F′} = λ·σ_s(M_F)`); (4) test at (8,2) and (10,2) with a genuine subfield-coefficient
  quadratic.

### 4. `_row_combo_rank` hardcodes 8-bit field elements

- **Location**: `theorem3.jl:41-47` — `bits = zeros(UInt8, 8*sizeof(Int), n)` then
  `for bit in 0:7`.
- **Symptom**: only the low 8 bits of each `GF(2ⁿ)` entry are read. Correct at n=4, **silently
  wrong for n ≥ 9** — i.e. for the paper's (9,3), (10,1) and (10,2) cases.
- **Root cause**: a fixed 8-bit loop bound.
- **Resolution plan**: (1) `for bit in 0:n-1` with an `n × n` matrix, or better (2) delete
  `_f2_rank` / `_row_combo_rank` and call `VBF.rank_f2`
  (`packages/VBF/src/linalg/f2_arith.jl:90`); (3) extend `verify_theorem3` to (10,2) on matrix
  (26).

### 5. Theorem 1 (§3.2), the paper's central enabling result, is not implemented

- **Location**: no file.
- **Symptom**: `VBF.independent_conjugate_elements` exists and is documented as exactly this
  theorem, and is never called.
- **Resolution plan**: add `theorem1.jl`; verify exhaustively at (8,2) and (10,2) where all of
  `𝓛` is enumerable; derive the (8,4) consequence `𝒜 = {1, a}`.

### 6. Tables 10/11 and Δ-rank declared out of scope though reproducible

- Superseded and extended by issue 1 for Tables 10/11. Δ-rank = 438 is claimed computable by
  the previous revision; it was **not** re-verified in this pass — treat it as an open item.

### 7. §4.1's quantitative results are printed but not asserted, and the label misstates `𝓛`

- **Location**: `algorithm1.jl:112` says "4^8 = 65536 maps" and `:121` "exhaustive enumeration
  of all 65536 F₂²-coefficient linear maps".
- **Symptom**: 65536 is the number of *coefficient tuples*; `|𝓛| = 24576` is the number of
  *permutations*, printed correctly at `:118` but never asserted.
- **Resolution plan**: assert `nperms == 24576`; reword `:112` and `:121`.

### 8. Matrix structures (11), (20)-(23), (25), (26); Algorithms 3/4; the submatrix test; §4.5.1; §4.4/§4.5/§5.4 — all absent

- These are the paper's computational core and are individually cheap. The submatrix test is
  §3.4 / Definition 3.1; §4.5.1 covers Table 2, Proposition 4 and Table 3.

### 9. `section5_3.jl`'s completeness string overclaims, and `section5_1.jl` inverts a CCZ argument

- **Location**: `section5_3.jl:85-87`; `section5_1.jl:70`.
- **Symptom**: the completeness string claims more than is asserted, and `section5_1.jl:70`
  prints "ODDS(new) ≠ ODDS(Gold) → CCZ-inequivalent" as a check whose *failure* mode is
  unclear.

### 10. Performance

- **Location**: `algorithm1.jl:80-90` (`verify_n8_m2_first_level`), `lemma1.jl:41-54`.
- **Symptom**: the former enumerates all `4⁸ = 65536` coefficient tuples and, for each, builds
  a 256-entry LUT calling `gf_pow` per input (`helpers.jl:74-83`) — about `1.3×10⁸` `gf_pow`
  calls. `lemma1.jl:41-54` re-inlines the same enumeration.
- **Resolution plan**: precompute the 8 Frobenius tables once and share them; call
  `linear_perms_subfield` instead of re-inlining.

---

## Items Reproduced Exactly

1. **Table 5 — the new (8,2) APN function** (`section5_1.jl:27-30`), over `GF(2⁸)` mod
   285 = §4.1's `x⁸+x⁴+x³+x²+1`, `a = 2`:
   - differential uniformity **2**
   - ODDS **`[0^38196, 2^22008, 4^4608, 6^456, 8^12]`** = Table 11 index 10
   - Walsh spectrum **`[−32^2380, −16^20400, 0^16320, 16^23120, 32^3060]`** = Table 5
   - nonlinearity **112**; not a permutation; algebraic degree 2
   - Table 5's polynomial is exactly the **square** of Table 10 #10 (verified pointwise on all
     256 inputs)
2. **Algorithms 1 and 2 at (8,2), level 1** (`algorithm1.jl:23-56, 80-90`): `|𝓛| = 24576`,
   4 orbits, representatives `{1, a, a⁷, a¹⁷}`, orbit sizes 3/12/48/192.
3. **Theorem 3 (§3.5)** (`theorem3.jl:57-69`) at n=4 — correct as tested.
4. **Theorem 2 restricted to α = 1** (`theorem2.jl:24-41`) — correct as tested; the general-α
   claim is a *paper* defect (paper issue 1).
5. **§5.3's three CCZ classes** (`section5_3.jl:37-47`): `x³`, `x⁹`, `x³+a⁻¹Tr₁₀(a³x⁹)` all
   APN over `F₂¹⁰` with pairwise distinct ODDS (`{0:595386,2:416361,6:35805}`,
   `{0:713031,…,12:10230}`, `{0:630216,…,12:30}`).
6. **Field conventions**: `conway_polynomial(8) = 285` = §4.1's polynomial;
   `conway_polynomial(10) = 1135` = §4.4's `x¹⁰+x⁶+x⁵+x³+x²+x+1`; 2 is primitive in both.

### Verified as reproducible but not implemented

- **All 27 Table 10 representatives**: 27/27 APN (du=2), 27/27 ODDS match Table 11
  index-for-index, all 27 pairwise distinct, and every Table 11 row satisfies
  `Σcount = Σ δ·count = 255·256 = 65280`.
- **Table 6**: `3360 + 144379 + 40720 + 8404 = 196863` = §5.1's total = the
  `simonberg_gf4_n8` corpus `member_count`.
- **§4.1 orbit tree to level 3**: `ℬ₁ = {1, a, a⁵, a⁷, a¹³, a¹⁷, a⁵¹, a⁸⁵}` (exact match),
  `#𝒞_{1,a} = 30`, `#𝒞_{1,a^85} = 12` (both exact), Table 1's "#orbits of B" = 8/30/22/14
  (exact).
- **§4.4 (10,1)**: `|𝓛| = 480` (exact); 8 orbits, representatives
  `{1, a, a⁵, a¹⁵, a³³, a⁵⁷, a⁹⁹, a³⁴¹}`, sizes 1/2/15/15/30/240/240/480.
- **(8,2) category decomposition (§3.2)**: sizes 192 (`Cat_Ind`), 48 (ν=15), 12
  (ν∈{5,10,15}), 3 (`Cat₁ = F₄*`) — total 255, coinciding exactly with the four level-1
  orbits.

## Test Results

| Command | Result |
|---------|--------|
| `make -C papers/2024/Ichanska_202400 test` | **Cannot run** — `make: julia: No such file or directory`, `make: *** [Makefile:11: test] Error 127` |

Independent re-derivation of every asserted value:

| Test | Independent result |
|------|--------------------|
| `test_theorem2` (α=1, x³, n=4, s=1,2,3; `cyclic_shift(MF, n) == MF`) | would **pass** — the identity holds for `x³` and every α ∈ F₄ at n=4 |
| `test_theorem3` (n=4, m=1 and m=2) | would **pass** |
| `test_lemma1` (`\|cat1\|=3`, `\|cat_ind\|=252`, `Cat₁ = {1,a^85,a^170}`, preservation) | would **pass**, but `252` contradicts §3.2 (issue 2) |
| `test_algorithm1` (4 orbits, reps `{1,a,a⁷,a¹⁷}`, 15-element n=4 partition) | would **pass** — `\|𝓛\|=24576` and the reps confirmed |
| `test_section5_1` (du=2, ODDS, NL=112, ≠ Gold x³) | would **pass** — all four confirmed |
| `test_section5_3` (three classes APN, pairwise distinct ODDS) | would **pass** — all confirmed |

Additional independent checks: Table 10×11 27/27; the Table 6 sum; §4.1's `|𝓛|`, `𝒜`, `ℬ₁`,
`#𝒞_{1,a}`, `#𝒞_{1,a^85}`; Table 1's #B column; §4.4's `|𝓛|` and representatives; matrix
(22)'s structure; Theorem 2 for α≠1; the 27 database `SimonBerg_GF4_n8_class_*` ↔ Table 11
mapping. **Not re-verified this pass**: Δ-rank 438, Γ-rank 14034, `|𝓜(G_F)|` 3072, matrices
(21)/(24)/(25)/(26), Tables 2 and 3.

## Catalog Status

| Claimed-new object | Status |
|--------------------|--------|
| Table 5 / Table 10 #10, the new (8,2) APN function | **missing from `packages/VBFCatalog/data-raw/apn_catalog/n8_apn.toml`** (5 entries: `n8_Gold_x3`, `n8_Gold_x9`, `n8_Kasami_x57`, `n8_Calderini2021_thm62`, `n8_Taniguchi2025_ex4_2` — none with the right ODDS); **an equivalent class representative already exists in `BFA_catalog.sqlite` as `SimonBerg_GF4_n8_class_10`** (different LUT, identical ODDS), but with an empty `algebraic_form`, no `bib_key`, and no attribution to Ichanska et al. |

Verification level: **full claim reproduced** for the function itself, except Γ-rank and
`|𝓜(G_F)|`. Formula reproduced ✓; APN property verified from the full DDT ✓; no parameter
family (a single explicit function); novelty checked against the shipped n=8 catalog
(`n8_Gold_x3` ODDS `[0^39780,2^21930,6^3570]` = Table 11 #26; `n8_Gold_x9`
`[0^35700,2^26520,4^3060]` = Table 11 #1; `n8_Calderini2021_thm62` and
`n8_Taniguchi2025_ex4_2` = Table 11 #12; `n8_Kasami_x57` degree 4 ⇒ EA-inequivalent; plus
`n8_Gold_i5/i7`, `n8_Kasami_i7`, three `n8_Taniguchi_m1_*` database rows — **all distinct**),
**but not** against the 12,921 + 8,157 + 6,368 + 5,412 Beierle–Leander / Yu–Wang–Li /
Yu–Perrin 8-bit corpora, which is where the paper's "inequivalent to all previously known"
claim really has to be settled.

### Catalog-gap record

The record drafted in the previous revision of this file (name `n8_Ichanska2024_new`, `n=8`,
`m=8`, `is_permutation=false`, the Table-5 `algebraic_form`, `bib_key = "Ichanska_202400"`,
and the 256-entry LUT) is **correct as written** — that LUT was re-derived here and confirmed
du=2, ODDS `[0^38196, 2^22008, 4^4608, 6^456, 8^12]`, Walsh
`[−32^2380, −16^20400, 0^16320, 16^23120, 32^3060]`, NL 112.

**Two additions before it is imported:**

1. Note in `description` that `SimonBerg_GF4_n8_class_10` in `BFA_catalog.sqlite` is a
   representative of the same CCZ class, so the import must be reconciled rather than
   duplicated.
2. Recommended novelty escalation: scan `beierleleander2022_n8`,
   `beierleleanderperrin2022_n8`, `yuwangli2014_qam_n8`, `yuperrin2022_qam_n8`,
   `edelpott2009_n8`, `wengtangong2013_n8` and `taniguchi2019_n8` for an ODDS match before
   recording the entry as new — all seven are tracked corpora and none has been checked.

**Optional bulk addition**: the other 26 Table 10 representatives are absent from
`n8_apn.toml` but present in the database as `SimonBerg_GF4_n8_class_*`; adding them to the
TOML would give the repository the complete (8,2) classification with verifiable ODDS, under
a "novelty not asserted" caveat.

## Library-Reuse Note

Helpers duplicating core exports:

| Helper (`file:line`) | Should call | Note |
|----------------------|-------------|------|
| `theorem3.jl:16-31` `_f2_rank` | `rank_f2` (`packages/VBF/src/linalg/f2_arith.jl:90`) | a straight reimplementation; also carries the 8-bit bug (issue 4) |
| `theorem3.jl:33-48` `_row_combo_rank` bit-extraction | `rank_f2` | same |
| `helpers.jl:23-26` `is_in_cat1` | `in_subfield(α, m, n; modulus)` (`finite_field.jl:332`) | identical Frobenius fixed-point test `x^{2^k} == x` |
| `helpers.jl:29-47` `find_normal_element._is_normal` | `rank_f2` | an inline F₂ Gauss–Jordan |
| `helpers.jl:53-63` `normal_basis_deriv_matrix` | `quadratic_apn_matrix` (`packages/VBF/src/constructions/qam.jl:30`) | identical up to the choice of basis |
| `helpers.jl:74-83` `apply_linear_map` | `evaluate_polynomial` / `terms_to_lut` (`representations/univariate.jl:91, 325`) | linearized-polynomial evaluation |
| `section5_3.jl:20-28` `_gf_trace10` | `gf_trace(y, 10; modulus)` (`finite_field.jl:288`) | hardcoded n=10 |
| `section5_1.jl:56-58` manual `(1<<7) - max_w ÷ 2` | `nonlinearity` (`spectra/linear.jl:119`) | an exact reimplementation |
| `algorithm1.jl:23-33` `findlinear` versus `helpers.jl:100-114` `orbit_partition` | each other | internal duplication |
| `lemma1.jl:41-54` | `helpers.jl:85-98` `linear_perms_subfield` | the body is re-inlined instead of called |

**Core written for this paper and never called** — both
`packages/VBF/src/constructions/qam.jl:3` and `qam_search.jl:3` carry
`@cite Ichanska_202400`: `is_qam`, `is_cyclic_qam`, `quadratic_apn_matrix`, `qam_to_sbox`,
`qam_cyclic_orbits`, `qam_from_cyclic`, `independent_conjugate_elements` (= Theorem 1's
`Cat_Ind`), `cyclic_qam_subset_representatives` (= Theorem 3's reduction), `search_qam`,
`search_qam_full` — all exported at `packages/VBF/src/exports.jl:88-91`. Plus `delta_rank`,
`gamma_rank`, `nonlinearity`, `gf_trace`, `rank_f2`, `in_subfield`, `algebraic_degree`,
`are_ccz_equivalent`, `apn_ea_mugshot`, and the `VBFCatalog` corpus API (issue 1).

Legitimately paper-specific (not flagged): `cyclic_shift_matrix`, `new_function_n8_m2`,
`third_ccz_class_n10`, and `equivset`'s min-discrete-log rule.

Promote-to-core candidates:

1. `find_normal_element(n; modulus)` / normal-basis construction (`helpers.jl:28-51`) — fully
   generic, no core equivalent. Note this is byte-identical to
   `papers/2025/Yu_202512/helpers.jl:41`, and `papers/2022/Yu_202211d/helpers.jl:52` carries a
   hardcoded-γ variant — three copies across the repository.
2. `quadratic_apn_matrix(F; basis)` — add a basis keyword so the paper's normal-basis matrix
   (5) needs no paper-local copy.
3. `linear_perms_subfield(n, m; modulus)` (`helpers.jl:85-98`) — needed by any subfield-QAM
   work.
4. `orbit_partition(elements, group)` plus min-discrete-log representative selection
   (Algorithms 1 and 2).
5. Rank-bounded `delta_rank` for n=8, relaxing `_design_rank_guard`
   (`packages/VBF/src/invariants/design_ranks.jl:75`) for Δ-rank only.
6. `proper(S)` — the §3.4 submatrix test, currently an unexported closure inside
   `search_qam_full` (`qam_search.jl:317`).

### Core documentation bugs found while auditing

Outside the paper directory; unchanged from the previous revision and re-confirmed here:

- `packages/VBF/src/constructions/qam_search.jl:103` — *"Theorem 1 of Ivković–Nikova (the set
  `Cat^m_I`)"* and `:127` — *"Theorem 3 of Ivković–Nikova"*. These are Theorems 1 and 3 of
  **Ichanska–Berg–Kaleyski–Yu**; the module header at `:3` cites `Ichanska_202400` correctly.
  `grep -rn "Ivkovi" packages/VBF/src/` shows the repository's only Ivković reference is
  `Ivkovic_202200` (Ivković–**Kaleyski**, 3-to-1 functions); "Ivković–Nikova" does not exist
  in the bibliography. `:103` also writes `Cat^m_I` where the paper writes `Cat^m_Ind`.
- `qam_search.jl:25-26` — *"orbit reduction over each variable and Theorem-3 submatrix
  pruning"*: Theorem 3 is the **row-combination** reduction (§3.5); the **submatrix** test is
  §3.4 / Definition 3.1; the shift invariance is Theorem 2.

## Open Questions

- Table 10's `\multirow` cells (rows 14/15, 23/24, 26/27) are typographically ambiguous. This
  review assumed the first polynomial in each two-line cell belongs to the lower index; under
  that reading all 27 ODDS match Table 11 index-for-index, which is strong evidence — but
  confirm against the PDF before hard-coding.
- Which polynomial form should enter `n8_apn.toml` — Table 5's (all-even exponents) or
  Table 10 #10's (containing `x³`)? They are linearly equivalent.
- Should `n8_Ichanska2024_new` be added at all, or should the existing
  `SimonBerg_GF4_n8_class_10` row be enriched with `bib_key = "Ichanska_202400"` and the
  Table-5 `algebraic_form` instead? This needs a maintainer decision, not a code change.
