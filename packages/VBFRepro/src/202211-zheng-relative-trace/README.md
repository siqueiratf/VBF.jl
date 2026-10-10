# Zheng_202211 — Constructing New APN Functions Through Relative Trace Functions

**Paper**: Zheng, Kan, Li, Peng, Tang. "Constructing New APN Functions Through Relative Trace
Functions." 2022.

**Reproduction path**: `packages/VBFRepro/src/202211-zheng-relative-trace/`

**Verdict**: Partial

Only item iii) of Theorem 3.3 (family F15) is implemented, and it carries an extra
`gcd(3,m)=1` condition the theorem does not require — which excludes a valid m=3 instance
that is verifiably APN. Six of the seven theorem items, an entire second results section
(Corollary 1 / Theorem 3.10 and the Appendix), both sporadic instances, all of Table III, and
Lemmas 3.1/3.2 are missing. Every one of those runs in seconds and was verified here. The
novelty check compares against an n=10 catalog that lacks 7 of the paper's own 13 Table III
representatives. Two genuine flaws in the publication were found, both of which this
reproduction is well-placed to document.

---

## Paper Issues

### 1. Theorem 3.3 item iv): the statement and the proof use different, non-equivalent conditions, and Remark 3.8 is false for the stated one

- **Location**: Theorem 3.3 iv) at `.tex:316` states `c / b^{2^{2s}−2^s+1} ∈ F_{2^m}`; the
  proof of iv) at `.tex:372` and `.tex:389-397` uses `c^{2^{2s}−2^s+1} / b ∈ F_{2^m}^*`.
  Remark 3.8 (`.tex:455`) asserts "there does not exist elements satisfying the conditions in
  iv)".
- **Computed counter-evidence** at n=10, m=5, s=7 (`3s ≡ 1 mod 10`),
  `E = 2^14 − 2^7 + 1 = 16257`:
  - *Proof's condition*: an **exhaustive** scan over all 682 non-cube `b ∈ F*_{2^10}` × all
    1022 `c` finds **zero** admissible pairs → Remark 3.8 is correct for this reading.
  - *Theorem-statement condition*: admissible pairs are plentiful, e.g.
    `(b,c) = (72,63), (928,1), (205,27), (738,29), (721,13), (897,63), (637,44), (66,8)`, and
    **all 8 give δ = 2** → Remark 3.8 is **false** for the reading printed in the theorem.
- **Short proof of the vacuity**, which the paper does not give: for odd `s`, `2^s ≡ 2` and
  `2^{2s} ≡ 1 (mod 3)`, so `3 | E`. Hence `c^E` is always a cube; since
  `gcd(3, 2^m−1) = 1` for odd `m`, every element of `F*_{2^m}` is a cube; therefore
  `c^E/b ∈ F*_{2^m}` forces `b` to be a cube, contradicting "b non-cube". The proof of iv)
  thus derives "c is a non-cube" from a hypothesis that can never be met.

### 2. Example 1 / the last row of Table III is stated for an arbitrary primitive element, but is not invariant under that choice

- **Location**: Example 1 (`.tex:648-654`) — "Let z be a primitive element in `F*_{2^10}`.
  Then `h_s(x) = a Tr(bx³)+a^q Tr(gx⁵+ex^{4q+1})` is APN over `F_{2^10}`, where `b=1, g=z,
  e=z^369`" — and the corresponding Table III row (`.tex:703`).
- **Computed counter-evidence** over `GF(2^10)` with modulus `x^10+x^3+1`: of the **600**
  primitive elements `z`, only **20** give δ=2 (e.g. `z = 23, 41, 42, 61, 72, 77, 98, 100,
  117, 277, …`). For `z = 2` — the generator itself — the function has **δ = 4**, i.e. it is
  not APN.
- **Control**: the other sporadic instance of the paper (Remark 3.6, `.tex:701`) is APN for
  **all 600** primitive `α`, so this is specific to Example 1's exponent 369 (and to whichever
  `z` and modulus the authors' Magma session happened to use), not a general artefact of the
  representation used here.

### 3. Editorial contradiction in Remark 3.11

- **Location**: Remark 3.11 (`.tex:526`) writes "We expect that Γ does indeed empty for any
  odd positive integer m", which contradicts both the preceding sentence ("Numerical
  experiments suggest that Γ is always nonempty", `.tex:520`) and Open Problem 2 ("Show that
  Γ is always nonempty", `.tex:528`).

