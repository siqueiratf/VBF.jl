# Li_202402 — Two New Infinite Families of APN Functions in Trivariate Form

**Paper**: Li, Kaleyski. "Two New Infinite Families of APN Functions in Trivariate Form."
2024.

**Reproduction path**: `papers/2024/Li_202402/`

**Verdict**: Partial

Six paper items (Theorems 1, 3, 6, 7, Propositions 4 and 8, plus the two *new* rows of Table
IV) are reproduced and numerically correct — every asserted constant was independently
confirmed. But Theorem 1's third hypothesis is implemented as the **wrong polynomial** (and
the substitute is logically redundant with the first condition, so it can never fail
independently), both theorems' **bivariate hypothesis is never checked** while the helper
written for it is dead code, and Table IV is only partly transcribed. Table V, §5B, §5C,
Remarks 5 and 9, the AB claims of Propositions 4 and 8, and the CCZ-equivalence claim to
Beierle–Leander #34/#35 are all absent — several of them cheap, and reproduced during this
review.

> Every load-bearing claim below was originally re-derived in pure Python and has since been
> re-verified against the repository's own Julia API (2026-08-15, Julia 1.12.6): GF(2ⁿ)
> arithmetic, DDT/differential spectrum, ortho-derivative, LAT, F₂ rank, orbit enumeration,
> and the shipped `VBFCatalog` SQLite. **Zero disagreements** across ~30 reconciled claims.

---

## Paper Issues

### 1. Proposition 8's proof verifies the wrong polynomial

- **Location**: §4, Proposition 8 proof (`.tex` line 1187; PDF p. 24).
- **Evidence**: it writes *"In Theorem 6, let i = 1 and q = 2. Then it is clear that
  `X^{q²+q+1}+X+1 = X⁷+X+1`, `X^{q²+q+1}+X^{q²}+1 = X⁷+X⁴+1` and
  **`X^{q²+q+1}+X^{q²+1}+X^{q+1}+X+1 = X⁷+X⁵+X³+X+1`** are irreducible."* But Theorem 6's
  third hypothesis (`.tex` 876) is `X^{q²+q+1}+X^{q+1}+X^q+X+1`, which for q=2 is
  **`X⁷+X³+X²+X+1`**, not `X⁷+X⁵+X³+X+1` — that is *Theorem 1's* condition, copy-pasted from
  Proposition 4.
- **Mitigation**: `X⁷+X³+X²+X+1` was verified irreducible over F₂, so Proposition 8's
  conclusion survives; only the proof text is wrong. Confirmed in the PDF, so it is not an
  OCR artifact.

### 2. Theorem 1 proof, Subcase (II.4): wrong case label on the conclusion

- **Location**: `.tex` line 522 — *"Thus Eqs. (2) have exactly 2^k solutions when
  `a^q c + b^{q+1} = 0`"*. The branch just analysed was `a^{q+1}+b^{q+1}+bc^q = 0`; the
  `a^q c+b^{q+1}=0` branch was already concluded at line 505.

### 3. Theorem 1 proof, `.tex` 505: `x ∈ {0,1}` / "exactly two solutions"

- From `(a^{q²+q+1}+a^{q²}b^{q+1}+b^{q²+q+1})(x^q+x)=0` one gets `x^q = x`, i.e.
  `x ∈ F_{2^k}` (`2^k` solutions), not `{0,1}`. The statement is correct only when k=1; the
  theorem's own conclusion is `2^k`.

### 4. Theorem 3 proof, Case (I) subcases mislabelled

- `.tex` 576, 578, 580 read (II.1), (II.2), (II.3) instead of (I.1), (I.2), (I.3).

### 5. Theorem 3 proof, `.tex` 630

- Substituting `x=0` into Eq. (30) yields `z^{q²}+z^q+1 = 0`, but the text prints
  `z^{q²}+z+1 = 0`. Both routes reach the same contradiction via Lemma 2, so the conclusion
  holds.

### 6. Theorem 3 proof, `.tex` 821

- *"which has no solutions in `F_{2^m}` since m is odd"* — Theorem 3's hypothesis is
  `m/gcd(i,m)` odd, not `m` odd; the correct justification is Lemma 2.

### 7. Theorem 3 proof, `.tex` 806

- *"has no roots in `F₂²`"* should be `F_{2^m}²`.

### 8. §5B understates the F1–F2 coincidence — a novelty gap

