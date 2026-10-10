# Gologlu_202207 — Biprojective Almost Perfect Nonlinear Functions

## Audit corrections (2026-10-10)

F011 is now evaluated for the exact Kim κ from the supplied LaTeX.
Independent direct Walsh summation and explicit enumeration of every
3-dimensional span confirm `η₃(κ)=3`, against the printed value 2. The convention
includes zero and counts every linear subspace; it does not count a disjoint
packing. Gold x³ also has η₃=3 and the same nonbent signature, yet the two
verified quadratic APNs have unequal ortho-derivative mugshots. The nonbent
signature alone therefore does not separate these two classes.

F031 is fixed: default reports exclude `m=7` nonbent enumeration. It requires
`full_search=true`; explicit opt-in is not a promise of practical completion.
The report deliberately prints a failed comparison for the paper's Kim value,
while tests pass by pinning the independently recomputed contradiction. The
older scope and implementation notes below are historical where superseded.


**Paper**: Göloğlu. "Biprojective Almost Perfect Nonlinear Functions." *IEEE Transactions on
Information Theory* **68**(7), 2022.

**Reproduction path**: `packages/VBFRepro/src/202207-gologlu-biprojective-apns/`

**Verdict**: Partial

The two headline families and Table I are reproduced exactly and independently confirmed.
Everything around them is missing: the whole Section III.A survey, every lemma (III.6, IV.1,
IV.2, IV.4, V.2, A.1, A.2), Remark III.3, Proposition VI.2, and the Section VI.A/VI.B
inequivalence arguments. Table III is at 2 of 9 rows. The paper's *central novelty argument*
— that family F₁ does not require `m` odd — is never exercised, and the one item skipped
with a written justification was skipped on a false premise, which hid a genuine error in
the paper. A default report path also launches an n=14 computation that will not terminate.

> Every numeric constant below was first re-derived independently in Python from the LaTeX
> definitions, using the same field conventions the repository uses
> (`primitive_polynomial(m)`, packing `x|(y<<m) → f|(g<<m)`), and has since been confirmed
> byte-for-byte against the repository's own Julia API and catalog SQLite (2026-08-15, Julia
> 1.12.6) — 41 reconciled claims, 0 substantive disagreements.

---

## Paper Issues

### 1. Proposition III.4 (ii) is wrong: `η₃(NB_κ) = 3`, not 2

- **Location**: Section III.B, Proposition III.4 (ii), attributed to "By computer".
- **Computed counter-evidence**, using the paper's own `κ(X) = X³ + X¹⁰ + U·X²⁴` with `U` a
  root of `X⁶+X⁴+X³+X+1` (= `conway_polynomial(6)`):

  ```
  κ    DU=2  |NB_κ|=22  N_F = [21, 28, 3]  → η₃ = 3
  x³   DU=2  |NB|  =22  N_F = [21, 28, 3]  → η₃ = 3   (Prop III.4(i) predicts 3 ✓ — pipeline calibrated)
  κ′ = X³+X¹⁰+bX¹⁷ (b³+b+1=0)              N_F = [21, 28, 3]
  [(b,1,0,b+1)₂,(0,b,b,b+1)₂]               N_F = [21, 28, 3]
  ```

  Computed both by the quadratic-rank criterion and by direct Walsh transform (the `nonbent`
  sets are identical). `κ` and `x³` are genuinely CCZ-inequivalent (ortho-derivative DDT
  `{2:1428, 4:168, 8:63}` versus `{2:1764, 8:63}`); `N_F` simply fails to separate them at
  n=6. Only the weaker `η₃ ≥ 2` survives.

### 2. Section III.A's Gold biprojective form is valid only for odd `i`

- **Location**: Section III.A.
- **Evidence**: `(x+ωy)^{2^i+1}` has `ω^{2^i} = ω²` for odd `i` — giving the stated
  `[(1,0,1,1)_{2^i}, (0,1,1,0)_{2^i}]` — but `ω^{2^i} = ω` for even `i`.
- **Severity**: low. The stated pair is still APN in every tested case; only the univariate
  identification breaks.

### 3. Table caption / label mismatch

- **Location**: Tables I and II.
- **Evidence**: the captions name a family `F₀` that is never defined; Table I's body rows
  are labelled `T`, and Table II's first block is unlabelled. Possibly an extraction artifact
  of the supplied `.tex`.

---

## Reproduction Issues

### 1. `proposition3_4_report()` launches an n=14 computation on the default path

