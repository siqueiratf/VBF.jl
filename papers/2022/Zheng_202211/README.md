# Zheng_202211 — Constructing New APN Functions Through Relative Trace Functions

**Paper**: Zheng, Kan, Li, Peng, Tang. "Constructing new APN functions through relative trace
functions." arXiv:2101.11535, 2022.

**Reproduction path**: `papers/2022/Zheng_202211/`

**Verdict**: Partial

One of the seven items of Theorem 3.3 is reproduced (item iii = family F15), plus Lemma 2.1.
Items i, ii, iv, v, vi and vii, Theorem 3.10, Corollary 1's two infinite families, both
Table III sporadic instances, and Remarks 3.4–3.8 are all missing. The reproduction also
imposes a condition (`gcd(3,m)=1`) that Theorem 3.3 iii) does not require, and its
CCZ-inequivalence claim is checked against a 2-element slice of a catalog that holds only 4
monomials at `n=10`. Everything omitted was verified here to be cheap — items i–vii,
Corollary 1 and the Remark 3.6 sporadic all check in seconds at `n=10`.

> **Environment note**: Julia is not installed in the review environment, so `make test` could
> not be executed. The committed `results/report.toml` and `results/theorem3_3.toml` record a
> prior in-repo pass; all load-bearing values were independently re-derived in Python.

---

## Paper Issues

### P1. Theorem 3.3 item iv) states a different condition from its own proof, and Remark 3.8 applies only to the proof's version

- **Location**: statement at tex line 316 — "iv) `gcd(3,m)=1`, `3s ≡ 1 mod n`, `b` not a cube,
  `c / b^{2^{2s}−2^s+1} ∈ F_{2^m}`"; proof at tex line 372 — "iv) … `b` is a non-cube … and
  `c^{2^{2s}−2^s+1} / b ∈ F*_{2^m}`". The numerator and denominator are swapped.
- **Consequence**: Remark 3.8 (tex line 455) says "there does not exist elements satisfying
  the conditions in iv)". That is true for the **proof's** condition — since `s` is odd,
  `3 | 2^{2s} − 2^s + 1`, so `c^{2^{2s}−2^s+1}` is always a cube while `λ·b` with `b` a
  non-cube never is, making the constraint set empty. It is **false** for the **statement's**
  condition.
- **Counter-evidence**: at `m=5, n=10, s=7` (`3·7 ≡ 1 mod 10`, `s` odd, `gcd(3,5)=1`),
  `k = 2^{14} − 2^7 + 1 ≡ 912 mod 1023`; take any non-cube `b` and any `λ ∈ F*_{2^5}`, and set
  `c = λ b^{912}`. Eight such `(a,b,c)` with `a ∉ F_{2^5}` were sampled: **all 8 gave `δ = 2`**
  — witnesses exist, so item iv as stated is non-vacuous and true.
- **Recommended wording**: "Theorem 3.3 iv) and its proof state reciprocal conditions;
  Remark 3.8's vacuity claim holds for the proof's version only."

### P2. Example 1 / Table III's last row is under-specified and false for a generic primitive element

- **Location**: tex lines 648–654 (Example 1) and tex line 703 (Table III last row,
  `α Tr_m^n(x^3) + α^q Tr_m^n(α x^5 + α^{369} x^{4q+1})`, condition column: "`α` primitive in
  `F*_{2^{10}}`").
- **Counter-evidence**: sweeping **all 600** primitive elements of `F_{2^{10}}`, the function
  is APN for exactly **20** of them (in both the `x^10+x^3+1` and the Magma/Conway
  `x^10+x^6+x^5+x^3+x^2+x+1` representation) — two Frobenius orbits, not all primitives.
  Concretely, under `x^10+x^3+1` with `z = 2` the function has `δ = 4`; under the
  Conway/Magma polynomial with `z = 2` it has `δ = 2`. The `a`-parameter is irrelevant (APN for
  all 40 sampled `a ∉ F_{2^5}` once `z` is right).
- Example 1 also never says what `a` is; only Table III reveals `a = α`.
- **Impact on this repo**: anyone implementing Example 1 with VBF's default
  `primitive_polynomial(10)` and `z = 2` gets a non-APN function and concludes the paper is
  wrong. The correct statement is "with `z` the default generator of Magma's `GF(2^10)`".

### P3. No other issues

Theorem 3.3 items i, ii, iii, v, vi and vii were all verified at `m=5, n=10` (8 random
admissible `(a,b,c)` each, `δ=2` in every case, 0 failures). Corollary 1 cases 1) and 2) were
verified at `m=5, n=10` (15 random `(a,b)` each, in both field representations, 0 failures).
Remark 3.6's sporadic function `α Tr(x^3) + α^q Tr(α^{11} x^9)` is APN (`δ=2`). Item iii holds
at `m=3` too (`gcd(3,m)=3`), consistent with the theorem's hypothesis being only "`m` odd".

