# Gologlu_202207 — Biprojective Almost Perfect Nonlinear Functions

**Paper**: Göloğlu. "Biprojective Almost Perfect Nonlinear Functions." IEEE Transactions on
Information Theory **68**(7), 2022.

**Reproduction path**: `papers/2022/Gologlu_202207/`

**Verdict**: Partial

The two new families `F₁`, `F₂` and the sporadic `F₃` are constructed correctly, their
APN-ness is confirmed, and every reproduced Table I value matches. Beyond that the gap is
large: Sections III.A, IV, V (all lemmas), VI.A and VI.B are absent; Table III is reproduced
for 2 of 7 rows; Table II is unverifiable with the current core; and `F₁` for **even** `m` —
the paper's central novelty argument — is never built. The default `make report` path
launches an `n=14` computation that will hang or OOM, and one item skipped as "out of scope"
conceals a probable error in the paper (Proposition III.4 (ii)). Three genuine catalog gaps
at `n=10` fall out of the review.

> **Environment note**: Julia is not installed in the review environment, so `make test`
> could not be executed. All expected constants in the test files were independently
> re-derived in Python with `modulus = primitive_polynomial(5) = x⁵+x²+1` and the packing
> `x | (y<<m) → f | (g<<m)`.

---

## Paper Issues

### P1. Proposition III.4 (ii) appears to be wrong: `η_m(NB_κ) = 3`, not 2