- **Location**: `proposition3_4.jl:78` (`for m in [5, 7]`), called unguarded from
  `report.jl:35` and from the `proposition3_4` Makefile target.
- **Symptom**: it builds six `SBox{14}` and calls `nonbent_signature`. Per the paper's own
  Table II, an F₂ member at n=14 has `η₃ = 13,219,303`; `expand_subspaces`
  (`packages/VBF/src/linalg/subspace_in_set.jl:69-95`) materialises every subspace as a
  `Vector{Int}` inside a `Set{Vector{Int}}` → multi-GB and roughly `9.2×10⁹` inner
  iterations. The expected outcome is a hang or OOM, not a `[FAIL]`. Everything else in
  `report.jl` is n ≤ 10.
- **Root cause**: `table2.jl` gates n=14 behind `full_search=true`; `proposition3_4.jl`
  re-introduces m=7 unconditionally.
- **Resolution plan**:
  1. Add `m_values::Vector{Int} = [3,5]` to `proposition3_4_report` and thread it into the
     loop.
  2. Pass `full_search ? [3,5,7] : [3,5]` from `report.jl:35`.
  3. Print an explicit skipped line.
  4. Fix `table2.jl:45`'s "~60s" note, which understates the real cost by orders of
     magnitude.

### 2. Proposition III.4 (ii) is skipped with a factually false justification

- **Location**: `proposition3_4.jl:58-63`.
- **Symptom**: it prints `[ -- ] … out-of-scope` on the grounds that "constructing the exact
  θ requires finding U … beyond the scope" and that "θ and θ′ are CCZ-equiv but not EA-equiv;
  N_F differs". Both claims are false: `kim_apn` is a **VBF core export** building exactly
  the paper's `κ`, and `N_F(κ) = N_F(κ′) = [21,28,3]`.
- **Root cause**: unawareness of `kim_apn`; the justification was asserted, never computed.
- **Resolution plan**:
  1. `K = kim_apn(); ηm = eta_m(K, 3)`.
  2. `print_check("η₃ = 2 (Prop III.4 ii)", ηm == 2)` — this will FAIL with 3.
  3. Record `N_F(κ)`, `N_F(x³)` and the ortho-derivative DDT spectra as evidence.
  4. Also build `κ′` and the biprojective form (all three agree).
  5. File the discrepancy as paper issue 1 above, not as a reproduction gap.

### 3. Family F₁ is never exercised for even `m` — the paper's central novelty argument

- **Location**: `theorem3_2.jl:64` (`m_values = [5,7]`), `report.jl:34` (`m_values=[3,5]`),
  `test/test_theorem3_2.jl` (m=5 only).
- **Symptom**: Section VI's "F₁ does not require m to be odd. This is enough to show that
  family F₁ is new" is never exercised. Worse, m=3 yields an **empty** candidate list
  (`gcd(3i,3) ≥ 3` for all `i`), so `report.jl:29`'s "Theorem III.2 APN (m=3,5)" claims
  coverage that does not exist.
- **Root cause**: `m_values` chosen without checking admissibility.
- **Resolution plan**:
  1. Add m=4 (n=8, cheap) and optionally m=8 to the defaults — verified APN for `i=1,3`
     (m=4), `i=1,3,5,7` (m=8) and `i=1,3,7` (m=10).
  2. Drop m=3, or print "no admissible i".
  3. Add negative-parameter checks showing `gcd(3i,m)=1` is necessary.

### 4. Table III is reproduced for 2 of 9 rows; two correct constants are dead code

- **Location**: `table1.jl:33-38` (`TABLE_III_EXPECTED["x3tr"]` and `["xu"]` are never
  referenced), `table1.jl:105-126`.
- **Symptom**: only `x³` and `x⁹` are computed; the 5 remaining quadratic rows and the 2
  `N/A` rows are absent.
- **Root cause**: partial transcription.
- **Resolution plan**:
  1. Add the five rows, all verified with `u = 2` and
     `modulus = primitive_polynomial(10) = x^10+x^3+1`:
     `x^6+x^33+u^31x^192` → `[341,6820,3720,31]`; `x^33+x^72+u^31x^258` →
     `[341,6820,3720,31]`; `x^3+tr(x^9)` → `[341,6820,4215,66,1]`; `x^3+u^341x^36` →
     `[341,6820,4400]`; `x^3+u^1022 tr(u^3x^9)` → `[341,6820,4250,66,1]`.
  2. Print `N/A` for `x^57` and `x^339` (degree 4 and 5, hence not component-wise
     plateaued).
  3. Wire `x3tr` and `xu` into real `print_check`s.