- **Location**: `.tex` 1286.
- **Evidence**: the paper flags the ortho-derivative-spectrum coincidence with family F1–F2
  only at **n=15**. It already holds at **n=12**. Instantiating F1–F2
  (`x^{2^s+1}+u^{2^k−1}x^{2^{ik}+2^{mk+s}}`, `n=pk`, `p=3`, `k=4`, `gcd(k,3)=1`,
  `gcd(s,12)=1`, `u=2` primitive) at s=1,5,7,11 gives APN functions whose ortho-derivative
  spectra are **exactly** the two Table V rows for n=12:
  - s=5, s=7 → `0×10149615, 2×5124105, 4×1267560, 6×201285, 8×29295, 10×1260` = Table V
    (n=12, i=1)
  - s=1, s=11 → `0×10118010, 2×5186790, 4×1238265, 6×200130, 8×26775, 10×3150` = Table V
    (n=12, i=3)
- **Consequence**: the paper's CCZ-inequivalence argument (§5A) is established **only at
  n=9**, where F1–F2 is undefined — and at n=9 the two functions turn out to be the
  Beierle–Leander sporadics. The claim "two *new* infinite families" therefore rests entirely
  on the n=9 instance plus the open question the paper itself leaves in §5B.

*Not counted as paper issues*: `=\emptyset` at `.tex` 445 and the tag `(Q22)` are Mathpix/OCR
artifacts of the `.tex` conversion, not defects in the PDF.

---

## Reproduction Issues

### 1. Theorem 1's third root condition is the wrong polynomial

- **Location**: `theorem1.jl:70-72`:
  ```julia
  c3 = poly_no_roots_f2m(m) do x
      pow(x, q2q1) ⊻ pow(x, q2q) ⊻ 1     # X^{q²+q+1} + X^{q²+q} + 1
  end
  ```
  also `theorem1.jl:11` (pseudocode), `:48` and `:50` (docstring), and
  `proposition4.jl:9, 32, 42, 64`.
- **Symptom**: `test_theorem1.jl`'s `@test c1 && c2 && c3` and `test_proposition4.jl`'s
  `@test c1 && c2 && c3` **pass**, but they certify the wrong statement. Paper Theorem 1
  (`.tex` 210) requires `X^{q²+q+1}+X^{q²+1}+X^{q+1}+X+1` (for q=2: `X⁷+X⁵+X³+X+1`). The
  repository checks `X^{q²+q+1}+X^{q²+q}+1` (for q=2: `X⁷+X⁶+1`), which is the **reciprocal
  of condition c1** — hence logically redundant with c1 and never an independent check. For
  all `2 ≤ m ≤ 10`, `1 ≤ i < m`, the repository's c3 verdict is *identical to c1's* in every
  case.
- **Root cause**: transcription — the exponent triple `(q²+1, q+1, 1)` was collapsed to
  `(q²+q)` and the two extra terms dropped.
- **Why it matters**: condition 3 is used exactly once in the paper's proof — Subcase (I.3),
  Eq. (9), where the factor is `Δ^{q²+q+1}+Δ^{q²+1}+Δ^{q+1}+Δ+1`. The repository's substitute
  does not certify that factor.
- **Resolution plan**:
  1. Replace `theorem1.jl:70-72` with
     `pow(x,q2q1) ⊻ pow(x,q2+1) ⊻ pow(x,q+1) ⊻ x ⊻ 1`.
  2. Update `proposition4.jl:42` to `pow(x,7) ⊻ pow(x,5) ⊻ pow(x,3) ⊻ x ⊻ 1`, and the strings
     at `:9`, `:32`, `:64`.
  3. Fix the docstrings at `theorem1.jl:48,50` and the pseudocode at `:11`.
  4. Add a regression test asserting the polynomial's coefficient set, not just its boolean
     verdict — e.g. evaluate at a fixed `x` and compare against a hard-coded value — so a
     reciprocal substitution can never pass again.

### 2. The printed label matches neither the paper nor the code

- **Location**: `theorem1.jl:92` —
  `print_check("X^{q²+q+1}+X^{q²+1}+X^{q+1)+1  no roots in GF(2^$m)", c3, io)`.
- **Symptom**: a three-way mismatch — the paper says `…+X^{q²+1}+X^{q+1}+X+1`, the label
  drops `+X` and has an unbalanced `)`, and the code computes `…+X^{q²+q}+1`.
- **Root cause**: the label was edited independently of the expression.
- **Resolution plan**: (1) fix the string after issue 1; (2) derive check labels from a single
  shared constant so label and expression cannot drift.

### 3. The bivariate hypothesis of Theorems 1 and 6 is never checked; the helper for it is dead code

