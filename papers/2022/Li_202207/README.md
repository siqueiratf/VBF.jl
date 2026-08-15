# Li_202207 — Two New Families of Quadratic APN Functions

**Paper**: Li, Zhou, Li, Qu. "Two New Families of Quadratic APN Functions." IEEE Transactions
on Information Theory **68**(7):4761–4769, 2022.

**Reproduction path**: `papers/2022/Li_202207/`

**Verdict**: Partial

Theorem 2 is reproduced correctly and confirmed APN at `m = 2, 4, 5` (and correctly non-APN
at `m = 3`). Theorem 3, however, is implemented with a **wrong Frobenius exponent**
(`z^{2^{2m+s}}` where the paper has `z^{2^{m+s}}`), so it does not implement the paper's
family at all — and at `m = 2` it emits a spurious PASS for a case where the paper's Theorem 3
is vacuous. A required hypothesis (`v ∈ F*_{2^m}`) is documented away as "any `v` works".
Tables IV and V and both "covers a known sporadic instance" claims — the paper's entire
novelty argument — are absent, although all of them were shown here to be cheaply checkable.

> **Environment note**: Julia is not installed in the review environment, so `make test`
> could not be executed. Claims below were re-derived from scratch in Python using VBF's own
> `PRIMITIVE_POLYNOMIALS`/`CONWAY_POLYNOMIALS` tables.

---

## Paper Issues

None found. Everything checked in the paper is correct:

- Theorem 2 is APN at `m = 2, 4, 5` (`δ = 2`) and non-APN at `m = 3` (`δ = 16`), exactly
  matching the `gcd(3,m)=1` hypothesis.
- Theorem 3's conditions are necessary as stated: at `m=3, s=1, μ=6`, only the **7** values
  `v ∈ F*_{2^3}` out of 511 give `δ=2` (504 fail, e.g. `v=2 → δ=16`), so "`v ∈ F*_{2^m}`" is
  not a removable hypothesis.
- Table V row 12 `(z^16 + u^5 z^2 + z)^9 + u^73 z^9` over `F_2^9` (`z^9+z^4+1 = 529`, `u = 2`):
  `δ = 2`, `μ = u^5` satisfies `μ^{2^{2m}+2^m+1} ≠ 1`, and `L` permutes `F_2^9`.
- Coverage claim (Section II) that Theorem 2 covers Edel–Pott Table 9 No. 1.9: building the
  explicit Edel–Pott instance from the tex (modulus 285, `u=2`) gives `δ=2` and an
  ortho-derivative differential spectrum `((0,38160),(2,22104),(4,4536),(6,456),(8,24))`
  **identical** to Theorem 2 at `m=4`.
- Coverage claim that Theorem 3 covers the Beierle–Leander `F_2^9` instance: building the
  36-term polynomial from the tex (modulus 529, `u=2`) gives `δ=2`, with an OD spectrum
  matching the Theorem-3 member `(s,μ,v) = (1, 15, 28)` and equal to the Table V row-12
  spectrum.
- Remark 1 (`m ≥ 3, s=1` always admits a valid `μ`) is consistent: at `m=2` there is
  genuinely no valid `μ`, and at `m=3` there are 126.

---

## Reproduction Issues

### 1. Theorem 3's linearized polynomial uses `z^{2^{2m+s}}` instead of `z^{2^{m+s}}`

- **Location**: `helpers.jl:56` (`e_high = 1 << (2m + s)`) and `theorem3.jl:38` (same);
  mis-transcribed also in the prose at `helpers.jl:47`, `theorem3.jl:8`, `:19`, `:32`, `:67`.