### 5. Proposition III.4 (iv) is not reproduced

- **Location**: `proposition3_4.jl` — no branch exists.
- **Symptom**: `X³ + tr(X⁹)` with `η_m ≥ 1` is absent, although `report.jl:29` advertises
  Proposition III.4 as EXACT.
- **Root cause**: omission.
- **Resolution plan**: build `x³ ⊕ gf_trace(gf_pow(x,9,…))` over `GF(2¹⁰)`; verified
  `N_F = [341,6820,4215,66,1]` ⇒ `η₅ = 1` (passes, and simultaneously supplies a Table III
  row).

### 6. Taniguchi rows are echoed, not computed, and the recomputation path cannot be matched to the paper's `i` indexing

- **Location**: `table1.jl:84-103`.
- **Symptom**: the default `include_taniguchi=false` just prints the constants;
  `include_taniguchi=true` calls `taniguchi_apn_representatives(m)` (Carlet form
  `(x·y, G(x,y))`), whose `(m,a,b)` labels cannot be mapped to Table I's `i=1,4` / `i=2,3`
  rows. It also costs roughly 4000 `differential_uniformity` calls on `SBox{10}`.
- **Root cause**: routed through the generic core builder rather than the paper's
  biprojective form.
- **Resolution plan**:
  1. `t_sbox(m,i,c,d) = biprojective_sbox(m, i, (1,0,c,d), 2i, (0,0,1,0))`.
  2. Use `(c,d) = (1,1)`, which satisfies `f(x,1) ≠ 0` for m=5, `i=1..4`.
  3. Verified targets: `i=1` → `[341,6820,3720,31]`, `i=2` → `[341,6820,3565]`, `i=3` →
     `[341,6820,3565]`, `i=4` → `[341,6820,3720,31]`, all DU=2.
  4. Keep `taniguchi_apn_representatives` as a secondary cross-check only.

### 7. Sections III.A, IV, the Section V lemmas, VI.A and VI.B are missing without disclosure

- **Location**: `report.jl:31` declares only "Lemma A.1/A.2 algebraic proofs, Proposition
  VI.2 BHK-F₁ details" as out of scope.
- **Symptom**: the survey, Lemmas III.6/IV.1/IV.2/IV.4/V.2, Remark III.3, Proposition VI.2
  and the Section VI.B claims are all silently absent — and all are checkable at
  `m ∈ {3,5}`, as the evidence below shows.
- **Root cause**: scope limited to the two families plus Table I.
- **Resolution plan**:
  1. `section3a.jl` for the five survey identifications.
  2. `lemma4_4.jl`, `lemma5_2.jl`.
  3. `lemma3_6.jl` cross-checking the projective criterion against `differential_uniformity`.
  4. `remark3_3.jl` — verified as an exact LUT identity (see below).
  5. `propositionVI_2.jl` — all seven cases verified below; use `apn_ea_mugshot` /
     ortho-derivative.
  6. `section6b.jl` computing `Set(lat(F))` and `is_ccz_equivalent_to_permutation`.
  7. Sync `report.jl:29-31` with what actually runs.

---

## Items Reproduced Exactly

| Paper item | File | Computed value |
|------------|------|----------------|
| Thm III.2/V.1 `F₁=[(1,0,1,1)_{2^i},(1,1,0,1)_{2^{2i}}]`, m=5, i=1..4 | `theorem3_2.jl:24-27` | DU=2, deg=2 (all `i`) |
| Thm III.2/V.3 `F₂=[(1,0,1,1)_{2^i},(0,1,1,0)_{2^{3i}}]`, m=5, i=1..4 | `theorem3_2.jl:35-39` | DU=2, deg=2 (all `i`) |
| Thm V.4 `F₃=[(0,1,1,0)₂,(1,u,u³,u¹³)_{2³}]` | `theorem3_2.jl:48-54` | DU=2, deg=2; `u=2, u³=8, u¹³=28` under `x⁵+x²+1` |
| Table I, `F₁` i=1,4 / i=2,3 | `table1.jl:21-29,59-67` | `[341,6820,3565]` / `[341,6820,3720,31]` |
| Table I, `F₂` i=1,4 / i=2,3 | idem | `[341,6820,4030,62,1]` / `[341,6820,3720,62,1]` |
| Table I, `F₃` | `table1.jl:77-82` | `[341,6324,2573,62,2]` |
| Table III, `x³` and `x⁹` | `table1.jl:110-125` | `[341,6820,5115,341,11]` for both |
| Proposition III.4 (i) | `proposition3_4.jl:44-56` | `η₃=3`, `η₅=11 = (2^m+1)/3` |
| Proposition III.4 (iii) | `proposition3_4.jl:66-74` | `η₅(F₃)=2` |
| Proposition III.4 (v) | `proposition3_4.jl:76-89` | `η₅(F₂)=1` for `i=1..4` |