---

## Reproduction Issues

### 1. `verify_f15_conditions` imposes `gcd(3,m)=1`, which Theorem 3.3 iii) does not require

- **Location**: `theorem3_3.jl:36` (`cond_gcd3m = gcd(3, m) == 1`), folded into `all_ok` at
  `:41`; also asserted in `test/test_theorem3_3.jl` (`@test r_cond.cond_gcd3m`) and stated in
  the file header comment (`theorem3_3.jl:7`) and `helpers.jl:32`.
- **Symptom**: Theorem 3.3 (`.tex:312`) requires only "n=2m, m ≥ 1 **odd**, a ∉ F_q, bc ≠ 0,
  s odd" plus iii)'s "b non-cube, c/b³ ∈ F_{2^m}". `gcd(3,m)=1` appears **only** in item iv).
  Table II's F15 row (`.tex:266`) likewise lists only "m odd, a ∉ F_q, b not a cube".
  Counter-evidence: `m=3` (n=6, `gcd(3,3)=3`), `a=2`, `b=2`, `c=b³=8`, modulus `x⁶+x+1`:
  `a ∉ F_{2^3}` ✔, `b` non-cube ✔, `c/b³ = 1 ∈ F*_{2^3}` ✔, and **δ = 2, deg = 2** — but
  `verify_f15_conditions(3, 2, 2).all_ok == false`.
- **Root cause**: condition iv)'s `gcd(3,m)=1` was mis-attributed to iii).
- **Resolution plan**:
  1. Drop `cond_gcd3m` from `verify_f15_conditions`'s `all_ok`, or make it an informational
     field.
  2. Fix the header comment and `helpers.jl:32`.
  3. Extend `m_values` to `[3,5,7]` and add a regression test asserting δ=2 at m=3.
  4. If `gcd(3,m)=1` is wanted for item iv), add it in a dedicated `theorem3_3_case_iv`
     routine.

### 2. Six of the seven Theorem 3.3 items are missing

- **Location**: `theorem3_3.jl` implements only case iii). `zheng_lut(m, s, a, b, c)`
  (`helpers.jl:35`) is already general in `s`, so the gap is purely in the driver and the
  condition predicates.
- **Symptom**: `theorem3_3_report` prints only the F15 line; `results/theorem3_3.toml`
  records only `n10_du` and `n14_du`.
- **Root cause**: a scope decision, not documented as such — `report.jl` lists only
  "Hexanomial families" and "sporadic instances" as out of scope; items i, ii, iv, v, vi, vii
  are not mentioned.
- **Resolution plan**:
  1. Add a `case_conditions(m, s)` table encoding i)-vii)'s `(s, predicate(b,c))`.
  2. Loop `zheng_lut` over sampled admissible `(b,c)` per case and assert δ=2.
  3. Add Remark 3.4's four equivalence assertions via `apn_ea_mugshot`.
  4. Add case iv) under **both** readings, asserting the theorem-statement reading is
     non-empty while the proof reading is empty — documenting paper issue 1.

### 3. Corollary 1, Theorem 3.10, Lemmas 3.1/3.2, Example 1, Remarks 3.4-3.8 and Table III are absent

- **Location**: no file covers Section 3B or Section 4.
- **Symptom**: the paper's second and third headline results (two infinite hexanomial
  families) and both sporadic instances have no executable counterpart.
- **Root cause**: scope.
- **Resolution plan**:
  1. Add `corollary1.jl` building `a Tr(bx³)+a^q Tr(gx⁵+ex^{4q+1})` for both parameter sets,
     asserting δ=2 and `apn_ea_mugshot` equality with `n10_Taniguchi_m1_a1_b6` / `_b7`, plus
     mutual inequality.
  2. Add `lemma3_1.jl` and `lemma3_2.jl` as exhaustive predicate checks (cheap at n=6,10,14).
  3. Add `table3.jl` building all 13 Table III representatives and asserting pairwise mugshot
     distinctness.
  4. Add `example1.jl` with the primitive-element scan documenting paper issue 2.

### 4. Lemma 2.1 is exercised on only one `(F, G)` pair, and is re-parametrised