- **Location**: Section III.B, Proposition III.4 (ii), proved "By computer".
- **Counter-evidence**, on the paper's own definition `κ(X) = X³ + X¹⁰ + U·X²⁴` with `U` a
  root of `X⁶+X⁴+X³+X+1` (= `conway_polynomial(6)`, exactly VBF's `kim_apn()`):

  ```
  κ            DU = 2   N_F = [21, 28, 3]   →  η_3 = 3
  x^3 (n=6)    DU = 2   N_F = [21, 28, 3]   →  η_3 = 3
  ```

  Proposition III.4 (i) predicts `η_3(NB_{x³}) = (2³+1)/3 = 3`, which the pipeline reproduces
  exactly — so the pipeline is calibrated. The value was computed three independent ways:
  (a) standard `F₂^6` dot-product components, (b) trace-pairing components `tr(U·κ(X))`, and
  (c) brute-force enumeration of all 3-dimensional `F₂` subspaces contained in `NB_κ`
  (`|NB_κ ∖ {0}| = 21` in all cases). All give 3.
- The paper's alternative `κ′ = X³+X¹⁰+b·X¹⁷` (`b³+b+1=0`) and its biprojective form
  `[(b,1,0,b+1)₂, (0,b,b,b+1)₂]` also give `N_F = [21,28,3]`, so this is not an artifact of
  representative choice. (`κ` and `x³` are genuinely CCZ-inequivalent — ortho-derivative DDT
  spectra `{0:2373, 2:1428, 4:168, 8:63}` vs `{0:2205, 2:1764, 8:63}` — so `N_F` simply fails
  to separate them at `n=6`.)
- **Consequence**: the paper's narrative that `κ` is distinguished from Gold by `η_m` at
  `m=3` does not hold; only the weaker `η_3(NB_κ) ≥ 2` survives.
- **Caveat**: flagged as a *probable* paper error. The paper gives no computation and the
  value is inherited from reference [4] (Göloğlu–Pavlů), which was not available for
  consultation.

### P2. Section III.A's Gold biprojective form holds only for odd `i`

- **Location**: Section III.A. The paper asserts, for `m` odd and `β = ω ∈ F₄∖F₂`,
  `G_i(x,y) = [(1,0,1,1)_{2^i}, (0,1,1,0)_{2^i}]` with no restriction on `i`.
- **Counter-evidence**: expanding `(x+ωy)^{2^i+1}`, `ω^{2^i} = ω²` when `i` is odd (giving the
  stated form) but `ω^{2^i} = ω` when `i` is even, yielding
  `[(1,0,0,1)_q, (0,1,1,1)_q]` instead.
- **Severity**: low. The stated pair is APN in every tested case (`m ∈ {3,5,7}`, all `i` with
  `gcd(i,m)=1`, DU = 2), so only the univariate identification is affected.

### P3. Table caption/label mismatch

- **Location**: Table I is captioned "for the Families `F₀`, `F₁`, `F₂` and the Function `F₃`"
  and Table II "For Families `F₀`, `F₁` and `F₂`", but `F₀` is never defined anywhere in the
  paper; the body rows are labelled `T` (Taniguchi) in Table I and left blank in Table II.
- **Caveat**: the supplied `.tex` is machine-extracted from the PDF, so this may be an
  extraction artifact rather than a publication error.

---

## Reproduction Issues

### 1. `proposition3_4_report()` silently launches an `n = 14` computation on the default report path

- **Location**: `proposition3_4.jl:78` (`for m in [5, 7]`), invoked unguarded from
  `report.jl:35` and from `Makefile:25-28` (`make proposition3_4`).
- **Symptom**: `make report` / `make proposition3_4` build six `SBox{14}` instances and call
  `nonbent_signature` on each. Per the paper's own Table II, an `F₂` member at `n=14` has
  `η₃ = 13 219 303`; `expand_subspaces`
  (`packages/VBF/src/linalg/subspace_in_set.jl:69-95`) materialises **every** subspace as a
  `Vector{Int}` *and* stores it in a `Set{Vector{Int}}` — i.e. ≥ 2.6 GB for the
  3-dimensional level alone, after roughly 9.2 × 10⁹ inner iterations (`1 681 988` 2-spaces ×
  `5 461` elements). The expected outcome is a hang or OOM, not a `[FAIL]`. Everything else in
  `report.jl` is `n ≤ 10`.
- **Root cause**: `table2.jl` correctly gates `n=14` behind `full_search=true`
  (`report.jl:38-43`), but `proposition3_4.jl` re-introduces `m = 7` on the default path.
- **Resolution plan**:
  1. Change `proposition3_4_report` to take `m_values::Vector{Int} = [3, 5]` and thread it
     through the `m in [5,7]` loop.
  2. Pass `m_values = full_search ? [3,5,7] : [3,5]` from `report.jl:35`.
  3. Add `println(io, "  [ -- ] Prop III.4 v at m=7 (n=14) — pass full_search=true")` on the
     skipped path.
  4. Correct `table2.jl:45` ("WARNING: each NF computation takes ~60s on modern hardware") —
     the measured cost at `n=14` is orders of magnitude larger. State the real bound or mark
     Table II unverifiable pending a bitset-based `expand_subspaces`.

### 2. Proposition III.4 (ii) is skipped with a factually incorrect justification

- **Location**: `proposition3_4.jl:58-63`
- **Symptom**: prints `[ -- ] Kim θ n=6 … out-of-scope`, justified by "Constructing the exact
  θ requires finding `U ∈ GF(2^6)` satisfying a specific degree-6 polynomial, which is beyond
  the scope of this fast verification". But `kim_apn()` is a **VBF core export**
  (`packages/VBF/src/constructions/sporadic_apn.jl:119`) that builds exactly
  `x³ ⊕ x¹⁰ ⊕ 2·x²⁴` over `conway_polynomial(6) = x⁶+x⁴+x³+x+1` — the paper's `κ` verbatim.
  The accompanying claim "θ and θ′ are CCZ-equiv but not EA-equiv; N_F differs" is
  computationally false: `N_F(κ) = N_F(κ′) = [21, 28, 3]`.
- **Root cause**: unawareness of the `kim_apn` core export; the accompanying claim was never
  computed.
- **Resolution plan**:
  1. Replace the two `println` lines with `K = kim_apn(); ηm = eta_m(K, 3)`.
  2. `print_check("Kim κ n=6: η_3(NB_F) = 2 (Prop III.4 ii)", ηm == 2)` — this will **FAIL**
     with `computed η_3 = 3`.
  3. Add a `print_kv` recording `N_F(κ) = [21,28,3]` alongside `N_F(x³) = [21,28,3]` and the
     ortho-derivative DDT spectra (`{0:2373,2:1428,4:168,8:63}` vs `{0:2205,2:1764,8:63}`) as
     evidence that `κ ≢_CCZ x³` while `N_F` coincides.
  4. Also build `κ′(X) = X³+X¹⁰+b·X¹⁷` and the biprojective `[(b,1,0,b+1)₂,(0,b,b,b+1)₂]` and
     check all three agree (they do), so the discrepancy cannot be blamed on the
     representative.
  5. Record the finding as a paper issue (P1) rather than a reproduction gap.

### 3. Family `F₁` is never exercised for even `m` — the paper's core novelty argument

- **Location**: `theorem3_2.jl:63` (default `m_values = [5, 7]`), `report.jl:34`
  (`m_values = [3, 5]`), `test/test_theorem3_2.jl` (only `m = 5`).
- **Symptom**: Section VI states "Note that the family `F₁` does not require `m` to be odd.
  This is enough to show that family `F₁` is new." No even-`m` instance is ever built. Worse,
  `m = 3` (used in `report.jl:34`) yields an **empty** candidate list, since `gcd(3i, 3) ≥ 3`
  for all `i` — so the report's "Theorem III.2 APN (m=3,5)" header claims coverage that does
  not exist.
- **Root cause**: `m_values` chosen without checking which `m` satisfy `gcd(3i, m) = 1`.
- **Resolution plan**:
  1. Add `m = 4` to the default `m_values` (`n = 8`, cheap). Verified: `F₁(m=4, i=1)` and
     `F₁(m=4, i=3)` are APN, `DU = 2`, `N_F = [85, 340]`.
  2. Drop `m = 3` from `report.jl:34`, or keep it and print an explicit "no admissible `i`"
     line.
  3. Add negative-parameter checks confirming the `gcd(3i,m)=1` hypothesis is necessary.
     Verified counter-evidence with the guard bypassed: `F₁(m=4,i=2)` DU = 16;
     `F₁(m=6,i=1)` DU = 128; `F₁(m=6,i=2)` DU = 256; `F₁(m=6,i=3)` DU = 8;
     `F₁(m=6,i=5)` DU = 128.

### 4. Table III is reproduced for 2 of 7 rows; two correct expected values sit unused as dead constants

- **Location**: `table1.jl:33-38` (`TABLE_III_EXPECTED`), `table1.jl:105-126`
- **Symptom**: `TABLE_III_EXPECTED["x3tr"]` and `["xu"]` are defined but never referenced
  (`grep` finds no use); only `x^3` and `x^9` are computed. `x^6+x^33+u^31 x^192` and
  `x^33+x^72+u^31 x^258` are absent entirely.
- **Root cause**: partial transcription.
- **Resolution plan** — all five remaining rows verified reproducible with
  `modulus = primitive_polynomial(10) = x^10+x^3+1` and `u = 2`:
  1. `x^3 + tr(x^9)` → `N_F = [341, 6820, 4215, 66, 1]` (build with `gf_trace`).
  2. `x^3 + u^341·x^36` → `N_F = [341, 6820, 4400]` (`u^341` is the primitive cube root of
     unity).
  3. `x^3 + u^1022·tr(u^3·x^9)` → `N_F = [341, 6820, 4250, 66, 1]`.
  4. `x^6 + x^33 + u^31·x^192` → `N_F = [341, 6820, 3720, 31]`.
  5. `x^33 + x^72 + u^31·x^258` → `N_F = [341, 6820, 3720, 31]`.
  6. Add `x^57` and `x^339` printing `N/A` (odd algebraic degree ⇒ not component-wise
     plateaued; matches the paper's `N/A`).
  7. Wire the `TABLE_III_EXPECTED` keys `x3tr` / `xu` into actual `print_check`s.

### 5. Proposition III.4 (iv) is not reproduced

- **Location**: `proposition3_4.jl` (no branch for part iv)
- **Symptom**: `F(X) = X³ + tr(X⁹)` with `η_m(NB_F) ≥ 1` is silently absent, even though
  `report.jl:29` claims "EXACT: … Proposition III.4 (m=3,5)".
- **Root cause**: omission.
- **Resolution plan**: build `x^3 ⊕ gf_trace(gf_pow(x,9,...))` over `GF(2^10)` and assert
  `eta_m(F,5) ≥ 1`. Verified: `N_F = [341, 6820, 4215, 66, 1]`, so `η_5 = 1` — it passes, and
  simultaneously supplies Table III row 5.

### 6. The Taniguchi family `T` in Table I is not reproduced in the paper's own parameterisation

- **Location**: `table1.jl:84-103`
- **Symptom**: with the default `include_taniguchi = false`, the `T` rows are only echoed from
  `TABLE_I_EXPECTED`; with `include_taniguchi = true` the code calls
  `taniguchi_apn_representatives(m)` and reports "distinct NF classes", which cannot be
  matched to the paper's `i = 1,4` / `i = 2,3` row indexing. The paper's `T` is
  `[(1,0,c,d)_{2^i}, (0,0,1,0)_{2^{2i}}]` (Section III.A) — directly constructible with the
  existing `biprojective_sbox`.
- **Root cause**: routed through the generic core family builder instead of the paper's
  biprojective form.
- **Resolution plan**:
  1. Add `t_sbox(m, i, c, d) = biprojective_sbox(m, i, (1,0,c,d), 2i, (0,0,1,0))`.
  2. Pick `(c,d)` satisfying the paper's `f(x,1) ≠ 0` condition — `c = d = 1` works for
     `m=5, i=1..4`.
  3. Verified target values: `i=1` → `[341,6820,3720,31]`; `i=2` → `[341,6820,3565]`;
     `i=3` → `[341,6820,3565]`; `i=4` → `[341,6820,3720,31]` — matching Table I `T_i14` /
     `T_i23` exactly, all DU = 2.
  4. Keep the `taniguchi_apn_representatives` cross-check as a secondary consistency test.

### 7. Sections III.A, IV, V-lemmas, VI.A and VI.B are missing without disclosure

- **Location**: `report.jl:31` declares only "OUT-OF-SCOPE: Lemma A.1/A.2 algebraic proofs,
  Proposition VI.2 BHK-F₁ details".
- **Symptom**: the following are silently absent, all computationally checkable at
  `m ∈ {3,5}`:
  - **Section III.A survey**: `κ′` as `[(b,1,0,b+1)₂,(0,b,b,b+1)₂]`; Gold as
    `[(1,0,1,1)_{2^i},(0,1,1,0)_{2^i}]`; Zhou–Pott `[(1,0,0,d)_{2^i},(0,0,1,0)_{2^j}]`;
    Taniguchi `T`; Carlet `C = [xy, (a,b,c,d)_r]`.
  - **Lemma III.6 / Lemma IV.1** (projective APN criterion): "`F` APN ⟺ `D_f^u = 0 = D_g^u`
    has exactly two solutions for each `u ∈ P¹(F_{2^m})`" — directly testable against
    `differential_uniformity`.
  - **Lemma IV.4** (i)–(iv) on `φ_q(x) = x^{q+1}+x+1`.
  - **Lemma V.2** (`λ_u` permutes `F_{2^m}` for `u ∈ F_{2^m}∖F₄`).
  - **Remark III.3**: `F₁ ~_EA [(1,0,1,1)_{2^i},(1,0,1,1)_{2^{m-2i}}]` via
    `L(x,y) = (x, y^{2^{m-2i}})`. Verified algebraically —
    `g^{2^{m-2i}} = x^{s+1} + x·y^s + y^{s+1}` with `s = 2^{m-2i}`.
  - **Section VI.B Walsh-spectrum claim**. Verified: for `F₁(i=1,2)`, `F₂(i=1,2)` and `F₃` at
    `n=10` the Walsh value set is exactly `{-64, -32, 0, 32, 64} = {0, ±2^{n/2}, ±2^{1+n/2}}`,
    matching the Gold spectrum as claimed.
  - **Section VI.B "not equivalent to a permutation"** — core exports
    `is_ccz_equivalent_to_permutation`.
- **Root cause**: scope set to the two new families plus Table I.
- **Resolution plan**:
  1. Add `section3a.jl` reproducing the five survey identifications (all `m = 3` or `m = 5`,
     cheap).
  2. Add `lemma4_4.jl` for `φ_q` (i)–(iv) and `lemma5_2.jl` for `λ_u` over `m ∈ {5,7}`.
  3. Add `lemma3_6.jl` implementing `D_f^u`, `D_g^u` and cross-checking the projective
     criterion against `differential_uniformity` for `F₁`, `F₂`, `F₃`.
  4. Add `remark3_3.jl` verifying the `F₁ ~_EA F′` output-map identity by LUT equality.
  5. Add `section6b.jl` computing `Set(lat(F))` and `is_ccz_equivalent_to_permutation(F)` for
     the five `n=10` functions.
  6. Update `report.jl:29-31` so the declared scope matches what is actually run.

---

## Items Reproduced Exactly

Every one independently re-verified with `modulus = primitive_polynomial(5) = x⁵+x²+1` and
packing `x | (y<<m) → f | (g<<m)`:

| Paper item | Reproduction | Verified value |
|---|---|---|
| Theorem III.2 `F₁ = [(1,0,1,1)_{2^i},(1,1,0,1)_{2^{2i}}]`, `m=5`, `i=1..4` | `theorem3_2.jl:24-27` | DU = 2, alg. degree 2 for all `i` |
| Theorem III.2 `F₂ = [(1,0,1,1)_{2^i},(0,1,1,0)_{2^{3i}}]`, `m=5`, `i=1..4` | `theorem3_2.jl:35-39` | DU = 2, alg. degree 2 for all `i` |
| Theorem V.4 `F₃ = [(0,1,1,0)₂,(1,u,u³,u¹³)_{2³}]`, `u` root of `x⁵+x²+1` | `theorem3_2.jl:48-54` | DU = 2, `u=2`, `u³=8`, `u¹³=28` |
| Prop III.4 (i) Gold `η_m = (2^m+1)/3` | `proposition3_4.jl:44-56` | `m=3`→3, `m=5`→11 |
| Prop III.4 (iii) `F₃`, `η_5 = 2` | `proposition3_4.jl:66-74` | 2 |
| Prop III.4 (v) `F₂`, `η_5 ≥ 1` | `proposition3_4.jl:76-89` (`m=5` part) | `η_5 = 1` for `i=1..4` |
| Table I `F₁` `i=1,4` | `table1.jl:21-29,59-67` | `[341, 6820, 3565]` |
| Table I `F₁` `i=2,3` | " | `[341, 6820, 3720, 31]` |
| Table I `F₂` `i=1,4` | " | `[341, 6820, 4030, 62, 1]` |
| Table I `F₂` `i=2,3` | " | `[341, 6820, 3720, 62, 1]` |
| Table I `F₃` | `table1.jl:77-82` | `[341, 6324, 2573, 62, 2]` |
| Table III `x^3`, `x^9` | `table1.jl:110-125` | `[341, 6820, 5115, 341, 11]` both |

`eta_m` indexing (`proposition3_4.jl:29-32`) is correct: `subspace_count_signature` returns
`[η₁, η₂, …, 0]`, so `sig[m] = η_m`.

## Test Results

| Command | Result |
|---------|--------|
| `make -C papers/2022/Gologlu_202207 test` | **Not run** — `julia` is not installed in the review environment |
| Independent re-derivation of all expected constants in `test/test_theorem3_2.jl`, `test/test_proposition3_4.jl`, `test/test_table1.jl` | **All confirmed** |

Note: the suite is not fast — `test_table1.jl` alone computes seven `n=10` nonbent signatures.

## Catalog Status

`packages/VBFCatalog/data-raw/apn_catalog/n10_apn.toml` currently contains exactly four
entries, all power functions: `n10_Gold_x3`, `n10_Gold_x9`, `n10_Kasami_x57`,
`n10_Dobbertin_x339`.

Equivalence evidence computed for all candidates (ortho-derivative DDT spectra — the repo's
canonical quadratic-APN CCZ invariant — plus `N_F`):

| function | `N_F` | ortho-derivative DDT spectrum |
|---|---|---|
| `n10_Gold_x3` | `[341,6820,5115,341,11]` | `{0:595386, 2:416361, 6:35805}` |
| `n10_Gold_x9` | `[341,6820,5115,341,11]` | `{0:713031, 2:211761, 4:92070, 6:15345, 8:5115, 12:10230}` |
| `F₁ i=1` | `[341,6820,3565]` | `{0:637701, 2:313131, 4:80910, 6:14415, 8:1395}` |
| `F₁ i=2` | `[341,6820,3720,31]` | `{0:626541, 2:330336, 4:79515, 6:10230, 8:930}` |
| `F₂ i=1` | `[341,6820,4030,62,1]` | `{0:624216, 2:334986, 4:76725, 6:11160, 8:465}` |
| `F₂ i=2` | `[341,6820,3720,62,1]` | `{0:640491, 2:304296, 4:89280, 6:13020, 8:465}` |
| `F₃` | `[341,6324,2573,62,2]` | `{0:632431, 2:322958, 4:77562, 6:13020, 8:1333, 10:186, 12:62}` |
| Taniguchi `T i=1` | `[341,6820,3720,31]` | `{0:635314, 2:317626, 4:80290, 6:11780, 8:2480, 10:62}` |
| Taniguchi `T i=2` | `[341,6820,3565]` | `{0:641514, 2:307706, 4:81375, 6:14880, 8:1705, 10:372}` |

All nine spectra are pairwise distinct. All five Göloğlu functions are quadratic (algebraic
degree 2), so by Yoshiara CCZ = EA; since none is EA-equivalent to a Gold function (distinct
`N_F` and OD spectra), by Dempwolff/Yoshiara none is CCZ-equivalent to any power function —
hence none is equivalent to `n10_Kasami_x57` or `n10_Dobbertin_x339` either.

Per-claim classification:

- **`F₂` (m=5, i∈{1,4})** — **missing** (paper claims new; CCZ-inequivalent to all four
  existing `n10` entries).
- **`F₂` (m=5, i∈{2,3})** — **missing** (a second, distinct EA class of the same family).
- **`F₃` (m=5)** — **missing** (the paper's sporadic function; also the only known non-Gold
  quadratic APN at `n=10` with `η_5 = 2`).
- **`F₁` (m=5, i∈{1,4} and i∈{2,3})** — **missing from the catalog, but not claimed new by
  the paper**: Section VI states "When `m=5`, `F₁` does not contain a new function as
  `{1,2,3,4} ≡ {±1, ±1/2} (mod 5)`", i.e. these coincide with the
  Budaghyan–Helleseth–Kaleyski quadrinomial family. BHK is itself absent from
  `n10_apn.toml`, so adding them is still a genuine catalog improvement — *optional*, and to
  be described as BHK ∩ `F₁`, not as new.
- **`F₁` (m=4, n=8)** — verified APN (`DU = 2`, `N_F = [85, 340]`) and it demonstrates the
  paper's even-`m` novelty claim, but `n=8` has thousands of known quadratic APN classes; per
  the caveat already recorded in `n8_Taniguchi2025_ex4_2`, absence from the catalog is not
  evidence of novelty. **Unverifiable** as a novelty claim; low priority.
- **`F₁`/`F₂` at m=7 (n=14)** — **unverifiable**: `nonbent_signature`/`are_ccz_equivalent` at
  `n=14` are computationally out of reach with the current `expand_subspaces` implementation
  (≈ 9.2 × 10⁹ iterations and ≥ 2.6 GB just for the 3-dimensional level).

### Catalog-gap records

Target file for all: `packages/VBFCatalog/data-raw/apn_catalog/n10_apn.toml`. LUTs (1024
entries each, exactly as `f1_sbox` / `f2_sbox` / `f3_sbox` produce them) are regenerable from
the builders named below.

**Record 1**
- `name = "n10_Gologlu2022_F2_i1"`
- `n = 10`, `m = 10`, `is_permutation = false`
- `lut`: `f2_sbox(5, 1)` — first 16 entries `0, 1, 8, 15, 10, 31, 23, 4, 26, 25, 3, 6, 9, 30, 5, 20`
- `algebraic_form = "Bivariate biprojective F(x,y) = [f,g] over GF(2^5), f = (1,0,1,1)_{2^1} = x^3 + x*y^2 + y^3, g = (0,1,1,0)_{2^3} = x^8*y + x*y^8; modulus x^5+x^2+1 (=37); packed z = x|(y<<5) -> f|(g<<5)"`
- `bib_key = "Gologlu_202207"`
- `source = "Göloğlu, 'Biprojective Almost Perfect Nonlinear Functions', IEEE Trans. Inf. Theory 68(7), 2022; Theorem III.2 family F₂ with m=5, i=1. LUT from f2_sbox(5, 1) (papers/2022/Gologlu_202207/theorem3_2.jl). Re-verified: differential_uniformity = 2, algebraic_degree = 2. N_F = [341, 6820, 4030, 62, 1] matches paper Table I row F₂ i=1,4."`
- Evidence: `N_F` and OD DDT spectrum `{0:624216, 2:334986, 4:76725, 6:11160, 8:465}` differ
  from every existing `n10` entry; quadratic ⇒ CCZ = EA; not EA-equivalent to Gold ⇒
  (Dempwolff/Yoshiara) not CCZ-equivalent to `x^57` or `x^339`.

**Record 2**
- `name = "n10_Gologlu2022_F2_i2"`
- `n = 10`, `m = 10`, `is_permutation = false`
- `lut`: `f2_sbox(5, 2)` — first 16 entries `0, 1, 5, 22, 17, 25, 4, 30, 31, 24, 18, 7, 20, 26, 9, 21`
- `algebraic_form = "... f = (1,0,1,1)_{2^2} = x^5 + x*y^4 + y^5, g = (0,1,1,0)_{2^6 mod 5 = 2^1} = x^2*y + x*y^2; modulus 37; packed z = x|(y<<5) -> f|(g<<5)"`
- `bib_key = "Gologlu_202207"`; `source` as above with `i = 2`
- Evidence: `N_F = [341, 6820, 3720, 62, 1]` (Table I row `F₂ i=2,3`); OD DDT
  `{0:640491, 2:304296, 4:89280, 6:13020, 8:465}` — distinct from Record 1 and from all
  existing entries.

**Record 3**
- `name = "n10_Gologlu2022_F3"`
- `n = 10`, `m = 10`, `is_permutation = false`
- `lut`: `f3_sbox()` — first 16 entries `0, 32, 832, 640, 96, 928, 864, 320, 352, 896, 480, 736, 800, 544, 992, 768`
- `algebraic_form = "Bivariate biprojective F(x,y) = [(0,1,1,0)_2, (1,u,u^3,u^13)_{2^3}] over GF(2^5), u = x root of x^5+x^2+1 (u=2, u^3=8, u^13=28); modulus 37; packed z = x|(y<<5) -> f|(g<<5)"`
- `bib_key = "Gologlu_202207"`
- `source = "Göloğlu (2022), Theorem V.4 / Proposition III.4 (iii) — sporadic biprojective APN on F_{2^10}. LUT from f3_sbox() (papers/2022/Gologlu_202207/theorem3_2.jl). Re-verified: differential_uniformity = 2, algebraic_degree = 2. N_F = [341, 6324, 2573, 62, 2] matches paper Table I. Notable: η_5(NB_F) = 2, a property otherwise shared only by Gold (odd m) and the sporadic Kim function — the necessary condition for CCZ-equivalence to a permutation."`
- Evidence: unique `η₁ = 6324` (all other `n10` quadratic APN examined have `6820`); OD DDT
  `{0:632431, 2:322958, 4:77562, 6:13020, 8:1333, 10:186, 12:62}` distinct from all others.

**Optional Records 4–5** (`F₁ i=1` / `F₁ i=2`, from `f1_sbox(5,1)` / `f1_sbox(5,2)`): same
shape, `algebraic_form` `f = (1,0,1,1)_{2^i}`, `g = (1,1,0,1)_{2^{2i}}`;
`N_F = [341,6820,3565]` and `[341,6820,3720,31]`. **The description must state** that at
`m=5` these coincide with the Budaghyan–Helleseth–Kaleyski quadrinomial family (paper
Section VI.A, Proposition VI.2) and are therefore *not* claimed new by Göloğlu.

## Library-Reuse Note

Excellent core reuse in `table1.jl` / `table2.jl` / `proposition3_4.jl`: `nonbent_signature`,
`gold_apn`, `taniguchi_apn_representatives`, `differential_uniformity`, `algebraic_degree`,
`gf_pow`, `gf_mul`, `primitive_polynomial`, `SBox`.

Reuse violations:

1. `helpers.jl:67-74` — `print_header` hand-rolls `"=" ^ 72` banners. Core exports
   `print_banner(io, lines...)` (`packages/VBF/src/io/report.jl:33`), which produces the
   identical format and is used correctly by `papers/2022/Kaleyski_202200/helpers.jl:17-21`.
   Fix: `print_banner(io, "Göloğlu (2022): Biprojective Almost Perfect Nonlinear Functions",
   "IEEE Transactions on Information Theory", "Julia $(VERSION) | $(Dates.now())")`. Note
   this also collides with `papers/2021/Calderini_202100`'s `print_header` — see that
   README's issue 5.
2. `proposition3_4.jl:58-63` — hand-waves the Kim function instead of calling the core export
   `kim_apn()`. See issue 2.
3. `table1.jl:14-15` — the header comment lists `load_catalog`, `load_sbox` in "VBF API used",
   but neither is used and `VBFCatalog` is not imported. Documentation drift.

Promote-to-core candidates:

1. `helpers.jl:27-65` — `biprojective_sbox(m, qi, coeff_f, rj, coeff_g; modulus)`. This is the
   generic `(q,r)`-biprojective pair builder of Definition III.1, and the *same* construction
   is independently re-implemented in `papers/2023/Calderini_202306` (`family_f1_lut` /
   `family_f2_lut`, per the `algebraic_form` fields of `n12_CalderiniLiVilla2023_F1/F2`) and
   imported by `papers/2021/Calderini_202100`. It belongs in
   `packages/VBF/src/constructions/biprojective.jl` alongside `taniguchi_apn`, with the
   Gold / Zhou–Pott / Taniguchi / Carlet-`C` special cases as named wrappers.
2. `helpers.jl:81-84` — `drop_trailing_zeros`. `subspace_count_signature`
   (`packages/VBF/src/linalg/subspace_in_set.jl:104-114`) always appends exactly one
   terminating `0` and every consumer then strips it. Either add a `trim::Bool` keyword to
   `nonbent_signature` / `subspace_count_signature`, or drop the sentinel in core.
3. A bitset-backed `expand_subspaces` (see issue 1) — currently the hard blocker on any
   `n ≥ 12` `N_F` computation.