- **Symptom**: `theorem3_report` and the test `theorem3_test` build
  `f(z) = (z^{2^{2m+s}} + μ z^{2^s} + z)^{2^m+1} + v z^{2^m+1}`. The paper's Theorem 3 (tex
  line 179) and Table V row 12 (`z^16 = z^{2^4}` with `m=3, s=1`) both give `z^{2^{m+s}}`.
  Actual vs expected at `m=3, s=1`: the reproduction's `μ`-set and the paper's `μ`-set are
  **different** (both of size 126, but `set(A) == set(B)` is `False`); the reproduction's
  smallest valid `μ` is `12`, the paper's is `6`.
- **Consequence at `m = 2`** — a default in `theorem3.jl:62` (`ms = [2,3]`) and `report.jl:23`:
  an exhaustive check over the 42 elements of `F*_{2^6}` with `μ^{2^4+2^2+1} ≠ 1` shows the
  paper's `L(z) = z^8 + μ z^2 + z` permutes for **0** of them (Theorem 3 is vacuous at `m=2`),
  whereas the reproduction's `L(z) = z^{32} + μ z^2 + z` permutes for **12**, smallest `μ = 6`.
  So `tests/test_theorem3.jl` and the report emit a PASS at `m = 2` for a function the paper's
  Theorem 3 does not produce.
- **Mitigating fact** (worth reporting, not hiding): at `m=3, s=1, v=1` both variants realise
  the *same* two ortho-derivative classes (intersection 2, repro-only 0, paper-only 0), so the
  error is not visible from `δ` alone.
- **Root cause**: a transcription slip when converting `2^{m+s}` from the tex, propagated into
  every docstring and the pseudocode block — so no internal cross-check could catch it.
- **Resolution plan**:
  1. Change `e_high` to `1 << (m + s)` in `helpers.jl:56` and `theorem3.jl:38`.
  2. Fix the prose at `helpers.jl:47` and `theorem3.jl:8/19/32/67`.
  3. Change the `ms` defaults from `[2,3]` to `[3]` (and `full` from `[2,3,4]` to `[3,4]`), or
     keep `m=2` but assert `found == false` with an explicit "Theorem 3 vacuous at m=2,
     cf. Remark 1" message.
  4. Add a regression test pinning `find_valid_mu(3,1) == 6` and
     `find_valid_mu(2,1) == (-1,false)`.
  5. Add a test reproducing Table V row 12 verbatim (`m=3, s=1, μ=u^5=32, v=u^73=336`,
     modulus 529) and asserting `δ=2`.

### 2. `v` is documented and accepted as any nonzero element of `F_{2^{3m}}`

- **Location**: `theorem3.jl:59` ("`v = nonzero scalar factor; any v ∈ F*_{2^{3m}} works`"), no
  guard in `theorem3_sbox` (`theorem3.jl:35`), Makefile knob `v ?= 1`.
- **Symptom**: Theorem 3 requires `v ∈ F*_{2^m}`. `make theorem3 m=3 v=2` produces `δ = 16` and
  prints a FAIL that looks like the theorem failing. Measured: only 7 of 511 nonzero `v` give
  `δ=2` at `m=3, s=1, μ=6`, exactly `F*_{2^3} = {1,28,29,332,333,336,337}`.
- **Root cause**: the subfield hypothesis was dropped when writing the docstring; `v=1` happens
  to be in the subfield, so the defaults pass.
- **Resolution plan**:
  1. Add `in_subfield(v, m, 3m; modulus) || error(...)` to `theorem3_sbox`.
  2. Correct the docstring to `v ∈ F*_{2^m}`.
  3. Add a test asserting the guard rejects `v = 2` at `m = 3` and that all 7 subfield `v` give
     `δ = 2`.

### 3. Tables IV and V and the two "covers a sporadic instance" claims are not reproduced at all

- **Location**: `report.jl:31-33` (a NOTE saying Γ-rank is out of scope) — nothing else.
- **Symptom**: the paper's *entire novelty argument* (Section II, Tables IV/V, and the
  Edel–Pott / Beierle–Leander coverage statements) has no executable counterpart. The Γ-rank
  excuse is valid (`gamma_rank` guards `n ≤ 7`,
  `packages/VBF/src/invariants/design_ranks.jl:78`), but `apn_ea_mugshot` at `n=8/9` is cheap
  and gives EA-inequivalence.