---

## Reproduction Issues

### 1. `verify_f15_conditions` imposes `gcd(3,m)=1`, which Theorem 3.3 iii) does not require

- **Location**: `theorem3_3.jl:36` (`cond_gcd3m = gcd(3, m) == 1`), documented as a condition
  at `theorem3_3.jl:26`, echoed in the report line `theorem3_3.jl:128`, and asserted in
  `test/test_theorem3_3.jl` (`@test r_cond.cond_gcd3m`).
- **Symptom**: Theorem 3.3's hypotheses are "`n = 2m`, `m ≥ 1` odd, `a ∉ F_q`, `bc ≠ 0`, `s`
  odd" plus item iii's "`s=3`, `b` non-cube, `c/b³ ∈ F*_{2^m}`". `gcd(3,m)=1` appears only in
  item **iv**. The reproduction would report `all_ok = false` for the perfectly valid
  `m = 3, 9, 15, …`. Counter-evidence: at `m=3, n=6`, 18 admissible `(a,b)` pairs all give
  `δ = 2`.
- **Root cause**: the condition was borrowed from a neighbouring item (or from the
  Budaghyan–Helleseth–Kaleyski family F14, which does need `3 ∤ m`).
- **Resolution plan**:
  1. Drop `cond_gcd3m` from `verify_f15_conditions`, or keep it as an informational field that
     does not enter `all_ok`.
  2. Update the docstring at `theorem3_3.jl:24-29` to list Theorem 3.3's actual hypotheses
     (`m` odd, `s=3` odd, `a ∉ F_q`, `bc ≠ 0`, `b` non-cube, `c/b³ ∈ F*_{2^m}`).
  3. Add `m = 3` to the `m_values` sweep as a cheap regression (`n=6`).
  4. Update `test/test_theorem3_3.jl` accordingly.

### 2. The `streaming` switch is dead code and the printed method label is wrong

- **Location**: `theorem3_3.jl:54` (`streaming::Bool = (2m >= 13)`), `:59`
  (`du = differential_uniformity(F)` — ignores `streaming`), `:60-62` (prints
  `"streaming row-by-row DDT"` or `"full DDT"`), plus the claims at `:11`, `:15`, `:49`, `:152`.
- **Symptom**: the same call is made either way. `VBF.differential_uniformity`
  (`packages/VBF/src/spectra/differential.jl:106-120`) is *always* row-by-row with a single
  `2^n` counts buffer — so the `"full DDT"` label printed for `n ≤ 12` is the inaccurate one,
  and the reported scope line "exact: APN at n=14 (streaming DDT, avoids OOM)" describes a
  mechanism that does not exist in the reproduction.
- **Root cause**: the kwarg was designed before it was discovered that core already streams.
- **Resolution plan**:
  1. Delete the `streaming` kwarg and its branch, or
  2. keep it only as a reporting note and change the label to
     `"VBF differential_uniformity (row-by-row, O(2^n) memory)"` for all `n`;
  3. fix the scope lines at `theorem3_3.jl:151-154` and `report.jl:22-25`.

### 3. The CCZ-inequivalence claim is checked against a 2-function slice of the catalog

- **Location**: `theorem3_3.jl:84` —
  `rows = filter(r -> r.is_quadratic, list_functions(db; is_apn = true, n = 10))`.
- **Symptom**: `n10_apn.toml` holds only `Gold x3`, `Gold x9`, `Kasami x57`, `Dobbertin x339`;
  only the two Golds are quadratic, so `apn_ea_mugshot` is compared against 2 functions. The
  paper's claim (Remark 3.4 + Table III) is inequivalence to **13** representatives, including
  F3 (two rows), F4 (two rows), the six Taniguchi F12 representatives, F14 (`s=3,7`), and
  Edel–Kyureghyan–Pott `x^3 + α^{341}x^{36}`. The printed check "F15 EA-mugshot distinct from
  all catalog n=10 APN [CCZ-inequiv proxy]" therefore overstates its evidence.