The `eta_m` indexing (`proposition3_4.jl:29-32`) is correct: `subspace_count_signature`
returns `[η₁, η₂, …, 0]`.

### Verified as reproducible but not implemented

- **Section III.A survey** — `κ′` biprojective `[(b,1,0,b+1)₂,(0,b,b,b+1)₂]` has
  ortho-derivative DDT spectrum `{2:1428, 4:168, 8:63}`, equal to `κ`'s; Gold
  `[(1,0,1,1)_{2^i},(0,1,1,0)_{2^i}]` at m=5 reproduces Gold `x³` (i=1) and `x⁹` (i=2)
  exactly; **Taniguchi T** in the paper's own form `[(1,0,c,d)_{2^i},(0,0,1,0)_{2^{2i}}]`
  gives Table I exactly (55 admissible `(c,d)` per `i`, all agreeing).
- **Remark III.3** — verified as an exact LUT identity: `L∘F == F′` with
  `L(x,y) = (x, y^{2^{m-2i}})` for m=5 (i=1,2,3) and m=7 (i=1,2,3).
- **Proposition VI.2 (i)-(vii)** — declared out of scope (`report.jl:31`) but **fully
  verifiable**. Building `C(X) = X³ + ωX^{(2^i+1)2^k} + ω²X^{3·2^m} + X^{2^m(2^i+1)2^k}` on
  `GF(2^10)` matches all seven cases by ortho-derivative DDT spectrum: (i) i=3,k=0 → F₁
  i=1/4; (ii) i=7,k=0 → F₁ i=2/3; (iii) i=5,k=0 → Carlet `[x³+xy²+y³, xy]`; (iv) i=9,k=0 →
  Gold `x³`; (v) i=7,k=1 → F₁ i=1/4; (vi) i=3,k=1 → F₁ i=2/3; (vii) i=5,k=1 → Carlet. All
  DU=2.
- **Section VI.B Walsh-spectrum claim** — F₁(i=1,2), F₂(i=1,2) and F₃ at n=10 all have
  bilinear-form rank distribution `{8:341, 10:682}` ⇒ `|W| ∈ {0, 2⁵, 2⁶}`, the Gold spectrum.
- **Even-m F₁** — verified APN (quadratic-APN test, kernel rank `n−1` for every `a ≠ 0`) at
  **m=4 (i=1,3), m=8 (i=1,3,5,7), m=10 (i=1,3,7)**, plus m=7 (i=1..6) for F₁ and F₂.
- **Section VI.B "not equivalent to a permutation"** — not attempted;
  `is_ccz_equivalent_to_permutation` is a core export.

## Test Results

Re-run on **2026-08-15** with **Julia 1.12.6**, project fully instantiated.

**Command**: `make -C packages/VBFRepro/src/202207-gologlu-biprojective-apns test`
**Exit code**: `0`  |  **Wall time**: `6 s` (includes `Pkg.instantiate()`; testset time 4.5 s)

| Testset | Pass | Broken | Fail | Total | Time |
|---------|------|--------|------|-------|------|
| `theorem3_2_test` | 15 | 0 | 0 | 15 | 1.8 s |
| `proposition3_4_test` | 5 | 0 | 0 | 5 | 1.1 s |
| `table1_test` | 10 | 0 | 0 | 10 | 1.6 s |
| **Total** | **30** | **0** | **0** | **30** | **4.5 s** |

Additional entrypoints exercised during review (not part of `make test`):

| Command | Result |
|---------|--------|
| `theorem3_2_report()` (defaults, `m_values=[5,7]`) | all 21 checks PASS, 4.7 s — includes **m=7 (n=14), i=1..6, F₁ and F₂, DU=2, deg=2** |
| `table1_report(; include_table3=true)` | all 11 checks PASS, 5.7 s — Table I (9 rows) and Table III (`x³`, `x⁹`) match the paper exactly |
| `make report` / `make full` / `proposition3_4_report()` | **NOT RUN** — `proposition3_4.jl:78` (`for m in [5,7]`) launches six `SBox{14}` `nonbent_signature` calls; measured cost is ≥ 20 min *per function for the k=2→3 step alone* plus a ≳1.6 GB intermediate (see reproduction issue 1) |