- **Root cause**: CCZ-inequivalence was treated as all-or-nothing (Γ-rank or nothing).
- **Resolution plan**:
  1. Add `table4.jl`: build the quadratic rows of Table IV (Gold `z^3`, `z^9`, F3 hexanomial
     row 4, F4 rows 5–6, F13 row 7, F14 rows 8–9, F16 row 10, F15 row 11, Theorem 2 row 12)
     and compare `apn_ea_mugshot`s; assert row 12 differs from every other row. The sharpest
     case is already verified: F16 row 10 `(x^3+xy^2+y^3, x^5+x^4y+y^5)` has OD spectrum
     `((0,36420),(2,25080),(4,3780))` ≠ Theorem 2's
     `((0,38160),(2,22104),(4,4536),(6,456),(8,24))`.
  2. Add `sporadic_coverage.jl`: build the Edel–Pott instance from tex Section II and assert
     `apn_ea_mugshot == apn_ea_mugshot(theorem2_sbox(4))` (verified true by OD spectrum).
  3. Add the Beierle–Leander `n=9` polynomial and assert its mugshot equals the Theorem-3
     member `(s,μ,v)=(1,15,28)` (verified true by OD spectrum).
  4. Keep the Γ-rank NOTE, but state explicitly that mugshot equality is *evidence for*
     coverage while mugshot inequality is *proof of* EA/CCZ-inequivalence for quadratic APN.

### 4. Only one `μ` per `m` is exercised

- **Location**: `theorem3.jl:80` (`μ, found = find_valid_mu(m, s)` — first valid only).
- **Symptom**: Theorem 3 quantifies over *all* admissible `μ`; the reproduction checks one.
  (All 126 at `m=3` were checked here for `s=1` and `s=2`: all give `δ=2`.)
- **Root cause**: the search helper returns the first hit.
- **Resolution plan**: add an opt-in `all_mu=true` mode iterating every valid `μ` (and
  `s ∈ {1,2}` at `m=3`) with an explicit exhaustive/budget label.

### 5. Directory and artifact convention deviations

- **Location**: `papers/2022/Li_202207/tests/` (every other paper uses `test/`); the `Makefile`
  has a `clean_results` target but nothing ever writes `results/`; there is no
  `results/report.toml` artifact, unlike Yu/Zheng/Beierle.
- **Root cause**: divergence from the `Beierle_202201`/`Yu_202211d` template named in
  `AGENTS.md:58`.
- **Resolution plan**: rename `tests/` → `test/`, and add an optional `save_results` path
  writing `results/report.toml`.

---

## Items Reproduced Exactly

| Item | Evidence |
|------|----------|
| **Theorem 2** `f(x,y) = (x³+xy²+y³+xy, x⁵+x⁴y+y⁵+xy+x²y²)` | Formula transcribed verbatim (`theorem2.jl:36-38`); APN verified independently at `m=2,4,5` (`δ=2`) and correctly rejected at `m=3` (`δ=16`); `f(0,0)=0`; algebraic degree 2. The bivariate packing `index = x|(y<<m)` is legitimate (coordinatewise XOR = `F_{2^m}²` addition) |
| **Theorem 3 shape** `f(z) = L(z)^{2^m+1} + v z^{2^m+1}` | Outer exponent `2^m+1` correct (`theorem3.jl:40`), and the two `μ` side conditions (`μ^{2^{2m}+2^m+1} ≠ 1`, `L` a permutation) are implemented exactly (`helpers.jl:53-81`). Only the inner exponent is wrong (issue 1) |
| **Remark 1 / `m=1` degeneracy** | `find_valid_mu(1,1)` correctly returns no `μ` (norm exponent 7 = `|F*_{2^3}|`) |