- **Location**: `lemma2_1.jl:29` (`bilinear_components`) and `:56` (`lemma2_1_is_apn`)
  hard-code `F=bx³, G=cx^{2^s+1}`, and index by `(x,u)` rather than the paper's `(x,d)` with
  `Δ_{d,F}(x) = F(dx)+F(dx+d)+F(d)`.
- **Symptom**: the file's stated claim is Lemma 2.1 ("F, G arbitrary quadratic, iff"), but
  the code only tests one instance; the "iff" direction (a non-APN case) is exercised only by
  the degenerate `c=0`.
- **Root cause**: specialisation. The re-parametrisation itself is sound — `x ↦ dx` is a
  bijection — so the check is mathematically equivalent, just not readable side-by-side with
  `.tex:172-181`.
- **Resolution plan**:
  1. Generalise `bilinear_components` to take `F, G` as closures or `(coef, exp)` term lists.
  2. Add a randomised agreement test
     `lemma2_1_criterion(F,G,a) == (differential_uniformity == 2)` over random quadratics at
     n=6 — exactly this was run here: 60/60 agree.
  3. Rename to `(x, d)` to mirror the paper.

### 5. The `streaming` keyword is dead and the printed method label is wrong

- **Location**: `theorem3_3.jl:54` (`streaming::Bool = (2m >= 13)`), `:59-62`.
- **Symptom**: both branches execute the identical `differential_uniformity(F)`; only
  `method_tag` changes. The n=10 report line prints "[full DDT]", but
  `differential_uniformity` (`packages/VBF/src/spectra/differential.jl:106-120`) never
  materialises a DDT matrix — it is row-by-row for every `n`. So the report attributes two
  different algorithms to one code path, and mislabels the `n ≤ 12` one.
- **Root cause**: a leftover parameter.
- **Resolution plan**:
  1. Delete the `streaming` kwarg, and the `test_theorem3_3.jl` call site passing
     `streaming = false`.
  2. Print a single accurate label, e.g. `"row-by-row DDT (VBF differential_uniformity)"`.
  3. If a genuine memory-bounded path is wanted at `n ≥ 16`, add it to core rather than to
     the paper.

### 6. The CCZ-inequivalence proxy is far weaker than the paper's Table III claim

- **Location**: `theorem3_3.jl:83-91` —
  `filter(r -> r.is_quadratic, list_functions(db; is_apn=true, n=10))`.
- **Symptom**: the comparison set is the **11** quadratic n=10 catalog entries
  (`n10_Gold_x3/x9/i7/i9`, `n10_Kasami_i9`, `n10_Taniguchi_m1_a1_b1/b6/b7`,
  `n10_Taniguchi_m2_a1_b1/b8/b9`). The paper's Table III also contains two F3
  representatives, two F4 representatives, two F14 (Budaghyan–Helleseth–Kaleyski)
  representatives and the Edel–Kyureghyan–Pott sporadic `x³+α³⁴¹x³⁶` — **none of which is in
  the catalog**. So `distinct_from_all = true` currently means "distinct from
  Gold/Kasami/Taniguchi", not "new".
- **Root cause**: reliance on catalog coverage that does not exist at n=10.
- **Resolution plan**:
  1. Build the seven missing Table III representatives locally — all verified APN here — and
     include them in the comparison.
  2. Keep the catalog scan as an additional check.
  3. State explicitly in the report that mugshot distinctness certifies CCZ-inequivalence
     only because both sides are quadratic APN (Yoshiara).

### 7. Invalid justification for the `b=2` default

- **Location**: `helpers.jl:61` — "b=2: non-cube when 3 | 2^n−1 (holds for all n here since
  3 | 2^{2m}−1)".
- **Symptom**: `3 | 2^n − 1` only guarantees that non-cubes *exist*; it says nothing about
  `2`. The default happens to be safe because `2` is primitive under both
  `PRIMITIVE_POLYNOMIALS[10] = x^10+x^3+1` and `PRIMITIVE_POLYNOMIALS[14]` (both confirmed to
  have `2` of full order), and `verify_f15_conditions` re-checks with `gf_is_dth_power` at
  runtime.
- **Resolution plan**: replace the comment with "2 is a generator under this modulus, hence
  `log(2)=1 ≢ 0 (mod 3)`, hence non-cube — re-checked at runtime by `gf_is_dth_power`".