Every constant originally derived in Python was confirmed byte-for-byte by the repository's
own API — 41 reconciled claims, 0 substantive disagreements.

## Catalog Status

`packages/VBFCatalog/data/apn/n10_apn.toml` holds 4 power functions; the SQLite
adds Gold/Kasami index variants and 6 Taniguchi members (14 n=10 rows in total).
Ortho-derivative DDT spectra were computed for all quadratic n=10 catalog entries and all
Göloğlu functions:

| function | ortho-derivative DDT spectrum |
|----------|-------------------------------|
| `n10_Gold_x3`, `n10_Gold_i9`, `n10_Kasami_i9` | `{2:416361, 6:35805}` |
| `n10_Gold_x9`, `n10_Gold_i7` | `{2:211761, 4:92070, 6:15345, 8:5115, 12:10230}` |
| `n10_Taniguchi_*` (6 entries) | 6 further distinct spectra |
| **F₁ i=1/4** | `{2:313131, 4:80910, 6:14415, 8:1395}` |
| **F₁ i=2/3** | `{2:330336, 4:79515, 6:10230, 8:930}` |
| **F₂ i=1/4** | `{2:334986, 4:76725, 6:11160, 8:465}` |
| **F₂ i=2/3** | `{2:304296, 4:89280, 6:13020, 8:465}` |
| **F₃** | `{2:322958, 4:77562, 6:13020, 8:1333, 10:186, 12:62}` |

No Göloğlu spectrum matches any catalog entry. All five are quadratic ⇒ CCZ = EA (Yoshiara);
none is EA-equivalent to Gold ⇒ by Dempwolff/Yoshiara none is CCZ-equivalent to any power
function, so `x^57` and `x^339` are excluded too.

- **F₂ (m=5, i ∈ {1,4})** → **missing**
- **F₂ (m=5, i ∈ {2,3})** → **missing**
- **F₃ (m=5)** → **missing**
- **F₁ (m=5, both classes)** → missing from the catalog, but *not claimed new* by the paper
  (Section VI: for m=5, F₁ ≡ BHK). An optional addition; must be attributed to BHK ∩ F₁.
- **F₁ (m=4, n=8)** → **not-new (probable)**: ortho-derivative DDT `{2:25080, 4:3780}`
  matches three existing n=8 catalog entries — `reprs8_35`,
  `SimonBerg_GF4_n8_class_2`, and `n8_Taniguchi_m1_a0_b2` (the `a=0` / Zhou–Pott member).
  Needs `are_ea_equivalent` to confirm; do **not** add.
- **F₁/F₂ at m=7 (n=14)** → **unverifiable**: no `n14_apn.toml` exists, and
  `nonbent_signature` / CCZ tooling is out of reach at n=14 with the current
  `expand_subspaces`.

### Catalog-gap records (3 entries)

Target file for all three: `packages/VBFCatalog/data/apn/n10_apn.toml`. LUTs are
1024 entries; regenerate verbatim from the named builder in
`packages/VBFRepro/src/202207-gologlu-biprojective-apns/theorem3_2.jl` and check against the SHA-256 of
`canonical_lut_bytes` given below (2 bytes per entry, little-endian).

**Record 1**

- `name = "n10_Gologlu2022_F2_i1"`, `n = 10`, `m = 10`, `is_permutation = false`
- `lut`: `f2_sbox(5, 1)` — first 16 = `0, 1, 8, 15, 10, 31, 23, 4, 26, 25, 3, 6, 9, 30, 5, 20`;
  sha256 = `8ce61cda5562ee6336ae6e4b0dde139e97c6b34a36647e1664d32021c83a2570`
- `algebraic_form = "Bivariate biprojective F(x,y)=[f,g] over GF(2^5), f=(1,0,1,1)_{2^1}=x^3+x*y^2+y^3, g=(0,1,1,0)_{2^3}=x^8*y+x*y^8; modulus x^5+x^2+1 (=37); packed z=x|(y<<5) -> f|(g<<5)"`
- `bib_key = "Gologlu_202207"`
- `source = "Göloğlu, 'Biprojective Almost Perfect Nonlinear Functions', IEEE Trans. Inf. Theory 68(7), 2022, Theorem III.2 family F2 (m=5, i=1). LUT from f2_sbox(5,1). Re-verified DU=2, deg=2; N_F=[341,6820,4030,62,1] = paper Table I row F2 i=1,4."`
- Evidence: ortho-derivative DDT `{2:334986, 4:76725, 6:11160, 8:465}`, distinct from all 14
  n=10 catalog entries.