- **Root cause**: catalog coverage at `n=10` is thin and the script silently inherits it.
- **Resolution plan**:
  1. Add `table3.jl` constructing the Table III representatives directly from the tex (they
     are all explicit): `x^{2^i+1}` for `i=1,3`; `x^{57}`; `x^{339}`;
     `x^6+x^{33}+α^{31}x^{192}`; `x^{33}+x^{72}+α^{31}x^{258}`; `x^3+Tr_1^{10}(x^9)`;
     `x^3+α^{-1}Tr_1^{10}(α^3x^9)`; the six Taniguchi F12 instances (`VBF.taniguchi_apn` /
     `taniguchi_apn_representatives` already exist); `x^3+α^{341}x^{36}`; F14 with `s=3,7`.
  2. Compare `apn_ea_mugshot(F15)` against all of them and report the count of comparisons
     made, not just "all catalog".
  3. Print the number of representatives compared, so the check cannot silently degrade when
     the catalog is thin.
  4. Rename the check to "EA-mugshot distinct from the N Table III representatives".

### 4. Six of the seven items of Theorem 3.3, plus Theorem 3.10, Corollary 1, and both sporadic instances, are missing

- **Location**: only item iii exists (`helpers.jl:63` `f15_sbox`, `theorem3_3.jl`);
  `report.jl:39-41` declares Section 3B, the sporadic instances, and the `n=14` CCZ test out of
  scope.
- **Symptom**: the reproduction covers roughly one seventh of Section 3A plus Lemma 2.1. Yet
  everything except the code-isomorphism tests is cheap: items i, ii, iv, v, vi, vii,
  Corollary 1 (both cases) and the Remark 3.6 sporadic function were each verified at `n=10`
  in seconds.
- **Root cause**: scope set to the single "new family F15" headline.
- **Resolution plan**:
  1. Add `theorem3_3_all_items.jl` with a `zheng_fs(m,s,a,b,c)` builder and a per-item
     admissible-parameter generator for i…vii; assert `δ=2` over a seeded sample, with
     `limit`/`max_evaluations` knobs.
  2. Add an explicit item-iv note reproducing P1: emit witnesses for the *statement's*
     condition and show the *proof's* condition is empty (`3 | 2^{2s}−2^s+1` for odd `s`).
  3. Add `corollary1.jl` for `h_s(x) = a Tr(bx^3) + a^q Tr(g x^5 + e x^{4q+1})` cases 1) and
     2), asserting `δ=2` and mutual EA-inequivalence (their OD spectra differ:
     `{0:633733,…}` vs `{0:631811,…}`), plus the paper's claim that both land in Taniguchi's
     F12 (compare with `VBF.taniguchi_apn`).
  4. Add `example1.jl` and `remark3_6.jl` for the two Table III sporadic rows — and
     **hard-code the modulus and generator**, documenting P2 (only 20 of 600 primitive `z`
     work; use `conway_polynomial(10) = 0b10001101111` with `z = 2`).
  5. Add `remark3_4.jl` asserting the stated equivalences (vii ≅ `x^3`, vi ≅ i, v ∈ F10) via
     mugshots.

### 5. `print_header` bypasses `print_banner`

- **Location**: `helpers.jl:15-20` hand-rolls `"=" ^ 72` banners.
- **Root cause**: boilerplate drift.
- **Resolution plan**: use `VBF.print_banner(io, title, venue)` as
  `papers/2022/Li_202207/helpers.jl:17` does.

---

## Items Reproduced Exactly

| Item | Evidence |
|------|----------|
| **F15 / Theorem 3.3 iii)** `f_3(x) = a Tr_m^n(b x³) + a^q Tr_m^n(b³ x⁹)` | Expanded correctly to `(ab)x³ + (ab^q)x^{3q} + (a^q c)x^9 + (a^q c^q)x^{9q}` (`helpers.jl:35-52`). `δ = 2` verified at **n = 10** (full check) and **n = 14** (quadratic-APN kernel test, all 16383 directions) with `a = b = 2`, `c = b³`, matching `results/theorem3_3.toml` (`n10_du = 2`, `n14_du = 2`) |
| **Parameter family validated beyond the reproduction's single point** | 12 random `(a, b, λ)` with `a ∉ F_{2^5}`, `b` non-cube, `c = λ b³`, `λ ∈ F*_{2^5}` — all `δ = 2`, 0 failures |
| **Theorem 3.3's side conditions** | `a ∉ F_q` via `in_subfield`, `b` non-cube via `gf_is_dth_power(b,3,n)` — correct use of core, and both hold for the defaults (`a = b = 2` is primitive under `primitive_polynomial(2m)`) |
| **Lemma 2.1** | The `P`/`Q` split `B_s(x,u) = a·P + a^q·Q` with `P, Q ∈ F_{2^m}` and `a + a^q ≠ 0 ⇒ (B=0 ⟺ P=Q=0)` is a faithful restatement; `lemma2_1_is_apn` cross-checks against `differential_uniformity`, and the tests verify `P, Q ∈ F_{2^m}`, symmetry, and the trivial solutions `x ∈ {0,u}` |