---

## Items Reproduced Exactly

| Paper item | Status |
|------------|--------|
| Theorem 3.3 **item iii)** = family F15, `f₃(x)=a·Tr(bx³)+a^q·Tr(b³x⁹)` | fully reproduced; APN verified at n=10 (δ=2) and n=14 (repository: δ=2; an independent 400-direction sample at n=14: max DDT = 2) |
| Lemma 2.1, *instantiated* for `F=bx³, G=cx^{2^s+1}` | partially reproduced (reproduction issue 4) |
| Table II, F15 row (function form and conditions) | reproduced, except for the added `gcd(3,m)=1` (reproduction issue 1) |
| "new up to CCZ" (Tables II/III) | partially — mugshot versus catalog only (reproduction issue 6) |

### Verified as reproducible but not implemented

All of the following were computed at n=10 and each runs in seconds:

| Missing item | Independent result |
|--------------|--------------------|
| Thm 3.3 i) (s=m−2=3, `c⁴/b ∈ F_q`) | 8/8 sampled `(b,c)` → δ=2; a **single** ortho-derivative class |
| Thm 3.3 ii) (s=(m−2)⁻¹ mod n = 7) | 8/8 → δ=2; single class |
| Thm 3.3 iii) (s=3, `c/b³ ∈ F_q`) | 8/8 → δ=2; single class |
| Thm 3.3 v) (s=m=5, `c ∉ F_q`) | 8/8 → δ=2 |
| Thm 3.3 vi) (s=m+2=7, `bc ∈ F_q`) | 8/8 → δ=2 |
| Thm 3.3 vii) (s=n−1=9, `c²/b ∉ F_q`) | 8/8 → δ=2 |
| Remark 3.4: i) ≡ BHK F14 (s=3) | ortho-derivative signatures **equal** ✔ |
| Remark 3.4: ii) ≡ F14 (s=7) | equal ✔ |
| Remark 3.4: vi) ≡ i) | equal ✔ |
| Remark 3.4: vii) ≡ Gold `x³` | equal ✔ |
| Remark 3.4: iii) ≠ i) | **distinct** ✔ — this is the novelty of F15 |
| Lemma 3.1 | n=6/10/14: the hypothesis holds for 13/61/253 values of `c`; **0** counterexamples |
| Lemma 3.2 | n=10 (s=7): 122 `x`, 0 counterexamples; n=14 (s=5): 506 `x`, 0 counterexamples |
| Lemma 2.1 as a *general* iff | 60/60 random quadratic `(F,G)` with random `a ∉ F_q` at n=6 |
| Corollary 1, case 1 (`g=1, e=1/b^{2q−2}`) | δ=2; ortho-derivative class = **`n10_Taniguchi_m1_a1_b6`** |
| Corollary 1, case 2 (`g=e=b`) | δ=2; class = **`n10_Taniguchi_m1_a1_b7`**; distinct from case 1 |
| Remark 3.4's "exactly 6 CCZ-inequivalent Taniguchi F12 over `F_2^10`" (Kaspers–Zhou) | reproduced: 11 valid `β` in `F₃₂` per `i ∈ {1,2}`; **exactly 6** ortho-derivative classes (sizes 1,5,5,1,5,5) |
| Remark 3.6 sporadic (`α Tr(x³)+α^q Tr(α¹¹x⁹)`) | δ=2 for **all 600** primitive `α`; class absent from the catalog |
| Table III, 13 rows | 12/13 reproduce as APN with pairwise-distinct ortho-derivative classes; the 13th is Example 1 (paper issue 2) |

**Also missing**: Theorem 3.9, Theorem 3.10 (both parts plus the whole Appendix), Corollary 1
(the two infinite hexanomial families), Example 1, Remarks 3.5, 3.7, 3.8, and Open Problems
1-3.

## Test Results

Executed 2026-08-15 on Julia 1.12.6 (project `/home/tiago/VBF.jl`, fully instantiated).

```
make -C packages/VBFRepro/src/202211-zheng-relative-trace test
```

- **Exit code**: `0`
- **Wall time**: `5 s` (includes `Pkg.instantiate()`)

| Testset | Pass | Broken | Fail | Total | Time |
|---------|-----:|-------:|-----:|------:|-----:|
| `lemma2_1_test` | 31 | 0 | 0 | 31 | 0.6 s |
| `theorem3_3_test` | 12 | 0 | 0 | 12 | 2.7 s |
| **Total** | **43** | **0** | **0** | **43** | — |

