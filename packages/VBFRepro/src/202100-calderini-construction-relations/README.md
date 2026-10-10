# Calderini_202100 — On Known Constructions of APN and AB Functions and Their Relation to Each Other

**Paper**: Calderini, Budaghyan, Carlet. "On known constructions of APN and AB functions
and their relation to each other." 2021.

**Reproduction path**: `packages/VBFRepro/src/202100-calderini-construction-relations/`

**Verdict**: Mostly complete

The widest coverage and the best library reuse of the 2021 batch: a file per theorem
mirroring the paper's numbering, exhaustive condition-⟺-APN checks where feasible, and no
helper duplicating a `VBF` export. Nine issues remain, mostly missing survey items. Two of
them — Proposition 7.5 and the Section 7 CCZ link — are declared expensive or unverifiable
when a cheap exact route exists; both are closable today with the evidence recorded below.
One genuine defect was found in the paper itself (Theorem 5.1's iff-condition is inverted).

> Every numeric claim below marked "independently confirmed" was re-derived from scratch in
> Python (GF(2^n) arithmetic, DDT, ANF degree, Walsh spectra, ortho-derivative invariants,
> Γ-rank) and then re-confirmed against this repository's own Julia API on 2026-08-15. The two
> derivations agree on all 28 checked values.

---

## Paper Issues

### 1. Theorem 5.1's iff-condition has the inclusion inverted — it must read `α ∉ S`

- **Location**: Section 5, Theorem 5.1 (attributed to [54], Zhou–Pott): "`F(x,y) = (xy, G(x,y))`
  is APN if and only if `α ∈ {u^{2^i+1}(t^{2^i}+t)^{1−2^j} : u, t ∈ F_{2^m}}`."
- **Computed counter-evidence** (`m = 4`, modulus `x⁴+x+1`, `i ∈ {1,3}`):
  - For `j = 0` and `j = 2`: `S∖{0} = {1,8,10,12,15}`, exactly the 5 nonzero **cubes**.
  - The APN `α` are `{2,3,4,5,6,7,9,11,13,14}`, exactly the 10 **non-cubes** — **disjoint
    from `S`**.
  - So the literal statement contradicts the theorem's own next sentence ("if `j` is even,
    then `F` is APN iff `α` is not a cube") and contradicts computation.
  - Consistency check for `j` odd (Remark 5.2): `S∖{0}` is all 15 nonzero elements, and
    **zero** `α` give APN (`j = 1` and `j = 3` both yield an empty APN list). Under the
    corrected reading `α ∉ S = ∅` this exactly reproduces Remark 5.2's "the family of
    Zhou–Pott is not defined then"; under the literal reading it would predict that *every*
    `α` works.
- **Severity**: real but local — the corrected reading is what the rest of the paper
  (Remark 5.2, Corollary 5.7) actually uses.

### 2. Section 6.1.3's "second case for `b=0`" is ambiguous or mis-numbered

- **Location**: Section 6.1.3 (n = 2·6), case `F₂`: "`k=4, r=2` is equivalent to the second
  case for `b=0`". The `b=0` cases are listed as `h=2, r=4` (first), `h=3, r=0` (second,
  "functions as in Theorem 6.2"), `h=5, r=4` (third).
- **Status**: the reproduction (`section6_1.jl:332-343` and `:531-534`) asserts the
  *empirical* match `F2(k=4,r=2) ≡ F1(b=0,h=2,r=4)` — the **first**-listed `b=0` case, not
  the Theorem-6.2 one — and documents the discrepancy. This could not be verified
  independently (the n=12 sweep is out of reach in Python), so it is recorded here as the
  reproduction's own claim rather than as confirmed counter-evidence.

---

## Reproduction Issues

### 1. Theorem 4.1 and Proposition 4.2 are not implemented

- **Location**: no file; `helpers.jl:58-92` implements only the *reduced* form
  `G' = x^{2^i+1} + a·x·y^{2^i} + b·y^{2^i+1}`.