**Record 2**

- `name = "n10_Gologlu2022_F2_i2"`, `n = 10`, `m = 10`, `is_permutation = false`
- `lut`: `f2_sbox(5, 2)` — first 16 = `0, 1, 5, 22, 17, 25, 4, 30, 31, 24, 18, 7, 20, 26, 9, 21`;
  sha256 = `9032ba58ded0de87c812e528e0645f28008cf39e582d2868563be2d3f3058158`
- `algebraic_form`: as above with `f=(1,0,1,1)_{2^2}`, `g=(0,1,1,0)_{2^{6 mod 5}}`
- `bib_key = "Gologlu_202207"`; `source` as above with i=2; `N_F = [341,6820,3720,62,1]`
- Evidence: ortho-derivative DDT `{2:304296, 4:89280, 6:13020, 8:465}` — distinct from
  Record 1 and from all catalog entries.

**Record 3**

- `name = "n10_Gologlu2022_F3"`, `n = 10`, `m = 10`, `is_permutation = false`
- `lut`: `f3_sbox()` — first 16 = `0, 32, 832, 640, 96, 928, 864, 320, 352, 896, 480, 736, 800, 544, 992, 768`;
  sha256 = `4760e53ddcd26d36e15ac1d78c37430f40c570cb35d1c98381d1182279cf6401`
- `algebraic_form = "Bivariate biprojective F(x,y)=[(0,1,1,0)_2,(1,u,u^3,u^13)_{2^3}] over GF(2^5), u root of x^5+x^2+1 (u=2, u^3=8, u^13=28); modulus 37; packed z=x|(y<<5) -> f|(g<<5)"`
- `bib_key = "Gologlu_202207"`; `source`: Theorem V.4 / Proposition III.4 (iii);
  `N_F = [341,6324,2573,62,2]`, `η₅ = 2`
- Evidence: ortho-derivative DDT
  `{2:322958, 4:77562, 6:13020, 8:1333, 10:186, 12:62}` — unique; the only known non-Gold
  quadratic APN at n=10 with `η₅ = 2`.

## Library-Reuse Note

- `helpers.jl:67-74` `print_header` hand-rolls a `"="^72` banner → should call core
  `print_banner(io, title, venue)`. The same pattern appears in 24 papers repo-wide; 26
  already use `print_banner`.
- `helpers.jl:81-84` `drop_trailing_zeros` — trivial, but a natural core companion to
  `subspace_count_signature`.
- `helpers.jl:27-65` `biprojective_sbox` — **promote-to-core candidate**. Five papers now
  carry their own bivariate/biprojective builder:
  `packages/VBFRepro/src/202207-gologlu-biprojective-apns/helpers.jl:27` (`biprojective_sbox`),
  `packages/VBFRepro/src/202503-gologlu-biprojective-equivalence/helpers.jl:119` (`biproj_eval`),
  `packages/VBFRepro/src/202207-li-quadratic-families/helpers.jl:29` (`bivariate_lut`),
  `packages/VBFRepro/src/202100-calderini-construction-relations/helpers.jl:58` (`bivariate_carlet_sbox`), and
  `packages/VBFRepro/src/202306-calderini-bivariate-families` (`family_f1_lut`). A generic `(q,r)`-biprojective/bivariate
  SBox constructor belongs in `packages/VBF/src/constructions/`.
- No other core-duplication violations: `gf_pow`, `gf_mul`, `primitive_polynomial`, `SBox`,
  `differential_uniformity`, `algebraic_degree`, `nonbent_signature`, `gold_apn` and
  `taniguchi_apn_representatives` are all correctly reused. `kim_apn` is the one core export
  that *should* have been used and was not (reproduction issue 2).

## Open Questions

- Proposition III.4 (ii)'s value 2 is inherited from reference [4] (Göloğlu–Pavlů), which
  was unavailable — is a different `η` definition in play there?
- Is `F₁(m=4)` genuinely EA-equivalent to `n8_Taniguchi_m1_a0_b2`? This needs
  `are_ea_equivalent`, which could not be run here.
- Is `F₀` in the Table I/II captions a real (undefined) family, or an extraction artifact?

The shared `biprojective_sbox` evaluator now comes from VBF. Paper scripts retain
their theorem-specific parameter selection and tests; the general evaluator does
not claim that arbitrary coefficients produce an APN function.