Both committed artifacts were regenerated from a fresh run and match in value:
`results/report.toml` (`lemma2_1_agree=true`, `lemma2_1_du=2`, `theorem3_3_conditions_ok=true`,
`theorem3_3_apn_ok=true`) and `results/theorem3_3.toml` (`all_conditions_ok=true`,
`all_apn_ok=true`, `n10_du=2`, `n10_is_apn=true`, `n14_du=2`, `n14_is_apn=true`).
`theorem3_3_report(m_values=[5,7])` runs in 14.8 s end-to-end; `lemma2_1_report` with the
exhaustive `u` loop at n=10 runs in 2.0 s.

**Coverage caveat**: `make test` exercises only m=5 (n=10). The `n14_du = 2` value in
`results/theorem3_3.toml` is produced by `make theorem3_3 save_results=true`, not by the test
suite, and no testset asserts the headline novelty result
(`table2_mugshot_comparison(...).distinct_from_all`) — `test_theorem3_3.jl` only checks
`μ.kind == :quadratic`. A `make test` pass therefore proves neither of the paper's headline
claims.

All ~35 load-bearing values previously derived in Python were re-checked against the
repository's own Julia API: **zero disagreements**.

## Catalog Status

| Claimed-new object | Status | Evidence |
|--------------------|--------|----------|
| **F15** `a Tr(bx³)+a^q Tr(b³x⁹)`, n=10 (Table II "new", Table III row 11) | **missing** | δ=2, deg=2; ortho-derivative DDT `{0:625239, 2:334986, 4:76725, 6:11160, 8:465, 1024:1}` matches none of the 11 quadratic n=10 catalog entries, and is distinct from all 12 other Table III rows built here |
| **Remark 3.6 sporadic** `α Tr(x³)+α^q Tr(α¹¹x⁹)`, n=10 (Table III row 12) | **missing** | δ=2 for all 600 primitive `α`; ortho-derivative DDT `{0:641514, 2:304296, 4:89280, 6:13020, 8:465, 1024:1}` — no catalog match |
| **Example 1 sporadic**, n=10 (Table III row 13) | **missing** (with a *valid* primitive) | with `z=23`, modulus 1033: δ=2, ortho-derivative DDT `{0:633454, 2:322958, 4:77562, 6:13020, 8:1333, 10:186, 12:62, 1024:1}` — no catalog match. See paper issue 2 for the primitive-element caveat |
| **Corollary 1 case 1** (`g=1, e=1/b^{2q−2}`) | **not-new** | class = `n10_Taniguchi_m1_a1_b6` — matching the paper's own admission that these lie in family F12 |
| **Corollary 1 case 2** (`g=e=b`) | **not-new** | class = `n10_Taniguchi_m1_a1_b7` |

### Catalog-gap records (3 entries)