- **Location**: `helpers.jl:72-79` (`bipoly_no_roots_f2m`, zero call sites — confirmed by
  `grep -rn bipoly_no_roots_f2m papers/2024/Li_202402/`), `theorem1.jl:93`, `theorem6.jl:88`.
- **Symptom**: both report files print
  `print_kv("bivariate condition", "verified implicitly by APN check below")`. That is
  logically backwards: the bivariate root-freeness is a *sufficient hypothesis* for APN-ness;
  observing `du=2` does not verify the hypothesis. Theorems 1 and 6 are therefore reproduced
  as "the conclusion happens to hold", not as "hypotheses ⇒ conclusion".
- **Root cause**: the helper was written and then never wired in.
- **Resolution plan**:
  1. Implement `theorem1_bivariate_condition(m,i)` =
     `X^{q²+q+1}+XY^{q²+q}+XY^q+X^{q²+q}+X^qY^{q²}+X^{q²}Y+Y^{q²+q+1}+Y^{q²+q}+Y^{q²}+Y^q+1`
     and `theorem6_bivariate_condition(m,i)` =
     `X^{q²+q+1}+X^{q+1}Y^{q²}+XY^q+X^qY^{q²}+X^{q²}Y+X^{q²}+Y^{q²+q+1}+Y^{q²+1}+Y^{q²+q}+Y^{q²}+1`,
     both via `bipoly_no_roots_f2m`.
  2. Assert root-freeness for `m ∈ {2,3,4,5}`, all `i`, and assert **failure** at (m=6,i=3)
     and at m=7 — the negative cases are what prove the checker works. Verified expected
     values: root-free everywhere for `m ≤ 6` except (6,3), which has 189 roots; m=7 has 882
     roots for every `i`.
  3. Replace the "verified implicitly" `print_kv` with a real `print_check`.

### 4. Header pseudocode misstates both bivariate polynomials

- **Location**: `theorem1.jl:12-14`, `theorem6.jl:12-14`.
- **Symptom**: `theorem1.jl:13` lists `…+X^{q²}Y^{q²}+X^{q²}Y^q+X^qY+…` where the paper
  (`.tex` 213) has `…+X^qY^{q²}+X^{q²}Y+…`; `theorem6.jl:13` lists `X^{q+1}Y^{q²+q}` where
  the paper (`.tex` 879) has `X^{q+1}Y^{q²}`, and omits `Y^{q²+1}+Y^{q²+q}+Y^{q²}`.
- **Root cause**: comment drift.
- **Resolution plan**: rewrite both comment blocks from `.tex` 213 and `.tex` 879 as part of
  issue 3.

### 5. Table V (§5B) is advertised but not implemented

- **Location**: `report.jl:30` (`"bounded: Table V (m≤4 default, m=5 with full=true)"`); no
  `section5b.jl` exists.
- **Symptom**: `theorem1_report` / `theorem6_report` print only `differential_uniformity` and
  `is_permutation` — no ortho-derivative spectrum is ever computed outside `section5a.jl`
  (n=9 only). Table V's six spectra are unreproduced.
- **Root cause**: the scope string was written ahead of the code.
- **Resolution plan**:
  1. Add `section5b.jl` with `TABLE_V_EXPECTED` for (n=12,i=1), (n=12,i=3) and (n=15,i=1..4)
     — all six values verified below.
  2. Assert `differential_spectrum(ortho_derivative(SBox(family1_lut(m,i))))` equals each.
  3. Assert the (n=12, i=2) differential spectrum has support `{0,4}`.
  4. Assert the §5B correspondence `OD(F₁ with i) == OD(F₂ with m−i)` at m=4 and m=5.
  5. Gate n=15 behind `full=true` (about 2-5 s per row in Julia).

### 6. §5C dismissed with a wrong search-space figure

- **Location**: `report.jl:31` —
  `"out-of-scope: Section 5C exhaustive search (m≤5, 2^45 candidates)"`.
- **Symptom**: §5C's form (`.tex` 1330-1332) has `8+8+7 = 23` free binary coefficients
  `c_ij ∈ F₂` per (m,i), i.e. **`2²³ ≈ 8.4×10⁶`** candidates, not `2⁴⁵`. At m=2 (64-entry
  LUTs) and m=3 (512-entry LUTs) this is entirely tractable in Julia.
- **Root cause**: the coefficient count was estimated from the field size instead of from
  `F₂`.