- **Symptom**: Theorem 4.1's general four-parameter
  `G(x,y) = s x^{2^i+2^j} + u x^{2^i}y^{2^j} + v x^{2^j}y^{2^i} + t y^{2^i+2^j}` with its
  condition ("`G(X,1)` has no zero in `F_{2^m}`") and Proposition 4.2's reduction to `G'`
  (`k = i−j`, `a ∈ {0,1}`, `b ∈ F_{2^m}*`) are never built. `theorem4_4.jl` starts from the
  already-reduced form, so the reduction step — the link between Carlet's bivariate
  construction and Taniguchi's simplification — is assumed rather than shown.
- **Root cause**: only the downstream reduced form was ported.
- **Resolution plan**:
  1. Add `theorem4_1_sbox(m,i,j,s,u,v,t)` and `theorem4_1_condition`.
  2. Verify condition ⟺ APN exhaustively at `m = 3` (and `m = 4` for `i−j` coprime to `m`).
  3. Verify Proposition 4.2 by showing every APN Theorem-4.1 EA-mugshot appears among the
     reduced `G'` mugshots.

### 2. Theorem 5.1 is implemented only via its "in particular" clause; Remark 5.2 is unverified

- **Location**: `theorem5_1.jl:216` — `for i in is, j in (0, 2)`.
- **Symptom**: only even `j` is tested, and only against "non-cube ⟺ APN". The general set
  `S = {u^{2^i+1}(t^{2^i}+t)^{1−2^j}}` is never constructed, so neither Theorem 5.1's actual
  statement nor Remark 5.2's degeneracy argument is exercised — and paper issue 1 is
  therefore invisible to the reproduction.
- **Root cause**: the convenient corollary was implemented in place of the theorem.
- **Resolution plan**:
  1. Build `S` per the theorem.
  2. Assert `S = cubes` for `j` even and `S = F_{2^m}` for `j` odd (Remark 5.2) at
     `m = 4, 6`.
  3. Assert `APN ⟺ α ∉ S` for all `j`, and add a `# NOTE (paper issue)` comment recording
     the inverted inclusion.

### 3. Proposition 7.5 is skipped by default, untested, and absent from `report.jl`

- **Location**: `proposition7_5.jl:318` (`skip::Bool = true`); `report.jl:7-16` does not
  include `proposition7_5.jl`; `test/runtests.jl` has no `test_proposition7_5.jl`.
- **Symptom**: the paper's final result — Kaleyski–Li's Theorem 7.4 family is contained in
  Göloğlu's `F₂` — is never executed by `make report` or `make test`, only via the opt-in
  `make proposition7_5`.
- **Root cause**: the check was written as an `apn_ea_mugshot` comparison at n=10 and then
  skipped for cost.
- **Counter-evidence that the cost objection is unfounded**: the paper's own proof is an
  **exact identity**, and it was verified during this review: `L ∘ F_KL == F_G2` **as LUTs**
  at `(m,i,j) = (5,3,1)`, with `L(x,y) = (x^{2^{m−i}}, y)`. That is an `O(2ⁿ)` comparison —
  no mugshot at n=10 is needed. (The identity `2^{3(m−i)} = 2⁶ ≡ 2 (mod 2⁵−1)` from the
  proof also holds.)
- **Resolution plan**:
  1. Replace the mugshot comparison with the pointwise identity `L ∘ F_KL == F_G2` — cheap,
     and it *is* the paper's proof.
  2. Flip `skip` to `false`.
  3. Add `test/test_proposition7_5.jl`.
  4. Include it in `report.jl`.

### 4. `theorem6_2_sbox` / `theorem6_2_condition` accept invalid parameters

- **Location**: `helpers.jl:214-236` and `helpers.jl:329-345`.
- **Symptom**: Theorem 6.2 requires `n = 2m`, `m` **even**, `i < m/2`, `gcd(i,m) = 1`. Only
  `theorem6_2_report` (`theorem6_2.jl:29-31`) enforces them; the builders silently accept
  `m` odd, where `h = m ÷ 2` truncates and the formula is meaningless. The same applies to
  `bivariate_carlet_sbox`, `hexanomial_sbox`, `pentanomial_sbox`, `zhou_pott_sbox`,
  `f1_sbox` and `f2_sbox`, none of which guard `gcd(i,m) = 1` or `m` even.
- **Root cause**: hypotheses live in the report drivers rather than the builders.
- **Resolution plan**: move the `iseven(m)`, `i < m÷2` and `gcd(i,m) == 1` assertions into
  the builder and condition functions themselves.

### 5. `print_header` collides with the Göloğlu reproduction; include order is load-bearing

- **Location**: `theorem7_1.jl:115-116`, `theorem7_2.jl:213-214` and
  `proposition7_5.jl:281-282` each `include` `packages/VBFRepro/src/202207-gologlu-biprojective-apns/helpers.jl` —
  which defines its own `print_header` — *before* the Calderini `helpers.jl`, with an
  explicit comment at `proposition7_5.jl:280` that "ours must win".