## Test Results

| Command | Result |
|---------|--------|
| `make -C papers/2022/Li_202207 test` | **Not run** — `julia` is not installed in the review environment |
| Independent re-verification (VBF's own moduli): Theorem 2 `m=2/4/5 → δ=2`, `m=3 → δ=16` | **Pass** |
| Theorem 3 paper-form `m=3 → δ=2` for all 126 `μ` and both `s∈{1,2}` | **Pass** |
| Theorem 3 `m=2`: paper-form has 0 valid `μ` vs reproduction-form 12 | **Discrepancy — see issue 1** |
| Table V row 12 `δ=2`; Edel–Pott and Beierle–Leander instances `δ=2` with matching OD spectra | **Pass** |

## Catalog Status

| Claimed-new object | Formula correct | APN verified | Family validated | Novelty checked | Catalog status |
|---|---|---|---|---|---|
| Theorem 2 family, `n=8` (`m=4`) | yes | yes (`δ=2`) | yes (`m=2,4,5`; `m=3` excluded) | yes in this review (≠ Gold x3/x9, Calderini2021_thm62, Taniguchi2025_ex4_2, F16) — **not** by the reproduction | **missing** from `n8_apn.toml` (see note) |
| Theorem 3 family, `n=9` (`m=3`) | **no** (wrong exponent) | yes, but for the wrong family | partial | no | **missing** from `n9_apn.toml` |

Note on the `n=8` entry: its OD spectrum equals that of the Edel–Pott Table 9 No. 1.9
function, which is very likely already inside the *corpus* `edelpott2009_n8` (the SQLite
store, not the curated TOML). The corpus could not be queried without Julia. It is **absent
from `n8_apn.toml`** either way.

### Catalog-gap record 1

```
target file      : packages/VBFCatalog/data-raw/apn_catalog/n8_apn.toml
name             = "n8_Li2022_thm2"
n = 8, m = 8, is_permutation = false
algebraic_form   = "Bivariate f(x,y) = (x^3 + x*y^2 + y^3 + x*y,  x^5 + x^4*y + y^5 + x*y + x^2*y^2) over GF(2^4)^2, modulus x^4+x+1 (=19); packed z = x|(y<<4)"
bib_key          = "Li_202207"
source           = "Li, Zhou, Li, Qu, 'Two New Families of Quadratic APN Functions', IEEE Trans. Inf. Theory 68(7):4761-4769, Theorem 2 at m=4 (Table IV row 12, Gamma-rank 14034). LUT from papers/2022/Li_202207/theorem2.jl theorem2_sbox(4)."
lut = [0, 17, 104, 111, 124, 122, 113, 97, 26, 127, 31, 108, 24, 106, 120, 28, 17, 16, 41, 62, 77, 91, 16, 16, 187, 206, 238, 141, 153, 251, 169, 221, 104, 63, 28, 93, 255, 191, 238, 184, 199, 228, 222, 235, 46, 26, 82, 112, 111, 40, 75, 26, 216, 136, 153, 223, 112, 67, 57, 28, 185, 157, 149, 167, 124, 90, 154, 170, 31, 46, 156, 187, 235, 185, 96, 36, 246, 179, 24, 75, 122, 76, 204, 236, 57, 24, 234, 221, 93, 31, 134, 210, 96, 53, 222, 157, 113, 17, 139, 253, 249, 142, 102, 7, 83, 71, 196, 198, 165, 166, 87, 66, 97, 17, 203, 173, 201, 174, 6, 119, 243, 247, 52, 38, 37, 54, 135, 130, 26, 207, 170, 105, 149, 87, 64, 148, 38, 135, 251, 76, 215, 97, 111, 207, 127, 186, 159, 76, 208, 2, 85, 145, 243, 66, 126, 217, 34, 132, 202, 122, 31, 140, 179, 54, 123, 255, 178, 32, 150, 113, 87, 166, 140, 124, 40, 206, 108, 239, 144, 5, 40, 188, 177, 51, 85, 162, 196, 37, 111, 143, 155, 109, 24, 250, 38, 210, 136, 125, 211, 48, 169, 63, 250, 122, 71, 198, 113, 230, 106, 152, 4, 224, 218, 63, 209, 34, 107, 237, 104, 248, 165, 52, 195, 68, 120, 220, 90, 232, 3, 176, 68, 225, 124, 172, 51, 245, 121, 190, 83, 130, 28, 168, 110, 204, 71, 228, 80, 229, 168, 104, 183, 97, 141, 90, 247, 54]
equivalence evidence:
  differential_uniformity = 2, algebraic_degree = 2
  ortho-derivative differential spectrum = {0:38160, 2:22104, 4:4536, 6:456, 8:24}
  distinct from every existing n8_apn.toml entry:
    n8_Gold_x3              {0:39780, 2:21930, 6:3570}
    n8_Gold_x9              {0:35700, 2:26520, 4:3060}
    n8_Kasami_x57           (not quadratic; no ortho-derivative)
    n8_Calderini2021_thm62  {0:39150, 2:20463, 4:4920, 6:675, 8:54, 10:12, 12:6}
    n8_Taniguchi2025_ex4_2  {0:38592, 2:21426, 4:4590, 6:654, 8:18}
  also distinct from Gologlu F16 at m=4 {0:36420, 2:25080, 4:3780}
  caveat: equals the OD spectrum of the Edel-Pott 2009 Table 9 No. 1.9 function
          (paper Sec. II) — check corpus "edelpott2009_n8" before inserting.
```

### Catalog-gap record 2 — deliberately withheld

The `n=9` Theorem 3 instance must be regenerated **after issue 1 is fixed**, since the current
code produces a different family. Once fixed, the record should use `m=3, s=1, μ=u^5=32,
v=u^73=336, modulus=529` (Table V row 12), with OD spectrum
`{0:170667, 2:66297, 4:15911, 6:5705, 8:1974, 10:385, 12:140, 14:84, 16:168, 18:147, 20:63,
22:63, 24:21, 26:7}` — distinct from all five quadratic `n9_apn.toml` entries
(`n9_Gold_x3/x17 {0:153811,…}`, `n9_Gold_x5 {0:159943,…}`,
`n9_Budaghyan2009_eq7 {0:160525,…}`, `n9_Budaghyan2009_eq8 {0:159226,…}`). Note it is
CCZ-equal to the Beierle–Leander `n=9` No. 9 instance, so check the corpus first.

## Library-Reuse Note

- **Duplication**: none serious. `helpers.jl` correctly uses `gf_mul`, `gf_pow`,
  `primitive_polynomial`, `SBox` and `print_banner` (this paper is the batch's positive
  example for banner use).
- `find_valid_mu` (`helpers.jl:66-79`) hand-rolls a permutation test with a `seen` array;
  `VBF.is_permutation(SBox{n}(lut))` exists. Marginal — the hand-rolled version early-exits,
  so this is a judgement call rather than a violation.
- **Promote-to-core candidate**: `bivariate_lut(m, f1, f2; modulus)` (`helpers.jl:29-40`) is a
  generic `GF(2^m)² → GF(2^m)²` packer, duplicated in spirit at
  `papers/2021/Calderini_202100/helpers.jl` and needed by every bivariate-APN paper (Göloğlu,
  Calderini, Li). It belongs in `packages/VBF/src/representations/`.

## Open Question

`papers/2022/Li_202207/input/tex_source/calderini_li_villa_2204.07462.tex` is **a different
paper** (Calderini–Li–Villa, "Two new families of bivariate APN functions", arXiv:2204.07462),
whose journal version is reproduced at `papers/2023/Calderini_202306`. No reproduction file
reads it. Is it intentionally kept as secondary context, or misfiled?