## Test Results

| Command | Result |
|---------|--------|
| `make -C papers/2022/Zheng_202211 test` | **Not run** — `julia` is not installed in the review environment |
| Committed `results/report.toml` | `lemma2_1_agree = true`, `lemma2_1_du = 2`, `theorem3_3_conditions_ok = true`, `theorem3_3_apn_ok = true` |
| Committed `results/theorem3_3.toml` | `n10_du = 2`, `n14_du = 2` |
| Independent re-verification: F15 `δ=2` at `n=10` (both moduli) and `n=14`; items i–vii at `m=5`; item iii at `m=3`; Corollary 1 both cases; Remark 3.6 sporadic; Example 1 primitive-element sweep (20/600) | **All confirmed** |

## Catalog Status

`n10_apn.toml` contains only 4 monomials (`Gold x3`, `Gold x9`, `Kasami x57`,
`Dobbertin x339`). Quadratic OD differential spectra at `n=10`:
`Gold x3 = {0:595386, 2:416361, 6:35805}`,
`Gold x9 = {0:713031, 2:211761, 4:92070, 6:15345, 8:5115, 12:10230}`.

| Claimed-new object | Formula | APN verified | Family validated | Novelty checked | Catalog status |
|---|---|---|---|---|---|
| F15 (Thm 3.3 iii), `n=10` | yes | yes (`n=10`, `n=14`) | yes (12 random admissible params) | partial (2 catalog functions only) | **missing** |
| Remark 3.6 sporadic, `n=10` | no | — | — | no | **missing** |
| Example 1 sporadic, `n=10` | no | — | — | no | **missing** |
| Corollary 1 case 1, `n=10` | no | — | — | — | missing, but the paper says ≅ Taniguchi F12 |
| Corollary 1 case 2, `n=10` | no | — | — | — | missing, but the paper says ≅ Taniguchi F12 |

### Catalog-gap record 1

```
target file      : packages/VBFCatalog/data-raw/apn_catalog/n10_apn.toml
name             = "n10_Zheng2022_F15"
n = 10, m = 10, is_permutation = false
algebraic_form   = "a*Tr_5^10(b*x^3) + a^32*Tr_5^10(b^3*x^9) = (a*b)x^3 + (a*b^32)x^96 + (a^32*b^3)x^9 + (a^32*b^96)x^288 in GF(2^10), a = b = 2 (primitive), modulus x^10+x^3+1 (=1033)"
bib_key          = "Zheng_202211"
source           = "Zheng, Kan, Li, Peng, Tang (2022), 'Constructing new APN functions through relative trace functions', Theorem 3.3 item iii) = family F15 of Table II (new). LUT from papers/2022/Zheng_202211/helpers.jl f15_sbox(5; a=2, b=2)."
lut              : generate with f15_sbox(5; a = 2, b = 2, modulus = primitive_polynomial(10))  [1024 entries]
equivalence evidence:
  differential_uniformity = 2 (verified n=10 exhaustively; the family also verified APN at n=14)
  algebraic_degree = 2
  ortho-derivative differential spectrum = {0:624216, 2:334986, 4:76725, 6:11160, 8:465}
    (identical under modulus 1033 and under Conway 1135, as expected for a CCZ invariant)
  distinct from every existing n10_apn.toml entry:
    n10_Gold_x3      {0:595386, 2:416361, 6:35805}
    n10_Gold_x9      {0:713031, 2:211761, 4:92070, 6:15345, 8:5115, 12:10230}
    n10_Kasami_x57   (not quadratic)
    n10_Dobbertin_x339 (not quadratic)
  note: the paper claims CCZ-inequivalence to all 13 Table III representatives; only
        the two catalog Golds were machine-checked here.
```

### Catalog-gap record 2