- **Symptom**: correctness depends on include ordering and on repeated re-evaluation of the
  same file; reversing two lines silently prints the wrong banner. Cross-paper `include`
  also contradicts the `AGENTS.md` rule that shared math belongs in `packages/VBF/src/`.
- **Root cause**: `biprojective_sbox` was needed from another paper directory and was
  reached for directly instead of being promoted.
- **Resolution plan**:
  1. Promote `biprojective_sbox` to `packages/VBF/src/constructions/`.
  2. Drop both cross-paper includes.
  3. Rename the paper-local banner to `calderini_print_header`.

### 6. `kaleyski_li_sbox` re-implements `biprojective_sbox`, and its header comment states the wrong formula

- **Location**: `proposition7_5.jl:292-310`; comment at `proposition7_5.jl:267`.
- **Symptom**: `kaleyski_li_sbox(5,3,1)` was verified **identical** to
  `biprojective_sbox(5, 3, (1,1,0,1), 1, (0,1,1,0))` — a pure duplication. Separately, the
  header comment writes the Kaleyski–Li function as
  `(x^{2^i+1} + x^{2^i}y + y^{2^i+1},  x^{2^i+1} + x²y + xy²)`; Theorem 7.4's second
  component is `x²y + xy²` with **no** `x^{2^i+1}` term. The implementation is correct; the
  comment is not.
- **Root cause**: a local re-derivation of a function that already existed, plus a
  transcription slip in its documentation.
- **Resolution plan**:
  1. Delete `kaleyski_li_sbox` and call `biprojective_sbox`.
  2. Fix the header formula.

### 7. Corollary 5.7's `c'` uses `b` where the paper derives `b^{2^i}`

- **Location**: `theorem5_6.jl:261` — `F2k = f2_sbox(m, i, k2, r2, b_t; ...)`.
- **Symptom**: the proof of Corollary 5.7 ends at
  `(xy, x^{2^i+1} + x^{2^i}y^{2^{2i}} + b^{2^i} y^{2^{2i}+2^{3i}})`, i.e. `c' = b^{2^i}`,
  but the code passes `b_t`. The check only asserts EA-class equality, which may absorb the
  difference (and Proposition 4.5-style arguments make many `c'` equivalent) — but the
  literal transcription differs from the paper.
- **Root cause**: the Frobenius power was dropped when transcribing the corollary.
- **Resolution plan**: pass `gf_pow(b_t, 1<<i, m; modulus = mod_m)` and keep the mugshot
  assertion. If the check still passes with plain `b_t`, record that as an additional
  observation rather than keeping the wrong constant.

### 8. Remark 7.3, Remark 6.3's `F₁'`/`F₂'` normalisation, and the Sections 2-3 survey items are absent

- **Location**: no files; `helpers.jl:45` declares Tables 1-2 out of scope.
- **Symptom**: missing are Remark 7.3 (the explicit substitution `L(x,y) = (αx, x+y)`
  showing `F₂` is EA-equivalent to form (7.1) — a cheap, exact check at `m = 5`), Remark
  6.3's derived forms `F₁'`/`F₂'` (only APN-preservation under `(x,y) ↦ (y,x)` is checked,
  `section6_1.jl:181-186`), Table 1 (known APN power functions — covered by core
  constructors), Table 2 (the 15 known quadratic families F1-F15), and the
  Brinkmann–Leander–Edel–Pott n=6 univariate formula given in Section 3.
- **Root cause**: survey material treated as out of scope.
- **Resolution plan**:
  1. Add Remark 7.3 first — one substitution, exact LUT check.
  2. For Table 2, a `families.md` cross-reference naming the `VBF` constructor for each of
     F1-F15 is the cheapest faithful reproduction of a survey table.

### 9. Section 7's CCZ link to the Edel–Pott function is declared unverifiable — but it is verifiable

- **Location**: `section7_example.jl:431-432` — "no reference representative available in
  this repo".
- **Symptom**: the paper's central Section 7 claim (that `F'` is the unique known APN
  function CCZ-inequivalent to both quadratic and power functions) is left unchecked.
- **Root cause**: the check was framed as needing an external reference representative.
- **Counter-evidence**: Γ-rank is a CCZ-invariant and is computable at n=6 (a `4096 × 4096`
  F₂ rank). Computed during this review:

  | function | deg | Γ-rank |
  |----------|-----|--------|
  | `n6_Gold_x3` | 2 | 1102 |
  | `n6_Kasami_x48` | 2 | 1102 |
  | `n6_Kim` | 2 | **1166** |
  | `dillon_apn_permutation()` | 4 | **1166** |
  | Section 7 `F = (B,G)` | 2 | **1166** |
  | Section 7 `F' = (B,G+f)` | 3 | **1300** |

  So `F'` is CCZ-**inequivalent** to Kim/Dillon, Gold and Kasami, and `F` lies in the
  Kim/Dillon CCZ class. That is the essential content of the paper's claim.