- **Resolution plan**:
  1. Correct the figure to `2²³`.
  2. Implement the m=2 search and assert the paper's counts: 49152 APN for i=1, all
     Gold-`x³`-equivalent; **zero** for i=2.
  3. Implement the m=3 search and assert 2880 APN for i=1, splitting 320 / 320 / 2240 by
     ortho-derivative spectrum.
  4. At minimum, add the §5C third-class representative (verified below), asserting APN and
     its spectrum.

### 7. `TABLE_IV_KNOWN` is incomplete and transcribed rather than computed

- **Location**: `section5a.jl:20-27`.
- **Symptom**: only 6 of Table IV's entries are present. **Family F13's eight spectra
  (`.tex` 1242) are entirely absent**, so `f1_new` / `f2_new` ("distinct from all Table IV
  known families") is a weaker claim than the paper's. Nothing in the dict is *computed*;
  F4/F5/F6/F10 are hard-coded numbers.
- **Root cause**: partial transcription.
- **Resolution plan**:
  1. Add F13's eight spectra from `.tex` 1242.
  2. Compute rather than transcribe the reproducible rows: Gold from
     `load_apn_function("n9_Gold_x3"/"x5"/"x17")`; F4 as `x³+a⁻¹Tr₉(a³x⁹)`; F5/F6 from
     `n9_Budaghyan2009_eq8` / `eq7`. All four verified to match the paper.
  3. Keep F10/F13 transcribed but state which parameters were not instantiated.

### 8. The AB claim of Propositions 4 and 8 is never checked

- **Location**: `proposition4.jl:11` and `proposition8.jl:11` both say *"Verify APN, AB,
  permutation (m odd), CCZ-equiv to Beierle-Leander rep. #34/#35 for m=3"*;
  `proposition4_report` / `proposition8_report` (`:52-80`) verify only APN and permutation.
- **Symptom**: "In particular, when m is odd, F is AB" (`.tex` 840, 1186) is unverified;
  `nonlinearity` and `walsh_transform` are exported and unused.
- **Root cause**: pseudocode written ahead of the code.
- **Resolution plan**: (1) add `nonlinearity(SBox(lut)) == 2^(n-1) − 2^((n-1)/2)` for odd `m`;
  (2) assert the Walsh support is `{0, ±2^((n+1)/2)}` at n=9 (verified:
  `{−32:61320, 0:130816, 32:69496}`); (3) either implement the Beierle–Leander cross-check or
  delete the `#34/#35` phrase (see issue 10).

### 9. Remarks 5 and 9 are not implemented at all

- **Location**: absent; `report.jl:26-34` lists no remark.
- **Symptom**: "the functions from Theorem 1 are 3-to-1" for even `n`, "Gold-like Walsh
  spectrum", "F is CCZ-equivalent to the Gold function `x³` for n=6", "cannot be
  CCZ-equivalent to a permutation for doubly-even n" — none is exercised, although
  `is_3_to_1`, `is_ccz_equivalent_to_permutation`, `walsh_transform` and `algebraic_degree`
  are all `VBF` exports.
- **Root cause**: a scope choice — but the checks are cheap, and all were verified here at
  n=6 and n=12 in seconds.
- **Resolution plan**: add `remark5.jl` asserting (1) `is_3_to_1` at n=6 and n=12 for both
  families; (2) the ortho-derivative spectrum at n=6 equals that of `n6_Gold_x3`;
  (3) `algebraic_degree == 2`; (4) `is_ccz_equivalent_to_permutation == false` at n=12 if the
  budget allows.

### 10. §5A's headline equivalence claim is only a comment

- **Location**: `section5a.jl:11`
  (*"Both match Beierle-Leander (2021) sporadic instances #34 and #35"*),
  `proposition4.jl:11`, `proposition8.jl:11`.
- **Symptom**: nothing asserts it. Querying `VBFCatalog.bulk_corpora`, all eight tracked
  corpora are **n=8** (`edelpott2009_n8`, `wengtangong2013_n8`, `yuwangli2014_qam_n8`,
  `taniguchi2019_n8`, `beierleleander2022_n8`, `beierleleanderperrin2022_n8`,
  `yuperrin2022_qam_n8`, `simonberg_gf4_n8`). `papers/2022/Beierle_202201/catalog_validation.jl:74`
  explicitly handles `beierleleander2022_n9` as absent, and
  `papers/2022/Beierle_202201/inputs/` does not exist. So the Beierle–Leander n=9 dataset is
  **genuinely not in the repository** — this claim is legitimately unverifiable here, but it
  must be *stated as such* rather than asserted in a comment.
- **Root cause**: a scope note placed in a comment instead of a `print_kv` / skipped test.
- **Resolution plan**: (1) turn the claim into an explicit "unverifiable — dataset [4] not in
  repo" report line; (2) file a request to import `apn_9bit.txt` (35 instances) as corpus
  `beierleleander2022_n9`; (3) once present, assert equality of ortho-derivative spectra with
  representatives #34/#35 and #30.

### 11. Wrong inline comment in `report.jl`

- **Location**: `report.jl:39` —
  `theorem1_report(m = 4, i = 3, io = io)   # n=12, k=gcd(3,4)=1, perm`.
- **Symptom**: `m ÷ k = 4` is even, so `theorem1_report:100-107` *skips* the permutation
  check; and `F` is in fact 3-to-1 at n=12 (verified). The comment asserts the opposite of
  what runs.
- **Resolution plan**: change to
  `# n=12, k=1, 3-to-1 (m/k even ⇒ Theorem 3 does not apply)`.

### 12. The default report silently runs two n=18 DDT computations; the cost note is inverted

- **Location**: `report.jl:24`
  (`"Set full=true to also run m=5 (n=15), which is slower (~2 min)"`) versus `report.jl:47`
  and `:61` (`proposition4_report(ms = [3, 5, 6])`, `proposition8_report(ms = [3, 5, 6])`),
  which run **unconditionally**.
- **Symptom**: `m=6 ⇒ n=18`, so `differential_uniformity` performs `2³⁶ ≈ 6.9×10¹⁰` inner
  iterations, twice — far more than the m=5 (n=15, `2³⁰`) path that the docstring calls "the
  slow one".
- **Root cause**: `full` gating applied to `theorem1_report` / `theorem6_report` but not to
  the propositions.
- **Resolution plan**: (1) default `ms = [3, 5]`; (2) move `m = 6` behind `full=true`;
  (3) correct the docstring cost estimate.

### 13. `bipoly_no_roots_f2m` excludes `(0,0)` from the search domain

- **Location**: `helpers.jl:75` — `(x == 0 && y == 0) && continue`.
- **Symptom**: the paper says "no roots in `F_{2^m}²`" (`.tex` 214), which includes the
  origin. Harmless for these two polynomials (constant term 1 ⇒ `f(0,0)=1`), but wrong as a
  general-purpose helper, and it would silently mask a genuine root for any polynomial
  without a constant term.
- **Resolution plan**: (1) drop the `continue`; (2) document that the domain is the full
  `F_{2^m}²`.

### 14. Spectrum plumbing re-implemented

- **Location**: `section5a.jl:39-73` (`spec_to_dict`, `dicts_equal`, `format_spec`).
- **Symptom**: `Spectrum` already carries `counts`, and `to_markdown` / `table_to_markdown`
  exist in core; the comparison helper reimplements zero-tolerant dict equality.
- **Resolution plan**: compare `Spectrum` objects directly (or via a single core helper) and
  use core formatting.

---

## Items Reproduced Exactly

| Paper item | File | Independent result |
|------------|------|--------------------|
| **Theorem 1** — `Δ(F₁)=2^k` for `F(x,y,z)=(x^{q+1}+x^q z+y z^q, x^q z+y^{q+1}, x y^q+y^q z+z^{q+1})` | `theorem1.jl:27-40` | `du = 2^gcd(i,m)` confirmed for all (m,i), m ≤ 4: (2,1)→2, (3,1)→2, (3,2)→2, (4,1)→2, (4,2)→4, (4,3)→2; m=5, i=1 APN |
| **Theorem 3** — permutation when `m/gcd(i,m)` odd | `theorem1.jl:100-107` | permutation confirmed for (3,1),(3,2),(5,1); correctly *not* a permutation for `m/k` even |
| **Theorem 6 / Theorem 7** — second family | `theorem6.jl:26-39, 95-102` | identical results; `du` and permutation confirmed on the same (m,i) grid |
| **Proposition 4** (i=1, q=2, gcd(m,7)=1) | `proposition4.jl:24-27` | APN and permutation at m=3,5; correctly throws at m=7 |
| **Proposition 8** | `proposition8.jl:24-27` | APN and permutation at m=3,5 |
| **Theorem 6 root conditions** | `theorem6.jl:60-68` | matches the paper exactly; `X⁷+X³+X²+X+1` verified irreducible over F₂ |
| **Table IV, F₁ row** (n=9) | `section5a.jl:30-32` | `0×164199, 2×76734, 4×13524, 6×4312, 8×2205, 12×147, 16×294, 18×147, 20×49, 22×21` — **exact match** |
| **Table IV, F₂ row** (n=9) | `section5a.jl:33-36` | `0×172557, 2×68355, 4×12201, 6×3871, 8×1638, 10×735, 12×1470, 14×49, 16×147, 18×441, 20×147, 42×21` — **exact match** |
| **Table IV, Gold rows** | transcribed `section5a.jl:21-22` | recomputed from `n9_Gold_x3/x5/x17`: `{0:153811,2:96579,6:10731,8:511}` (x³ and x¹⁷) and `{0:159943,2:78183,4:18396,6:4599,8:511}` (x⁵) — **both match** |
| **Table IV, F5 / F6 rows** | transcribed `section5a.jl:24-25` | recomputed from `n9_Budaghyan2009_eq8` → the F5 row exactly; `n9_Budaghyan2009_eq7` → the F6 row exactly |

### Verified as reproducible but not implemented

These are all cheap and all check out — they are the concrete gap:

- **Table IV, F4 row**: `x³+a⁻¹Tr₉(a³x⁹)` gives
  `{0:159016,2:79389,4:19089,6:3483,8:493,10:144,12:18}` for **all 511** nonzero `a`. Matches
  the paper.
- **Table V, n=12**: i=1 → `0×10149615, 2×5124105, 4×1267560, 6×201285, 8×29295, 10×1260`;
  i=3 → `0×10118010, 2×5186790, 4×1238265, 6×200130, 8×26775, 10×3150`. **Both exact.** i=2
  gives differential spectrum support `{0,4}` exactly as §5B states.
- **Table V, n=15**: i=1,2,3,4 ortho-derivative spectra **all four exact** (about 150 s of
  compute each).
- **§5B correspondence** "Theorem 1 with parameter `i` ↔ Theorem 6 with parameter `m−i`":
  confirmed at m=4 (1↔3) and m=5 (1↔4, 2↔3) by spectrum equality.
- **§5C, m=3 third class**: `F(x,y,z)=(x³+xz²+yz²+z³, x²y+x²z+z³, x²z+y³)` is APN with
  ortho-derivative spectrum
  `0×160391, 2×78204, 4×18606, 6×3017, 8×966, 10×294, 12×105, 14×35, 20×14` — **exact**.
- **Remarks 5/9, 3-to-1**: confirmed at n=6 (m=2,i=1) and n=12 (m=4, i=1 and i=3), both
  families.
- **Remark 5, n=6 ≡ Gold `x³`**: the ortho-derivative spectrum of `F` equals that of
  `n6_Gold_x3` (`{0:2205,2:1764,8:63}`).
- **Propositions 4/8 "AB"**: the n=9 Walsh spectrum is `{−32:61320, 0:130816, 32:69496}` —
  support `{0,±2⁵}`, i.e. AB.
- **Propositions 4/8 factorizations**: `f(X,Y)=∏(X+ω^{2^i}Y+ω^{63·2^i})` and
  `∏(X+ω^{11·2^i}Y+ω^{58·2^i})` verified pointwise over `F₂₇²` with `ω` a root of `X⁷+X+1`.
- **Bivariate hypotheses** of Theorems 1 and 6: root-free for every (m,i) with `m ≤ 6` except
  (m=6,i=3) and all of m=7 (7 | m), as expected.

## Test Results

Executed on 2026-08-15 with **Julia 1.12.6** (`julia --project=/home/tiago/VBF.jl`; the
paper's tests live in `tests/`, not `test/`).

| Command | Exit code | Wall time |
|---------|-----------|-----------|
| `make -C papers/2024/Li_202402 test` | **0** | **7 s** (includes `Pkg.instantiate()`) |

| Testset | Pass | Broken | Fail / Error | Total | Time |
|---------|------|--------|--------------|-------|------|
| `theorem1_test`     | 10 | 0 | 0 | 10 | 1.6 s |
| `proposition4_test` |  8 | 0 | 0 |  8 | 1.2 s |
| `theorem6_test`     | 10 | 0 | 0 | 10 | 0.1 s |
| `proposition8_test` |  9 | 0 | 0 |  9 | 1.1 s |
| `section5a_test`    |  9 | 0 | 0 |  9 | 1.1 s |
| **Total**           | **46** | **0** | **0** | **46** | — |

Julia's `Test` summary printed only `Pass | Total | Time` columns for every testset, i.e. no
broken, failed, or errored tests were recorded.

**Caveat**: passing does **not** mean faithful. Reproduction issues 1 and 3 mean two of these
testsets (`theorem1_test`'s and `proposition4_test`'s `@test c1 && c2 && c3`) certify a
statement the paper does not make, and the bivariate hypothesis of Theorems 1 and 6 is not
exercised at all.

Measured cost note: `differential_uniformity` at n=15 takes **1.53 s**, not the "~2 min"
claimed at `report.jl:24`. Since DDT cost scales as 2^{2n}, the two unconditional `m = 6`
(n=18) calls at `report.jl:47` and `:61` cost ≈ 64× that each, i.e. ≈ 100 s apiece — so the
docstring's cost ranking is inverted by roughly two orders of magnitude. `make test` is
unaffected (7 s): the testsets only use m ∈ {3, 5}.

## Catalog Status

| Claimed-new object | Status | Evidence |
|--------------------|--------|----------|
| **F₁ over F₂⁹** (Thm 1 / Prop 4, m=3, i=1) | **missing** | the ortho-derivative spectrum `{0:164199,…,22:21}` differs from **all 12** quadratic n=9 entries in `BFA_catalog.sqlite` (Gold x3/x5/x17/i5/i7/i8, Kasami_i8, Budaghyan2009 eq7/eq8, BCL2008, EdelPott2009, Yu2020_f7) and from all 9 entries in `n9_apn.toml`. It is a CCZ-invariant for quadratic APN (CCZ ⇔ EA, Yoshiara 2012). Non-quadratic n=9 entries (Kasami x13/x241 degree 3/5, Welch–Niho x19 degree 3, Inverse x510 degree 8) are excluded by degree, as the paper argues (`.tex` 1209) |
| **F₂ over F₂⁹** (Thm 6 / Prop 8, m=3, i=1) | **missing** | same table; ortho-derivative spectrum `{0:172557,…,42:21}` distinct from every entry and from F₁ |
| **n=6 instance** (m=2, i=1, both families) | **not-new** | ortho-derivative spectrum `{0:2205,2:1764,8:63}` = `n6_Gold_x3`; the paper says so itself (Remark 5) |
| **n=12 instances** (Thm 1, i=1 and i=3) | **missing** from `n12_apn.toml` (which holds only `n12_CalderiniLiVilla2023_F1/F2`, both with different ortho-derivative spectra) — **but novelty is not established**: both coincide with BCL family F1–F2 (paper issue 8). Recommend adding them, if at all, labelled as F1–F2-equivalent representatives, not as new |
| **n=15 instances** | **unverifiable** at catalog level — `n15_apn.toml` does not exist and no n=15 corpus is tracked; the paper itself says the four spectra coincide with F1–F2 |
| CCZ-equivalence to Beierle–Leander #34/#35 | **unverifiable in-repo** — the BL n=9 dataset (ref [4], 35 instances) is not present; all 8 tracked corpora are n=8 |

### Catalog-gap record 1

```
target file : packages/VBFCatalog/data-raw/apn_catalog/n9_apn.toml
name              = "n9_LiKaleyski2024_F1"
n                 = 9
m                 = 9
is_permutation    = true
algebraic_form    = "Trivariate F(x,y,z) = (x^3 + x^2*z + y*z^2, x^2*z + y^3, x*y^2 + y^2*z + z^3) over GF(2^3)^3, modulus x^3+x+1 (=11); packed idx = x*2^6 + y*2^3 + z -> f1*2^6 + f2*2^3 + f3"
bib_key           = "Li_202402"
source            = "Li, Kaleyski, 'Two new infinite families of APN functions in trivariate form', Theorem 1 / Proposition 4 with m = 3, i = 1 (q = 2). AB permutation over F_{2^9}."
```

Equivalence evidence: differential uniformity 2, algebraic degree 2, permutation, AB (Walsh
support `{0,±32}`); ortho-derivative differential spectrum
`[0^164199, 2^76734, 4^13524, 6^4312, 8^2205, 12^147, 16^294, 18^147, 20^49, 22^21]`,
distinct from every quadratic n=9 catalog entry (Gold x³/x¹⁷ `{0:153811,2:96579,6:10731,8:511}`,
Gold x⁵ `{0:159943,…}`, Budaghyan2009 eq7 `{0:160525,…}`, eq8 `{0:159226,…}`, and the six
`known-family` / `known-sporadic` rows) — all verified. The paper reports it CCZ-equivalent to
Beierle–Leander representative #34 (not checkable in-repo).

The 512-entry LUT was computed during this review and is available from the reviewing agent's
output; regenerate deterministically with `trivariate_lut(3, 1)` from `helpers.jl` under
modulus 11. First 16 values: `0, 1, 3, 4, 5, 6, 7, 2, 8, 72, 265, 335, 393, 459, 137, 205`.

### Catalog-gap record 2

```
target file : packages/VBFCatalog/data-raw/apn_catalog/n9_apn.toml
name              = "n9_LiKaleyski2024_F2"
n                 = 9
m                 = 9
is_permutation    = true
algebraic_form    = "Trivariate F(x,y,z) = (x^3 + x*y^2 + y*z^2, x*y^2 + z^3, x^2*z + y^3 + y^2*z) over GF(2^3)^3, modulus x^3+x+1 (=11); packed idx = x*2^6 + y*2^3 + z -> f1*2^6 + f2*2^3 + f3"
bib_key           = "Li_202402"
source            = "Li, Kaleyski, 'Two new infinite families of APN functions in trivariate form', Theorem 6 / Proposition 8 with m = 3, i = 1 (q = 2). AB permutation over F_{2^9}."
```

Equivalence evidence: as record 1, with ortho-derivative differential spectrum
`[0^172557, 2^68355, 4^12201, 6^3871, 8^1638, 10^735, 12^1470, 14^49, 16^147, 18^441, 20^147, 42^21]`
— distinct from every catalog entry **and** from `n9_LiKaleyski2024_F1`. The paper reports it
CCZ-equivalent to Beierle–Leander representative #35. First 16 LUT values:
`0, 8, 24, 32, 40, 48, 56, 16, 1, 72, 283, 354, 429, 500, 191, 214`.

## Library-Reuse Note

**Duplicating core** — none outright. `helpers.jl` uses `gf_mul`, `gf_pow`,
`primitive_polynomial`, `print_banner`; the claim files use `differential_uniformity`,
`is_permutation`, `SBox`, `ortho_derivative`, `differential_spectrum`, and
`print_section` / `print_check` / `print_kv`. Minor:

- `section5a.jl:39-73` (`spec_to_dict` / `dicts_equal` / `format_spec`) reimplements
  `Spectrum` comparison and formatting → use `Spectrum.counts` equality and `to_markdown` /
  `table_to_markdown` (issue 14).

**Core exported but not used, despite the paper needing it:**

| Export | Where it should be called |
|--------|---------------------------|
| `nonlinearity` / `walsh_transform` | the Propositions 4/8 AB claim (`proposition4.jl:70`, `proposition8.jl:70`) — issue 8 |
| `is_3_to_1` | Remarks 5 and 9 — issue 9 |
| `is_ccz_equivalent_to_permutation` | Remark 5's doubly-even claim — issue 9 |
| `algebraic_degree` | the "F is quadratic" premise of Theorems 1 and 6 |
| `apn_ea_mugshot` / `ortho_integral` | the §5A distinctness argument (stronger than raw spectra) |
| `load_apn_function` / `apn_catalog_names` | Table IV's Gold, F5 and F6 rows — computable from `n9_Gold_*` and `n9_Budaghyan2009_eq7/eq8` (issue 7) |

**Promote-to-core candidates** — core genuinely lacks these, and all are currently
paper-local and generic:

1. `poly_no_roots_f2m(P, m)` (`helpers.jl:60-65`) — "does this map `GF(2ᵐ)→GF(2ᵐ)` have a
   root?"; recurs in every root-condition paper.
2. `bipoly_no_roots_f2m(P, m)` (`helpers.jl:72-79`) — the bivariate version, over the *full*
   `GF(2ᵐ)²` (issue 13).
3. `split_triple` / `join_triple` / `trivariate_lut` (`helpers.jl:24-53`) — generalise to
   `multivariate_lut(m, k, f)` / `pack_tuple` / `unpack_tuple`. The catalog already carries
   hand-rolled bivariate packing (`n12_CalderiniLiVilla2023_F1`'s `algebraic_form`:
   `"packed z=x|(y<<6)"`), so this is duplicated across the repository.

## Open Questions

- Should the n=12 Theorem-1 instances be added to `n12_apn.toml` at all, given they are
  ortho-derivative-spectrum-equal to BCL family F1–F2 (paper issue 8)? Recommendation: add
  them only with an explicit "equivalent to F1–F2" note, or not at all.
- Should the reproduction attempt the §5C exhaustive search at m=2 and m=3 (`2²³` candidates
  each), or is it deliberately out of scope? The `2⁴⁵` figure suggests it was ruled out on a
  mistaken estimate.
- `n9_LiKaleyski2024_F1/F2` fix a particular F₂-linear identification `F_{2^3}³ ≅ F_{2^9}`
  (concatenation packing). Confirm the catalog's convention for storing multivariate-form
  functions before importing.