```
target file      : packages/VBFCatalog/data-raw/apn_catalog/n10_apn.toml
name             = "n10_Zheng2022_rem36_sporadic"
n = 10, m = 10, is_permutation = false
algebraic_form   = "z*Tr_5^10(x^3) + z^32*Tr_5^10(z^11*x^9) in GF(2^10), z = 2 primitive, modulus x^10+x^6+x^5+x^3+x^2+1 (Conway, =1135)"
bib_key          = "Zheng_202211"
source           = "Zheng et al. (2022), Table III row 'sporadic, see Remark 3.6' (b = 1 a cube, c = z^11 with c^4/b in U; property P_{m-2})."
lut              : generate as [ z*Tr(x^3) + z^32*Tr(z^11*x^9) ] over modulus 1135, z = 2
equivalence evidence:
  differential_uniformity = 2 (verified exhaustively)
  ortho-derivative differential spectrum = {0:640491, 2:304296, 4:89280, 6:13020, 8:465}
  distinct from n10_Gold_x3, n10_Gold_x9, and from n10_Zheng2022_F15 above
```

### Catalog-gap record 3

```
target file      : packages/VBFCatalog/data-raw/apn_catalog/n10_apn.toml
name             = "n10_Zheng2022_ex1_sporadic"
n = 10, m = 10, is_permutation = false
algebraic_form   = "z*Tr_5^10(x^3) + z^32*Tr_5^10(z*x^5 + z^369*x^129) in GF(2^10), z = 2, modulus x^10+x^6+x^5+x^3+x^2+1 (Conway/Magma default, =1135)"
bib_key          = "Zheng_202211"
source           = "Zheng et al. (2022), Example 1 / Table III last row (b=1, g=z, e=z^369)."
lut              : generate as above over modulus 1135 with z = 2
equivalence evidence:
  differential_uniformity = 2 (verified exhaustively, Conway representation)
  ortho-derivative differential spectrum = {0:632431, 2:322958, 4:77562, 6:13020, 8:1333, 10:186, 12:62}
  distinct from n10_Gold_x3, n10_Gold_x9, n10_Zheng2022_F15, n10_Zheng2022_rem36_sporadic
  CRITICAL: the modulus and generator are load-bearing. Under VBF's default
  primitive_polynomial(10) = x^10+x^3+1 with z = 2 this function has
  differential_uniformity = 4. Only 20 of the 600 primitive elements yield an
  APN function in either representation (see Paper Issue P2).
```

## Library-Reuse Note

Duplicates a core export:

- `zheng_lut` — `helpers.jl:35-52` — is a hand-rolled 4-term univariate polynomial LUT
  builder, exactly `VBF.terms_to_lut(terms, n, modulus; powtab)`
  (`packages/VBF/src/representations/univariate.jl:331`, exported at `exports.jl:21`). Fix
  target: `terms_to_lut([(ab,3),(abq,3q),(aqc,2^s+1),(aqcq,(2^s+1)q)], n, modulus)`, which
  also gets `monomial_power_table` amortisation for free at `n = 14`.
- `print_header` — `helpers.jl:15-20` — should call `VBF.print_banner`.

Legitimately paper-specific (not flagged): `bilinear_components` and `lemma2_1_is_apn`
(`lemma2_1.jl:29-107`) implement Lemma 2.1's specific `(P,Q)` subfield split, which core does
not have; `verify_f15_conditions` composes existing core predicates.

Good reuse already present: `in_subfield`, `gf_is_dth_power`, `differential_uniformity`,
`apn_ea_mugshot`, `primitive_polynomial`, `print_section`/`print_check`/`print_kv`,
`load_catalog`/`list_functions`/`load_sbox`.

Promote-to-core candidate: a relative-trace-form LUT builder
`trace_form_lut(a, F_terms, G_terms, m, n)` for `a·Tr_m^n(F(x)) + a^q·Tr_m^n(G(x))` — this
shape recurs across the Zheng, Budaghyan–Helleseth–Kaleyski (F14) and Taniguchi (F12)
reproductions. Alternatively, just use `gf_relative_trace` (already exported) inside
`terms_to_lut`.

## Open Questions

1. `report.jl:22-25` and `theorem3_3.jl:151-154` describe the scope as "exact: APN at n=14
   (streaming DDT)". Should the scope statement be rewritten now that core always streams
   (issue 2)?
2. Should the reproduction pin the Magma/Conway modulus (`conway_polynomial(10) = 1135`)
   globally, given that Table III and Example 1 are only correct in Magma's default field
   (P2)? `helpers.jl:36` currently defaults to `primitive_polynomial(2m)`.