- **Resolution plan**:
  1. Add the Γ-rank comparison to `section7_example.jl` (or use the repository's
     `gamma_rank`, noting the `n ≥ 8` design-rank guard does not apply at n=6).
  2. Add the Edel–Pott function to the catalog (see Catalog Status) and compare directly.

### 10. Minor: sampling scope and unused Makefile target

- `theorem5_4.jl` is explicitly a **seeded random sample** (150 tuples per `(m,i)`, seed
  24301) — honestly labelled, but Theorem 5.4's `m` odd branch is only exercised at `m = 3`.
- `section6_1_n10_sweep` (Section 6.1.2) and `section6_1_n12_sweep` (Section 6.1.3) are
  opt-in; Section 6.1.4 (n=16) is skipped with a documented cost estimate. All three are
  correctly labelled in `helpers.jl:36-44`.
- The `Makefile` has a `clean_results` target, but nothing in the reproduction ever writes a
  `results/` directory.

---

## Items Reproduced Exactly

| Item | Evidence |
|------|----------|
| Theorem 3.1 (hexanomial) | Formula in `helpers.jl:103-125` matches term-for-term. Independent check at `m=2` (16 cases) and `m=3` (128 cases): condition ⟺ APN with **0 mismatches**; 4 and 36 APN instances respectively |
| Theorem 4.3 (pentanomial) | Formula matches; same condition ⟺ APN with **0 mismatches** at `m = 2, 3` |
| Theorem 6.2 | Formula and condition `(cX^{2^i+1}+bX^{2^i}+1)^{2^{m/2}+1} + X^{2^{m/2}+1}` match. Exhaustive `m=4, i=1` over all 256 `(b,c)`: **0 mismatches**, **10 APN pairs** — exactly what `section6_1_report` expects |
| Theorem 6.2 novelty (Section 6.1.1) | The 10 APN pairs form **exactly one** EA class by ortho-derivative signature, distinct from Gold (2 classes), hexanomial (1), Taniguchi (3) and Zhou–Pott (2) at n=8 |
| Theorem 5.1, "in particular" clause | `m=4`, `i ∈ {1,3}`, `j ∈ {0,2}`: non-cube `α` ⟺ APN, **0 violations** in 60 cases |
| Theorem 7.2 (Göloğlu F1/F2) | `F1(m=4,i=1)`, `F1(m=5,i=1)`, `F2(m=5,i=1)`, `F2(m=5,i=2)` all `du = 2, deg = 2`. Out-of-hypothesis probes: `F1(m=3,i=1)` → `du = 16`, `F2(m=4,i=1)` → `du = 32`, the report's printed values |
| Proposition 7.5 | **Stronger than the repository's own check**: `L(x,y) = (x^{2^{m−i}}, y)` maps `F_KL(m=5,i=3,j=1)` to Göloğlu `F2(m=5,i=2)` **exactly as LUTs**, not merely up to EA. Both `du = 2` |
| Section 7 n=6 example | `F = (B,G)`: `du = 2`, `deg = 2`. `F' = (B, G+f)` with the 27-term switch: `du = 2`, `deg = 3`. All 27 `f`-terms transcribed correctly |
| Theorem 7.1 forms f1-f4 | Coefficient tuples at `theorem7_1.jl:153-172` match (7.1)-(7.4) exactly |
| Theorem 5.6 F1/F2/F3 | `f1_sbox`, `f2_sbox`, `zhou_pott_sbox` match the paper's canonical forms |

## Test Results

Reviewed 2026-08-15 with **Julia 1.12.6** (project instantiated and precompiled).

| | |
|---|---|
| Command | `make -C packages/VBFRepro/src/202100-calderini-construction-relations test` |
| Exit code | **0** |
| Wall time | **26 s** |
| Result | **101 / 101 pass, 0 fail, 0 broken** |