```
target file : packages/VBFCatalog/data-raw/apn_catalog/n10_apn.toml

[[apn_functions]]
name = "n10_Zheng2022_F15"
n = 10, m = 10, is_permutation = false
algebraic_form : "a*Tr_5^10(b*x^3) + a^q*Tr_5^10(b^3*x^9) over GF(2^10), q=2^5,
                  a = b = alpha (primitive, = 2), modulus x^10+x^3+1 (=1033);
                  expands to (ab)x^3 + (a b^q)x^{96} + (a^q b^3)x^9 + (a^q b^{3q})x^{288}"
bib_key : Zheng_202211
source  : Zheng, Kan, Li, Peng, Tang (2022), Theorem 3.3 item iii) / Table II family F15 /
          Table III row 11. Verified APN (differential_uniformity=2, algebraic_degree=2).
          Also APN and quadratic at n=6 (m=3) and n=14 (m=7).
lut : first 16 = [0,493,380,968,95,827,698,647,456,681,363,339,202,290,1008,321]
      sha256(csv)[:16] = 35647e6265573ef6   (regenerate via packages/VBFRepro/src/202211-zheng-relative-trace/helpers.jl
      f15_sbox(5; a=2, b=2, modulus=1033))
equivalence evidence : OD-DDT = {0:625239, 2:334986, 4:76725, 6:11160, 8:465, 1024:1};
      distinct from all 11 quadratic n=10 catalog entries and from Gold x^3/x^9, F3, F4,
      F14(s=3), F14(s=7), the Edel-Kyureghyan-Pott sporadic, all 6 Taniguchi F12 classes,
      and both Corollary-1 families.

[[apn_functions]]
name = "n10_Zheng2022_rem36_sporadic"
n = 10, m = 10, is_permutation = false
algebraic_form : "alpha*Tr_5^10(x^3) + alpha^q*Tr_5^10(alpha^11 * x^9) over GF(2^10),
                  alpha primitive (=2), modulus x^10+x^3+1 (=1033)"
bib_key : Zheng_202211
source  : Zheng et al. (2022), Remark 3.6 / Table III row 12 ("sporadic"). Verified APN
          for ALL 600 primitive elements alpha of GF(2^10) under this modulus.
lut : first 16 = [0,821,99,427,66,691,684,672,991,352,404,470,474,673,284,154]
      sha256(csv)[:16] = ecfee37f931b9bc5
equivalence evidence : OD-DDT = {0:641514, 2:304296, 4:89280, 6:13020, 8:465, 1024:1};
      no catalog match; distinct from F15 and from all Table III rows.

[[apn_functions]]
name = "n10_Zheng2022_ex1_sporadic"
n = 10, m = 10, is_permutation = false
algebraic_form : "z*Tr_5^10(x^3) + z^q*Tr_5^10(z*x^5 + z^369*x^{4q+1}) over GF(2^10),
                  q=2^5, modulus x^10+x^3+1 (=1033), z = 23 (a primitive element for which
                  the construction is APN -- NOT every primitive element works, see note)"
bib_key : Zheng_202211
source  : Zheng et al. (2022), Example 1 / Table III row 13. Verified APN
          (differential_uniformity = 2, algebraic_degree = 2).
note    : the paper states this for an arbitrary primitive z; under modulus 1033 only
          20 of the 600 primitive elements yield an APN function (z = 2 gives delta = 4).
lut : first 16 = [0,77,393,409,583,907,698,811,490,617,585,407,157,671,586,21]
      sha256(csv)[:16] = 679086b7512c226d
equivalence evidence : OD-DDT = {0:633454, 2:322958, 4:77562, 6:13020, 8:1333, 10:186,
      12:62, 1024:1}; no catalog match.
```

**Side note for a different reproduction**: the **BHK F14** representative at n=10
(`x³+ωx⁹+ω²x^{3q}+x^{9q}`, `ω=α³⁴¹`) is also APN and also absent from the catalog
(ortho-derivative DDT `{0:638724, 2:313131, 4:80910, 6:14415, 8:1395, 1024:1}`) — that
belongs to the `Budaghyan_202011` reproduction, not this one.

## Library-Reuse Note

| Helper | Line | Verdict |
|--------|------|---------|
| `zheng_lut` | `helpers.jl:35-52` | **reuse violation** — hand-rolls a 4-term polynomial evaluation with `gf_mul`/`gf_pow` per point. Should be `terms_to_lut([(ab,3),(abq,3q),(aqc,2^s+1),(aqcq,(2^s+1)q)], n, modulus)` (`packages/VBF/src/representations/univariate.jl:331`), optionally with a shared `monomial_power_table` |
| `lemma2_1_is_apn` power tables | `lemma2_1.jl:63-65` | **reuse violation** — `sq_lut`, `pow_s_lut` and `frob_lut` each duplicate `gf_monomial_lut(n, d; modulus)` (`packages/VBF/src/representations/finite_field.jl:252`) |
| `print_header` | `helpers.jl:15-20` | **reuse violation** — hand-rolls the `"="^72` banner; should call `print_banner`. The same pattern appears in 8+ other papers — a repo-wide cleanup candidate |
| `bilinear_components` | `lemma2_1.jl:29` | paper-specific, but see reproduction issue 4 (should be generic in `F`, `G`) |
| `verify_f15_conditions`, `f15_sbox` | — | legitimately paper-specific; correctly reuse `in_subfield` and `gf_is_dth_power` |
| `table2_mugshot_comparison` | `theorem3_3.jl:74` | correctly reuses `apn_ea_mugshot`, `load_catalog`, `list_functions`, `load_sbox` |