| Testset | Pass | Broken | Fail | Total | Time |
|---------|-----:|-------:|-----:|------:|-----:|
| `theorem3_1_test`       | 18 | 0 | 0 | 18 | 0.5s  |
| `theorem4_4_test`       | 16 | 0 | 0 | 16 | 3.7s  |
| `theorem5_1_test`       | 18 | 0 | 0 | 18 | 0.3s  |
| `theorem5_4_test`       |  5 | 0 | 0 |  5 | 0.6s  |
| `theorem5_6_test`       |  9 | 0 | 0 |  9 | 1.3s  |
| `theorem6_2_test`       |  9 | 0 | 0 |  9 | 0.2s  |
| `section6_1_test`       | 17 | 0 | 0 | 17 | 4.4s  |
| `theorem7_1_test`       |  4 | 0 | 0 |  4 | 12.1s |
| `theorem7_2_test`       |  2 | 0 | 0 |  2 | 0.2s  |
| `section7_example_test` |  3 | 0 | 0 |  3 | 0.1s  |
| **Total**               | **101** | **0** | **0** | **101** | **26s** |

`test/runtests.jl` has no `test_proposition7_5.jl`, so Proposition 7.5 is **not** covered by
this run (see reproduction issue 3).

The items the previous revision recorded as "not reachable in Python" were all executed
during this re-review:

| Item | Result (Julia 1.12.6, 2026-08-15) |
|---|---|
| `section6_1_report()` (n=8, exhaustive over `(h,k,r,b,c)`, `i=1`) | **PASS**, 4.4s in-test. 10 valid `(b,c)`, 1 EA class, 120 APN sweep instances = 90 hexanomial + 20 new + 10 Taniguchi; all 7 published Section 6.1.1 outcomes reproduced |
| `theorem7_1_report(m=3)` | **PASS**, 26.2s standalone. 43,904 APN instances in the normalized sweep → 2 EA classes; f1–f4 forms give 6,272 APN instances → the same 2 classes |
| `theorem4_4_report(m=3)` / `(m=4)` | **PASS**. `m=3`: pentanomial = hexanomial = bivariate-Carlet, 1 class each. `m=4`: same, plus Proposition 4.5 verified — all 10 non-cube `b` share one EA class, for both `i=1` and `i=3` |
| `section6_1_n12_report(deep=true)` (Section 6.1.3 targeted) | **PASS**, 41.7s. Settles paper issue 2 |
| `section6_1_n10_sweep` / `section6_1_n12_sweep` (aggregate) | still opt-in; **not run** in this review (documented cost) |

## Catalog Status

The paper claims **one new APN function** (Section 6.1.1 / Theorem 6.2 at n=8).

- Theorem 6.2 new n=8 class: **present** — `n8_Calderini2021_thm62` in
  `packages/VBFCatalog/src/entries/apn_catalog/n8_apn.toml` (parameters `m=4, i=1, b=1, c=6`,
  modulus 19). The catalog LUT was verified APN with `deg = 2`, and its ortho-derivative
  signature is exactly the single class produced by the 10 valid `(b,c)` pairs
  `{(1,6),(1,7),(8,4),(8,11),(10,2),(10,14),(12,3),(12,9),(15,5),(15,13)}`. Novelty versus
  Gold/hexanomial/Taniguchi/Zhou–Pott was independently confirmed; the paper's further claim
  of inequivalence to the external n=8 tables of [52] and [53] is **unverifiable** here
  (those corpora are not in the repository).
- Göloğlu F1/F2 (Theorem 7.2) and Kaleyski–Li (Theorem 7.4) are not claimed new by this
  paper (they are [41]/[43]); they belong to `Gologlu_202207`'s scope.

### Catalog-gap record (1 entry)

The Brinkmann–Leander–Edel–Pott n=6 function — the **only known APN function
CCZ-inequivalent to both quadratic and power functions** — is absent from `n6_apn.toml`,
which has only `n6_Gold_x3`, `n6_Kasami_x48` and `n6_Kim`. It is produced exactly by this
reproduction's `section7_example.jl` as `F' = (B, G+f)`.

```toml
name              = "n6_EdelPott_switch"
description       = "The Brinkmann-Leander-Edel-Pott n=6 APN function: the only known APN function CCZ-inequivalent to both quadratic and power functions. Obtained as the Section 7 bivariate switch F' = (B(x,y), G(x,y)+f(x,y)) over GF(2^3) x GF(2^3), with B(x,y)=x^3+y^3+x^2 y+a^9 x y^2, G(x,y)=a^54 x^5 + a^54 x y^4 + a^45 y^5 and the 27-term Boolean switch f of Calderini-Budaghyan-Carlet (2021) Section 7. Re-verified: differential_uniformity = 2, algebraic_degree = 3, is_permutation = false. Inequivalence evidence: Gamma-rank = 1300, versus 1166 for n6_Kim and dillon_apn_permutation() and 1102 for n6_Gold_x3 and n6_Kasami_x48 -- Gamma-rank is a CCZ-invariant, so this function is CCZ-inequivalent to every existing n=6 catalog entry."
n                 = 6
m                 = 6
is_permutation    = false
algebraic_form    = "Bivariate F'(x,y) = (B(x,y), G(x,y)+f(x,y)) over GF(2^3), modulus x^3+x+1 (=11), a = generator (x); packed z = x|(y<<3) -> B|(G+f)<<3. Univariate form (Calderini et al. 2021, Section 3): x^3 + a^17(x^17+x^18+x^20+x^24) + a^14 Tr_1^2(x^21) + a^14 Tr_1^3(a^18 x^9) + a^14 Tr_1^6(a^52 x^3 + a^6 x^5 + a^19 x^7 + a^28 x^11 + a^2 x^13)."
bib_key           = "Edel_200900"
source            = "Edel and Pott, Adv. Math. Commun. 3(1):59-81 (2009); independently found by Brinkmann and Leander, Des. Codes Cryptogr. 49(1-3):273-288 (2008) (bib key Brinkmann_200812). LUT reproduced from packages/VBFRepro/src/202100-calderini-construction-relations/section7_example.jl (section7_example_report), Section 7 of Calderini-Budaghyan-Carlet (2021)."
lut               = [0, 57, 27, 52, 45, 22, 15, 2, 49, 45, 21, 31, 44, 18, 49, 57, 19, 62, 52, 47, 4, 11, 58, 35, 12, 36, 20, 10, 11, 33, 10, 54, 61, 61, 33, 23, 15, 13, 10, 30, 46, 43, 13, 62, 12, 43, 54, 7, 31, 43, 63, 29, 55, 33, 46, 14, 34, 51, 61, 58, 58, 41, 28, 57]
```

Target file: `packages/VBFCatalog/src/entries/apn_catalog/n6_apn.toml`. Note that this LUT is
*not* a permutation and *not* injective — that is correct; it is the APN function, not
Dillon's permutation.

## Library-Reuse Note

Reuse is excellent. `gf_mul`, `gf_pow`, `gf_is_dth_power`, `primitive_polynomial`, `SBox`,
`differential_uniformity`, `algebraic_degree`, `apn_ea_mugshot`, `APNEAMugshot`,
`is_quadratic_apn_rank`, `gold_apn`, `kasami_apn`, `taniguchi_apn`,
`taniguchi_apn_representatives` and the `print_*` family are all used rather than
reimplemented. **No helper duplicates a `VBF` export.**

Flagged:

- `kaleyski_li_sbox` (`proposition7_5.jl:292`) duplicates `biprojective_sbox` — verified
  LUT-identical (reproduction issue 6).
- Cross-paper `include` of `packages/VBFRepro/src/202207-gologlu-biprojective-apns/helpers.jl` at `theorem7_1.jl:115`,
  `theorem7_2.jl:213` and `proposition7_5.jl:281` (reproduction issue 5).

Promote-to-core candidates:

- `biprojective_sbox(m, qi, coeff_f, rj, coeff_g)` → `packages/VBF/src/constructions/`;
  already used by two paper directories.
- The bivariate packer `(x,y) ↦ (xy, G(x,y))` with `index = x|(y<<m)` and
  `value = (xy)|(G<<m)` — repeated verbatim in `bivariate_carlet_sbox`, `zhou_pott_sbox`,
  `theorem6_2_sbox`, `f1_sbox`, `f2_sbox`, `_theorem5_4_sbox` and `kaleyski_li_sbox`. A
  `bivariate_sbox(m, B, G)` builder in core would remove roughly 120 duplicated lines.
- `zhou_pott_sbox` alongside the existing `taniguchi_apn` — Zhou–Pott is a named infinite
  family (F10) and belongs with the other family constructors.

## Open Questions

- Is paper issue 2 (Section 6.1.3's "second case") a mis-numbering in the publication or a
  genuine equivalence that could not be reached here? Confirming requires running
  `make -C packages/VBFRepro/src/202100-calderini-construction-relations section6_1_n12`.
- Should `n8_Taniguchi2025_ex4_2`'s novelty note be revised given the invariant coincidence
  with Edel–Pott 1.3 reported under `Budaghyan_202101`?
